#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}/.."

# We must first perform a native build.
meson build --wipe --prefix=/usr
cd build
ninja

# Now we can update the translations.
ninja com.vysp3r.ProtonPlus-update-po
