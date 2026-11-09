# Recovering a Steam compatibility tool

ProtonPlus can report a problem with a Valve Proton build or Steam Linux Runtime
owned by Steam. Games depending on that tool may show “Compatibility tool
failed”, hang while downloading a runtime, or exit before starting.

The warning belongs to the Steam installation selected in ProtonPlus. Open
**Learn More** to see its installation type, Steam directory, affected app IDs,
and any known install paths. Native, Flatpak, and Snap Steam have separate
configuration and logs. A library on another drive may contain the affected
tool even when Steam itself lives elsewhere.

## What the warning establishes

ProtonPlus checks for either:

- A known Steam tool whose appmanifest claims a completed installation but
  whose required files are missing. These include `toolmanifest.vdf` and, for
  Proton, its `proton` launcher. A nonzero build ID alone does not prove the
  files are usable.
- A failure for a known tool in that installation's `logs/compat_log.txt`
  during the previous 24 hours: a missing tool manifest or an unsupported
  version of zero. This can identify the failure even when both its
  appmanifest and its library registration are absent.

Active or paused updates defer the warning. Usable installed files or a later
successful log entry suppress the corresponding log failure. Optional tools
that have never been installed do not produce warnings just because they are
absent. Missing, unreadable, older, or unrecognized log evidence can prevent
detection; an absent warning does not prove that every Steam tool is healthy.

These checks do not establish a single cause. Steam download state, account
entitlements, or compatibility settings can produce similar symptoms.
ProtonPlus reads this evidence; it does not install Valve depots or rewrite
Steam's appmanifests as a repair.

## First checks

1. Confirm that the selected Steam installation is the one running the game.
   If you have several Steam installations, inspect each separately.
2. Finish or resume outstanding downloads in that Steam client. Find the
   affected Proton or Steam Linux Runtime under **Library → Tools**, open its
   properties, and verify its installed files. Restart Steam and retry the game.
3. If the tool was assigned another compatibility tool manually, review that
   setting in Steam. Steam Linux Runtime is itself a runtime, rather than a
   Windows game that needs Proton assigned to it. Avoid assigning Proton to
   runtime apps through mass edits or external configuration changes.
4. Restart ProtonPlus after Steam finishes recovery to refresh the diagnostics.
   Dismissing the warning only hides it for the current ProtonPlus session.

## When normal verification does not recover the tool

The upstream [Steam compatibility-tool failure report](https://github.com/ValveSoftware/steam-for-linux/issues/13248)
contains diagnostic logs and community recovery approaches, including direct
depot downloads. The original ProtonPlus report is
[#1232](https://github.com/Vysp3r/ProtonPlus/issues/1232).

Those workarounds are examples for particular installations and builds. Use
the affected app ID and the current depot/build information from Steam, and
the destination printed by the actual download. Do not copy another user's
build IDs, hardcoded native Steam paths, or depot selection into Flatpak,
Snap, or a different Steam library. Some tools need more than one depot.

If you choose a manual recovery, finish the download, close games, and fully
exit the affected Steam client before replacing installed files or editing an
appmanifest. Back up the original files first. A running Steam client can
rewrite its own records. Restart Steam after the changes and verify the tool
and a dependent game before considering the recovery complete.

For further help, include ProtonPlus's System Information, the affected Steam
installation type and app ID, whether its appmanifest exists, and relevant
recent lines from that installation's `compat_log.txt` and `content_log.txt`.
Remove account identifiers and private paths before sharing logs.
