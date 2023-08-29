<h1 align="center">
    <img align="center" width=150 src="data/icons/hicolor/scalable/apps/com.vysp3r.ProtonPlus.svg" />
    <br><br>
    ProtonPlus
</h1>

<p align="center">
  <strong>A simple Wine and Proton-based compatibility tools manager</strong>
</p>

<p align="center">
    <a align="center" href="https://flathub.org/apps/com.vysp3r.ProtonPlus">
        <img width='240' alt='Download on Flathub' src='https://dl.flathub.org/assets/badges/flathub-badge-i-en.svg' />
    </a>
</p>

<p align="center">
    <a href="https://github.com/Vysp3r/ProtonPlus/stargazers">
      <img alt="Stars" title="Stars" src="https://img.shields.io/github/stars/Vysp3r/ProtonPlus?style=shield&label=%E2%AD%90%20Stars&branch=main&kill_cache=1%22" />
    </a>
    <a href="https://github.com/Vysp3r/ProtonPlus/releases/latest">
      <img alt="Latest Release" title="Latest Release" src="https://img.shields.io/github/v/release/Vysp3r/ProtonPlus?style=shield&label=%F0%9F%9A%80%20Release">
    </a>
    <a href="https://klausenbusk.github.io/flathub-stats/#ref=com.vysp3r.ProtonPlus&interval=infinity&downloadType=installs%2Bupdates">
      <img alt="Flathub Downloads" title="Flathub Downloads" src="https://img.shields.io/badge/dynamic/json?color=informational&label=Downloads&logo=flathub&logoColor=white&query=%24.installs_total&url=https%3A%2F%2Fflathub.org%2Fapi%2Fv2%2Fstats%2Fcom.vysp3r.ProtonPlus">
    </a>
    <a href="https://github.com/Vysp3r/ProtonPlus/blob/main/LICENSE.md">
      <img alt="License" title="License" src="https://img.shields.io/github/license/Vysp3r/ProtonPlus?label=%F0%9F%93%9C%20License" />
    </a>
    <a href="https://t.me/ProtonPlus">
      <img alt="Telegram" title="Telegram" src="https://img.shields.io/endpoint?color=neon&style=shield&url=https%3A%2F%2Ftg.sumanjay.workers.dev%2FProtonPlus">
    </a>
    <a href="https://discord.gg/Fyf8bWexpQ">
      <img alt="Discord" title="Discord" src="https://dcbadge.vercel.app/api/server/Fyf8bWexpQ?style=flat&theme=default-inverted">
    </a>
</p>

<p align="center">
  <a href="https://stopthemingmy.app">
    <img alt="Please do not theme this app" src="https://stopthemingmy.app/badge.svg"/>
  </a>
</p>

<p align="center">
    <i>Join the <a href="https://t.me/ProtonPlus">Telegram</a>/<a href="https://discord.gg/Fyf8bWexpQ">Discord</a>! — Don't forget to star the repo if you are enjoying the project!</i>
</p>

[<img alt='Download on Flathub' src='data/previews/Preview-1.png' />](https://flathub.org/apps/details/com.vysp3r.ProtonPlus)

- - - -

## 📦️ Alternative installation methods

> **Warning**
> The main installation method is Flatpak from Flathub

### Arch Linux (AUR)
[https://aur.archlinux.org/packages/protonplus](https://aur.archlinux.org/packages/protonplus) (Maintained by yochananmarqos)

- - - -

## 🏗️ Building from source

<details>
  <summary>Requirements</summary>

- [git](https://github.com/git/git)
- [ninja](https://github.com/ninja-build/ninja)
- [meson >= 0.59.0](https://github.com/mesonbuild/meson)
- [gtk4](https://gitlab.gnome.org/GNOME/gtk/)
- [libadwaita >= 1.2](https://gitlab.gnome.org/GNOME/libadwaita)
- [json-glib](https://gitlab.gnome.org/GNOME/json-glib)
- [libsoup](https://gitlab.gnome.org/GNOME/libsoup)
- [libarchive](https://github.com/libarchive/libarchive)
- [desktop-file-utils](https://gitlab.freedesktop.org/xdg/desktop-file-utils)
</details>


<details>
  <summary>Fedora</summary>

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
</details>

<details>
  <summary>Flatpak Builder</summary>

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
</details>

- - - -

## ⁉️ ProtonPlus vs ProtonUp-Qt

|                   | ProtonPlus                                  | ProtonUp-Qt                                      |
| :---------------- | :-----------------------------------------: | :----------------------------------------------: |
| **GUI Toolkit**   | [GTK4](https://gitlab.gnome.org/GNOME/gtk)  | [QT](https://www.qt.io/)                         |
| **Language**      | [Vala](https://gitlab.gnome.org/GNOME/vala) | [Python](https://www.python.org/)                |
| **Based on**      | Nothing                                     | [ProtonUp](https://github.com/AUNaseef/protonup) |
| **Looks best on** | [GNOME](https://gitlab.gnome.org/GNOME)     | [KDE](https://kde.org/)                          |

- - - -

## 🙌 Contribute to ProtonPlus
**Please read our [Contribution Guidelines](/CONTRIBUTING.md)**

All contributions are highly appreciated.

- - - -

## ✨️ Contributors

[![Contributors](https://contrib.rocks/image?repo=Vysp3r/ProtonPlus)](https://github.com/Vysp3r/ProtonPlus/graphs/contributors)

- - - -

## 💝 Acknowledgment

This README is based on the README from [Gradience](https://github.com/GradienceTeam/Gradience) by [Gradience Team](https://github.com/GradienceTeam)

**[⤴️ Back to Top](#ProtonPlus)**
