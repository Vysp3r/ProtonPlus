# Contributing to ProtonPlus

Thank you for contributing to ProtonPlus. The project is a Linux GTK4 and
libadwaita application written primarily in Vala, built with Meson, and
distributed as a Flatpak and native Linux packages.

Please read this guide, the [README](README.md), and the [Code of
Conduct](CODE_OF_CONDUCT.md) before starting. For security issues, follow
[SECURITY.md](SECURITY.md) instead of opening a public issue.

## Before you start

Search existing issues and pull requests before opening a new one. For a
substantial feature or architectural change, open or comment on an issue
first so the scope can be agreed before implementation. Small fixes,
documentation improvements, tests, and translations are welcome without prior
approval.

The default integration branch is main; the required CI workflow runs for pull
requests targeting main. There is no enforced branch-name or commit-message
convention, but short-lived branches such as fix/... or feat/... and concise
imperative commit subjects make reviews easier.

## Set up a checkout

Fork the repository, then clone your fork and create a topic branch:

~~~bash
git clone https://github.com/YOUR_USERNAME/ProtonPlus.git
cd ProtonPlus
git switch -c fix/short-description
~~~

### Native build dependencies

For a native build, install the development packages provided by your
distribution for:

- Git, a C compiler, pkg-config, Meson 1.0 or newer, Ninja, and Vala
- GLib, including glib-compile-schemas, GTK4, and libadwaita 1.6 or newer
- json-glib, libsoup 3, libgee, libarchive, libnotify, Cairo, AppStream, and
  SDL 3.2 or newer
- gettext and desktop-file-utils
- Python 3 for the maintenance-script tests

scripts/get-dependencies.sh installs the native packages used by the project
on Arch-based systems. It is not a portable dependency installer and must not
be run unchanged on other distributions.

### Flatpak build dependencies

For the sandboxed build, install Flatpak, configure a Flathub remote, and have
network access. The build helper installs the GNOME 50 SDK and runtime, the
Vala SDK extension, and Flatpak Builder when needed.

Use com.vysp3r.ProtonPlus.local.yml for development. It builds the current
checkout. The other manifest, com.vysp3r.ProtonPlus.yml, builds a tagged Git
source and is primarily used for release packaging.

## Build and run

The project helper is the easiest way to build a development checkout:

~~~bash
# Build natively into build-native/
./scripts/build.sh native

# Build and run the native application
./scripts/build.sh native run
~~~

The native helper configures Meson with /usr as the install prefix and sets the
data and locale paths needed when running from the checkout. To install a
native build system-wide, use the normal privilege boundary explicitly:

~~~bash
sudo meson install -C build-native
~~~

For a native debug build, use either of these commands:

~~~bash
./scripts/build.sh native debug       # build and run under GDB
./scripts/build.sh native-debug       # build /tmp/protonplus-build-debug
~~~

The debug modes require GDB. The VS Code configuration uses the latter build
directory.

To build and install the local Flatpak for the current user:

~~~bash
./scripts/build.sh local
./scripts/build.sh local run
~~~

The Flatpak build runs in a sandbox and uses the permissions declared in the
local manifest. It is useful for checking packaging, runtime integration, and
launcher detection in the same general environment as the distributed app.

The Makefile provides shortcuts for common operations, including make build,
make build-run, make build-debug, make local, make flathub, and make clean.

## Test changes

For a fresh test build, configure it once, then compile and run the complete
suite:

~~~bash
meson setup build-tests
meson compile -C build-tests
meson test -C build-tests --print-errorlogs
~~~

If build-tests/ already exists, reconfigure it with:

~~~bash
meson setup build-tests --reconfigure
~~~

make tests is a verbose shortcut for the reconfigure, compile, and test steps,
but it assumes that build-tests/ has already been configured.

The test suite includes Vala unit tests, maintenance-script tests, and—when
the corresponding host tools are available—desktop-file, AppStream, and
GSettings schema validation. Add a focused regression test for behavior that
could otherwise regress, especially for provider parsing, release identity,
cache state, filesystem transactions, launcher layouts, VDF parsing, and
asynchronous UI state.

