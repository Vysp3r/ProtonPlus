SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.NOTPARALLEL:
.DEFAULT_GOAL := help

BUILD_DIR ?= build
TARGET ?=
export BUILD_DIR TARGET

.PHONY: help native run debug native-debug native-deps flatpak-toolchain \
        local flathub run-local run-flathub lint linter package translations \
        translations-update icons clean

help:
	@printf '%s\n' \
		'make native                Build the native application.' \
		'make run                   Build and run the checkout.' \
		'make debug                 Build and run the checkout under GDB.' \
		'make native-debug          Build /tmp/protonplus-build-debug for an external debugger.' \
		'make native-deps           Check native build dependencies.' \
		'make local | flathub       Build and install a Flatpak from the selected manifest.' \
		'make run-local | run-flathub  Build, install, and run the selected Flatpak.' \
		'make lint                  Check Vala source and test style.' \
		'make linter                Run the advisory Flathub linters.' \
		'make package TARGET=appimage|debian13|ubuntu26.04|fedora45|archlinux' \
		'make translations          Regenerate POTFILES and the gettext template.' \
		'make translations-update   Also merge language catalogs.' \
		'make icons                 Regenerate application PNG icons.' \
		'make clean                 Remove generated build and distribution directories.' \
		'./tests/check.sh [AREA]     Build and run the selected checks.' \
		'Native builds, checks, and translations use BUILD_DIR (default: build).'

define resolve-build-dir
build_dir="$${BUILD_DIR:-build}"
if [[ "$$build_dir" != /* ]]; then
	build_dir="$$PWD/$$build_dir"
fi
endef

define configure-build
if [[ ! -f "$$build_dir/meson-private/coredata.dat" ]]; then
	meson setup "$$build_dir" --prefix=/usr
fi
endef

define compile-native
meson compile -C "$$build_dir"
schema_dir="$$build_dir/data/glib-2.0/schemas"
mkdir -p "$$schema_dir"
cp data/com.vysp3r.ProtonPlus.gschema.xml "$$schema_dir/"
glib-compile-schemas "$$schema_dir"
endef

native:
	@$(resolve-build-dir)
	$(configure-build)
	$(compile-native)

run debug: native
	@$(resolve-build-dir)
	export LOCALE_DIR="$$build_dir/po"
	export XDG_DATA_DIRS="$$build_dir/data:$${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
	$(if $(filter debug,$@),gdb -batch -ex run -ex bt )"$$build_dir/src/protonplus"

native-debug:
	@build_dir=/tmp/protonplus-build-debug
	options=(--buildtype=debug)
	if [[ -f "$$build_dir/meson-private/coredata.dat" ]]; then
		options+=(--reconfigure)
	fi
	meson setup "$$build_dir" --prefix=/usr "$${options[@]}"
	$(compile-native)

native-deps:
	@for tool in glib-compile-schemas meson ninja valac; do
		if ! command -v "$$tool" >/dev/null; then
			printf 'Missing required dependency: %s\n' "$$tool" >&2
			exit 1
		fi
	done
	build_dir=$$(mktemp -d "$${TMPDIR:-/tmp}/protonplus-native-deps.XXXXXX")
	trap 'rm -rf -- "$$build_dir"' EXIT
	meson setup "$$build_dir" --prefix=/usr --wrap-mode=nodownload

flatpak-toolchain:
	@arch=$$(flatpak --default-arch)
	flatpak install -y "runtime/org.gnome.Sdk/$$arch/51" \
		"runtime/org.gnome.Platform/$$arch/51" \
		"runtime/org.freedesktop.Sdk.Extension.vala/$$arch/26.08" \
		org.flatpak.Builder

local flathub: flatpak-toolchain
	@flatpak run org.flatpak.Builder --verbose --sandbox --force-clean --ccache --user --install \
		"build-flatpak/$@/build" "$(if $(filter local,$@),com.vysp3r.ProtonPlus.local.yml,com.vysp3r.ProtonPlus.yml)"

run-local: local
run-flathub: flathub
run-local run-flathub:
	@flatpak run --user com.vysp3r.ProtonPlus

lint:
	@if ! command -v io.elementary.vala-lint >/dev/null; then
		printf '%s\n' 'Install Vala-Lint to run this check (io.elementary.vala-lint).' >&2
		exit 1
	fi
	io.elementary.vala-lint --config=.vala-lint.conf src/ tests/

linter: flatpak-toolchain
	@build_dir=build-flatpak/local/build
	repo=build-flatpak/local/repo
	manifest=com.vysp3r.ProtonPlus.local.yml
	flatpak run org.flatpak.Builder --verbose --sandbox --force-clean --ccache \
		--repo="$$repo" "$$build_dir" "$$manifest"
	# Local builds have expected differences, so these results are advisory.
	flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest com.vysp3r.ProtonPlus.yml || :
	flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest "$$manifest" || :
	flatpak run --command=flatpak-builder-lint org.flatpak.Builder appstream \
		"$$build_dir/export/share/metainfo/com.vysp3r.ProtonPlus.metainfo.xml" || :
	flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo "$$repo" || :

package:
	@case "$$TARGET" in
		appimage) ./packaging/appimage/build.sh ;;
		'') printf '%s\n' 'Specify a package target with TARGET=...' >&2; exit 1 ;;
		*) bash packaging/native-container.sh build "$$TARGET" ;;
	esac

translations:
	@$(resolve-build-dir)
	potfiles=$$(mktemp po/.POTFILES.XXXXXX)
	trap 'rm -f -- "$$potfiles"' EXIT
	{
		printf '%s\n' '# This file is generated automatically. Do not edit.'
		find data -type f \( -name '*.in' -o -name '*.ui' \) \
			-not -path '*/build/*' \
			-not -path 'data/com.vysp3r.ProtonPlus.metainfo.xml.in'
		find src -type f -name '*.vala' -not -path '*/build/*'
	} | LC_ALL=C sort > "$$potfiles"
	chmod 644 "$$potfiles"
	mv -- "$$potfiles" po/POTFILES
	$(configure-build)
	meson compile -C "$$build_dir" com.vysp3r.ProtonPlus-pot

translations-update: translations
	@$(resolve-build-dir)
	meson compile -C "$$build_dir" com.vysp3r.ProtonPlus-update-po

icons:
	@for size in 512 256 128 64 48 32 16; do
		output="data/icons/hicolor/$${size}x$${size}/apps"
		mkdir -p "$$output"
		rsvg-convert --width="$$size" --height="$$size" \
			--output="$$output/com.vysp3r.ProtonPlus.png" data/icons/com.vysp3r.ProtonPlus.svg
	done

clean:
	@for directory in _build .flatpak-builder .flatpak build build-appimage build-dir \
		build-flatpak build-native build-native-debug build-tests builddir dist /tmp/protonplus-build-debug; do
		if [[ -d "$$directory" ]]; then
			printf 'Removing %s\n' "$$directory"
			rm -rf -- "$$directory"
		fi
	done
