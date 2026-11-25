# Install ProtonPlus

ProtonPlus runs on Linux. Flathub is the recommended installation method.

## Flatpak

If Flathub is missing from your Flatpak remotes, add it first:

```sh
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

Install and launch ProtonPlus:

```sh
flatpak install flathub com.vysp3r.ProtonPlus
flatpak run com.vysp3r.ProtonPlus
```

The package needs host filesystem access for Steam libraries and access to
specific launcher data directories. If a launcher is missing, check the
[supported installation types](compatibility.md#launchers) and the
[launcher detection steps](troubleshooting.md#a-launcher-is-missing).

## GitHub release packages

Choose the package for your distribution and architecture from
[GitHub Releases](https://github.com/Vysp3r/ProtonPlus/releases). File names
include the ProtonPlus version, the package target, and the architecture
(`x86_64` or `aarch64`).

| Distribution or format | Target | Install the downloaded file |
| --- | --- | --- |
| Debian 13 | `debian13` | `sudo apt install ./FILE.deb` |
| Ubuntu 26.04 LTS | `ubuntu26.04` | `sudo apt install ./FILE.deb` |
| Fedora 45 | `fedora45` | `sudo dnf install ./FILE.rpm` |
| Arch Linux / Arch Linux ARM | `archlinux` | `sudo pacman -U ./FILE.pkg.tar.zst` |
| AppImage | `anylinux` | `chmod +x ./FILE.AppImage`, then `./FILE.AppImage` |

Releases with native packages also provide AppImage `.zsync` update metadata,
a source archive, and `SHA256SUMS`. To verify downloads, put the checksum file
in the same directory and run:

```sh
sha256sum --check --ignore-missing SHA256SUMS
```

## Community packages

Distribution packagers and community maintainers publish these packages on
their own schedules.

| Distribution | Package source | Maintainer |
| --- | --- | --- |
| Arch Linux | [AUR](https://aur.archlinux.org/packages/protonplus) | [yochananmarqos](https://github.com/yochananmarqos) |
| Fedora | [Copr](https://copr.fedorainfracloud.org/coprs/wehagy/protonplus/) | [wehagy](https://github.com/wehagy) |
| Fedora | [Terra](https://terrapkg.com/) | [Owen Zimmerman](https://github.com/Owen-sz) |
| NixOS | [nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/pr/protonplus/package.nix) | [getchoo](https://github.com/getchoo) |
| Ubuntu | [Pacstall](https://pacstall.dev/packages/protonplus) | [Vysp3r](https://github.com/Vysp3r) |
| openSUSE | [OBS](https://software.opensuse.org/package/ProtonPlus) | [rrahl0](https://github.com/rrahl0) |
| Void Linux | [Official package](https://github.com/void-linux/void-packages/blob/master/srcpkgs/protonplus/template) | [xJayMorex](https://github.com/xJayMorex) |
| Gentoo | [Overlay](https://github.com/amielke/amielke-overlay/tree/master/games-util/protonplus) | [amielke](https://github.com/amielke) |

[Meta Package Manager](https://mpm.run/managers/protonplus/) integrates with the
ProtonPlus CLI to manage compatibility tools.

## Build from source

The contribution guide covers build dependencies and commands for both native
and local Flatpak builds. [Build instructions](../CONTRIBUTING.md#build-and-run)
