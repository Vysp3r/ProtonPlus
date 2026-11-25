# Contributing to ProtonPlus

ProtonPlus is a Linux GTK4 and libadwaita app written in Vala and built with
Meson. Read the [Code of Conduct](CODE_OF_CONDUCT.md) before contributing. Use
the [security policy](SECURITY.md) to report a vulnerability privately.

## Before you start

- Search existing issues and pull requests.
- Discuss substantial features or architecture changes in an issue first.
  Small fixes, documentation, tests, and translations can go directly into a
  pull request.
- Open pull requests against `main`. Short-lived branches and concise commit
  subjects make reviews easier.

## Set up a checkout

Fork the project, then clone your fork and create a branch.

```bash
git clone https://github.com/YOUR_USERNAME/ProtonPlus.git
cd ProtonPlus
git switch -c fix/short-description
```

### Native build dependencies

Install your distribution's development packages for these tools and libraries.

- **Build tools** include Git, GNU Make, a C compiler, pkg-config, Meson 1.0 or
  newer, Ninja, Vala, and gettext.
- **Libraries** include GLib, GTK 4.14 or newer, libadwaita 1.5 or newer,
  SDL 3.2 or newer, json-glib, libsoup 3, libgee, libarchive, SQLite, libyaml, and Cairo.
- **Desktop tools** include `glib-compile-schemas` and desktop-file-utils.

The [packaging recipes](packaging/) list distro-specific dependency names.
Use `make native-deps` to check your setup with a temporary Meson configuration
and dependency downloads disabled.

### Flatpak build dependencies

Install Flatpak, configure the Flathub remote, and have network access. The
Makefile installs the GNOME 51 SDK and runtime, the Vala SDK extension, and
Flatpak Builder when needed.

The [local manifest](com.vysp3r.ProtonPlus.local.yml) builds your checkout. The
[release manifest](com.vysp3r.ProtonPlus.yml) builds a tagged source.

## Build and run

| Command | Result |
| --- | --- |
| `make native` | Build into `build/` with `/usr` as the default install prefix. |
| `make run` | Build and launch the checkout with its local data and translations. |
| `make debug` | Build and run under GDB. Requires GDB. |
| `make native-debug` | Build into `/tmp/protonplus-build-debug` for an external debugger. |
| `sudo meson install -C build` | Install an existing native build system-wide. |
| `make local` | Build and install the checkout as a Flatpak for the current user. |
| `make run-local` | Build, install, and launch the local Flatpak. |

Use `BUILD_DIR` to override the native build directory. Run `make help` for
all commands, including packaging, icon generation, and build cleanup.

## Test changes

```bash
./tests/check.sh
./tests/check.sh launch-options
```

The first command builds and runs the full Meson suite and checks the diff.
The second runs the focused launch-options groups. For test paths, GUI checks,
and fixture rules, see [Testing and validation](docs/testing.md).

Use disposable profiles or injected backends for installation, launcher, and
Steam tests. Add a focused regression when the behavior could regress.

## Lint

Install Vala-Lint so `io.elementary.vala-lint` is on your `PATH`. Then run
`make lint` to check Vala files under `src/` and `tests/`.
[Vala-Lint installation instructions](https://github.com/vala-lang/vala-lint#building-testing-and-installation)

For automatic checks, install pre-commit and run `pre-commit install` in your
checkout. The hook checks staged Vala files using `.vala-lint.conf`. Both
the hook and `make lint` report issues without editing files.

## Find the right code

- [Codebase guide](docs/codebase-guide.md) for source locations, service
  boundaries, and persisted data.
- [Provider architecture](docs/provider-architecture.md) for adding providers,
  release sources, or installation workflows.
- [Launch-option catalog](docs/launch-options.md) for editor controls and
  capability checks.
- [Maintenance and releases](docs/maintenance.md) for debugging, CI behavior,
  and packaging.

### Coding and UI guidelines

- Follow `.editorconfig`, including four spaces for Vala and tabs for Makefile
  recipes. Add each new `.vala` file to the nearest `meson.build`.
- Keep network, archive, and filesystem work off GTK callbacks. Propagate
  cancellation and verify the selected object and operation after async yields.
- Stage and promote installs transactionally, roll back on failure, and clean
  up paths owned by the operation.
- Use `_(...)` or `ngettext(...)` for user-visible strings and escape dynamic
  markup. Keep labels concise and allow keyboard access to controls.
- Check UI changes in light and dark themes and at narrow widths. Keep layout
  allocation stable when conditional controls become unavailable.

## Translations and metadata

Use [Weblate](https://hosted.weblate.org/projects/protonplus/protonplus/) for
translation contributions. Run `make translations` after changing translatable
strings or adding or removing Vala sources. It regenerates `po/POTFILES` and
`po/com.vysp3r.ProtonPlus.pot`. Use `make translations-update` to merge language
catalogs intentionally.

Check changes to desktop files, AppStream metadata, GSettings, icons, and
resources with the relevant Meson validation. Regenerate tracked PNG icons
with `make icons` when the source icon changes.

## Issues and pull requests

### Bug reports

Include the expected and actual behavior, steps to reproduce, and the ProtonPlus
version, distribution, desktop environment, installation type, and launcher.
Add the affected provider or release and useful logs or screenshots. Remove
any tokens and private data. [Bug report form](https://github.com/Vysp3r/ProtonPlus/issues/new/choose)

### Feature requests

Describe the user problem, the proposed behavior, and alternatives you
considered. [Feature request form](https://github.com/Vysp3r/ProtonPlus/issues/new/choose)

### Pull requests

- Explain one coherent change and link its issue when available.
- Describe new dependencies, settings, and migration behavior.
- Include tests and update relevant documentation, metadata, or translations.
- Report the checks you ran and what you verified manually. Attach screenshots
  or a recording for meaningful UI changes.

Use the [pull request template](.github/pull_request_template.md). Keep version
bumps and release metadata with release work. [Release checklist](docs/maintenance.md#prepare-a-release)

## AI-assisted development

AI tools, including OpenAI Codex, have been used to help advance ProtonPlus
further. AI was used as a supporting engineering tool within a structured
development process, under human direction and subject to code review, testing,
and validation. Project decisions and final responsibility remain with the
maintainers.
