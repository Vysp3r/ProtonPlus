# Testing and validation

Run focused fixtures while iterating, then run the full suite and the manual
checks relevant to the change.

## Everyday checks

From the repository root, run:

```bash
./tests/check.sh
./tests/check.sh launch-options
./tests/check.sh /launch-command-writer
```

The helper configures `build/` when needed and compiles before running tests.
It checks diff whitespace after the tests pass. Use
`BUILD_DIR=build-tests ./tests/check.sh` to select another build directory.

- **Full suite.** Run with no arguments to include the standalone GTK and
  maintenance-script tests.
- **Named areas.** Use `downloads`, `providers`, `installation`, `steam`,
  `launch-options`, `controller`, or `cli` for a recursive group of GLib tests.
- **GLib paths.** Use an explicit path such as `/launch-command-writer` for
  GLib's `-p` selection. Paths that match no tests fail.

For download recovery, including nested fixture groups:

```bash
./tests/check.sh downloads
```

Relative `BUILD_DIR` values resolve against the repository root, even if you
invoke the helper from another directory. It returns the first failing status.

## Configure a test build manually

Choose one build directory and use it consistently. The examples below use
`build/`:

```bash
meson setup build
meson compile -C build
meson test -C build --print-errorlogs
```

If it is already configured, do not run setup again. If Meson inputs changed
and an explicit reconfigure is needed:

```bash
meson setup build --reconfigure
```

`build-tests/` also works if you already use it. Meson normally regenerates
an existing build during compilation when its inputs change.

### Tests registered with Meson

- **ProtonPlus unit tests** runs the fixture-backed Vala suite using TAP.
- **Maintenance script tests** covers native package commands, AppImage
  bundling, and release metadata. Release metadata
  checks use `xmllint` and skip when it is unavailable.
- **Check command tests** covers build setup, fixture paths, and failure
  propagation using isolated command stubs.
- **GTK suites** cover Tools, Games, Downloads, Help, Steam diagnostics, and
  launch-option flag widgets.
- **Metadata validation** checks desktop, AppStream, and GSettings files when
  the matching host tools are available.

The standalone suites in `tests/gui/` use Xvfb when available or default to the
current display. They skip if neither can be opened. The Tools layout fixture
constrains its content viewport to the requested logical width. A tiling
compositor can enlarge the toplevel without changing the width under test.
Narrow-layout checks assert both the content's minimum width and its allocation.
Optional snapshots capture the constrained viewport.

## Focused GLib test paths

List or run individual GLib paths directly through the compiled binary:

```bash
(cd tests && ../build/tests/protonplus-tests -l)
(cd tests && ../build/tests/protonplus-tests -p /providers)
(cd tests && ../build/tests/protonplus-tests -p /launch-command-writer)
(cd tests && ../build/tests/protonplus-tests -p /steam-restart-orchestrator)
```

Run the binary with `tests/` as its working directory. Archive fixtures use
paths relative to that directory; running from the repository root can produce
false missing-fixture failures. Meson's registered unit test already supplies
the correct working directory.

For download changes, run all three levels explicitly (`-p /web`,
`-p /web/persistent`, `-p /web/partial-cache`): GLib's `-p` selection does not
recursively include nested suites. HTTP fixtures require loopback socket access.
They use temporary cache directories and injected short recovery policies; no
real downloads or Steam profiles are touched. Sparse files exercise the 2 GiB
retention limit without allocating that much disk space.

The argument after `-p` is a GLib test path or prefix, not a Meson test name.
To run the entire registered unit executable through Meson:

```bash
meson test -C build --print-errorlogs "ProtonPlus unit tests"
```

## Test map

