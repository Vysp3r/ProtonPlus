#!/usr/bin/env bash

set -euo pipefail

format=$1
target=$2
version=$3
archive=$(realpath "$4")
output=$(realpath "$5")
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
artifact="$output/ProtonPlus-$version-$target-$(uname -m)"
export MESON_TESTTHREADS=2
SOURCE_DATE_EPOCH=$(date +%s -r "$project/meson.build")
export SOURCE_DATE_EPOCH

case $format in
  deb)
    cp -a "$project" "$work/source"
    cd "$work/source"
    cp -a packaging/debian debian
    package_version=${version/-/\~}
    cat > debian/changelog <<EOF
protonplus ($package_version-1) unstable; urgency=medium

  * Build ProtonPlus $version from the upstream source archive.

 -- ProtonPlus contributors <dev@vysp3r.com>  $(date -R -r meson.build)
EOF
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends build-essential
    apt-get build-dep -y --no-install-recommends ./
    dpkg-buildpackage --build=binary --no-sign
    install -m644 "$work/protonplus_${package_version}-1_$(dpkg --print-architecture).deb" "$artifact.deb"
    ;;
  rpm)
    dnf -y install rpm-build dnf5-plugins
    package_version=${version/-/\~}
    package_version=${package_version//-/.}
    defines=(--define "upstream_version $version" --define "package_version $package_version")
    spec="$project/packaging/fedora/protonplus.spec"
    dnf -y builddep "${defines[@]}" "$spec"
    mkdir -p "$work/SOURCES"
    cp "$archive" "$work/SOURCES/"
    rpmbuild -bb "${defines[@]}" --define "_topdir $work" "$spec"
    install -m644 "$work"/RPMS/*/protonplus-"$package_version"-1.*.rpm "$artifact.rpm"
    ;;
  pkg.tar.zst)
    pacman -Syu --needed --noconfirm base-devel sudo
    useradd --create-home package-builder
    cp "$project/packaging/arch/PKGBUILD" "$archive" "$work/"
    chown -R package-builder "$work"
    cd "$work"
    checksum=$(sha256sum -- "$archive")
    # makepkg delegates dependency installation to pacman in this build container.
    printf '%s\n' 'package-builder ALL=(root) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/protonplus-build
    chmod 440 /etc/sudoers.d/protonplus-build
    runuser -u package-builder -- env PROTONPLUS_VERSION="$version" \
      PROTONPLUS_SOURCE_SHA256="${checksum%% *}" makepkg --syncdeps --noconfirm
    install -m644 "$work"/protonplus-*.pkg.tar.zst "$artifact.pkg.tar.zst"
    ;;
  *)
    printf 'Unknown package format: %s\n' "$format" >&2
    exit 1
    ;;
esac
