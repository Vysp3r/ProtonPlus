# Codebase guide

This guide maps the current ProtonPlus codebase and the boundaries that matter
when changing it. It complements the contributor setup in
[`CONTRIBUTING.md`](../CONTRIBUTING.md) and the provider-specific extension
guide in [`provider-architecture.md`](provider-architecture.md).

## System overview

ProtonPlus is a Linux GTK4/libadwaita application written primarily in Vala.
It discovers supported game-launcher installations, builds a catalog of tools
eligible for each launcher, obtains releases from upstream hosting APIs, and
installs those releases into launcher-specific layouts. Steam adds game
library, VDF configuration, launch-option editing, and restart coordination.

There are two process composition roots in `src/main.vala`:

- With no command argument, `Widgets.Application` creates the GUI process,
  initializes global settings and host capabilities, composes the Steam
  session/configuration/restart services, and creates the main window.
- With a command argument, `CLI.Handler` runs under a `GLib.MainLoop`. Commands
  that can mutate tools also compose the Steam lifecycle services so CLI and
  GUI operations produce the same restart receipts.

The broad dependency direction is:

```text
data / GSettings / host state
              |
              v
launcher models -> provider definitions -> tools -> release catalogs
       |                                      |
       v                                      v
games and installed inventory           releases and variants
       |                                      |
       +------------------+-------------------+
                          v
               InstallJob / services
                          |
                          v
          filesystem, metadata, Steam receipts
                          |
                          v
                    GTK UI or CLI
```

Widgets may coordinate presentation, but they should not become remote API
parsers, provider registries, filesystem transactions, or persistence owners.

## Repository map

| Path | Responsibility |
| --- | --- |
| `src/main.vala`, `src/globals.vala` | Process selection, global settings, host capability detection, cache root, and localization setup. |
| `src/models/` | Launchers, games, providers, releases, assets, variants, installed inventory, and Steam lifecycle value objects. |
| `src/models/launchers/` | System/Flatpak/Snap detection, launcher-specific directories, libraries, profiles, and capabilities. |
| `src/models/providers/` | Built-in provider definitions, validation, stable IDs, variants, filtering, and install layouts. |
| `src/providers/sources/` | Stateless GitHub, GitHub Actions, GitLab, and Forgejo fetch/normalization adapters. |
| `src/services/` | Install/update/remove coordination, archive transactions, Steam configuration and restart lifecycle, process guards, and migrations. |
| `src/utils/` | Filesystem, archive, network, cache, process, metadata, translation, VDF, and platform helpers. |
| `src/widgets/` | GTK4/libadwaita application, loading flow, main navigation, Tools, Games, preferences, downloads, introduction, and MangoHud UI. |
| `src/cli/` | Command parsing, stable/legacy identity matching, progress, return codes, and injectable terminal output. |
| `data/` | GResources, CSS, icons, desktop/AppStream metadata, GSettings schema, and systemd user units. |
| `tests/` | One TAP-producing Vala test executable, Python maintenance tests, and host-independent fixtures. |
| `po/` | Gettext POT source list, template, and translation catalogs. |
| `scripts/` | Native/Flatpak/AppImage build helpers and maintenance commands. |

Each source subtree contributes files to the shared `sources` collection in
its local `meson.build`; `src/meson.build` builds a static core library used by
both the application and tests.

## Core runtime flows

### Startup and launcher discovery

`Widgets.Loading.Box.load()` calls `Models.Launcher.get_all()`. The launcher
model constructs all supported system, Flatpak, and Snap candidates, retains
detected installations, and then initializes each launcher:

1. Select launcher-supported categories (`PROTON`, `WINE`, `DXVK`, `VKD3D`).
2. Resolve and attempt to create each category's target directory. A target
   filesystem failure is logged but does not prevent other launcher state from
   loading; installation workflows enforce writability when a mutation begins.
3. Create a `Group` with an `InstalledToolInventory`.
4. Filter the `ProviderRegistry` definitions through launcher capabilities and
   ask `ProviderCatalog` to create `ProviderTool` instances.
5. Add TinkerGame and the retained legacy SteamTinkerLaunch tool for Steam's Proton group.
6. Load the launcher library and, for Steam, profiles plus effective staged
   configuration overlays.

The resulting launchers are passed to the header and `Widgets.Main.Box`.
Changing launcher detection therefore affects models, group/tool composition,
the loading view, CLI listing, and potentially physical target identity.

