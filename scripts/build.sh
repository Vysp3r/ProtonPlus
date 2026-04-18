#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." &> /dev/null && pwd)"

# Colors for logging
RESET="\033[0m"
YELLOW="\033[33m"
GREEN="\033[32m"
RED="\033[31m"
CYAN="\033[36m"

show_log() {
  local message_type="$1"
  local message="$2"

  local color
  case "${message_type}" in
    INFO)  color="${YELLOW}" ;;
    PASS)  color="${GREEN}" ;;
    ERROR) color="${RED}" ;;
    *)     color="${RESET}" ;;
  esac

  local fd=1
  [[ "${message_type}" == "ERROR" ]] && fd=2

  printf "${color}[%s]${RESET} ${CYAN}%s${RESET}\n" "${message_type}" "${message}" >&$fd
}

check_dependencies() {
  local missing=false
  for dep in "$@"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      show_log "ERROR" "Missing dependency: $dep"
      missing=true
    fi
  done
  if [[ "$missing" == "true" ]]; then
    exit 1
  fi
}

flatpak_dependency_check() {
  show_log "INFO" "Ensuring required Flatpak dependencies are installed..."
  flatpak install -y runtime/org.gnome.Sdk/x86_64/50 runtime/org.gnome.Platform/x86_64/50 runtime/org.freedesktop.Sdk.Extension.vala/x86_64/25.08 org.flatpak.Builder
  show_log "PASS" "Required dependencies are installed."
}

build() {
  local variant="$1"
  local manifest="$2"
  local run_mode="${3:-}"

  if [[ "${variant}" == "native" ]]; then
    check_dependencies meson ninja
    show_log "INFO" "Starting native build..."
    local build_dir="build-native"
    show_log "INFO" "Configuring build directory: ${build_dir}"
    meson "${build_dir}" --wipe --prefix=/usr
    (
      cd "${build_dir}" || exit 1
      show_log "INFO" "Building files using Ninja..."
      ninja

      if [[ "${run_mode}" == "run" ]]; then
        show_log "PASS" "Running native build..."
        cd src || exit 1
        ./protonplus
      fi
    )
  else
    check_dependencies flatpak
    flatpak_dependency_check
    show_log "INFO" "Starting Flatpak build for variant: ${variant}..."
    local build_dir="build-flatpak/${variant}/build"
    show_log "INFO" "Configuring build directory: ${build_dir}"
    flatpak run org.flatpak.Builder --verbose \
      --sandbox --force-clean --ccache --user --install \
      "${build_dir}" \
      "${manifest}"

    if [[ "${run_mode}" == "run" ]]; then
      show_log "PASS" "Running Flatpak build..."
      flatpak run --user com.vysp3r.ProtonPlus
    fi
  fi
}

clean() {
  show_log "INFO" "Cleaning build directories..."
  local directories=(
    "_build"
    ".flatpak-builder"
    ".flatpak"
    "build-dir"
    "build-flatpak"
    "build-native"
    "build"
  )

  local cleaned_count=0

  for dir in "${directories[@]}"; do
    if [[ -d "${dir}" ]]; then
      show_log "INFO" "Removing directory: ${dir}"
      rm -rf -- "${dir}"
      ((cleaned_count++))
    fi
  done

  if (( cleaned_count > 0 )); then
    show_log "PASS" "Cleaned $cleaned_count directories."
  else
    show_log "INFO" "No directories were cleaned."
  fi
}

rebuild_translations() {
  show_log "INFO" "Building native files before updating translations..."
  check_dependencies python3
  python3 scripts/extract-translatables.py data/runners.json src/translatables.vala
  build "native" "" ""
  (
    cd build-native || exit 1
    show_log "INFO" "Updating translation files..."
    ninja com.vysp3r.ProtonPlus-update-po
  )
  show_log "PASS" "Translations updated successfully."
}

