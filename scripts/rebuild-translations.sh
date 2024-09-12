#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}/.."

# We must first perform a native build.
BUILD_DIR="build-native"
meson "${BUILD_DIR}" --wipe --prefix=/usr
cd "${BUILD_DIR}"
ninja

# Now we can update the translations.
ninja com.vysp3r.ProtonPlus-update-po