### Provider and release browsing

The ordinary provider path is definition-driven:

```text
ProviderDefinition -> ProviderRegistry -> ProviderCatalog -> ProviderTool
       -> ReleaseSourceRegistry -> ReleaseSource -> ReleaseCatalog
       -> ReleasePageResult -> Release / Asset / Variant
```

`ReleaseSource` fetches and normalizes one page. `ReleaseCatalog` owns the
mutable page, pagination, cached snapshot, refresh behavior, and latest-release
lookup for one tool. A forced refresh replaces published releases only after a
successful page fetch; latest discovery starts at upstream page one without
mutating browse state.

Use [`provider-architecture.md`](provider-architecture.md) for the exact
provider, source, and specialized-workflow extension rules.

### Installed-state discovery

Every `Group` owns one `InstalledToolInventory`. It scans the launcher's
ProtonPlus-managed tool directories, reads `.protonplus` metadata and compatibility-tool
manifests, and resolves installed entries back to tools. Stable persisted
identity wins; carefully bounded legacy fallbacks may migrate metadata when a
match is unambiguous.

Services invalidate this inventory after installation or removal. Consumers
refresh it at an explicit boundary and read a snapshot. Do not let a widget or
each tool independently rescan the same directory; that creates stale and
cross-launcher state.

Steam-selectable tools have a separate boundary:
`SteamCompatibilityToolDiscovery` reads Steam library apps, the active Steam
`compatibilitytools.d`, native distro roots, or Flatpak Steam extensions as
appropriate for that launcher. External entries remain lightweight
`CompatibilityTool` models and never enter inventory or installation
workflows. `CompatibilityTool.path` is the launcher/host path; its explicit
inspection path is used for sandbox-side VDF, Proton-launcher, and bounded
feature probes. Package/custom roots obtain their exact identity from
`compatibilitytool.vdf`. Official Steam library tools instead use their stable
Valve app ID mapping and require a regular `toolmanifest.vdf`; Proton entries
also require a regular `proton` launcher. Display names never supply persisted
Steam compatibility-tool IDs.

### Install, update, and removal

UI and CLI create an `InstallJob` containing the target tool, release/asset or
variant, install location, mode, progress, and cancellation state. The job
delegates to the singleton `InstallationService`.

For provider-backed jobs, `InstallationService` resolves an exact compatible
variant before registering an operation, downloading, or touching the
filesystem. It then:

1. Reserves the destination before any asynchronous check, rejecting overlapping
   install, update and removal requests. The reservation lasts through update
   finalization and rollback; each accepted operation resets cancellation once.
2. Checks for active compatibility processes.
3. Selects the workflow from explicit job capability/context.
4. Registers download and cache-operation lifecycle.
5. Executes the transactional workflow.
6. Invalidates installed inventory and finalizes tool state/history.
7. Records a Steam change receipt when the target belongs to Steam storage.

`StandardArchiveWorkflow` stages extraction privately, validates and promotes
the result, restores the previous installation on failed replacement, writes
metadata, and cleans owned temporary paths. `SteamTinkerLaunchWorkflow` is a
separate transaction because its layout and lifecycle materially differ.
`TinkerGameWorkflow` specializes archive preparation to validate the required
runtime and stage its Steam registration with the installation; see
[`tinkergame.md`](tinkergame.md) for supported targets and migration policy.

Operations that can change an existing compatibility tool perform a second
asynchronous, target-aware process check at the workflow's final mutation
boundary, after download and staging but before moving or deleting installed
state. This minimizes the check-to-mutation race; it cannot provide
kernel-level locking against a compatibility process starting in the final few
instructions between the snapshot and the filesystem mutation.

### Download recovery

`Utils.Web` owns HTTP recovery. Downloads use a separate Soup session with a
30-second socket inactivity timeout; API sessions retain libsoup's original
timeout policy. Both use the same configured proxy resolver and user agent.
Every attempt starts from the catalog URL and follows redirects anew, so an
expired redirected URL is never persisted as an asset identity.

