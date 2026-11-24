# ProtonPlus release history

This archive contains earlier releases. The six newest releases are listed in
the [AppStream metadata](../data/com.vysp3r.ProtonPlus.metainfo.xml.in).

## 0.6.3 (2026-08-11)

- ✨ Improved the introduction screen on smaller windows
- ✨ Added a warning when YAD 15 may prevent SteamTinkerLaunch from working
- 🐛 Fixed new Proton-GE x86-64 releases not being detected
- 🐛 Fixed DW-Proton not using GitHub releases
- 🐛 Fixed inaccessible Faugus folders preventing ProtonPlus from starting
- 🐛 Fixed SteamTinkerLaunch installations sometimes starting more than once
- 🐛 Fixed some tool descriptions not being translated
- 🌐 Updated Czech, German, Russian, Simplified Chinese, Swedish, and Ukrainian localizations

## 0.6.2 (2026-08-09)

- ✨ Added AppImage builds for AArch64 systems
- ✨ Added a configurable download speed limit
- 🐛 Fixed Faugus launcher not being detected under Flatpak
- 🐛 Fixed controllers not working under Flatpak
- 🌐 Updated German localization

## 0.6.1 (2026-08-09)

- ✨ Improved how ProtonPlus finds Steam compatibility tools
- ✨ Improved mass editing and controller navigation in the Games tab
- 🐛 Fixed compatibility tool installation for some Steam setups
- 🐛 Fixed tool usage counts and game lists when moving to another tool
- 🐛 Fixed tool installation on some Linux systems and improved archive safety
- 🐛 Fixed translations missing from the AppImage version
- 🌐 Updated Czech and Slovak translations

## 0.6.0 (2026-08-09)

- ✨ Added Faugus Launcher support
- ✨ Added CPU-aware x86-64 and ARM64 variant selection
- ✨ Added scheduled background updates and notifications
- ✨ Added controller navigation with contextual hints, optional haptic feedback, and a first-run
  guide
- ✨ Added Breeze Light, Breeze Dark, SteamOS, and OLED themes
- ✨ Added a built-in MangoHud editor and proxy settings
- ✨ Added Steam shortcut creation and guided Steam restarts, including SteamOS Gaming Mode
- ✨ Added default Steam compatibility prefix migration
- ✨ Added an active downloads indicator
- ✨ Added ARM64 Flatpak support
- ✨ Reworked the launch options editor with hardware-aware options and exact command previews
- ✨ Preserved custom and unknown safe launch options during single-game and mass edits
- ✨ Improved Games and Tools navigation, search, filtering, selection, and repository links
- ✨ Improved stable release selection, Latest handling, and variant selection
- ✨ Improved downloads and tool updates with timeout recovery, archive checks, preserved
  settings, and safer rollback
- ✨ Improved Steam multi-user, VDF, and shortcut handling
- ✨ Improved command-line validation and error reporting
- 🐛 Fixed custom executable launches and kept the app usable when some Steam data cannot be
  loaded
- 🐛 Fixed release and installation issues affecting Proton-TKG, Proton-CachyOS, DXVK, VKD3D,
  Lutris, and Steam Tinker Launch
- 🌐 Added Arabic localization
- 🌐 Added Slovak localization
- 🌐 Updated Simplified Chinese localization
- 🌐 Updated German localization
- 🌐 Updated Italian localization

## 0.5.22 (2026-07-24)

- 🐛 Fixed Proton-GE RTSP download

## 0.5.21 (2026-06-24)

- 🐛 Fixed Proton-GE downloading wrong version
- 🐛 Fixed yad check for Steam Tinker Launch
- 🌐 Updated German localization
- 🌐 Updated Chinese localization
- 🌐 Updated Portuguese localization
- 🌐 Updated Polish localization
- 🌐 Updated French localization
- 🌐 Updated Ukrainian localization
- 🌐 Updated Spanish localization
- 🌐 Updated Greek localization
- 🌐 Updated Japanese localization

## 0.5.20 (2026-04-18)

- ✨ Added a new "Downloads" tab
- ✨ Added more launch options
- ✨ Added a "Run custom executable" button
- ✨ Added a SteamOS theme and an OLED theme
- 🐛 Fixed DXVK-Sarek
- 🐛 Fixed tool usage count to account for default tool
- 🐛 Fixed tool usage count to account for non-steam games
- 🐛 Fixed an error that occured when installing a tool in any launcher except for Steam
- 🌐 Updated Ukrainian localization
- 🌐 Updated Spanish localization
- 🌐 Updated Chinese localization