generate_icons() {
  show_log "INFO" "Checking required dependencies..."
  check_dependencies optipng inkscape
  show_log "PASS" "Dependency check successful."
  show_log "INFO" "Generating icons..."

  local SVG_DIR="data/logo"
  local EXPORT_DIR="data/logo/icons/hicolor"
  local ICON_SIZES=(512 256 128 64 48 32 16)

  for svg_file in "${SVG_DIR}"/*.svg; do
    local svg_name="$(basename "${svg_file}")"

    for size in "${ICON_SIZES[@]}"; do
      local png_output_dir="${EXPORT_DIR}/${size}x${size}/apps"
      if [[ ! -d "${png_output_dir}" ]]; then
        mkdir -p "${png_output_dir}"
      fi

      local png_file="${png_output_dir}/${svg_name%.*}.png"

      inkscape --export-type="png" \
        --export-filename="${png_file}" \
        --export-area-page \
        --export-width="${size}" \
        --export-height="${size}" \
        "${svg_file}"

      optipng -o7 "${png_file}"
    done
  done

  show_log "PASS" "Icons successfully generated."
}

flathub_linter() {
  show_log "INFO" "Linting the local source code..."

  check_dependencies flatpak
  flatpak_dependency_check

  # We must perform a Flatpak build *and* export to a ostree "repo" directory.
  # NOTE: We will perform a LOCAL build so that we check the LOCAL manifest.
  # NOTE: We don't trigger INSTALL in this case, since we're just linting.
  local BUILD_VARIANT="local"
  local BUILD_MANIFEST="com.vysp3r.ProtonPlus.local.yml"
  local BUILD_DIR="build-flatpak/${BUILD_VARIANT}/build"
  local BUILD_OSTREE_REPO="build-flatpak/${BUILD_VARIANT}/repo"

  flatpak run org.flatpak.Builder --verbose \
    --sandbox --force-clean --ccache \
    --repo="${BUILD_OSTREE_REPO}" \
    "${BUILD_DIR}" \
    "${BUILD_MANIFEST}"

  # Allow command failures after this point, since linters may exit with errors.
  set +e

  # Now we can run the Flathub linters.
  flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest "${BUILD_MANIFEST}"
  flatpak run --command=flatpak-builder-lint org.flatpak.Builder appstream "${BUILD_DIR}/export/share/metainfo/com.vysp3r.ProtonPlus.metainfo.xml"
  flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo "${BUILD_OSTREE_REPO}"

  set -e
  show_log "INFO" "The following errors can be safely ignored."
  show_log "INFO" "\"appstream-screenshots-not-mirrored-in-ostree\" (only happen in local build, but will not happen on Flathub)"
  show_log "INFO" "\"appstream-external-screenshot-url\" (only happen in local build, but will not happen on Flathub)"
  show_log "INFO" "\"finish-args-flatpak-appdata-folder-access\" (we need to access the host filesystem since Steam libraries can be anywhere)"
  show_log "INFO" "\"finish-args-flatpak-spawn-access\" (necessary to be able to manage STL)"
  show_log "INFO" "\"appid-filename-mismatch: com.vysp3r.ProtonPlus.local\" (only happens on the local source code)"
  show_log "INFO" "Done linting the local source code..."
}

show_help() {
  cat <<EOF
ProtonPlus Build Script

Usage: $(basename "$0") COMMAND [ARGS]

Commands:
  local [run]       Build Flatpak using local manifest (com.vysp3r.ProtonPlus.local.yml)
  flathub [run]     Build Flatpak using Flathub manifest (com.vysp3r.ProtonPlus.yml)
  native [run]      Build natively using meson and ninja
  translations      Update translation files (.po)
  icons             Generate icons from SVG
  linter            Run Flathub linter on local source
  appimage          Build AppImage using sharun
  clean             Remove all build-related directories
  help              Show this help message

Options:
  run               If provided, the application will be launched after a successful build
EOF
}

main() {
  cd "${ROOT_DIR}"

  case "${1:-}" in
    local)
      build "local" "com.vysp3r.ProtonPlus.local.yml" "${2:-}"
      ;;
    flathub)
      build "flathub" "com.vysp3r.ProtonPlus.yml" "${2:-}"
      ;;
    native)
      build "native" "" "${2:-}"
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
      ./make-appimage.sh
      ;;
    clean)
      clean
      ;;
    help|--help|-h)
      show_help
      return 0
      ;;
    *)
      if [[ -n "${1:-}" ]]; then
        show_log "ERROR" "Unknown command: ${1:-}"
      fi
      show_help
      exit 1
      ;;
  esac

  show_log "PASS" "Finished: ${1:-}"
}

main "$@"