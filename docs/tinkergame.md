# TinkerGame and SteamTinkerLaunch

ProtonPlus offers TinkerGame for new installations. Existing SteamTinkerLaunch
installations remain visible, updatable and removable under their original
identity. They are never converted or removed by installing TinkerGame.

## Reviewed upstream contract

The initial integration was reviewed against upstream commit
[`b8218f94fe179d8a388cadefa13930335ae790d8`](https://github.com/360900/tinkergame/tree/b8218f94fe179d8a388cadefa13930335ae790d8)
(`v0.1.0-alpha.14`). The reviewed files are `README.md`, `MIGRATION.md`,
`install.sh`, `Makefile`, `tinkergame`, `lib/core/{common,paths,bootstrap,deps}.sh`,
`lib/gui/prepare.sh`, `lib/steam/libraries.sh`, and `lib/cli/compat.sh`.

**Release policy:** automatically offer the newest published GitHub release,
including alpha/prereleases, using its source ZIP archive. Drafts are skipped.
The catalog offers one release because TinkerGame occupies one managed slot.
Catalog browsing uses the normal cache; Check for Updates fetches upstream
again and compares the installed release tag with the newest published tag.
New releases do not require a ProtonPlus update. An installation from the old
commit-pinned implementation is replaced once to record the release tag.
Missing runtime files or invalid registration can still be repaired at the
same version. Existing staging validation and rollback remain in place; if
upstream changes the required runtime layout or registration contract,
ProtonPlus may need a follow-up fix. Discovery failures preserve the installed
version, and CLI removal works without contacting GitHub.

| Contract | Legacy | Successor |
| --- | --- | --- |
| Provider/CLI ID | `steam-tinker-launch` | `tinkergame` |
| Executable | `steamtinkerlaunch` | `tinkergame` |
| Compatibility directory | `SteamTinkerLaunch` | `TinkerGame` |
| Steam identity | `Proton-stl` | `Proton-tg` |
| Configuration directory | `steamtinkerlaunch` | `tinkergame` |

Legacy release-kind strings, tool IDs and `steamtinkerlaunch-changed` restart
receipts retain their existing meaning. TinkerGame uses the ordinary
compatibility-tool installation/update/removal receipts. Both installations
can coexist and retain independent operation IDs and inventory entries.

## Managed installation

The supported combination is **native ProtonPlus and native Steam outside
SteamOS**. Flatpak Steam, Snap Steam, Flatpak ProtonPlus and SteamOS are rejected
explicitly. Upstream has separate sandbox and Deck dependency/bootstrap paths;
these are not claimed as supported by this integration.

ProtonPlus installs the source runtime under the selected Steam instance's
`compatibilitytools.d/TinkerGame`. It retains the executable, all modules and
runtime data. Every runtime file in the reviewed source's `lib`, `collections`,
`data`, `eval`, `guicfgs`, `lang` and `misc` trees must be present as a regular
file with no symlink component. Other extracted links are preserved, not
traversed. Validation runs off the GTK thread.

The executable loads adjacent modules. ProtonPlus changes the exact verified
`SYSTEMSTLCFGDIR` assignment in `lib/core/paths.sh` to `$TG_LIBDIR/..`, binding
data lookup to the managed runtime even when a system installation coexists.
It sets executable permissions and writes the two Steam manifests in staging,
using the upstream `Proton-tg`, `/tinkergame run`, and
`/tinkergame waitforexitandrun` contracts.

Upstream `compat add` discovers Steam through `~/.steam/root`, `~/.steam/steam`
and cached configuration. It is not a selected-target registration API.
ProtonPlus therefore does **not** execute upstream registration, installation,
initialization or uninstall commands. Runtime and registration are promoted
as one directory transaction: a preparation failure leaves the old tree
untouched, and failed promotion restores the previous tree and manifests.
Existing installations must carry matching ProtonPlus ownership metadata to
be replaced or removed. Ownership is checked again after asynchronous work,
immediately before replacing or deleting the installation. Configuration lives outside this directory and is
always retained on removal. No global `~/.local/bin` link is installed; native
game launch options can use the absolute managed executable path explicitly.

The workflow reuses the archive staging/promotion transaction, process guard,
cancellation, inventory invalidation and restart-receipt lifecycle. It checks
runtime dependencies for both GUI and CLI installations. Upstream still checks
`xdotool` despite describing it as optional in its README; the required list
also includes `pidof`, `pkill`, `tar`, and `jq`. Make is unnecessary because the
upstream installer is not run. YAD >= 7.2 is required; YAD 15 is accepted because
`lib/gui/prepare.sh` probes and omits its removed options. SteamTinkerLaunch's
YAD 15 warning is unchanged.

## Explicit migration

1. Install TinkerGame while keeping SteamTinkerLaunch installed.
2. On TinkerGame's release row, choose **Copy SteamTinkerLaunch Settings…**.
   This action appears only while a legacy installation is discovered.
3. Review the copied settings and select TinkerGame for individual games in
   Games when ready. Test those games before removing the legacy tool.

Migration copies `${XDG_CONFIG_HOME:-$HOME/.config}/steamtinkerlaunch` into a
private staging directory beside the destination. It requires a validated
TinkerGame installation, refuses any existing `tinkergame` destination
(including a symlink), and publishes only a completed copy. It preserves
symlinks without following them and rejects unsupported file types. Failed
copies and filename collisions leave the original settings intact and permit
retry. No automatic merge or deletion of an existing destination is offered.

The only transformation renames `SteamTinkerLaunch` in copied file/directory
basenames to `TinkerGame`, as documented upstream. File contents and symlink
targets remain unchanged. Review custom commands, old CLI subcommands, absolute
paths and links to old downloads manually. Custom data/cache locations outside
the configuration tree are left in place.

Migration never reassigns games or rewrites launch options. An explicit game
selection uses the existing `SteamConfigurationService` and persisted intent
lifecycle; Steam-owned files change only after Steam is confirmed stopped.
Ambiguous references in commands, quoted arguments or scripts are never
replaced. Legacy cleanup remains a separate user action after game testing.

## CLI and validation

Individual `install`, `update`, and `uninstall` commands accept `tinkergame`;
`list <launcher>` includes both installed products. Legacy IDs continue to
address SteamTinkerLaunch for update/removal. A legacy fresh-install request
reports that TinkerGame is the offered successor; it never silently redirects.
GUI bulk updates and CLI `update all` / `update <launcher>` also check installed
TinkerGame releases. Bulk removal retains its existing provider-only scope.

`/tinkergame` tests use a structural archive fixture with inert executable and
module contents and injected dependencies/process queries. They exercise
installation, update, removal, ownership separation, incomplete archives,
promotion/registration failure, cancellation, process guards, migration,
identity parsing and YAD classification. The fixture file names come from the
reviewed source tree; no test executes TinkerGame or touches a real Steam
installation. `/steam-configuration/tinkergame-reassignment-preserves-launch-options`
covers persisted staged reassignment and unchanged raw launch options.

Automated fixtures and upstream shell syntax checks do not establish GUI,
packaging, game-launch, Steam restart or Steam Deck acceptance. Those require
separate integration testing.