| Area | Focused paths/files |
| --- | --- |
| Provider definitions and sources | `/provider-definitions`, `/provider-registry`, `/providers`, `provider-*-test.vala`, provider JSON fixtures. |
| Releases, cache, and identity | `/release-catalog`, `/release-identity`, `/assets`, release page and identity tests. |
| Launcher/tool identity and layout | `/identity`, `/install-layout`, launcher-specific tests, `variant-settings-test.vala`. |
| CPU/variant selection | `/cpu-capabilities`, `/variant-compatibility`, `/variant-selector`. |
| Installed state and metadata | `/installed-tool-inventory`, `/protonplus-metadata`, `/protonplus-installed-discovery`, `/compatibility-tool` |
| Steam-selectable tools | `/steam-compatibility-tool-discovery`, `/steam/library-compatibility-tools-use-stable-identities` |
| Proton-Autogen | `/proton-autogen`, **Games presentation** |
| Steam tool diagnostics | `/steam-library-diagnostics`, `/steam/broken-steam-library-tool-is-detected`, **Steam diagnostics presentation** |
| Download recovery | `./tests/check.sh downloads` or the three `/web` paths above |
| Completed archive publication | `/filesystem/competing-file-publications`, `/installer-transaction/competing-cache-publishers`, `/installer-transaction/stale-cache-eviction-preserves-repair`. |
| Installation and updates | `/compatibility-process-guard`, `/installer-transaction`, `/update-transaction`, `/steamtinkerlaunch`. |
| VDF and Steam library parsing | `/vdf`, `/vdf-binary`, `/vdf-shortcuts`, `/steam`. |
| Steam lifecycle | `/steam-session`, `/steam-configuration`, `/steam-restart-manager`, `/steam-restart-orchestrator`, `/steam-restart-presentation`. |
| Shared Steam key repair | `/steam-key-repair`. |
| Launch options | `/launch-options`, `/launch-command`, `/launch-command-parser`, `/launch-command-composer`, `/launch-command-writer`, `/launch-command-editor-projection`, `/launch-option-capabilities`; see [`launch-options.md`](launch-options.md) for feature-probe fixtures and compatibility contracts. |
| CLI | `/cli`, using `RecordingCliOutputSink` for output assertions. |
| Saved variant preferences | `/variant-settings` |
| Optional component detection | `/system/components`, `/system/flatpak-dependency` |
| Repository scripts | `tests/scripts-test.vala`, `tests/check-script-test.vala`, normally run by Meson. |

Prefer behavior assertions over source-text or formatting assertions. For a
bug fix, add the smallest regression that fails for the observed behavior and
passes through the real owner of that behavior.

## Safety rules for tests

- Use temporary directories, fixture launchers, injected backends, and fake
  session identities. Never point tests at a real Steam profile, VDF file,
  compatibility-tools directory, or active launcher session.
- Do not run installation, update, removal, configuration, or restart commands
  manually against data that cannot be restored.
- Do not use `Posix.dup`, `dup2`, or process-wide stdout/stderr redirection to
  capture CLI output. Inject `RecordingCliOutputSink`; GLib owns the TAP
  stream.
- Keep native, Flatpak, Snap, and SteamOS session cases separate. One mocked
  backend does not prove another installation type.
- Test failures in an already dirty worktree may come from in-progress user
  changes. Inspect the exact diff and failure before editing outside the task.

## Manual validation

Automated GTK suites exercise presentation in controlled fixtures. Use manual
checks for the exact interaction in a real desktop, controller, or launcher
environment.

At minimum, consider:

- light and dark appearance;
- normal and narrow window widths;
- zero, one, and multiple items in conditional dropdowns/lists;
- pointer hit targets, keyboard focus, controller navigation, and active-tab
  clicks;
- initial state, restored selection, loading, empty, error, busy, success, and
  cancellation states affected by the change;
- escaped dynamic markup and long translated strings;
- single-game and multi-game Apply behavior for launch-option changes;
- compatible and incompatible CPU variants on representative hardware;
- native, Flatpak, or SteamOS lifecycle behavior only in a disposable and
  intentionally prepared environment.

If a real GUI, launcher, packaging environment, or hardware variant was not
available, say so. Compilation is not a substitute for that evidence.

## Generated and packaging checks

Run these only when the change requires them:

```bash
make translations  # translatable strings or Vala source list
make lint          # Vala source and tests
make local         # local Flatpak packaging/integration
make linter        # advisory Flathub lint suite
make icons         # source application icon changed
```

`make translations` updates only `po/POTFILES` and the POT
template. `make translations-update` also merges language catalogs;
keep that larger generated diff separate from code changes where practical.
Neither command builds the application. Icon generation updates tracked PNG
assets. Flatpak commands require installed runtimes, network access, and
substantially more time than native unit tests.

`make package TARGET=debian13` builds a native package and runs the
Meson suite in Docker or Podman. The **CI** and **Release** workflows also
install each distro package in a fresh container. AppImage jobs build with
stock Arch dependencies, then check zsync metadata, extract the artifact, and
run the bundled `protonplus version` command in a container with networking
disabled.

From the directory containing `ProtonPlus-$VERSION-source.tar.gz`, run
`packaging/appimage/build-container.sh` with Docker and export `VERSION` and
`ARCH` (the host's `uname -m`). Pass `--try-debloated` to opt in to the
optional helper. If the helper fails, the script discards that container and
retries with stock packages in a fresh container.

See the [release checklist](maintenance.md#prepare-a-release) for the tested
platforms.

## Final verification and report

For a normal code change, the baseline is:

```bash
meson compile -C build
meson test -C build --print-errorlogs
git diff --check
git status --short
```

Then inspect the exact diff for files in scope. In the handoff, name the
focused and full commands that ran, state whether they passed, and separate
automated evidence from manual GUI/runtime evidence. Do not claim visual or
live Steam behavior was verified when it was not.
