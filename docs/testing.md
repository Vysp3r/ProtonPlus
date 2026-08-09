# Testing and validation

ProtonPlus combines pure model tests, fixture-backed filesystem and network
parsers, asynchronous service tests, GTK-adjacent presentation tests, and
manual integration behavior. Use the smallest relevant checks while iterating,
then broaden validation in proportion to the change.

## Configure a test build

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

`build-tests/` is the contributor guide's fresh-test convention and works the
same way. The Makefile's `make tests` target configures it when missing and
reconfigures it when it already exists.

The Meson suite currently contains:

- `ProtonPlus unit tests`: the Vala/GLib test binary using TAP.
- `Maintenance script tests`: Python tests for repository scripts.
- Host-tool validation added from `data/` when the matching validation tools
  are available, including desktop, AppStream, and GSettings checks.

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
| Installation and updates | `/compatibility-process-guard`, `/installer-transaction`, `/update-transaction`, `/steamtinkerlaunch`. |
| VDF and Steam library parsing | `/vdf`, `/vdf-binary`, `/vdf-shortcuts`, `/steam`. |
| Steam lifecycle | `/steam-session`, `/steam-configuration`, `/steam-restart-manager`, `/steam-restart-orchestrator`, `/steam-restart-presentation`. |
| Launch options | `/launch-options`, `/launch-command`, `/launch-command-parser`, `/launch-command-composer`, `/launch-command-writer`, `/launch-command-editor-projection`, `/launch-option-capabilities`; see [`launch-options.md`](launch-options.md) for feature-probe fixtures and compatibility contracts. |
| CLI | `/cli`, using `RecordingCliOutputSink` for output assertions. |
| Repository scripts | `tests/scripts_test.py`, normally run by Meson. |

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
make translations              # translatable strings or Vala source list
pre-commit run --all-files      # Vala lint
./scripts/build.sh local        # local Flatpak packaging/integration
./scripts/build.sh linter       # advisory Flathub lint suite
./scripts/build.sh icons        # source application icon changed
```

`make translations` updates many tracked files by design. Icon generation also
updates tracked PNG assets. Flatpak commands require installed runtimes,
network access, and substantially more time than native unit tests.

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
