#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}/.."

BUILD_DIR="build-native"
meson "${BUILD_DIR}" --wipe --prefix=/usr
cd "${BUILD_DIR}"
ninja

if [[ "$1" == "run" ]]; then
  cd src
  ./com.vysp3r.ProtonPlus
fi
