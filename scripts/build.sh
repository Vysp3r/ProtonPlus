#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

show_log() {
  local message_type="$1"
  local message="$2"

  local RESET="\033[0m"
  local YELLOW="\033[33m"
  local GREEN="\033[32m"
  local RED="\033[31m"
  local CYAN="\033[36m"

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

build() {
  local variant="$1"
  local manifest="$2"
  local run_mode="${3:-}"

  if [[ "${variant}" == "native" ]]; then
    show_log "INFO" "Starting native build..."
    local build_dir="build-native"
    show_log "INFO" "Configuring build directory: ${build_dir}"
    meson "${build_dir}" --wipe --prefix=/usr
    cd "${build_dir}" || return 1
    show_log "INFO" "Building files using Ninja..."
    ninja

    if [[ "${run_mode}" == "run" ]]; then
      show_log "PASS" "Running native build..."
      cd src || return 1
      ./protonplus
    fi
  else
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
  build "native" "" ""
  cd ../build-native
  show_log "INFO" "Updating translation files..."
  ninja com.vysp3r.ProtonPlus-update-po
  show_log "PASS" "Translations rebuilt successfully."
}

generate_icons() {
    show_log "INFO" "Checking required dependencies..."

    MISSING_DEPENDENCY=false

    if ! command -v optipng >/dev/null 2>&1 ; then
        MISSING_DEPENDENCY=true
        show_log "ERROR" "Missing optipng dependency."
    fi

    if ! command -v inkscape >/dev/null 2>&1 ; then
        MISSING_DEPENDENCY=true
        show_log "ERROR" "Missing inkscape dependency."
    fi
    
    if $MISSING_DEPENDENCY = true ; then
        show_log "ERROR" "Dependency check failed."
        exit 1;
    fi

    show_log "PASS" "Dependency check successful."

    show_log "INFO" "Generating icons..."

    SVG_DIR="data/logo"
    EXPORT_DIR="data/logo/icons/hicolor"
    ICON_SIZES=(512 256 128 64 48 32 16)

    for svg_file in "${SVG_DIR}"/*.svg; do
        svg_name="$(basename "${svg_file}")"

        for size in "${ICON_SIZES[@]}"; do
            png_output_dir="${EXPORT_DIR}/${size}x${size}/apps"
            if [[ ! -d "${png_output_dir}" ]]; then
                mkdir -p "${png_output_dir}"
            fi

            png_file="${png_output_dir}/${svg_name%.*}.png"

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

    # We must perform a Flatpak build *and* export to a ostree "repo" directory.
    # NOTE: We will perform a LOCAL build so that we check the LOCAL manifest.
    # NOTE: We don't trigger INSTALL in this case, since we're just linting.
    BUILD_VARIANT="local"
    BUILD_MANIFEST="com.vysp3r.ProtonPlus.local.yml"
    BUILD_DIR="build-flatpak/${BUILD_VARIANT}/build"
    BUILD_OSTREE_REPO="build-flatpak/${BUILD_VARIANT}/repo"
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

    set +x
    show_log "INFO" "The following errors can be safely ignored."
    show_log "INFO" "\"appstream-screenshots-not-mirrored-in-ostree\" (only happen in local build, but will not happen on Flathub)"
    show_log "INFO" "\"appstream-external-screenshot-url\" (only happen in local build, but will not happen on Flathub)"
    show_log "INFO" "\"finish-args-flatpak-appdata-folder-access\" (we need to access the host filesystem since Steam libraries can be anywhere)"
    show_log "INFO" "\"finish-args-flatpak-spawn-access\" (necessary to be to manage STL)"
    show_log "INFO" "\"appid-filename-mismatch: com.vysp3r.ProtonPlus.local\" (only happens on the local source code)"
    show_log "INFO" "Done linting the local source code..."
}

main() {
  cd "${SCRIPT_DIR}/.."

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
    clean)
      clean
      ;;
    *)
      show_log "ERROR" "Usage: $0 {local|flathub|native|clean} [run] or {translations|icons|linter}"
      exit 1
      ;;
  esac
}

main "$@"