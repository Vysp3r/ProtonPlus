#!/usr/bin/env bash

set -euo pipefail

package=$(realpath "$1")
version=$2
app_id=com.vysp3r.ProtonPlus
desktop="/usr/share/applications/$app_id.desktop"
metainfo="/usr/share/metainfo/$app_id.metainfo.xml"

case $package in
  *.deb)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends "$package"
    dpkg-query -W protonplus ca-certificates dconf-gsettings-backend glib-networking
    ;;
  *.rpm)
    dnf -y --setopt=install_weak_deps=False install "$package"
    rpm -q protonplus ca-certificates dconf glib-networking
    ;;
  *.pkg.tar.zst)
    pacman -Syu --noconfirm
    pacman -U --noconfirm "$package"
    pacman -Q protonplus ca-certificates dconf glib-networking
    ;;
  *)
    printf 'Unknown package format: %s\n' "$package" >&2
    exit 1
    ;;
esac

# Check runtime prerequisites before adding the metadata validators.
test -x /usr/bin/protonplus
libraries=$(ldd -r /usr/bin/protonplus 2>&1)
printf '%s\n' "$libraries"
if [[ $libraries == *'not found'* || $libraries == *'undefined symbol'* ]]; then
  exit 1
fi
test -s "/usr/share/glib-2.0/schemas/$app_id.gschema.xml"
gsettings list-keys "$app_id.State"
test "$(GSETTINGS_BACKEND=memory /usr/bin/protonplus version)" = "ProtonPlus $version"

test -s "$desktop"
test -s "$metainfo"
for size in 16 32 48 64 128 256 512; do
  test -s "/usr/share/icons/hicolor/${size}x${size}/apps/$app_id.png"
done

case $package in
  *.deb) apt-get install -y --no-install-recommends appstream desktop-file-utils ;;
  *.rpm) dnf -y install appstream desktop-file-utils ;;
  *.pkg.tar.zst) pacman -S --needed --noconfirm appstream desktop-file-utils ;;
esac
desktop-file-validate "$desktop"
sh "$(dirname -- "$0")/validate-appstream.sh" appstreamcli "$metainfo"
