#!/bin/sh

set -eu

ARCH=$(uname -m)
REPOSITORY=${GITHUB_REPOSITORY:-Vysp3r/ProtonPlus}
APPIMAGE_APPDIR=${PROTONPLUS_APPIMAGE_APPDIR:-./AppDir}
APPIMAGE_LOCALE_SOURCE=${PROTONPLUS_APPIMAGE_LOCALE_SOURCE:-/usr/share/locale}
VERIFY_ENVIRONMENT=${1:-}

set -- /usr/lib/gio/modules/libgiognomeproxy.so \
    /usr/lib/gio/modules/libgiognutls.so \
    /usr/lib/gio/modules/libgiolibproxy.so

verify_linkage() {
    for binary do
        if [ ! -f "$binary" ] || [ ! -r "$binary" ] || [ ! -s "$binary" ]; then
            printf 'Missing or unreadable AppImage input: %s\n' "$binary" >&2
            return 1
        fi
        if ! linkage=$(LC_ALL=C ldd -r "$binary" 2>&1) ||
            printf '%s\n' "$linkage" | grep -Eq 'not found|undefined symbol'; then
            printf 'Unusable linkage for %s\n%s\n' "$binary" "$linkage" >&2
            return 1
        fi
    done
}

if [ "$VERIFY_ENVIRONMENT" = --verify-environment ]; then
    for tool in bash gcc valac meson ninja pkg-config glib-compile-resources \
        glib-compile-schemas msgfmt desktop-file-validate patchelf ldd zsyncmake quick-sharun; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            printf 'Required AppImage tool missing: %s\n' "$tool" >&2
            exit 1
        fi
    done
    pacman -Qo "$@"
    verify_linkage "$@"
fi

# Stock Mesa links LLVM. Allow the larger bundle when the smaller Mesa package
# could not be installed.
if command -v pacman >/dev/null 2>&1 && pacman -Q mesa >/dev/null 2>&1; then
    export I_WANT_FAT_APPIMAGE=${I_WANT_FAT_APPIMAGE:-1}
fi

# Build and install locally to /usr
if [ -f build-appimage/meson-private/coredata.dat ]; then
    meson setup build-appimage --wipe --prefix=/usr
else
    meson setup build-appimage --prefix=/usr
fi
meson compile -C build-appimage
meson install -C build-appimage

VERSION=$(bash packaging/set-version.sh --print-version)
if [ "$VERIFY_ENVIRONMENT" = --verify-environment ]; then
    verify_linkage /usr/bin/protonplus
    test "$(GSETTINGS_BACKEND=memory /usr/bin/protonplus version)" = "ProtonPlus $VERSION"
fi
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
quick-sharun /usr/bin/protonplus "$@"

# Quick-Sharun matches catalogs against the lowercase executable name and
# removes ProtonPlus' case-sensitive gettext domain during locale debloating.
# Restore only ProtonPlus catalogs instead of deploying the full locale tree.
find "$APPIMAGE_LOCALE_SOURCE" -type f \
    -path '*/LC_MESSAGES/com.vysp3r.ProtonPlus.mo' \
    -exec sh -c '
        locale_source=$1
        appdir=$2
        shift 2

        for catalog do
            relative_path=${catalog#"$locale_source"/}
            destination=$appdir/share/locale/$relative_path
            mkdir -p "${destination%/*}"
            cp "$catalog" "$destination"
        done
    ' sh "$APPIMAGE_LOCALE_SOURCE" "$APPIMAGE_APPDIR" {} +

# Desktop integration tools look for AppStream metainfo under usr/share.
install -Dm644 data/com.vysp3r.ProtonPlus.metainfo.xml.in \
    "$APPIMAGE_APPDIR/usr/share/metainfo/com.vysp3r.ProtonPlus.metainfo.xml"

# Turn AppDir into AppImage
quick-sharun --make-appimage
