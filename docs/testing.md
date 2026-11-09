# Testing and validation

ProtonPlus combines pure model tests, fixture-backed filesystem and network
parsers, asynchronous service tests, GTK-adjacent presentation tests, and
manual integration behavior. Use the smallest relevant checks while iterating,
then broaden validation in proportion to the change.

## Everyday checks

From the repository root, run:

```bash
./scripts/check.sh
./scripts/check.sh launch-options
./scripts/check.sh /launch-command-writer
```

`./scripts/check.sh` configures `build/` only when needed, compiles it, runs the
full Meson suite, and checks diff whitespace. Named areas include all nested
tests; a GLib path argument runs just that path from `tests/`, where fixtures
resolve correctly. Run the full command
before releasing or handing off a change. Use
`BUILD_DIR=build-tests ./scripts/check.sh` to reuse an older test build.

Available areas are `downloads`, `providers`, `installation`, `steam`,
`launch-options`, `controller`, and `cli`. They run GLib tests; use the full
command for the separate GUI and maintenance-script tests.

For download recovery, including nested fixture groups:

```bash
./scripts/check.sh downloads
```

The helper also works when invoked from another directory. Relative
`BUILD_DIR` values always resolve against the repository root. It stops at the
first failed build, test, or whitespace check and preserves that exit status.
Focused checks also fail when the requested path selects no tests, so a typo
cannot produce a successful check without exercising anything.

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

`build-tests/` also works if you already use it. Meson automatically regenerates
an existing build during compilation when its inputs change; everyday checks
do not need an explicit reconfigure.

The Meson suite currently contains:

- `ProtonPlus unit tests`: the Vala/GLib test binary using TAP.
- `Maintenance script tests`: Python tests for repository scripts. Release
  metadata checks use `xmllint` and skip when it is unavailable.
- `Check command tests`: isolated command stubs covering build setup, focused
  fixture paths, and failure propagation without compiling or touching user data.
- `Games presentation`: fixture-backed wide/narrow list bindings, selection
  presentation, activation forwarding, model replacement, and focus cleanup.
- Host-tool validation added from `data/` when the matching validation tools
  are available, including desktop, AppStream, and GSettings checks.

GUI tests use Xvfb when available, otherwise the current display, and skip if
neither can be opened. The Tools layout fixture constrains its content viewport
to the requested logical width: a tiling compositor can enlarge the toplevel
without changing the width under test. Narrow-layout checks assert both the
content's minimum width and its allocation. Optional snapshots capture that
viewport, rather than the compositor-sized window.

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
| Provider definitions and sources | `/provider-definitions`, `/provider-registry`, `/providers`, `provider_*_test.vala`, provider JSON fixtures. |
| Releases, cache, and identity | `/release-catalog`, `/release-identity`, `/assets`, release page and identity tests. |
| Launcher/tool identity and layout | `/identity`, `/install-layout`, launcher-specific tests, `variant_settings_test.vala`. |
| CPU/variant selection | `/cpu-capabilities`, `/variant-compatibility`, `/variant-selector`. |
| Installed state and metadata | `/installed-tool-inventory`, `/metadata`, `/compatibility-tool`. |
| Steam selectable-tool discovery | `/steam-compatibility-tool-discovery`; injected Steam-library, native-system, and Flatpak extension roots only. `/steam/library-compatibility-tools-use-stable-identities` covers the library-loading projection. |
| Steam tool diagnostics | `/steam-library-diagnostics`, `/steam/broken-steam-library-tool-is-detected`, and `Steam diagnostics presentation`: missing manifests/registration, real file checks, updating/recovered tools, stale logs, bounded reads, symlinks, and selection across native/Flatpak/Snap fixtures. |
| Download recovery | `/web`, `/web/persistent`, `/web/partial-cache`, `web_test.vala`: loopback HTTP fixtures for retry deadlines, both Retry-After formats, resume/restart rates, validator/range safety, cancellation, persistent metadata, locks, expiry/storage limits, cache clearing, and API session/proxy isolation. |
| Installation and updates | `/compatibility-process-guard`, `/installer-transaction`, `/update-transaction`, `/steamtinkerlaunch`. |
| VDF and Steam library parsing | `/vdf`, `/vdf-binary`, `/vdf-shortcuts`, `/steam`. |
| Steam lifecycle | `/steam-session`, `/steam-configuration`, `/steam-restart-manager`, `/steam-restart-orchestrator`, `/steam-restart-presentation`. |
| Launch options | `/launch-options`, `/launch-command`, `/launch-command-parser`, `/launch-command-composer`, `/launch-command-writer`, `/launch-command-editor-projection`, `/launch-option-capabilities`; see [`launch-options.md`](launch-options.md) for feature-probe fixtures and compatibility contracts. |
| CLI | `/cli`, using `RecordingCliOutputSink` for output assertions. |
| Saved variant preferences | `/variant-settings`: canonical/legacy keys, damaged JSON, unknown-entry preservation, and memory-backed GSettings persistence. |
| Optional component detection | `/system/components`, `/system/flatpak-dependency`: injected command availability, a single Flatpak query, exact IDs, aliases, failures, and immutable lookup state. |
| Repository scripts | `tests/scripts_test.py`, `tests/check_script_test.py`, normally run by Meson. |

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

Automated checks establish model and service behavior, but they do not render
the application or exercise a real desktop/session. For GTK changes, manually
check the exact requested path and report what was actually exercised.

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
./scripts/build.sh translations # translatable strings or Vala source list
pre-commit run --all-files       # Vala lint
./scripts/build.sh local         # local Flatpak packaging/integration
./scripts/build.sh linter        # advisory Flathub lint suite
./scripts/build.sh icons         # source application icon changed
```

`./scripts/build.sh translations` updates only `po/POTFILES` and the POT
template. `./scripts/build.sh translations update` also merges language catalogs;
keep that larger generated diff separate from code changes where practical.
Neither command builds the application. Icon generation updates tracked PNG
assets. Flatpak commands require installed runtimes, network access, and
substantially more time than native unit tests.

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