Useful commands for a targeted run are:

~~~bash
meson test -C build-tests --list
meson test -C build-tests --print-errorlogs "ProtonPlus unit tests"
~~~

When testing installation or launcher behavior manually, use a disposable
profile or test fixture. Do not point a development build at data you cannot
restore, and close games before testing compatibility-tool updates or removal.

## Code quality and maintenance commands

Run these checks before opening a pull request:

~~~bash
git diff --check
pre-commit run --all-files
meson compile -C build-tests
meson test -C build-tests --print-errorlogs
~~~

Install the pre-commit package with your distribution or Python tooling, then
install the hook locally if desired:

~~~bash
pre-commit install
~~~

The repository configures vala-lint through .pre-commit-config.yaml and
.vala-lint.conf. There is no separate formatter or static-analysis workflow;
the compiler, Meson validation tests, Vala lint, and Flatpak linters are the
authoritative checks currently configured in the repository. CI runs the local
Flatpak build and its tests on x86_64 and aarch64. Its Flatpak lint step is
advisory.

Additional helper commands:

~~~bash
make translations
./scripts/build.sh linter
./scripts/build.sh icons
./scripts/build.sh clean
~~~

make translations regenerates po/POTFILES and updates .po files.
./scripts/build.sh linter runs flatpak-builder-lint on the local manifest.
./scripts/build.sh icons regenerates tracked PNG icons from the SVG source.
./scripts/build.sh clean removes ignored build and distribution directories.

The linter and icon commands require Flatpak tooling and rsvg-convert,
respectively. Do not commit generated build directories. Generated icon PNGs
are tracked and should only be regenerated when the source icon changes.

## Project layout and architecture

- src/cli/ — command-line handling and output.
- src/models/ — launcher, game, tool, release, asset, and provider models.
- src/models/launchers/ — supported launcher integrations and their
  installation capabilities.
- src/models/providers/ — provider definitions, validation, and catalog
  composition.
- src/providers/sources/ — GitHub, GitHub Actions, GitLab, and Forgejo
  release-source adapters and parsers.
- src/services/ — installation jobs, transactional workflows, and migrations.
- src/utils/ — filesystem, archive, network, cache, system, translation, and
  VDF helpers.
- src/widgets/ — GTK4/libadwaita application, window, preferences, tools,
  games, and MangoHud UI.
- data/ — resources, icons, CSS, desktop metadata, AppStream metadata,
  GSettings schema, and systemd units.
- po/ — gettext catalogs and the generated source-file list.
- tests/ — Vala regression tests, fixtures, and maintenance-script tests.
- scripts/ — build, dependency, translation, icon, AppImage, and version
  maintenance helpers.
- docs/provider-architecture.md — the provider and release-source extension
  model.

### Adding a provider

Read [docs/provider-architecture.md](docs/provider-architecture.md) first.
Ordinary providers are definition-driven; they do not require a provider
subclass, widget branch, or installation-service branch.

1. Add or update the relevant definition in
   src/models/providers/definitions/ and include it through the existing
   built-in definition collection.
2. Reuse an existing release source and installation layout whenever their
   semantics match. Keep provider identity, variants, asset selection, and
   launcher-specific layouts explicit.
3. Add or update focused tests and fixtures under tests/, especially for
   filtering, canonical asset URLs, variants, identity, and cache behavior.
4. Add a new source adapter only when the upstream API semantics require one;
   register it in src/providers/sources/release-source-registry.vala and test
   malformed responses, pagination, failures, identity, and asset selection.

### Adding launcher or installation behavior

Launcher integrations belong under src/models/launchers/. Installation
transactions belong under src/services/. The installation service selects a
workflow from the job's capabilities: ordinary archive providers use the
standard workflow, while materially different behavior such as Steam Tinker
Launch has a dedicated workflow. Do not add branches keyed only to a provider
ID when a capability or launcher context expresses the requirement more
accurately.

