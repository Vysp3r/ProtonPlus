.PHONY: translations build build-run clean flathub appimage linter icons local run

translations:
	./scripts/build.sh translations

build:
	./scripts/build.sh native

build-run:
	./scripts/build.sh native run

run: build-run

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