## 0.5.19 (2026-04-13)

- 🐛 Fixed launchers not being detected on certain distro
- 🌐 Updated Polish localization
- 🌐 Updated Spanish localization
- 🌐 Updated Ukrainian localization

## 0.5.18 (2026-04-12)

- ✨ Improved the launch options, mass edit and default compatibility tool view
- ✨ Removed Proton-Sarek
- 🐛 Fixed a few typos
- 🐛 Fixed broken icons
- 🐛 Fixed XDG base directory specification
- 🐛 Fixed Proton-CachyOS (Temporary fix)
- 🐛 Fixed Latest releases for Bottles
- 🐛 Fixed updates not preserving symlink for user_settings.py
- 🌐 Updated German localization
- 🌐 Updated Polish localization
- 🌐 Updated French localization
- 🌐 Updated Chinese localization
- 🌐 Updated Portuguese localization
- 🌐 Updated Japanese localization
- 🌐 Updated Indonesian localization
- 🌐 Updated Spanish localization
- 🌐 Updated Ukrainian localization

## 0.5.17 (2026-02-21)

- ✨ Added CLI support
- 🐛 Fixed Lutris install directory for Proton runners
- 🐛 Fixed unnecessary re-downloads of the same runner as an "update"
- 🌐 Updated Portuguese localization
- 🌐 Added Vietnamese localization

## 0.5.16 (2026-02-01)

- ✨ Added DW-Proton Latest
- ✨ Added Proton-Sarek Latest
- ✨ Added Proton-Sarek (Async) Latest
- ✨ Added Proton-EM Latest
- ✨ Added Proton-GE RTSP Latest
- 🐛 Fixed network error not being displayed when they should
- 🐛 Fixed "Unknown error" dialog appearing on successful update
- 🐛 Fixed "Games" tab runners not refreshing when installing/removing a runner
- 🌐 Updated German localization
- 🌐 Updated French localization
- 🌐 Updated Portuguese localization
- 🌐 Updated Chinese localization
- 🌐 Updated Spanish localization
- 🌐 Updated Czech localization
- 🌐 Updated Arabic localization
- 🌐 Added Georgian localization

## 0.5.15 (2026-01-02)

- ✨ Added DW-Proton
- 🌐 Updated German localization
- 🌐 Updated Portuguese localization

## 0.5.14 (2025-12-08)

- ✨ Migrate user_settings.py on update
- ✨ Added a button to open runners install directory
- ✨ Added a basic cache system for downloaded runners
- ✨ Improved new user experience
- ✨ Added API limit/connection issue warning dialog
- ✨ Improved "Runners" tab filters
- ✨ Added preferences dialog
- ✨ Added report button to error dialogs
- ✨ Added GitHub/GitLab access token
- ✨ Added release date under release name
- 🐛 Fixed possible negative remaining download time
- 🐛 Fixed select/unselect all
- 🐛 Fixed Proton-CachyOS not downloading the good version
- 🐛 Fixed invalid files from being downloaded
- 🐛 Fixed Wine-Proton invalid download url
- 🐛 Fixed SteamTinkerLaunch download issue
- 🐛 Fixed Proton-GE Latest version check issue
- 🐛 Fixed Proton-CachyOS invalid directory name
- 🌐 Added Japanese localization
- 🌐 Updated Chinese localization
- 🌐 Updated French localization
- 🌐 Updated Spanish localization
- 🌐 Updated Italian localization
- 🌐 Updated Portuguese localization
- 🌐 Updated Russian localization

## 0.5.13 (2025-10-07)

- ✨ Added a search bar in the "Games" tab
- ✨ Added a way to see the speed and remaining time of downloads
- ✨ Added Wine runners to Bottles
- ✨ Update runtime to GNOME 49
- 🐛 Fixed icons issue
- 🐛 Fixed Proton-GE RTSP
- 🐛 Fixed error when cancelling install during extraction
- 🌐 Updated Spanish localization
- 🌐 Updated Portuguese localization
- 🌐 Updated Italian localization
- 🌐 Updated Arabic localization
- 🌐 Updated Finnish localization
- 🌐 Updated Polish localization
- 🌐 Updated French localization
- 🌐 Updated Ukrainian localization

## 0.5.12 (2025-07-25)

