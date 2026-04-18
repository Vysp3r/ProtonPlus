#!/bin/sh
set -eu
ARCH=$(uname -m)

# Build and install locally to /usr
meson setup build-appimage --prefix=/usr
ninja -C build-appimage install

VERSION=$(grep -m1 "version:" meson.build | cut -d"'" -f2)
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.bg.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/256x256/apps/com.vysp3r.ProtonPlus.png
export DESKTOP=/usr/share/applications/com.vysp3r.ProtonPlus.desktop
export STARTUPWMCLASS=com.vysp3r.ProtonPlus
export GTK_CLASS_FIX=1
export DEPLOY_P11KIT=1

# Deploy dependencies
quick-sharun \
/usr/bin/protonplus \
/usr/share/com.vysp3r.ProtonPlus \
/usr/share/locale \
/usr/share/vala \
/usr/lib/gio/modules/libgiognomeproxy.so \
/usr/lib/gio/modules/libgiognutls.so \
/usr/lib/gio/modules/libgiolibproxy.so

# Turn AppDir into AppImage
quick-sharun --make-appimage
