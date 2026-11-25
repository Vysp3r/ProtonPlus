#!/bin/sh

set -eu

mode=${1:---stock-only}
case "$mode" in
    --stock-only|--try-debloated) ;;
    *)
        printf 'Usage: %s [--stock-only|--try-debloated]\n' "$0" >&2
        exit 2
        ;;
esac
: "${VERSION:?Set VERSION to the source archive version}"
: "${ARCH:?Set ARCH to the host architecture}"
test "$(uname -m)" = "$ARCH"

archive="$(pwd)/ProtonPlus-$VERSION-source.tar.gz"
output="$(pwd)/ProtonPlus-$VERSION/dist"
test -s "$archive"
mkdir -p "$output"

# Resolve the image once so a retry starts from the same pristine image.
image=ghcr.io/pkgforge-dev/archlinux:latest
docker pull "$image"
image=$(docker image inspect --format '{{.Id}}' "$image")

build_container() {
    docker run --rm --entrypoint /bin/sh \
        --env VERSION --env GITHUB_REPOSITORY \
        --mount "type=bind,src=$archive,dst=/source.tar.gz,readonly" \
        --mount "type=bind,src=$output,dst=/output" \
        "$image" -ec '
            build_dir=$(mktemp -d) || exit 1
            cd "$build_dir" || exit 1
            tar -xf /source.tar.gz || exit 1
            cd "ProtonPlus-$VERSION" || exit 1

            pacman-key --init || exit 1
            pacman -Sy --noconfirm archlinux-keyring || exit 1
            tools=https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/main/useful-tools

            # Reserve status 75 for the optional stage. Install the helper
            # after the stock package transaction supplies curl.
            if [ "$1" = --try-debloated ]; then
                export PROTONPLUS_APPIMAGE_HELPER_URL="$tools/get-debloated-pkgs.sh"
            fi
            /bin/sh packaging/appimage/get-dependencies.sh "$1"
            curl --fail --location --retry 3 --output /usr/local/bin/quick-sharun \
                "$tools/quick-sharun.sh" || exit 1
            chmod +x /usr/local/bin/quick-sharun || exit 1
            /bin/sh packaging/appimage/build.sh --verify-environment || exit 1
            cp dist/*.AppImage dist/*.AppImage.zsync /output/ || exit 1
        ' sh "$1"
}

if build_container "$mode"; then
    exit 0
else
    status=$?
fi

if [ "$mode" = --try-debloated ] && [ "$status" -eq 75 ]; then
    echo "Retrying AppImage build in a fresh stock Arch container."
    build_container --stock-only
else
    exit "$status"
fi
