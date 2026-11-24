# Troubleshoot ProtonPlus

## A launcher is missing

Open the launcher at least once to create its data directory. In
**Preferences → Advanced → Maintenance**, choose **Refresh application data**.
Check that your launcher uses a
[supported installation type](compatibility.md#launchers). For a Flatpak
launcher, confirm that its app data exists and that any external Steam
library is visible to ProtonPlus.

## Releases fail to load

Check your network connection and proxy in **Preferences → Advanced →
Network**. If you hit an API rate limit, configure a GitHub or GitLab token
under **API Tokens**. Use the reported error to distinguish a missing release
from an invalid token or upstream outage.

## An install or update is blocked

Close games that are using the compatibility tool and retry. ProtonPlus
protects active tools from changes that could affect a running game.

## Downloads or release listings look stale

Choose **Delete cache** in **Preferences → Advanced → Maintenance**, then
retry. ProtonPlus will fetch the release listing and any needed archives again.

## An archive fails to install

Refresh the release and retry. The provider may have published an incomplete
archive or one in an unsupported format. If the error persists, include the
provider, release, and exact error when filing a report.

## Steam reports a failed compatibility tool

To check a Valve Proton build or Steam Linux Runtime, use the
[Steam compatibility-tool recovery guide](steam-tool-troubleshooting.md).

## Wine or Proton fails to start on openSUSE

On openSUSE MicroOS, Aeon, or Kalpa, an SELinux `execmod` denial can prevent
Wine or Proton from launching inside a Flatpak. Check the SELinux audit log
for the failed launch, then check the boolean's current value:

```sh
getsebool selinuxuser_execmod
```

If the log confirms the denial and the boolean is off, the documented
workaround is to enable it. This changes host policy until the next boot:

```sh
sudo setsebool selinuxuser_execmod on
```

If the test resolves the failure and you want the policy change to survive
reboots, use `sudo setsebool -P selinuxuser_execmod on`. Use `off` to restore
the disabled setting. [Upstream Bottles report](https://github.com/bottlesdevs/Bottles/issues/3326)

## ProtonPlus reports a missing settings schema on NixOS

If ProtonPlus installed through nix-flatpak reports that
`com.vysp3r.ProtonPlus.State` is missing, check if a Flatpak override changes
`GSETTINGS_SCHEMA_DIR`. The ProtonPlus Flatpak sets this variable to its
bundled schema directory. To explicitly set that path in nix-flatpak, add
this to your configuration and rebuild:

```nix
{
  services.flatpak.overrides.settings."com.vysp3r.ProtonPlus".Environment.GSETTINGS_SCHEMA_DIR =
    "/app/share/glib-2.0/schemas";
}
```

[nix-flatpak override syntax](https://github.com/gmodena/nix-flatpak#inline-configuration)

## Report a problem

Include the ProtonPlus version, installation type, selected launcher, and steps
to reproduce the problem. Copy environment details from **Preferences →
Advanced → System Information** and remove private paths or tokens before
sharing. [Issue tracker](https://github.com/Vysp3r/ProtonPlus/issues)
