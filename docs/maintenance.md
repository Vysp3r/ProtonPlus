# Maintaining ProtonPlus

Start with [the codebase guide](codebase-guide.md) to locate behavior and
[the test map](testing.md#test-map) to select checks. This guide covers the
repeated work of maintaining the project and records the maintenance audit.

## Everyday workflow

```bash
./scripts/build.sh help
./scripts/build.sh native run       # build and run the checkout
./scripts/check.sh /release-catalog # check one area while editing
./scripts/check.sh                  # full suite and whitespace checks
```

`./scripts/build.sh native run` and checks share `build/` and its local resources;
installation is a separate `sudo meson install -C build` action. Override it with
`BUILD_DIR=build-tests ./scripts/check.sh` if you already have another test build.
The native build and translation commands honor the same override.
Meson regenerates changed build definitions during compilation.

When a checkout has moved, an old Meson build can retain absolute paths to
its original location. If reconfiguration still references the old directory,
recreate that generated build configuration with
`meson setup build --wipe .`. This discards compiled results and preserves
source files. Do not use `./scripts/build.sh clean` just to fix one stale build.

Keep one problem per change. Trace its read, state, write, and persistence
owners, fix it there, and use an existing behavioral test where possible.
Add a regression when the failure could otherwise return. Run
`./scripts/build.sh translations` only when changing translatable strings or
adding/removing Vala sources. It updates the source list and template only.
Use `./scripts/build.sh translations update` to merge language catalogs explicitly;
keep that generated diff separate when practical.

The full suite can skip GUI tests when no display is available. Read its
summary and record what still needs manual checking; passing headless checks
does not establish controller, packaging, or live Steam behavior.

## Debug a report

Collect the ProtonPlus version and packaging, launcher installation type,
affected provider/variant/release, exact action, and terminal error before
trying to reproduce. Preferences > Advanced > System Information provides
copyable environment and launcher information. For a crash before Preferences
opens, use terminal output or `./scripts/build.sh native debug` for a native
backtrace.

| Symptom | Start here | Focused check |
| --- | --- | --- |
| Launcher missing | `src/models/launchers/`, then `Launcher.get_all()` | Launcher-specific tests; test packaging visibility separately. |
| Release missing or wrong asset | Provider definition, matching source, then `ReleaseCatalog` | `/providers`, `/provider-definitions`, `/release-catalog` |
| Installed tool missing or wrong variant | `InstalledToolInventory`, metadata, then `ProviderTool.get_directory_name()` | `/installed-tool-inventory`, `/identity`, `/install-layout` |
| Install/update fails | `InstallationService`, selected workflow, then archive/download helpers | `/installer-transaction`, `/update-transaction`; download paths below. |
| Steam edit disappears or restart stays pending | Configuration service, restart manager/store, then session evidence | `/steam-configuration`, `/steam-restart-manager`, `/steam-session` |
| Launch command changes unexpectedly | Parser, edit state, then writer; compare preview and Apply | `/launch-command-parser`, `/launch-command-writer` |
| Controller focus or dialog problem | `ControllerManager`, relevant policy, widget registration/cleanup | Relevant `/controller-*` paths; repeat on hardware. |

For downloads, the named area includes all nested paths:

```bash
./scripts/check.sh downloads
```

Named areas use recursive GLib `-r` selection. Explicit `/paths` retain `-p`,
which does not recursively select nested groups. Use `-l` on the test binary
from `tests/` to find exact paths.
Use fixtures for filesystem, launcher, and Steam mutations, as described in
[testing.md](testing.md#safety-rules-for-tests).

## Prepare a release

1. Inspect the working tree and run `./scripts/check.sh`. Run the relevant GUI
   checks from [testing.md](testing.md#manual-validation) and review both
   architecture build results in CI. Check local Flatpak packaging when its
   inputs changed.
2. Preview the next version, then update it:

   ```bash
   ./scripts/set-version.sh 0.6.10 --dry-run
   ./scripts/set-version.sh 0.6.10
   ```

   Substitute the intended version. This changes Meson and the tagged source
   reference in `com.vysp3r.ProtonPlus.yml`; it does not create a release.
3. Add the newest AppStream release entry with its version, ISO date, and notes
   to `data/com.vysp3r.ProtonPlus.metainfo.xml.in`. Keep entries newest first.
4. Run `./scripts/set-version.sh 0.6.10 --check` and `./scripts/check.sh`,
   then inspect the exact release diff. `--check` is read-only; without an explicit
   version it uses Meson's version. It checks local metadata, not whether a
   remote Git tag exists or packaging succeeds.
   The metadata check requires `xmllint` (the libxml2 tools package).
5. Commit the reviewed release changes and create the matching `vVERSION` tag
   through the normal release process. Publishing a GitHub release triggers
   AppImage builds; they check metadata against the published tag before
   compilation. Manual workflow dispatch does not impose release metadata
   consistency on development snapshots.

Meson, the newest AppStream entry, and the tagged Flatpak manifest are aligned
at **0.6.9**. The matching **v0.6.9** Git tag must be published through the
release process before the tagged manifest can fetch its source. `--check`
validates local metadata only; use the local manifest to build the checkout
before publishing that tag.

## Maintenance audit and priorities

The ordering below estimates recurring effort from local code and test
coverage. It does not measure feature usage. Completed changes remove
duplication without changing installed-tool identities or Steam data formats.

| Priority | Finding and evidence | Action / status |
| --- | --- | --- |
| 1 | Build/run previously built twice and could implicitly install system-wide. Test instructions used multiple defaults. | Completed: build/run once from the checkout; `scripts/check.sh` uses `build/` for full and focused checks. Build and maintenance commands live in scripts; translation source-list generation moved there when the Makefile was removed. |
| 2 | Version updates had no consistency check across Meson, tagged Flatpak source, and AppStream. | Completed: read-only `--check`, fixture tests, and a release-only AppImage guard. Local metadata is aligned; publishing the matching source tag remains a release step. |
| 3 | `InstallJob` and inventory separately spelled non-default variant directory suffixes. A change in one could make an installed tool disappear from discovery. | Completed: `ProviderTool.get_directory_name()` owns full spelling; job-to-inventory regression covers default and named variants. CLI batch updates also reuse single-update reporting. |
| 4 | Three GUI executables repeated Meson display/environment registration. | Completed: one registration table preserves target names and per-test environment. New GUI tests add a table entry. |
| 5 | Reports omitted the launcher packaging and exact tool/release; the PR template repeated generic checkboxes and linked to a missing heading. | Completed: targeted integration/log prompts and a shorter problem/validation/maintenance template. |
| 6 | The built-in MangoHud editor maintained an independent config format and many settings pages. | Removed at the maintainer's request: editor, config writer, preview, and unused preference switch. External overlay launch options remain supported; existing MangoHud configuration files are untouched. |
| 7 | `src/widgets/tools/tools-releases-box.vala` repeated successful load/refresh presentation work and owned saved-variant JSON. | Shared completion preserves request generations, refresh failure retention, inventory refresh, and row-handler cleanup. `ToolVariantPreferences` owns saved selection and legacy-key fallback. |
| 8 | `src/widgets/games/games-box.vala` combined wide/narrow factories, sort-header controller focus, filtering, and mass-edit navigation. | List construction, bindings, and row focus belong to `GameListView`; the controller adapter is separate. `GameCollection` still owns state, and `Games.Box` coordinates filtering and page navigation. |
| 9 | `src/utils/controller-manager.vala` has substantial surface, timer, and focus lifecycle work; policy decisions already have separate helpers. | Preserve that boundary. Prioritize cleanup regressions and hardware coverage over a new controller abstraction. |
| 10 | Simple launch toggles repeated catalog text, recognition tokens, and serialization types in UI groups and wrappers. | Completed: 68 simple controls use their stable catalog ID; dynamic inputs remain explicit. Change shared metadata in the catalog. |
| 11 | Startup repeatedly queried installed Flatpaks for individual optional components. | Completed: one injectable `InstalledComponents` snapshot queries and parses the list once, retaining native detection and exact-ID matching. |
| 12 | The Tools GUI test assumed the compositor honored a 400-pixel toplevel width. | Completed: a controlled content viewport tests minimum width and allocated width independently of desktop window placement. |
| 13 | `ReleaseRow` repeated creation and registration for seven actions. | Completed: a small registration helper retains explicit instance-method connections and action IDs. |

The shared Steam graph now lives in `SteamLifecycle`, used by GUI and CLI;
GUI restart orchestration remains in `Application`. Provider entries use named
`ProviderConfig` fields, which `ProviderDefinition` snapshots defensively.
Inline Tools browsing remains in place. Its actions menu belongs permanently
to the release toolbar, and expansion/request generations each have one owner.

## Feature costs and scope choices

The MangoHud editor was removed at the maintainer's request. The remaining
rows suggest maintenance boundaries, rather than a new support policy.
Further feature removals should account for usage and compatibility.

| Area | Recurring cost | Suggested maintenance boundary |
| --- | --- | --- |
| Ordinary providers | Low to moderate when a definition reuses an existing host adapter and archive workflow. Upstream names and variants still change. | Prefer exact definition/fixture edits. Avoid provider subclasses or provider-ID branches in widgets. |
| New hosting APIs | Pagination, authentication, malformed data, asset rules, and failure fixtures. | Add an adapter only for semantics existing sources cannot represent. |
| Steam configuration/restart | High: persisted intent, external writers, process evidence, platform-specific restarts. | Keep the separate owners and existing safety contracts. Maintain these even if feature growth pauses. |
| Launch-option editing | High: raw shell spelling, wrappers, unknown content, mass-edit preservation, changing option support. | Prefer catalog updates; route all serialization through the writer. Limit new wrapper semantics until fixture coverage exists. |
| Controller navigation | High manual cost across GTK controls, dialogs, input handoff, hardware, and Steam Deck. | Consider pausing new navigation features when hardware validation is unavailable. Keep input fixes and cleanup. |
| External MangoHud overlay | Launch-option detection and serialization only; the config editor has been removed. | Preserve existing wrapper/environment commands. Users manage the overlay's configuration externally. |
| SteamTinkerLaunch / TinkerGame | Specialized runtime, dependency checks, migration, registration, and installation transactions. | Keep their support limits explicit. Avoid further generalization or merging workflows merely because both target Steam. |
| Launcher installation types | Directory/layout discovery plus native, Flatpak, Snap, and shared-target differences. | Fix supported cases; require a reproducible fixture and packaging check before expanding the matrix. |
| CLI / background updates | Moderate, kept smaller by sharing install/update lifecycle with GUI. | Reuse services and result reporting; avoid a second implementation of tool mutations. |
| Flatpak / native / AppImage | SDK/dependency changes, architectures, packaging resources, release artifacts. | Keep Flatpak CI as integration evidence. Consider reducing distribution scope only if packaging becomes a recurring blocker. |

Avoid replacing the current service boundaries with one large manager or
introducing a plugin framework for ordinary providers. Both increase the
amount of context needed for routine fixes. Prefer small removals of repeated
decisions, named owners for durable state, and fixtures at the risky boundaries.
