%global app_id com.vysp3r.ProtonPlus

Name:           protonplus
Version:        %{package_version}
Release:        1%{?dist}
Summary:        Manage compatibility tools for Linux game launchers
License:        GPL-3.0-or-later
URL:            https://github.com/Vysp3r/ProtonPlus
Source0:        %{url}/releases/download/v%{upstream_version}/ProtonPlus-%{upstream_version}-source.tar.gz

BuildRequires:  appstream
BuildRequires:  dbus-daemon
BuildRequires:  dejavu-sans-fonts
BuildRequires:  desktop-file-utils
BuildRequires:  gcc
BuildRequires:  gettext
BuildRequires:  git-core
BuildRequires:  glibc-langpack-en
BuildRequires:  make
BuildRequires:  meson >= 1.0
BuildRequires:  vala
BuildRequires:  xorg-x11-server-Xvfb
BuildRequires:  xorg-x11-xauth
BuildRequires:  /usr/bin/xmllint
BuildRequires:  pkgconfig(cairo)
BuildRequires:  pkgconfig(gee-0.8)
BuildRequires:  pkgconfig(gio-unix-2.0)
BuildRequires:  pkgconfig(gtk4) >= 4.14
BuildRequires:  pkgconfig(json-glib-1.0)
BuildRequires:  pkgconfig(libadwaita-1) >= 1.5
BuildRequires:  pkgconfig(libarchive)
BuildRequires:  pkgconfig(sqlite3)
BuildRequires:  pkgconfig(yaml-0.1)
BuildRequires:  pkgconfig(libsoup-3.0)
BuildRequires:  pkgconfig(sdl3) >= 3.2

Requires:       ca-certificates
Requires:       dconf
Requires:       glib-networking

%description
ProtonPlus discovers, installs, updates, and removes compatibility tools for
Steam and other Linux game launchers. It also manages Steam compatibility
tool selections and game launch options.

%prep
%autosetup -n ProtonPlus-%{upstream_version}

%build
%meson
%meson_build

%install
%meson_install
%find_lang %{app_id}

%check
dbus-run-session -- %{__meson} test -C %{_vpath_builddir} --print-errorlogs

%files -f %{app_id}.lang
%license LICENSE.md
%{_bindir}/protonplus
%{_datadir}/applications/%{app_id}.desktop
%{_datadir}/glib-2.0/schemas/%{app_id}.gschema.xml
%{_datadir}/icons/hicolor/*/apps/%{app_id}.png
%{_datadir}/metainfo/%{app_id}.metainfo.xml
