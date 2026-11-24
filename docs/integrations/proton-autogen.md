# Proton-Autogen integration

ProtonPlus shows Proton-Autogen in the launcher selector when it finds the
`proton-autogen` host command or an existing `~/.config/proton-autogen/games`
directory. Both native and Flatpak ProtonPlus use this host profile location.
Choose **Refresh application data** in **Preferences → Advanced → Maintenance**
after changing profiles externally. Proton-Autogen owns game execution,
prefix and environment configuration, and runtime selection.

When ProtonPlus detects the host command, each row in **Games** has a play
button that runs `proton-autogen run` with the registered executable path.
Flatpak ProtonPlus runs the command on the host.

## Proton installations

The launcher ID is `proton-autogen-system`. It uses the same tool target and
install layouts as native Steam (`steam-system`). Without a detected native
Steam installation it uses `~/.local/share/Steam/compatibilitytools.d`.
The Tools catalog offers Proton-GE, Proton-CachyOS, DW-Proton, Proton-RTSP,
Proton-Tkg, Proton-EM, and Proton-Wineland. These are Proton distributions
that supply a `proton` launcher.

The Games picker lists builds with an executable `proton` in this shared
directory. ProtonPlus refreshes these choices when opening the editor. It saves
the build's folder name, which Proton-Autogen can match during runtime selection.
An existing absolute path in a profile is recognized when it resolves to the
same installed directory. Saved selections outside this list are shown as
unavailable in ProtonPlus and are preserved until the user picks a new one.
Proton-Autogen uses its own search paths when launching. Custom native Steam
locations must be discoverable by Proton-Autogen to use builds stored there.

## Profile compatibility contract

Every readable, regular `*.json` file directly in
`~/.config/proton-autogen/games` can represent a registered executable. The
file must contain a UTF-8 JSON object and be at most 1 MiB. ProtonPlus uses the
discovered filename as the edit target and skips symlink entries. The profile
fields used by ProtonPlus are described below.

| Field | Expected value |
| --- | --- |
| `id` | Optional string. Used with `path` to detect a replacement of the loaded profile. |
| `name` | Optional string. The filename portion of `path` supplies the label when the name is empty or absent. |
| `path` | Required nonempty absolute executable path. The profile stays visible when the executable is temporarily unavailable. |
| `proton` | Optional string or null. Empty, absent, and null values display as Automatic. An explicit choice writes a folder name. Clearing an explicit choice writes an empty string. |
| `config_path` | Optional upstream metadata. The persisted value is preserved. |

### Saving a selection

- Loading skips malformed profiles and unsupported types for fields ProtonPlus
  reads.
- Apply rereads the file and sets only the top-level `proton` value. It
  preserves other bytes, including unknown fields and nested values.
- Writes use atomic replacement with an ETag check. A changed executable, ID,
  or Proton choice requires a refresh before editing.
- A multi-game edit reports failures per game and keeps successful edits.

The launcher icon comes from [Proton-Autogen](https://github.com/N3oRay/proton-autogen/blob/main/usr/share/icons/hicolor/scalable/apps/proton-autogen-hd.svg).
