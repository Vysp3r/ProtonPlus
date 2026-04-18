#!/bin/sh
set -eu
ARCH=$(uname -m)

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
    libappstream-glib \
    bluez-libs \
    libnm \
    glib-networking \
    libproxy

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano
