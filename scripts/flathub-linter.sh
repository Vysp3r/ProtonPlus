#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}/.."

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
echo -e "\n\n\n\nLinter Results:\n"
flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest "${BUILD_MANIFEST}"
flatpak run --command=flatpak-builder-lint org.flatpak.Builder appstream "${BUILD_DIR}/export/share/metainfo/com.vysp3r.ProtonPlus.metainfo.xml"
flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo "${BUILD_OSTREE_REPO}"

set +x
echo -e "\nSome linter errors regarding external icons, screenshots or screenshot files may happen in a local build but not on Flathub. Those can be safely ignored."
echo -e "\nAlways ignore the following linter errors:\n- \"appid-filename-mismatch: com.vysp3r.ProtonPlus.local\" (because we perform linting of the local development source code)\n- \"finish-args-flatpak-spawn-access\" (it's the only way for us to install Runners on the Host)"