The recovery window is **10 minutes from the first interruption**, including
subsequent transfers and waits, with **32 total attempts** as a second bound.
It does not reset when some bytes arrive. Backoff grows 1/2/4/8/16/30 seconds,
then stays at 30. Numeric and HTTP-date `Retry-After` can extend that wait; if
it exceeds the remaining recovery window, the operation fails without retrying
early. A timer cancels an in-flight request when the recovery window expires.
Transient socket/DNS errors and HTTP 408/429/500/502/503/504 are recoverable.
Other HTTP statuses, TLS, local filesystem, and validation failures are terminal.

`InstallJob` exposes downloading, waiting to retry (countdown and next attempt),
and reconnecting states to the existing GUI and CLI progress paths. Waiting
preserves progress and clears speed/ETA; Cancel remains responsive. Transfer
speed uses a three-second exponentially smoothed estimate, reset for each
accepted response, so waits, saved bytes, and discarded transfers cannot inflate
speed or ETA. Unknown totals report bytes with no ETA; all attempts retain the
shared global speed limiter.

`PartialDownloadCache` owns unvalidated bytes under `partials/`, separate from
validated `archives/`. Version-1 metadata records catalog asset identity (URL,
name, size, digest), strong ETag, byte count, total representation length, identity
encoding, and update time. Mirrored downloads use version 2 with the effective
endpoint so older builds reject their partial bytes. Changing the endpoint
invalidates the partial while retaining the per-asset lock. The optional
`github-download-mirror` setting is resolved once at the `InstallJob` download
boundary; catalog URLs and completed archive identities remain canonical.
A new operation checks metadata types/version, expiry,
regular files without following symlinks, and exact byte count before sending
`Range`/`If-Range`. Missing or weak validators cannot resume. A `206` must match
the validator, offset, total, and complete remaining range. A `200` replaces the
partial; a `416` abandons the validator and retries a full download. Malformed
responses are discarded, never appended. Completed downloads still undergo the
workflow's size/digest and extraction validation before archive publication.

Recoverable terminal failures retain eligible partials for manual Retry and a
later application launch. Explicit Cancel, permanent failure, invalid metadata,
and validation failure discard partials. Only interrupted transfers with a
strong validator are retained; metadata is checkpointed after terminal recovery,
so a process crash during transfer may safely fall back to a fresh download.
Per-asset OS locks reject concurrent writers, including other processes. A shared
cache lock covers each complete installation transaction, including cache hits,
verification, extraction and staging, so another GUI or CLI process cannot clear
its working files. Its small lock file lives beside
the disposable cache tree so clearing cannot replace a locked inode.

Cleanup runs off the UI thread under an exclusive cache lock, after installation
transactions and around standalone downloads. It never prunes active transfers. Retained partials expire after **7 days**;
cleanup keeps at most **32 entries / 2 GiB total**, preferring recent entries.
Active transfers are exempt from these retention limits; when all leases finish,
cleanup applies them. Clear Cache waits for active operations and removes both
partial and completed archives, while Steam restart state remains outside cache.

### Steam configuration and restart lifecycle

Steam-owned files have a separate safety boundary:

```text
game / preferences action
        -> SteamConfigurationService
        -> immediate write only when Steam is confirmed stopped
           OR persisted SteamConfigurationIntent
        -> SteamRestartManager
        -> SteamRestartStateStore
        -> banner / dialog / notification
        -> SteamRestartOrchestrator
        -> confirmed stop -> reconcile -> relaunch -> verify new generation
```

`SteamConfigurationService` is the production mutation entry point for
default/per-game compatibility mappings, regular and non-Steam launch options,
and the ProtonPlus shortcut. While Steam is running, it stages replayable
intent instead of writing Steam-owned files; model loading overlays that intent
in memory so accepted state remains visible after a ProtonPlus restart.

`SteamRestartManager` deduplicates receipts by physical Steam target/resource,
persists them, watches session evidence, and clears only satisfied records.
Each state mutation takes a nonblocking process lock, reloads current records,
and holds the lock through reconciliation and persistence. A busy lock reports
failure for retry instead of overwriting another GUI or CLI writer. Read
boundaries and file observation refresh external changes; unchanged records
retain their verification identity, while stale verification cannot clear a
newer edit.
`SteamSessionService` keeps native process evidence separate from Flatpak
instance evidence. `SteamRestartOrchestrator` owns preflight, shutdown,
confirmed exit, configuration reconciliation, detached relaunch, and new-session
verification. SteamOS Gaming Mode uses a bounded handoff rather than the normal
Desktop Mode reconciliation path.

