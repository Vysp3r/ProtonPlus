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

# Reinstall the requested packages from the Arch repositories, even when the
# image already has the same versions. Keep this inventory for the file check.
set -- base-devel curl wget git meson ninja vala gcc pkgconf glib2 cairo gtk4 libadwaita \
    json-glib libsoup3 libgee libarchive sqlite libyaml gettext desktop-file-utils appstream \
    libxml2 bluez-libs libnm glib-networking libproxy mesa patchelf sdl3 \
    libx11 libxrandr libxss pulseaudio pulseaudio-alsa xorg-server-xvfb zsync

echo "Installing stock AppImage build dependencies..."
pacman -Syu --noconfirm "$@" || exit 1
pacman -Qk "$@" || exit 1

if [ "$mode" = --stock-only ]; then
    exit 0
fi

if [ -n "${PROTONPLUS_APPIMAGE_HELPER_URL:-}" ]; then
    if ! curl --fail --location --retry 3 --output /usr/local/bin/get-debloated-pkgs \
        "$PROTONPLUS_APPIMAGE_HELPER_URL" ||
        ! chmod +x /usr/local/bin/get-debloated-pkgs; then
        echo "Could not prepare the optional AppImage dependency helper." >&2
        exit 75
    fi
fi

if command -v get-debloated-pkgs >/dev/null 2>&1; then
    echo "Installing optional debloated packages..."
    if get-debloated-pkgs --add-common --prefer-nano; then
        exit 0
    fi
    echo "Optional AppImage dependencies failed. Discard this build environment." >&2
    exit 75
fi
