#!/bin/sh

set -eu

ARCH=$(uname -m)
REPOSITORY=${GITHUB_REPOSITORY:-Vysp3r/ProtonPlus}

# Build and install locally to /usr
if [ -f build-appimage/meson-private/coredata.dat ]; then
    meson setup build-appimage --wipe --prefix=/usr
else
    meson setup build-appimage --prefix=/usr
fi
meson compile -C build-appimage
meson install -C build-appimage

VERSION=$(meson introspect --projectinfo build-appimage | python3 -c \
    'import json, sys; print(json.load(sys.stdin)["version"])')
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.bg.hook"
export UPINFO="gh-releases-zsync|${REPOSITORY%/*}|${REPOSITORY#*/}|latest|*${ARCH}.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/256x256/apps/com.vysp3r.ProtonPlus.png
export DESKTOP=/usr/share/applications/com.vysp3r.ProtonPlus.desktop
export STARTUPWMCLASS=com.vysp3r.ProtonPlus
export GTK_CLASS_FIX=1
export DEPLOY_P11KIT=1

# Deploy dependencies
quick-sharun \
    /usr/bin/protonplus \
    /usr/share/locale \
    /usr/share/vala \
    /usr/lib/gio/modules/libgiognomeproxy.so \
    /usr/lib/gio/modules/libgiognutls.so \
    /usr/lib/gio/modules/libgiolibproxy.so

# Turn AppDir into AppImage
quick-sharun --make-appimage
