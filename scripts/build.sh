#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"

RESET="\033[0m"
YELLOW="\033[33m"
GREEN="\033[32m"
RED="\033[31m"
CYAN="\033[36m"

show_log() {
  local message_type="$1"
  local message="$2"
  local color
  local fd=1

  case "${message_type}" in
    INFO) color="${YELLOW}" ;;
    PASS) color="${GREEN}" ;;
    ERROR)
      color="${RED}"
      fd=2
      ;;
    *) color="${RESET}" ;;
  esac

  if [[ ! -t "${fd}" || -n "${NO_COLOR:-}" ]]; then
    printf '[%s] %s\n' "${message_type}" "${message}" >&"${fd}"
    return
  fi

  printf '%b[%s]%b %b%s%b\n' \
    "${color}" "${message_type}" "${RESET}" \
    "${CYAN}" "${message}" "${RESET}" >&"${fd}"
}

check_dependencies() {
  local missing=false
  local dependency

  for dependency in "$@"; do
    if ! command -v "${dependency}" >/dev/null 2>&1; then
      show_log "ERROR" "Missing dependency: ${dependency}"
      missing=true
    fi
  done

  if [[ "${missing}" == "true" ]]; then
    return 1
  fi
}

flatpak_dependency_check() {
  local architecture
  architecture="$(flatpak --default-arch)"

  show_log "INFO" "Ensuring required Flatpak dependencies are installed..."
  flatpak install -y \
    "runtime/org.gnome.Sdk/${architecture}/50" \
    "runtime/org.gnome.Platform/${architecture}/50" \
    "runtime/org.freedesktop.Sdk.Extension.vala/${architecture}/25.08" \
    org.flatpak.Builder
  show_log "PASS" "Required dependencies are installed."
}

configure_meson_build() {
  local build_dir="$1"
  shift

  local setup_args=(setup "${build_dir}" --prefix=/usr "$@")
  if [[ -f "${build_dir}/meson-private/coredata.dat" ]]; then
    setup_args+=(--reconfigure)
  fi

  show_log "INFO" "Configuring build directory: ${build_dir}"
  meson "${setup_args[@]}"
}

compile_schemas_for_build() {
  local build_dir="$1"
  local schema_dir="${build_dir}/data/glib-2.0/schemas"

  mkdir -p "${schema_dir}"
  cp "${ROOT_DIR}/data/com.vysp3r.ProtonPlus.gschema.xml" "${schema_dir}/"
  glib-compile-schemas "${schema_dir}"
}

build_native() {
  local run_mode="${1:-}"
  local build_dir="${ROOT_DIR}/build-native"

  case "${run_mode}" in
    "" | run | debug) ;;
    *)
      show_log "ERROR" "Unknown native run mode: ${run_mode}"
      return 1
      ;;
  esac

  check_dependencies glib-compile-schemas meson ninja
  if [[ "${run_mode}" == "debug" ]]; then
    check_dependencies gdb
  fi

  show_log "INFO" "Starting native build..."
  configure_meson_build "${build_dir}"
  meson compile -C "${build_dir}"
  compile_schemas_for_build "${build_dir}"

  case "${run_mode}" in
    "") ;;
    run)
      show_log "INFO" "Running native build..."
      env \
        LOCALE_DIR="${build_dir}/po" \
        XDG_DATA_DIRS="${build_dir}/data:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
        "${build_dir}/src/protonplus"
      ;;
    debug)
      show_log "INFO" "Running native build with GDB..."
      env \
        LOCALE_DIR="${build_dir}/po" \
        XDG_DATA_DIRS="${build_dir}/data:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
        gdb -batch -ex run -ex bt "${build_dir}/src/protonplus"
      ;;
  esac
}

build_native_debug() {
  local build_dir="/tmp/protonplus-build-debug"

  check_dependencies glib-compile-schemas meson ninja
  show_log "INFO" "Starting native debug build..."
  configure_meson_build "${build_dir}" --buildtype=debug
  meson compile -C "${build_dir}"
  compile_schemas_for_build "${build_dir}"
}

check_native_dependencies() {
  local build_dir
  local status=0

  check_dependencies glib-compile-schemas meson ninja valac
  build_dir="$(mktemp -d "${TMPDIR:-/tmp}/protonplus-native-deps.XXXXXX")"

  show_log "INFO" "Checking native build dependencies with Meson..."
  if ! meson setup \
    "${build_dir}" \
    --prefix=/usr \
    --wrap-mode=nodownload; then
    show_log "ERROR" "Native dependency check failed."
    status=1
  else
    show_log "PASS" "Native build dependencies are available."
  fi

  rm -rf -- "${build_dir}"
  return "${status}"
}

build_flatpak() {
  local variant="$1"
  local manifest="$2"
  local run_mode="${3:-}"
  local build_dir="build-flatpak/${variant}/build"

  if [[ -n "${run_mode}" && "${run_mode}" != "run" ]]; then
    show_log "ERROR" "Unknown Flatpak run mode: ${run_mode}"
    return 1
  fi

  check_dependencies flatpak
  flatpak_dependency_check
  show_log "INFO" "Starting Flatpak build for variant: ${variant}..."
  flatpak run org.flatpak.Builder --verbose \
    --sandbox --force-clean --ccache --user --install \
    "${build_dir}" \
    "${manifest}"

  if [[ "${run_mode}" == "run" ]]; then
    show_log "INFO" "Running Flatpak build..."
    flatpak run --user com.vysp3r.ProtonPlus
  fi
}

