#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}/.."

BUILD_VARIANT="local"
BUILD_MANIFEST="com.vysp3r.ProtonPlus.local.yml"
BUILD_DIR="build-flatpak/${BUILD_VARIANT}/build"
BUILD_OSTREE_REPO="build-flatpak/${BUILD_VARIANT}/repo"
flatpak run org.flatpak.Builder --verbose \
  --sandbox --force-clean --ccache --user --install \
  "${BUILD_DIR}" \
  "${BUILD_MANIFEST}"

if [[ "$1" == "run" ]]; then
  flatpak run --user protonplus
fi
