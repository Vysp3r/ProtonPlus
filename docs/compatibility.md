# Supported launchers and tools

## Launchers

| Launcher | Installation types | Tool categories |
| --- | --- | --- |
| Steam | System, Flatpak, Snap | Proton, including Steam Tinker Launch |
| Proton-Autogen | System profiles | Proton in native Steam's compatibility-tool directory |
| Faugus Launcher | System, Flatpak | Selected Proton tools |
| Lutris | System, Flatpak | Proton, Wine, DXVK, VKD3D |
| Heroic Games Launcher | System, Flatpak | Proton, Wine |
| Bottles | System, Flatpak | Proton, Wine, DXVK |
| WineZGUI | System, Flatpak | Wine |

The launcher menu shows detected installations, and each launcher has its own
tool catalog. ProtonPlus filters release variants by CPU architecture and ISA
level, including native AArch64 builds and eligible x86-64 variants on AArch64
hosts. Available versions and variants come from each provider's upstream
releases.

See the [Games tab guide](usage.md#manage-games-in-other-launchers) for the
libraries and actions available to each launcher.

## Compatibility tools

Installed tools appear first within each category. ProtonPlus orders other
tools by estimated popularity. Enable **Show Niche Tools** or **Show Legacy
Tools** under **Preferences → Tools** to browse those releases.

### Proton and Steam tools

- Proton-GE
- Proton-CachyOS
- DW-Proton
- Proton-Wineland
- Proton-EM
- Luxtorpeda
- Proton-Tkg
- Proton-RTSP
- TinkerGame for native Steam with native ProtonPlus outside SteamOS.
  [Supported setups and migration](integrations/tinkergame.md)
- Rosemary for macOS games on x86-64 native and Flatpak Steam. Enable **Show
  Niche Tools** and install it, then restart Steam and select Rosemary in the
  game's compatibility settings.
- Proton-Anime and Proton-HEVC with **Show Niche Tools** enabled
- Steam Tinker Launch for existing installations
- Boxtron and Roberta with **Show Legacy Tools** enabled

### Wine

- Wine-Vanilla (Kron4ek)
- Wine-Staging (Kron4ek)
- Wine-Proton (Kron4ek)
- Wine-Staging-Tkg (Kron4ek)

### DXVK

- DXVK (doitsujin)
- DXVK (Sarek)
- DXVK GPL+Async (Ph42oN)

### VKD3D

- VKD3D-Proton
- VKD3D-Lutris with **Show Legacy Tools** enabled