- 🐛 Fixed launchers loading issue
- 🐛 Fixed possible parsing issue
- 🐛 Fixed force exit not working in the warning dialog when closing the application
- 🐛 Fixed application freezing in a certain scenario
- 🌐 Updated Czech localization
- 🌐 Updated Russian localization

## 0.5.11 (2025-07-24)

- ✨ Added non-steam games support
- ✨ Added an update indicator
- ✨ Added a way to see the games prefix
- ✨ Added a sticky filter bar to the "Runners" tab
- ✨ Added a way to see which runners are used
- ✨ Improve Proton-GE Latest handling
- 🐛 Fixed a launcher loading issue
- 🌐 Added Ukrainian localization
- 🌐 Added Arabic localization
- 🌐 Updated Indonesian localization
- 🌐 Updated German localization
- 🌐 Updated Chinese localization
- 🌐 Updated Spanish localization
- 🌐 Updated Portuguese localization
- 🌐 Updated Dutch localization

## 0.5.10 (2025-07-14)

- ✨ Delete cache on exit
- 🐛 Fixed runners not downloading for HGL
- 🐛 Fixed recursive copy error
- 🐛 Fixed icons not showing up when running under Flatpak
- 🐛 Fixed WineZGUI Flatpak not appearing in launcher list
- 🌐 Updated Chinese localization
- 🌐 Updated Spanish localization

## 0.5.9 (2025-07-13)

- ✨ Added Proton-GE Latest
- ✨ Added WineZGUI support
- ✨ Added a profile switch button
- ✨ Made the runners dynamic
- ✨ Added a loading screen
- ✨ Updated donation button link
- ✨ Made the game list sort-able via the header
- ✨ Added a shortcut to open protontricks
- 🐛 Fixed "Load more" scrolling to top after clicking it
- 🐛 Fixed SteamTinkerLaunch from being duplicated
- 🐛 Fixed launch options parsing issue
- 🐛 Fixed Steam shortcut not using system language to launch the application
- 🐛 Fixed issue with incorrectly identifying Steam shortcut
- 🐛 Fixed crash when CompatToolMapping is missing in config.vdf
- 🐛 Fixed incorrect insertion position when launch options are missing
- 🌐 Updated Italian localization
- 🌐 Updated Portuguese localization
- 🌐 Updated Indonesian localization
- 🌐 Updated Russian localization
- 🌐 Updated German localization
- 🌐 Updated Dutch localization
- 🌐 Updated Bosnian localization
- 🌐 Updated Serbian localization
- 🌐 Updated Chinese localization

## 0.5.8 (2025-07-02)

- 🐛 Fix games being duplicated when switching tab back and forth
- 🌐 Update Polish localization
- 🌐 Updated German localization

## 0.5.7 (2025-06-30)

- 💄 Improved UI/UX
- 💄 Refined the game library list header
- 💄 Improved dropdown's in game library
- 🐛 Removed Proton Kron4ek
- 🐛 Fix issue related to the new custom dropdown's
- 🐛 Fix changing compatibility tool not working in certain cases
- 🌐 Update Czech localization
- 🌐 Updated German localization
- 🌐 Updated Chinese localization

## 0.5.6 (2025-06-27)

- ✨ Added an header to the library game list
- ✨ Added a donation button
- 🐛 Fix compatibility tool detection
- 🐛 Change DXVK Sarek naming scheme
- 🐛 Fix library loading issue
- 🐛 Fix a crash
- 🌐 Updated Chinese localization
- 🌐 Updated Indonesian localization
- 🌐 Updated Portuguese localization

## 0.5.5 (2025-06-16)

- 🐛 Fix Steam profile detection

## 0.5.4 (2025-06-16)

- 🐛 Fix Steam profile detection
- 🌐 Updated Chinese localization
- 🌐 Updated German localization
- 🌐 Updated Portuguese localization

## 0.5.3 (2025-06-14)

- ✨ Added the ability to manage launch options of games
- ✨ Added a way to open the install/prefix directory of games
- ✨ Added the ability to set the default compatibility tool for Steam games
- 🌐 Updated Chinese localization
- 🌐 Updated German localization
- 🌐 Updated Portuguese localization

## 0.5.2 (2025-06-09)

- 🐛 Fixed ProtonDB logo not appearing with light theme
- 🐛 Fixed shortcut button not working properly
- ✨ Made the games be sorted by name by default
- ✨ Made it possible to unselect a game by clicking on it
- ✨ Added a way to select/unselect all the games
- ✨ Added a way to sort by game name and sort by compatbility tool name

