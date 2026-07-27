.PHONY: appimage build build-debug build-run clean debug flathub gen-potfiles icons install linter local local-run run tests translations uninstall

gen-potfiles:
	@set -e; { \
		printf '%s\n' '# This file is generated automatically. Do not edit.'; \
		find data -type f \( -name '*.in' -o -name '*.ui' \) -not -path '*/build/*'; \
		find src -type f -name '*.vala' -not -path '*/build/*'; \
	} | LC_ALL=C sort > po/POTFILES.tmp
	@mv po/POTFILES.tmp po/POTFILES

translations: gen-potfiles
	./scripts/build.sh translations

build:
	./scripts/build.sh native

build-run:
	./scripts/build.sh native run

build-debug:
	./scripts/build.sh native-debug

debug:
	./scripts/build.sh native debug

run: build-run

install: build
	sudo meson install -C build-native

uninstall:
	sudo ninja -C build-native uninstall

clean:
	./scripts/build.sh clean

flathub:
	./scripts/build.sh flathub

appimage:
	./scripts/build.sh appimage

linter:
	./scripts/build.sh linter

icons:
	./scripts/build.sh icons

local:
	./scripts/build.sh local

local-run:
	./scripts/build.sh local run

tests:
	meson setup build-tests --reconfigure
	meson compile -C build-tests
	meson test -C build-tests --verbose
