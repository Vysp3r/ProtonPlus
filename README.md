<h1 align="center">
    <img align="center" width=150 src="data/logo/com.vysp3r.ProtonPlus.svg" />
    <br><br>
    ProtonPlus
</h1>

<p align="center">
  <strong>A modern compatibility tools manager for Linux.</strong>
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
</p>

<p align="center">
    Don't forget to star the repo if you are enjoying the project!</i>
</p>

[<img alt='Preview 1' src='data/previews/Preview-1.png' />](https://flathub.org/apps/details/com.vysp3r.ProtonPlus)

## 📦️ Installation methods

<a href="https://flathub.org/apps/com.vysp3r.ProtonPlus">
    <img width='240' alt='Download on Flathub' src='https://flathub.org/api/badge?svg&locale=en&light' />
</a>

<p></p>

> [!WARNING]
> The main installation method is Flathub

### [Arch Linux (AUR)](https://aur.archlinux.org/packages/protonplus) (Maintained by yochananmarqos)

### [Fedora (COPR)](https://copr.fedorainfracloud.org/coprs/wehagy/protonplus/) (Maintained by wehagy)

### [NixOS (MyNixOS)](https://mynixos.com/nixpkgs/package/protonplus) (Maintained by Seth)

## 🏗️ Building from source

**Requirements**

- [git](https://github.com/git/git)
- [ninja](https://github.com/ninja-build/ninja)
- [meson >= 0.62.0](https://github.com/mesonbuild/meson)
- [gtk4](https://gitlab.gnome.org/GNOME/gtk/)
- [libadwaita >= 1.4](https://gitlab.gnome.org/GNOME/libadwaita)
- [json-glib](https://gitlab.gnome.org/GNOME/json-glib)
- [libsoup](https://gitlab.gnome.org/GNOME/libsoup)
- [libarchive](https://github.com/libarchive/libarchive)
- [desktop-file-utils](https://gitlab.freedesktop.org/xdg/desktop-file-utils)
- [libgee](https://gitlab.gnome.org/GNOME/libgee)

<details>
  <summary>Linux</summary>

1. Install all dependencies (I am on Fedora, so for you this line might be different)
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
      desktop-file-utils \
      libgee-devel
    ```

2. Clone the GitHub repo and change to repo directory
    ```bash
    git clone https://github.com/Vysp3r/ProtonPlus.git && \
      cd ProtonPlus
    ```

3. Build the local source code as a native application
    ```bash
    ./scripts/build-native.sh
    ```

4. (Optional) Install application
    ```bash
    ninja install
    ```

5. Start application
    ```bash
    cd src && \
    ./com.vysp3r.ProtonPlus
    ```
</details>

<details>
  <summary>Linux (Flatpak Builder)</summary>

1. Install all dependencies (I am on Fedora, so for you this line might be different)
    ```bash
    sudo dnf install \
      git \
      flatpak
    ```

2. Add the flathub repo to your system if not added before
    ```bash
    flatpak --if-not-exists remote-add \
      flathub https://flathub.org/repo/flathub.flatpakrepo
    ```

3. Install the necessary runtimes and build tools for Flatpak
    ```bash
    flatpak install \
      runtime/org.gnome.Sdk/x86_64/46 \
      runtime/org.gnome.Platform/x86_64/46 \
      runtime/org.freedesktop.Sdk.Extension.vala/x86_64/23.08 \
      org.flatpak.Builder
    ```

4. Clone the GitHub repo and change to repo directory
    ```bash
    git clone https://github.com/Vysp3r/ProtonPlus.git && \
      cd ProtonPlus
    ```

5. Build the local source code as a Flatpak and install for the current user
    ```bash
    ./scripts/build-local.sh

    # Alternative: Runs application after the build.
    ./scripts/build-local.sh run
    ```

6. Run the application
    ```bash
    flatpak --user run \
      com.vysp3r.ProtonPlus
    ```
</details>

## 🌐 Translate

**You can translate ProtonPlus on [Weblate](https://hosted.weblate.org/projects/protonplus/protonplus/) or by modifying the files directly**

## 🙌 Contribute
**Please read our [Contribution Guidelines](/CONTRIBUTING.md)**

All contributions are highly appreciated.
## ✨️ Contributors

[![Contributors](https://contrib.rocks/image?repo=Vysp3r/ProtonPlus)](https://github.com/Vysp3r/ProtonPlus/graphs/contributors)

**[⤴️ Back to Top](#ProtonPlus)**
