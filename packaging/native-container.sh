#!/usr/bin/env bash

set -euo pipefail

mode=$1
target=$2
archive=${3:-}
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output=$(realpath -m "${4:-$project/dist}")

case $target in
  debian13)    format=deb; image=docker.io/library/debian:13 ;;
  ubuntu26.04) format=deb; image=docker.io/library/ubuntu:26.04 ;;
  fedora45)    format=rpm; image=registry.fedoraproject.org/fedora:45 ;;
  archlinux)   format=pkg.tar.zst; image=ghcr.io/pkgforge-dev/archlinux:latest ;;
  *) printf 'Unknown package target: %s\n' "$target" >&2; exit 1 ;;
esac

engine=${PROTONPLUS_CONTAINER_ENGINE:-}
if [[ -z $engine ]]; then
  if command -v docker >/dev/null; then
    engine=docker
  else
    engine=podman
  fi
fi
if ! command -v "$engine" >/dev/null; then
  printf 'Container engine %s is unavailable. Native builds require Docker or Podman.\n' "$engine" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

if [[ -z $archive ]]; then
  # Include current source edits and new files while excluding ignored output.
  cd "$project"
  version=$(meson introspect --projectinfo meson.build | python3 -c \
    'import json, sys; print(json.load(sys.stdin)["version"])')
  archive="$work/ProtonPlus-$version-source.tar.gz"
  git ls-files --cached --others --exclude-standard -z > "$work/source-paths"
  while IFS= read -r -d '' path; do
    parent=$path
    while [[ $parent == */* ]]; do
      parent=${parent%/*}
      [[ ! -L $parent ]] || continue 2
    done
    if [[ -f $path || -L $path ]]; then
      printf '%s\0' "$path"
    fi
  done < "$work/source-paths" | tar --create --gzip --file="$archive" \
    --transform="flags=rh;s|^|ProtonPlus-$version/|" --no-recursion --null --files-from=-
else
  archive=$(realpath "$archive")
  archive_name=${archive##*/}
  version=${archive_name#ProtonPlus-}
  version=${version%-source.tar.gz}
fi

tar -xf "$archive" -C "$work"
source_dir="$work/ProtonPlus-$version"
case $mode in
  build)
    mkdir -p "$output"
    "$engine" run --rm --volume "$source_dir:/source:ro" \
      --volume "$archive:/input/${archive##*/}:ro" --volume "$output:/output" \
      "$image" bash /source/packaging/build.sh "$format" "$target" "$version" \
      "/input/${archive##*/}" /output
    ;;
  test)
    "$engine" run --rm --volume "$source_dir:/source:ro" --volume "$output:/output:ro" \
      "$image" bash /source/packaging/test-install.sh \
      "/output/ProtonPlus-$version-$target-$(uname -m).$format" "$version"
    ;;
  *) printf 'Unknown container operation: %s\n' "$mode" >&2; exit 1 ;;
esac
