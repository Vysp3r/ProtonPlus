#!/bin/sh

set -eu

echo "Installing package dependencies..."
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
    appstream-glib \
    bluez-libs \
    libnm \
    glib-networking \
    libproxy \
    patchelf \
    sdl3 \
    libnotify

if command -v get-debloated-pkgs >/dev/null 2>&1; then
    echo "Installing debloated packages..."
    echo "---------------------------------------------------------------"
    get-debloated-pkgs --add-common --prefer-nano
fi
