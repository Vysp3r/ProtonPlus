.PHONY: gen-potfiles translations build build-run clean flathub appimage linter icons local run

gen-potfiles:
	@echo "# This file is generated automatic" > po/POTFILES
	@find data -name "*.in" -not -path "*/build/*" >> po/POTFILES
	@find data -name "*.ui" -not -path "*/build/*" >> po/POTFILES
	@find src -name "*.vala" -not -path "*/build/*" >> po/POTFILES

translations: gen-potfiles
	./scripts/build.sh translations

build:
	./scripts/build.sh native

build-run:
	./scripts/build.sh native run

build-debug:
	./scripts/build.sh native debug

run: build-run

install: translations build
	cd build-native && sudo ninja install

uninstall: 
	cd build-native && sudo ninja uninstall
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