## 0.5.1 (2025-06-08)

- 🐛 Fixed Proton Kron4ek

## 0.5.0 (2025-06-07)

- ✨ Added support for Proton Kron4ek
- ✨ Added a way to add a shortcut of ProtonPlus in Steam
- ✨ Added a way to see if a compatibility tool is used or not for Steam
- ✨ Added the ability to change the compatibility tool of Steam games
- ✨ Added the ability to change the compatibility tool of multiple Steam game at the same time
- 🐛 Fix UI freeze when installing/removing STL
- 💄 Improved the UX of most of the dialogs

## 0.4.32 (2025-06-02)

- 🌐 Updated Portuguese localization
- 🌐 Updated Indonesian localization
- 🌐 Updated French localization

## 0.4.31 (2025-05-25)

- 🌐 Updated Chinese localization
- 🌐 Updated German localization
- 🌐 Updated French localization

## 0.4.30 (2025-05-20)

- ✨ Added support for Proton EM

## 0.4.29 (2025-05-19)

- 🐛 Fix only Steam showing up
- 🌐 Updated Portuguese localization

## 0.4.28 (2025-05-19)

- 🐛 Added check for inactive Steam installations
- 🧑‍💻 Updated runtime to GNOME 48
- 🌐 Updated Chinese localization

## 0.4.27 (2025-03-11)

- ✨ Added Proton CachyOS for Bottles
- ✨ Re-ordered runners
- ✨ Removed deprecated runners
- 🌐 Updated German translation

## 0.4.26 (2025-03-07)

- ✨ Added support for Proton CachyOS
- 🌐 Updated Spanish localization
- 🌐 Updated Portuguese localization

## 0.4.25 (2025-02-23)

- 🐛 Fix some DXVK runners using the wrong name
- 🌐 Fix typo in German localization

## 0.4.24 (2025-02-16)

- 🐛 Fix HGL support
- 🌐 Updated German translation

## 0.4.23 (2025-02-16)

- 🐛 Fix Proton-Sarek install issues
- 🌐 Updated German translation
- 🌐 Updated Czech translation

## 0.4.22 (2025-02-15)

- 🐛 Fixed libadwaita version minimum requirement

## 0.4.21 (2025-02-15)

- ✨ Added a way to view the description of each release
- ✨ Added support for DXVK Sarek
- ✨ Added support for Proton in Lutris (without using Steam)
- 🐛 Fixed installed only filter
- 🧑‍💻 Backend improvements
- 🌐 Updated localization

## 0.4.20 (2024-10-04)

- 💄 Switched app icon to PNG format due to poor SVG support in KDE

## 0.4.19 (2024-10-03)

- 🐛 Fix for Proton-Sarek support

## 0.4.18 (2024-10-02)

- ✨ Added support for Proton-Sarek
- 💄 Updated the application icon
- 🌐 Updated Swedish translation

## 0.4.17 (2024-09-16)

- 🌐 Updated German translation

## 0.4.16 (2024-09-12)

- ✨ Added support for Steam Tinker Launch
- ✨ Made Ctrl-Q quit the application
- ✨ The window now remembers the last-used size
- 💄 Improved UI polish and consistency
- 🌐 Made it easier to translate the application
- 🌐 Added Swedish translation

## 0.4.15 (2024-07-17)

- 🐛 Fix appdata

## 0.4.11 (2024-07-17)

- 🌐 Updated localization

## 0.4.10 (2024-04-29)

- ✨ Added Proton-GE RTSP to Steam
- 🌐 Updated localization

## 0.4.9 (2023-12-10)

- 🐛 Fixed installed only infinite loading
- 🐛 Fixed GitLab downloads not working
- 🌐 Updated localization

## 0.4.8 (2023-11-23)

- 🐛 Fixed missing Bottles icon
- 🌐 Updated localization

## 0.4.7 (2023-11-12)

- 💄 Modernised the UI
- 🧑‍💻 Backend improvements
- 🌐 Updated localization

## 0.4.6 (2023-08-26)

- ✨ Added an installed only filter
- ✨ Added Kron4ek builds and Proton-tkg to HGL
- ✨ Added VKD3D support for Lutris
- ✨ Added Kron4ek Wine-Builds Staging
- ✨ Added DXVK GPL+Async (Ph42oN)
- 💄 Added description to groups
- 💄 Improved Steam Deck experience
- 🧑‍💻 General improvements
- 🌐 Updated localization

