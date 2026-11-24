#!/bin/sh

set -eu

echo "Installing AppImage build dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
    git \
    meson \
    ninja \
    vala \
    gcc \
    pkgconf \
    gtk4 \
    libadwaita \
    json-glib \
    libsoup3 \
    libgee \
    libarchive \
    gettext \
    desktop-file-utils \
    appstream \
    libxml2 \
    bluez-libs \
    libnm \
    glib-networking \
    libproxy \
    patchelf \
    sdl3

if command -v get-debloated-pkgs >/dev/null 2>&1; then
    # The stock packages above also work when the optional GitHub release is unavailable.
    if [ -z "${SOURCE:-}" ] && command -v curl >/dev/null 2>&1; then
        package_list=https://api.github.com/repos/pkgforge-dev/archlinux-pkgs-debloated/releases/latest
        if ! headers=$(curl --fail --silent --head --max-time 10 "$package_list") ||
            printf '%s\n' "$headers" | grep -Eiq '^x-ratelimit-remaining:[[:space:]]*0[[:space:]]*$'; then
            printf '%s\n' 'Optional AppImage dependency packages are unavailable. Using stock Arch packages.'
            exit 0
        fi
    fi
    echo "Installing debloated packages..."
    echo "---------------------------------------------------------------"
    get-debloated-pkgs --add-common --prefer-nano
fi