Any new .vala file must be added to the appropriate meson.build file. Update
tests, documentation, and translations when the change affects them.

## Coding and UI guidelines

- Use four spaces for Vala and Python. Use tabs for Makefile recipes and follow
  .editorconfig for Meson, YAML, JSON, and other files.
- Follow the existing Vala and GLib conventions. Keep changes focused and avoid
  unrelated formatting or architectural rewrites.
- Keep network, filesystem, archive, and other blocking work out of GTK filter,
  sort, and rendering callbacks. Use the existing asynchronous services and
  pass cancellation through the whole operation.
- After an asynchronous yield, verify that the requested object and current
  operation still match before updating UI or cache state.
- Preserve transactional installation and update behavior: stage privately,
  promote atomically, roll back on failure, and clean up only paths owned by
  the current operation.
- Wrap user-visible strings with gettext helpers (_() or ngettext()), use clear
  accessible labels and tooltips, and keep controls keyboard reachable. Check
  UI changes in both light and dark themes and at narrow window sizes.
- Avoid duplicating information in compact GTK controls and preserve layout
  allocation when a conditional control is temporarily unavailable.

## Translations and metadata

User-facing text is translated with gettext and coordinated through
[Weblate](https://hosted.weblate.org/projects/protonplus/protonplus/). When
adding or removing translatable source files, regenerate the source list and
translation catalogs:

~~~bash
make translations
~~~

Do not hand-edit generated translation output unless you are intentionally
updating a catalog. Changes to icons, desktop metadata, AppStream metadata,
GSettings, or resources should be tested through the Meson build and relevant
validation tests.

## Issues and pull requests

### Bug reports

Use the [bug report form](https://github.com/Vysp3r/ProtonPlus/issues/new/choose)
after checking existing issues and the latest release. Include:

- a clear description of the actual and expected behavior;
- reproducible steps, input, and relevant upstream provider or release;
- distribution, desktop environment, ProtonPlus version, installation type, and
  launcher setup;
- logs, screenshots, or a stack trace when useful; and
- whether the issue occurs in both native and Flatpak builds, if relevant.

Never include secrets such as API tokens or private paths containing sensitive
information. Report vulnerabilities privately using [SECURITY.md](SECURITY.md).

### Feature requests

Use the [feature request form](https://github.com/Vysp3r/ProtonPlus/issues/new/choose).
Explain the user problem, the proposed behavior, alternatives considered, and
why the change benefits ProtonPlus users generally.

### Pull requests

Open pull requests against main and complete
[.github/pull_request_template.md](.github/pull_request_template.md). A good
pull request:

- contains one coherent change and links the relevant issue when one exists;
- explains motivation, design decisions, new dependencies, and configuration
  changes;
- includes focused tests or explains why tests are not practical;
- updates documentation, metadata, and translations when applicable;
- includes screenshots or a recording for meaningful UI changes; and
- reports the exact build, test, lint, or manual verification performed.

Reviewers prioritize correctness, data safety, regressions, accessibility,
performance, maintainability, and consistency with the existing architecture.
Passing CI is necessary but does not replace manual review of behavior and UI.

## Release and versioning notes

Release work is maintainer-led. The project version is declared in meson.build;
scripts/set-version.py VERSION updates the Meson version and the tagged source
reference in the Flathub manifest. Release notes in
data/com.vysp3r.ProtonPlus.metainfo.xml.in and the Git tag (vVERSION) are
updated separately. Publishing a GitHub release triggers the AppImage
workflow.

Contributors should not change the project version or release metadata unless
the pull request is specifically part of a release. If a version-related
change is requested, use --dry-run first and verify every generated and manual
update before committing.

## Final checklist

Before requesting review:

~~~bash
git diff --check
meson compile -C build-tests
meson test -C build-tests --print-errorlogs
pre-commit run --all-files
~~~

Then run the application or the relevant Flatpak build, inspect the diff for
unrelated changes, and describe the verification in the pull request.