## 0.4.5 (2023-07-30)

- 📝 Updated README, appdata and preview image
- 🐛 Fix Flathub download link
- ♻️ Update delete dialog
- ✨ Added the ability to download older versions
- 🌐 Updated localization

## 0.4.4 (2023-06-13)

- 🍱 Replaced the preview video
- 🐛 Fixed Proton Tkg
- 🐛 Fixed install directories creation
- 🌐 Updated German translation

## 0.4.3 (2023-06-05)

I disabled Proton-Tkg (Steam) for now. I will re-add it for the next update.

- 🍱 Updated the preview images and video
- 💄 Updated the UI
- ⚡️ Backend optimization

## 0.4.2 (2023-04-21)

- 🍱 Change preview video file format to webm
- 🌐 Fixed README typo and added Czech translation
- 🌐 Added German translation
- ⚡️ Backend optimization

## 0.4.1 (2023-04-05)

- ✨ Added a tasks queue system
- 💄 Updated the installer UI
- 🐛 Fix window always being able to be closed
- 🐛 Fix preferences page being empty
- 🐛 Fix Steam install message
- 📝 Updated Flathub download logo

## 0.4.0 (2023-04-04)

- ✨ Complete UI Overhaul
- 🧑‍💻 Project Refactor

## 0.3.12 (2023-03-15)

- ✨ Added support for Bottles
- 🔨 Update appdata
- 💬 Update the release notes

## 0.3.11 (2023-03-12)

- ✨ Added support for Heroic Games Launcher
- 🔨 Update appdata
- 💬 Update the release notes

## 0.3.10 (2023-03-02)

- ✨ Updated the About window
- 🎨 Added utilities for folders and files
- 🎨 Migrated preferences system to GLib.Settings
- ✨ Implementated cancelation dialog when downloading
- 🔧 Modified filesystem permissions scopes
- 🔨 Update appdata
- 💬 Update the release notes

## 0.3.9 (2023-02-26)

- 🐛 Fixed installer tool switching
- 🔇 Remove debug log
- 💄 Updated icons
- 🐛 Fixed tools and releases not being locked when needed
- 🐛 Fixed progress bar not being hidden when needed
- 🌐 Updated translation files
- 🔨 Update appdata
- 💬 Update the release notes

## 0.3.8 (2023-02-21)

- 🐛 Fix flathub manifest
- 🌐 Added missing russian translations
- 🔨 Update appdata
- 💬 Update the release notes

## 0.3.7 (2023-02-17)

- ✨ Add warning for gamescope compatibility issues
- 🔇 Remove debug log
- 🐛 Fix download getting canceled randomly
- 🌐 Added missing translations
- 🔨 Update appdata
- 💬 Update the release notes

## 0.3.6 (2023-01-29)

- 🐛 Fix directory creation
- 🐛 Fix releases not always changing
- ✨ Added Proton Tkg
- 🔨 Update appdata
- 💬 Update the release notes

## 0.3.5 (2023-01-21)

- 🌐 Add missing translations
- 🔨 Update appdata
- 💬 Update the release notes

## 0.3.4 (2023-01-15)

- 📝 Update README.md
- 🌐 Add Chinese(Simplified) Translation
- 🐛 Fix translation
- 🔨 Update appdata
- 💬 Update the release notes

## 0.3.3 (2023-01-04)

- 🐛 Correct desktop file exec
- 🔨 Update appdata
- 💬 Update the release notes

## 0.3.2 (2023-01-03)

- 🌐 Add Indonesian translation
- 🌐 Add Brazilian Portuguese (pt-BR) translation
- 💄 Lock dialogs to main window
- 📝 Fix README.md typo
- 📝 Add desktop-file-utils link to README.md
- 🐛 Fix possible crash scenario
- 🧑‍💻 Project refactor
- 🐛 Fix tool renaming
- 🐛 Fix download not working on some machine
- 🔨 Update appdata
- 💬 Update the release notes

## 0.3.1 (2022-12-13)

- 🔨 Correct desktop file category
- 🌐 Adding a Russian translation
- 🌐 Added spanish translation
- 🐛 Fix installed tools not showing up properly
- 🐛 Fix buttons being clickable when switching tool
- 🧱 Rename InstallTool to Installer
- ⚰️ Remove dead code from Release
- 🚸 Added a tooltip in About
- 🌐 Add missing translation
- 📝 Update README.md
- 🔨 Update appdata
- 🔨 Update meson
- 💬 Update the release notes

