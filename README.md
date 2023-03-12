<h1 align="center">ProtonPlus (WIP)</h1>

<p align="center">
    <img src="https://img.shields.io/github/stars/Vysp3r/ProtonPlus?style=shield&label=%E2%AD%90%20Stars&branch=main&kill_cache=1%22">
    <a href="https://github.com/Vysp3r/ProtonPlus/releases/latest">
      <img alt="Latest Release (Semver)" src="https://img.shields.io/github/v/release/Vysp3r/ProtonPlus?style=shield&label=%F0%9F%9A%80%20Release">
    </a>
    <a>
      <img title="License" src="https://img.shields.io/github/license/Vysp3r/ProtonPlus?style=shield" />
    </a>
    <a href="https://t.me/ProtonPlusOfficial">
      <img title="Telegram" src="https://img.shields.io/endpoint?color=neon&style=shield&url=https%3A%2F%2Ftg.sumanjay.workers.dev%2FProtonPlusOfficial">
    </a>
    <a href="https://discord.gg/Fyf8bWexpQ">
      <img title="Discord" src="https://discordapp.com/api/guilds/1062063752779943997/widget.png?style=shield">
    </a>
</p>

<p align="center">
    <i>Join the telegram! — Don't forget to star the repo if you are enjoying the project!</i>
</p>

- - - -

ProtonPlus is a simple Proton version manager that make it easy to install and manage Proton versions. It works with Steam, Lutris, Heroic Games Launcher and Bottles. It was made in Vala with GTK4 and Libadwaita using GNOME Builder. <b>This project is still in its early phase, so please keep that in mind before using it.</b>

If you have any questions about ProtonPlus or want to share information with us, please go to one of the following places:

<img align="right" width=150 src="data/icons/hicolor/scalable/apps/com.vysp3r.ProtonPlus.svg" />

- [Github Discussions](https://github.com/Vysp3r/ProtonPlus/discussions)
- [Telegram Server](https://t.me/ProtonPlusOfficial)
- [Discord Server](https://discord.gg/Fyf8bWexpQ)

*Before you file an [issue](https://github.com/Vysp3r/ProtonPlus/issues/new/choose), make sure you have read the [known issues](#-known-issues) section.*

**For more information, [read the documentation!](https://github.com/Vysp3r/ProtonPlus/wiki)**

- - - -

## 💾 Download

[<img align="center" width=150 src="https://camo.githubusercontent.com/1682ee5722ac262c660297d4541837e5c8765c7e239fa2a6ce7c3f4817a79283/68747470733a2f2f666c61746875622e6f72672f6173736574732f6261646765732f666c61746875622d62616467652d656e2e706e67" />](https://flathub.org/apps/details/com.vysp3r.ProtonPlus)

- - - -

## ✨ Features
- Install and manage Proton versions for Steam, Lutris, Bottles and Heroic Games Launcher
- And much more...

- - - -

## 👀 Preview
<img alt="ProtonPlus Preview" align="center" width="60%" src="Preview-1.png" />

- - - -

## 💥 Known Issues

- Bottles support not working

- - - -

## 📝 TODOs

- Comment the code
- Document the project
- Add a game list with additional data like Deck compatibility and Anti-cheat status
- Add the ability to add custom locations
- Add games specific fixes (ex. Star Citizen)
- Add an update notification system

- - - -

## ⁉️ ProtonPlus vs ProtonUp-Qt

|                   | ProtonPlus                                  | ProtonUp-Qt                                      |
| :---------------- | :-----------------------------------------: | :----------------------------------------------: |
| **GUI Toolkit**   | [GTK4](https://gitlab.gnome.org/GNOME/gtk)  | [QT](https://www.qt.io/)                         |
| **Language**      | [Vala](https://gitlab.gnome.org/GNOME/vala) | [Python](https://www.python.org/)                |
| **Based on**      | Nothing                                     | [ProtonUp](https://github.com/AUNaseef/protonup) |
| **Looks best on** | [GNOME](https://gitlab.gnome.org/GNOME)     | [KDE](https://kde.org/)                          |

- - - -

## 🛠️ Building from Source

_Requirements_
- [git](https://github.com/git/git)
- [ninja](https://github.com/ninja-build/ninja)
- [meson >= 0.59.0](https://github.com/mesonbuild/meson)
- [gtk4](https://gitlab.gnome.org/GNOME/gtk/)
- [libadwaita >= 1.2](https://gitlab.gnome.org/GNOME/libadwaita)
- [json-glib](https://gitlab.gnome.org/GNOME/json-glib)
- [libsoup](https://gitlab.gnome.org/GNOME/libsoup)
- [libarchive](https://github.com/libarchive/libarchive)
- [desktop-file-utils](https://gitlab.freedesktop.org/xdg/desktop-file-utils)

### Fedora

1. Install all dependencies:
    ```bash
    sudo dnf install \
      git \
      ninja-build \
      meson \
      gtk4-devel \
      libadwaita-devel \
      json-glib-devel \
      libsoup3-devel \
      libarchive-devel \
      desktop-file-utils
    ```

2. Clone the GitHub repo and change to repo directory:
    ```bash
    git clone https://github.com/Vysp3r/ProtonPlus.git && \
      cd ProtonPlus
    ```

3. Build the source:
    ```bash
    meson build --prefix=/usr && \
    cd build && \
    ninja
    ```

4. (Optional) Install application:
    ```bash
    ninja install
    ```

5. Start application:
    ```bash
    cd src && \
    ./com.vysp3r.ProtonPlus
    ```

### Flatpak Builder

1. Install the distro dependencies using your package manager (apt, dnf, pacman, etc):
    ```bash
    sudo <insert your distro package manager and install options here> \
      git \
      flatpak \
      flatpak-builder
    ```

2. Add the flathub repo to your user if not added before:
    ```bash
    flatpak --user --if-not-exists remote-add \
      flathub https://flathub.org/repo/flathub.flatpakrepo
    ```

3. Install the needed runtimes for flatpak:
    ```bash
    flatpak --user install \
      runtime/org.gnome.Sdk/x86_64/43 \
      runtime/org.gnome.Platform/x86_64/43
    ```

4. Clone the GitHub repo and change to repo directory:
    ```bash
    git clone https://github.com/Vysp3r/ProtonPlus.git && \
      cd ProtonPlus
    ```

5. Build the source inside the "build-dir" in the repo directory and install for the current user:
    ```bash
    flatpak-builder --user --install --force-clean \
      build-dir \
      com.vysp3r.ProtonPlus.json
    ```

6. Start application:
    ```bash
    flatpak --user run \
      com.vysp3r.ProtonPlus
    ```

- - - -

## 💖 Contributing
**Please read our [Contribution Guidelines](/CONTRIBUTING.md)**

All contributions are highly appreciated.

- - - -

## 📜 License

ProtonPlus is licensed under [GPL 3.0](/LICENSE.md)

```
 Copyright © 2022 Charles "Vysp3r" Malouin
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
```

**[⤴️ Back to Top](#ProtonPlus)**