The state file is safety state, not cache. Clearing the release cache must not
remove a pending restart requirement.

### Launch-option editing

The Steam launch-options editor is split into UI-free semantic services and
GTK adapters:

```text
raw source -> shell tokenizer -> LaunchCommandParser -> editor projection
     + current selection sources + edit state
                 -> LaunchCommandWriter
                 -> exact preview and Apply command
```

`LaunchCommandParser` preserves raw shell tokens and classifies managed,
unrecognized, opaque, wrapper, boundary, and game-argument content.
`LaunchCommandComposer` validates catalog selections and builds a managed
command. `LaunchCommandWriter` decides whether a source can be safely merged
and is the only serializer used by preview and Apply.

`LaunchCommandEditState` owns baseline fingerprints, modified option IDs, and
explicit Clear. Clear changes the session to a full-source replacement; later
edits must not merge old source content back. Mass edit shares control state
but calls the writer independently for every game's original command.

## Identity and persistence contracts

| Contract | Owner and purpose |
| --- | --- |
| `Launcher.family_id`, `instance_id` | Stable UI and CLI launcher identity. |
| `tool_target_family_id`, `tool_target_id` | Physical compatibility-tool storage identity; may intentionally be shared by launcher instances. |
| Provider/tool/variant/release IDs | Stable catalog, selection, update, cache, and installed metadata identity. |
| `.protonplus` file in an installed tool | Provider, tool, launcher target, variant, release, and legacy matching metadata. |
| `data/com.vysp3r.ProtonPlus.gschema.xml` | User preferences and durable UI selections. |
| `$XDG_CACHE_HOME/ProtonPlus/` | Recoverable release snapshots, downloaded archives, and private operation workspaces. |
| `$XDG_STATE_HOME/ProtonPlus/steam-restart-state.json` | Private durable restart receipts and staged Steam configuration intents. Never treat as disposable cache. |
| Steam `config.vdf`, profile `localconfig.vdf`, `shortcuts.vdf` | Steam-owned configuration; mutate through `SteamConfigurationService`. |

Persisted and user-visible IDs must not be derived from translated labels or
display strings. Any intentional rename needs migration behavior and tests for
old data.

## Where to make a change

| Goal | Primary location | Also inspect |
| --- | --- | --- |
| Add an ordinary provider | `src/models/providers/definitions/` | Provider fixtures, registry/source/layout tests, translations if visible text changes. |
| Add a hosting API | `src/providers/sources/` and source registry | `SourceType`, parser fixtures, pagination/failure/identity tests. |
| Change launcher detection/layout | `src/models/launchers/` | Launcher initialization, target identity, CLI IDs, install layouts, Flatpak manifest. |
| Change archive installation | `src/services/standard-archive-workflow.vala` | `InstallationService`, process guard, metadata, inventory, installer/update transaction tests. |
| Change Steam configuration | `steam-configuration-service.vala` | VDF helpers, manager/store, session evidence, orchestrator, effective-state overlays. |
| Change launch options | `src/widgets/games/launch-options-editor/` | Read [`launch-options.md`](launch-options.md), then check parser/composer/writer/projection tests and both single-game and mass-edit Apply paths. |
| Change tool variants | Variant models and provider definitions | Catalog asset selection, saved selection, Tools UI projection, install/update guard. |
| Change GTK behavior | Relevant `src/widgets/` subtree | Model/service boundary, async lifetime, controller access, translations, manual checks. |
| Add a setting | GSettings schema and preferences widgets | Defaults, bindings, migrations when semantics change, schema validation. |
| Add a CLI behavior | `src/cli/cli.vala` | Stable aliases/return codes, `CliOutputSink`, lifecycle composition, CLI tests. |

## Non-obvious rules

- GSettings, metadata, CLI aliases, and state-file fields are compatibility
  surfaces even when they are not visible in the GUI.
- Do not mutate complete release/variant collections to implement filtering;
  several install/update and persistence paths share them.
- Do not redirect process-wide stdout/stderr in tests. CLI output is injected
  through `CliOutputSink`; descriptor replacement corrupts GLib TAP output.
- New UI strings require gettext extraction, but documentation text does not.
- A successful build or headless test does not validate GTK placement,
  interaction hit areas, focus, rendered markup, or actual Steam lifecycle
  behavior. Record those checks separately.