## 0.3.0 (2022-12-11)

- ✨ Add localization system
- 🚸 Added more tooltips
- 🚸 Update About for better UX
- 🧑‍💻 Project refactor
- 🐛 Fix styles localization
- ✨ Added remember last launcher preference
- 🍱 Update preview images
- 📝 Update README.md
- 🔨 Update appdata
- 🔨 Update meson
- 💬 Update the release notes

## 0.2.3 (2022-12-05)

- 💄 Fix ListBox CSS missing
- 🚚 Renamed HomeInfo to AboutTool
- 💄 Update Home layout
- 🧑‍💻 Refactor ProtonMessageDialog
- 🚚 Rename Selector to InstallTool
- 🐛 Fix Adw-Critical error
- 🐛 Fix crash on tool delete
- 🍱 Update preview images
- 📝 Update README.md
- 🔨 Update appdata
- 💬 Update the release notes

## 0.2.2 (2022-12-03)

- 🧑‍💻 Project refactor
- 🐛 Fix ListBox missing scrollbar
- ✨ Add launcher cleanup utility
- 🐛 Fix possible crash scenario
- ➖ Remove Posix dependency
- 🐛 Fix button always being active
- 🧑‍💻 Add new message dialog widget
- 🐛 Fix useless log showing up
- 🔨 Update appdata
- 💬 Update the release notes

## 0.2.1 (2022-12-01)

- 🔨 Update appdata
- 🐛 Fix tool renaming for nothing
- 🐛 Fix selector window freezing
- 🐛 Fix Gtk-Critical errors
- 🐛 Fix buttons being active by default in selector
- 💬 Update the release notes

## 0.2.0 (2022-11-29)

For stability reasons, I've decided to disable Bottles and Heroic Games Launcher support for now. I
also disabled Proton Tkg for the same reasons.

- ✨ Add NorthstarProton compatibility tool
- 🐛 Fix NorthstarProton not showing up
- 🔨 Update flatpak config
- 💬 Renamed tools in a uniform way
- 🧑‍💻 Project refactor
- 🚸 Add error message to selector
- 🔨 Update appdata
- 💬 Update the release notes

## 0.1.9 (2022-11-21)

We are now officialy on Flathub!

- 🔨 Update appdata
- 🔨 Update flatpak config
- 🍱 Update symbolic icon
- 🍱 Add icon
- 🔨 Update .desktop
- 🍱 Update the preview image
- 🍱 Add a preview image
- 🐛 Fix install button always being clickable
- 💬 Update the release notes

## 0.1.3 (2022-11-19)

The new naming convention for extracted directories is basically making sure each installed tools
is easily recognizable to make it easier to manage them.

Naming convention: Tool name + Tool version

Example: GE-Proton | GE-Proton7-41

- ✏️ Fix typo in the release notes
- 🍱 Update the preview image
- ⚰️ Remove unused custom widget
- 🚧 Add notifications tab
- 💄 Update selector window components to Libadwaita
- 🧱 Separate Release from CompatibilityTool
- 🧱 Rename CompatibilityTool to Tool
- ⚰️ Remove unused file
- 💄 Update home message dialog to libadwaita
- ⚰️ Remove unused custom widget
- ✨ Added a naming convention extracted directories
- 🚚 Rename compatibilitytool to tool
- 💬 Update the release notes

## 0.1.2 (2022-11-02)

ProtonPlus now requires Libadwaita version 1.2 or higher.

- 📝 Update README.md
- 🐛 Fix Preferences window default siz
- 💄 Move main window to Libadwaita
- 💄 Move about window to Libadwaita
- ⚰️ Remove dead code
- 💄 Update main window components to Libadwaita
- ⚰️ Remove dead code
- 💄 Add an effect when extracting a tool
- 🐛 Fix label not showing up
- 🐛 Fix wrong label showing up
- 💄 Update preferences window to Libadwaita
- ⬆️ Update the runtime version
- 💬 Update the release notes

## 0.1.1 (2022-10-24)

- 🐛 Fix Steam not showing up on fresh install
- 🐛 Fix Kron4ek Wine-Builds Vanilla not showing properly
- 🐛 Fix installed tools showing files
- 🐛 Fix selector closing after an installation
- 🐛 Fix extraction not always working
- 📝 Update README.md
- 🐛 Fix Lutris DXVK not showing up

## 0.1.0 (2022-10-23)

- 🎉 Initial release
- 📝 Create pull request template