clean() {
  local directories=(
    "${ROOT_DIR}/_build"
    "${ROOT_DIR}/.flatpak-builder"
    "${ROOT_DIR}/.flatpak"
    "${ROOT_DIR}/build"
    "${ROOT_DIR}/build-appimage"
    "${ROOT_DIR}/build-dir"
    "${ROOT_DIR}/build-flatpak"
    "${ROOT_DIR}/build-native"
    "${ROOT_DIR}/build-native-debug"
    "${ROOT_DIR}/build-tests"
    "${ROOT_DIR}/builddir"
    "${ROOT_DIR}/dist"
    "/tmp/protonplus-build-debug"
  )
  local cleaned_count=0
  local directory

  show_log "INFO" "Cleaning build directories..."
  for directory in "${directories[@]}"; do
    if [[ -d "${directory}" ]]; then
      show_log "INFO" "Removing directory: ${directory}"
      rm -rf -- "${directory}"
      ((cleaned_count += 1))
    fi
  done

  if ((cleaned_count > 0)); then
    show_log "PASS" "Cleaned ${cleaned_count} directories."
  else
    show_log "INFO" "No directories were cleaned."
  fi
}

rebuild_translations() {
  show_log "INFO" "Building native files before updating translations..."
  build_native
  show_log "INFO" "Updating translation files..."
  meson compile -C "${ROOT_DIR}/build-native" com.vysp3r.ProtonPlus-update-po
  show_log "PASS" "Translations updated successfully."
}

generate_icons() {
  local svg_file="${ROOT_DIR}/data/icons/com.vysp3r.ProtonPlus.svg"
  local export_dir="${ROOT_DIR}/data/icons/hicolor"
  local icon_sizes=(512 256 128 64 48 32 16)
  local size

  check_dependencies rsvg-convert
  show_log "INFO" "Generating application icons..."

  for size in "${icon_sizes[@]}"; do
    local png_output_dir="${export_dir}/${size}x${size}/apps"
    local png_file="${png_output_dir}/com.vysp3r.ProtonPlus.png"

    mkdir -p "${png_output_dir}"
    rsvg-convert \
      --width="${size}" \
      --height="${size}" \
      --output="${png_file}" \
      "${svg_file}"
  done

  show_log "PASS" "Icons successfully generated."
}

flathub_linter() {
  local build_variant="local"
  local build_manifest="com.vysp3r.ProtonPlus.local.yml"
  local build_dir="build-flatpak/${build_variant}/build"
  local ostree_repo="build-flatpak/${build_variant}/repo"

  show_log "INFO" "Linting the local source code..."
  check_dependencies flatpak
  flatpak_dependency_check

  # Build and export to an OSTree repository so every Flathub linter can run.
  flatpak run org.flatpak.Builder --verbose \
    --sandbox --force-clean --ccache \
    --repo="${ostree_repo}" \
    "${build_dir}" \
    "${build_manifest}"

  # These diagnostics are advisory because local builds have expected differences.
  set +e
  flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest "${build_manifest}"
  flatpak run --command=flatpak-builder-lint org.flatpak.Builder appstream \
    "${build_dir}/export/share/metainfo/com.vysp3r.ProtonPlus.metainfo.xml"
  flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo "${ostree_repo}"
  set -e

  show_log "INFO" "The following local-build diagnostics can be safely ignored:"
  show_log "INFO" "appstream-screenshots-not-mirrored-in-ostree"
  show_log "INFO" "appstream-external-screenshot-url"
  show_log "INFO" "finish-args-flatpak-appdata-folder-access"
  show_log "INFO" "finish-args-flatpak-spawn-access"
  show_log "INFO" "appid-filename-mismatch: com.vysp3r.ProtonPlus.local"
  show_log "PASS" "Finished linting the local source code."
}

show_help() {
  cat <<EOF
ProtonPlus Build Script

Usage: $(basename "$0") COMMAND [ARGS]

Commands:
  local [run]        Build Flatpak using the local manifest
  flathub [run]      Build Flatpak using the Flathub manifest
  native [run|debug] Build natively, optionally running the result
  native-debug       Build a native debug binary for an external debugger
  native-deps        Check native build tools and libraries
  translations       Update translation files (.po)
  icons              Regenerate application icons from the SVG source
  linter             Run Flathub linters on the local source
  appimage           Build an AppImage using sharun
  clean              Remove build-related directories
  help               Show this help message
EOF
}

main() {
  cd "${ROOT_DIR}"

  case "${1:-}" in
    local)
      build_flatpak "local" "com.vysp3r.ProtonPlus.local.yml" "${2:-}"
      ;;
    flathub)
      build_flatpak "flathub" "com.vysp3r.ProtonPlus.yml" "${2:-}"
      ;;
    native)
      build_native "${2:-}"
      ;;
    native-debug)
      build_native_debug
      ;;
    native-deps)
      check_native_dependencies
      ;;
    translations)
      rebuild_translations
      ;;
    icons)
      generate_icons
      ;;
    linter)
      flathub_linter
      ;;
    appimage)
      "${SCRIPT_DIR}/make-appimage.sh"
      ;;
    clean)
      clean
      ;;
    help | --help | -h)
      show_help
      return 0
      ;;
    *)
      if [[ -n "${1:-}" ]]; then
        show_log "ERROR" "Unknown command: ${1}"
      fi
      show_help
      return 1
      ;;
  esac

  show_log "PASS" "Finished: ${1}"
}

main "$@"
