#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}/.."

flatpak-builder --user --install --force-clean --verbose \
  build-dir \
  com.vysp3r.ProtonPlus.local.yml
