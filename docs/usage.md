# Use ProtonPlus

## Manage tools

1. Select your launcher, then open **Tools**.
2. Choose a tool category, open a tool, and select a release or variant to install.
3. Use the installed, used, and unused filters to review the tools you have.
4. Open an installed release to update or remove it, visit its upstream page, or migrate games where supported.

The header shows download and update progress. You can cancel downloads there.
ProtonPlus sends a desktop notification when an operation finishes while the
application is inactive.

## Manage Steam games

Open **Games** to select a Steam profile, change a game's compatibility tool, or
edit launch options. Select multiple games for bulk edits. ProtonPlus lets you
know when Steam needs to restart for changes to take effect.

Use **Preferences** to set Steam's default compatibility tool or add a
ProtonPlus shortcut to Steam.

## Use Proton-Autogen

Select **Proton-Autogen** in the launcher menu. **Tools** manages builds in
native Steam's compatibility-tool directory. **Games** shows the executables
registered with Proton-Autogen. Choose an installed build or select
**Automatic** to let Proton-Autogen choose. Use the play button to launch an
executable. [Proton-Autogen integration guide](integrations/proton-autogen.md)

## Gamepad navigation

Use the D-pad or left stick to move and the right stick to scroll. The
configured confirm button activates the focused control. Use the other face
button to go back or close a dialog or menu. Follow the on-screen hints for
page, search, filter, menu, and launcher shortcuts.

On Steam Deck, focus a text field and press **Steam + X** to open the on-screen
keyboard. On other systems, use the system's on-screen keyboard or a physical
keyboard.

## Command-line interface

Use `protonplus` for native installations and `flatpak run com.vysp3r.ProtonPlus`
for Flatpak. With no arguments, either command opens the graphical app.

```text
protonplus version
protonplus help
protonplus list [launcher_id]
protonplus search [--json] [query]
protonplus outdated [--json] [launcher_id]
protonplus sync [launcher_id]
protonplus cleanup
protonplus install <launcher_id> <runner_id> [latest]
protonplus uninstall <launcher_id> <runner_id> [all]
protonplus uninstall <launcher_id> all
protonplus update <launcher_id> [runner_id]
protonplus update all
```

Start with `list` to find launcher IDs, then use `list <launcher_id>` to find
the runner IDs, versions, and display names of installed tools grouped by
category. Older installations without a recorded tag show `—` in the Version
column. The list covers releases that ProtonPlus can match to a provider.
`list`, `help`, `version`, `search`, and `outdated` are read-only.

- `search` finds available runners for detected launchers. It matches words
  case-insensitively across the package ID, name, and description. Omit the
  query to list the catalog.
- `outdated` checks the upstream release for each installed `Latest` variant
  and for managed TinkerGame installations. Pinned releases are excluded. Omit
  the launcher ID to check all detected launchers. A failed check is reported
  on stderr and returns a nonzero exit status, with successful results still
  available on stdout.
- `sync` refreshes the release metadata cache for one launcher or all detected
  launchers. It reports provider and cache write failures on stderr.
- `cleanup` clears cached release metadata, downloaded archives, and partial
  downloads. It waits for cache operations and leaves installed tools intact.

`search --json` and `outdated --json` emit an object with `schema_version` (1)
and a `packages` array. Each package has `id` (`<launcher_id>/<runner_id>`),
`launcher_id`, `runner_id`, `tool_target_id`, and `name`. Search adds `category`
and `description`. Update results add `installed_version`, `latest_version`,
and `variant_id`. An unknown installed version or variant is `null`. A runner
with several outdated variants can have several rows with the same package ID.

```sh
protonplus list
protonplus list steam-system
protonplus install steam-system proton-ge latest
protonplus update steam-system
protonplus update all
protonplus uninstall steam-system proton-ge
```

`latest` selects the newest eligible release. Use
`uninstall <launcher_id> <runner_id> all` for every release of one tool, or
`uninstall <launcher_id> all` for every managed tool in that launcher.

## Preferences

- Choose a theme (system, Adwaita, Breeze, SteamOS, or OLED), language,
  controller confirm button, and vibration setting.
- Set the update frequency, startup checks, and background updates.
- Configure GitHub and GitLab API tokens, a proxy, and a shared download speed limit.
- Set legacy-tool visibility and default-prefix migration behavior.
- Clear cached releases and downloads or open **System Information**.

Native builds store cached data under the XDG user cache directory, usually
`~/.cache/ProtonPlus`. Flatpak builds use the sandbox's XDG cache directory.

### GitHub download mirrors

In **Preferences → Advanced → Network**, set **GitHub Download Mirror** to a
trusted HTTPS URL prefix and apply the field. Leave it empty for direct
downloads. ProtonPlus adds a trailing slash if needed. Use a prefix without
credentials, a query string, or a fragment.

For example, `https://mirror.example/` changes
`https://github.com/owner/repo/releases/download/tag/asset` to
`https://mirror.example/https://github.com/owner/repo/releases/download/tag/asset`.

The mirror is independent of the HTTP or SOCKS proxy setting. It applies to
new GitHub release asset downloads in the GUI and CLI. Ongoing downloads keep
their original endpoint. API requests, release lists, source archives,
Actions artifacts, and other hosts use their original endpoints.

Changing the mirror discards partial downloads from the previous endpoint.
Validated archives remain reusable. ProtonPlus still checks the size and
digest whenever the provider supplies them.

### Repair shared Steam compatibility tool keys

To inspect a Steam installation, run `protonplus steam-key-repair steam-system preview`.
Use the corresponding launcher ID for Steam Flatpak or Snap. The preview lists
duplicate keys, their claimants, affected AppIDs, and pending ProtonPlus edits.
AppID 0 is Steam's global default. Games that inherit the default follow it
unless you add a per-game assignment.

Exit Steam completely before applying the repair. Copy the preview token and
select a directory the preview says can retain the key. For example:

```sh
protonplus steam-key-repair steam-system apply TOKEN 'Shared Key' 'Default Latest' \
  '0=Alternate Latest' '12345=Alternate Latest'
```

Each optional assignment sends one AppID to a rekeyed directory. Omitted
assignments continue to use the historical key or inherit the global default.
Repair one shared key at a time and run a fresh preview before repairing the
next. A conflicting external tool or pending edit must be resolved before
applying. If an operation stops partway through, exit Steam and run
`protonplus steam-key-repair steam-system resume` for the same target.
