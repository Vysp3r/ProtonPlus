# Launch-option verification matrix

Reviewed 2026-11-26. This is an audit of the existing editor and candidate
provider-specific controls. It covers the runtime options relevant to the
editor and the candidate features listed here. Each release or source revision
identifies the evidence checked. Earlier and later builds can differ, including archives from
the same provider. Defaults below are upstream behavior with the option unset.
Game profiles, user configuration, hardware and launcher defaults can override
them. For Proton's Python `check_environment` helper, an empty string or `0`
disables the named feature and a nonempty string other than `0` enables it.
Use `0` and `1` for ordinary toggles. Version selectors and native tools can
have different rules.

## Proton runtimes

| Provider or runtime | Exact option and accepted values | Default, verified build and evidence |
| --- | --- | --- |
| Valve Proton | `PROTON_LOG=0\|1\|<Wine debug channels>`, `PROTON_USE_WINED3D=0\|1`, `PROTON_FORCE_LARGE_ADDRESS_AWARE=0\|1`, `PROTON_NO_FSYNC=0\|1` | Logging off, DXVK for D3D9–11, large-address awareness on, FSync on when available. These are the baseline switches in the [Proton 11.0 launcher](https://github.com/ValveSoftware/Proton/blob/proton_11.0/proton) and [runtime documentation](https://github.com/ValveSoftware/Proton/blob/proton_11.0/README.md). The checked branch README lists `PROTON_NO_NTSYNC` but its launcher does not read it. Treat NTSync as build-dependent. |
| Proton-GE | `PROTON_ENABLE_WAYLAND=0\|1`, `PROTON_LOCAL_SHADER_CACHE=0\|1`, `PROTON_NO_NTSYNC=0\|1`, `PROTON_USE_OPTISCALER=0\|1\|<release version>` | Wayland and the local cache opt in, NTSync is requested by default, OptiScaler opts in and `1` selects the default release. GE-Proton11-14 opts in to its Vulkan layers with `LOW_LATENCY_LAYER=1` and `DXVK_NVAPI_VKREFLEX=1`. In that build, D7VK is installed for DirectDraw and proxies DirectDraw-only calls to Wine. `PROTON_USE_D7VK` appears in a removal comment. [Launcher](https://github.com/GloriousEggroll/proton-ge-custom/blob/GE-Proton11-14/proton) · [Runtime options](https://github.com/GloriousEggroll/proton-ge-custom/blob/GE-Proton11-14/README.md) |
| Proton-CachyOS | `PROTON_ENABLE_WAYLAND=0\|1`, `PROTON_LOCAL_SHADER_CACHE=0\|1`, `PROTON_DXVK_LOWLATENCY=0\|1`, `PROTON_VKD3D_LOWLATENCY=0\|1`, `LOW_LATENCY_LAYER=0\|1`, `DXVK_NO_HDR=0\|1` | First five opt in. The checked build is cachyos-11.0-20261015-slr. Its DXVK patch detects HDR automatically and checks for exactly `DXVK_NO_HDR=1` to disable detection, subject to `dxgi.disableHDR` configuration. [Tagged HDR patch](https://github.com/CachyOS/proton-cachyos/blob/cachyos-11.0-20261015-slr/patches/dxvk/0001-dxvk-Implement-support-for-HDR-detection-via-NtUserD.patch) · [Launcher](https://github.com/CachyOS/proton-cachyos/blob/cachyos-11.0-20261015-slr/proton) · [Runtime options](https://github.com/CachyOS/proton-cachyos/blob/cachyos-11.0-20261015-slr/README.md) |
| DW-Proton | `PROTON_ENABLE_WAYLAND=0\|1`, `PROTON_LOCAL_SHADER_CACHE=0\|1`, `PROTON_USE_OPTISCALER=0\|1\|<release version>`, `PROTON_FSR4_UPGRADE=0\|1\|<supported version>`, `PROTON_MLFG_UPGRADE=0\|1` | Wayland, local cache and upgrades opt in. This is the dwproton-11.0-17 launcher. Per-game profiles can set other defaults. [Launcher](https://github.com/dawn-winery/dwproton-mirror/blob/dwproton-11.0-17/proton) · [Runtime options](https://github.com/dawn-winery/dwproton-mirror/blob/dwproton-11.0-17/README.md) |
| Proton-Wineland | `PROTON_ENABLE_WAYLAND=0\|1`, `PROTON_LOCAL_SHADER_CACHE=0\|1`, `PROTON_UPSCALER_UPGRADE=0\|1`, `PROTON_USE_OPTISCALER=0\|1\|<release version>` | Wayland on, local cache and upscaler upgrades opt in. OptiScaler opts in. The release README also documents `PROTON_USE_PIPEWIRE=0` to override its PipeWire default. [wineland-11.0-20261124 launcher](https://github.com/nanomatters/proton-cachyos/blob/wineland-11.0-20261124/proton) · [Runtime options](https://github.com/nanomatters/proton-cachyos/blob/wineland-11.0-20261124/README.md) |
| Proton-EM | `PROTON_ENABLE_WAYLAND=0\|1`, `PROTON_USE_SDL=0\|1` (alias `PROTON_PREFER_SDL`), `PROTON_FSR4_UPGRADE=0\|1\|<supported version>`, `PROTON_MLFG_UPGRADE=0\|1`, `PROTON_ENABLE_HDR=0\|1` on builds that still read it | Explicit Wayland and SDL opt in. FSR 4 behavior is version-dependent, with automatic upgrades supported from 10.0-20. MLFG defaults on with FSR 4 in 10.0-33 and newer. HDRTEST releases remove the legacy HDR switch. EM-10.0-37-HDR contains a local shader cache TODO and no launcher read for `PROTON_LOCAL_SHADER_CACHE`. [Launcher](https://github.com/BananaWorks07/Proton/blob/EM-10.0-37-HDR/proton) · [EM additions](https://github.com/BananaWorks07/Proton/blob/em-10/docs/EM-ADDITIONS.md) · [FSR 4 values](https://github.com/BananaWorks07/Proton/blob/em-10/docs/FSR4.md) |
| Proton-RTSP | `PROTON_LOG=0\|1\|<Wine debug channels>`, `PROTON_USE_WINED3D=0\|1`, `PROTON_USE_WOW64=1` | Logging off, DXVK for D3D9–11, exact `1` selects the alternate WoW64 path on x86-64. RTSP is built in to this release. No separate RTSP launch toggle was identified. [proton-rtsp-11.0-20260609-4 launcher](https://github.com/SpookySkeletons/proton-rtsp/blob/proton-rtsp-11.0-20260609-4/proton) |
| Proton-Tkg | `PROTON_NVAPI_DISABLE=0\|1`, `PROTON_WINEDBG_DISABLE=0\|1`, `PROTON_PULSE_LOWLATENCY=0\|1`, `PROTON_USE_CUSTOMD3D9=0\|1`, `PROTON_WINETRICKS=0\|1` | The template launcher reads all five. The build script rewrites feature defaults in the generated `user_settings.py`. The inspected config disables the PulseAudio override and Winetricks prompt by default, and the other defaults depend on the build profile. Confirm the generated release before offering a Tkg-specific control. [Launcher template](https://github.com/Frogging-Family/wine-tkg-git/blob/37259617863cd2f4d1dcba67b67c68fb18049e09/proton-tkg/proton_template/conf/proton) · [Build config](https://github.com/Frogging-Family/wine-tkg-git/blob/37259617863cd2f4d1dcba67b67c68fb18049e09/proton-tkg/proton-tkg.cfg) · [Valve experimental Sniper workflow](https://github.com/Frogging-Family/wine-tkg-git/actions/workflows/proton-valvexbe-sniper.yml) |
| Proton-Anime | `PROTON_USE_D7VK=0\|1`, `PROTON_USE_OPTISCALER=0\|1\|<release version>`, `PROTON_LOCAL_SHADER_CACHE=0\|1` | All three opt in. Both Anime-Proton11-7 release archives carry the same `proton` launcher, byte-for-byte, and it calls all three features. The ARM64 build runs x86-64 games using FEX. Game-level support still differs across architectures. [Release archives](https://github.com/MrLGamer/proton-anime/releases/tag/Anime-Proton11-7) · [Tagged launcher](https://github.com/MrLGamer/proton-anime/blob/Anime-Proton11-7/proton) |
| Proton-HEVC | `PROTON_HEVC_DEFAULTS=0\|1`, `PROTON_USE_WINED3D=0\|1`, `WINE_D3D_CONFIG=renderer=vulkan` | The wrapper enables its defaults unless the value is exactly `0`. Those defaults select WineD3D, set its Vulkan renderer and add a builtin DXGI override if needed. This is the Proton-HEVC-11.0-2-r1 packaging path. [Launcher](https://github.com/changeforan/zzz-cloud-hevc/blob/Proton-HEVC-11.0-2-r1/packaging/proton-launcher.py) · [Release notes](https://github.com/changeforan/zzz-cloud-hevc/releases/tag/Proton-HEVC-11.0-2-r1) |

### Proton-Anime game fixes and integrations

All rows refer to Anime-Proton11-7. The x86-64 and ARM64 launcher check
establishes option recognition. Its release notes document a smaller set of games
tested on ARM64. No game was launched for this audit.

| Exact option | Accepted values and default | Evidence |
| --- | --- | --- |
| `PROTON_USE_XXMI` and the overrides `PROTON_USE_GIMI`, `PROTON_USE_SRMI`, `PROTON_USE_ZZMI`, `PROTON_USE_HIMI`, `PROTON_USE_WWMI`, `PROTON_USE_EFMI` | `0` or unset leaves the importer off, `1` selects the current release, and a release version pins it. Auto-selection depends on game detection. Importers require D3D11. | [Tagged integrations](https://github.com/MrLGamer/proton-anime/blob/Anime-Proton11-7/ADDITIONS.md) · [Downloader patch](https://github.com/MrLGamer/proton-anime/blob/Anime-Proton11-7/patches/protonfixes/0004-protonfixes-add-XXMI-model-importer-downloader.patch) |
| `PROTON_USE_RESHADE`, `PROTON_RESHADE_PATH` | ReShade is off by default. `1` selects the current release and a release version pins it. The path accepts a host directory or `0` for prefix-local storage. The default storage directory is `$XDG_DATA_HOME/reshade`, falling back to `~/.local/share/reshade`. Without XXMI, ReShade and OptiScaler compete for the same `dxgi.dll` load slot. | [Tagged integrations](https://github.com/MrLGamer/proton-anime/blob/Anime-Proton11-7/ADDITIONS.md) · [Downloader patch](https://github.com/MrLGamer/proton-anime/blob/Anime-Proton11-7/patches/protonfixes/0005-protonfixes-add-ReShade-downloader.patch) |
| `PROTON_HSR_FPS`, `PROTON_GI_FPS` | Positive integer FPS. Unset leaves the game limit alone. HSR needs a prior launch to create its settings. GI is documented for `GenshinImpact.exe` and `YuanShen.exe`. | [Tagged game fixes](https://github.com/MrLGamer/proton-anime/blob/Anime-Proton11-7/GAMEFIXES.md) · [HSR launcher implementation](https://github.com/MrLGamer/proton-anime/blob/Anime-Proton11-7/proton) · [GI Wine patch](https://github.com/MrLGamer/proton-anime/blob/Anime-Proton11-7/patches/wine-hotfixes/proton-anime/genshin/0001-HACK-kernelbase-unlock-Genshin-Impact-frame-rate-cap.patch) |
| `PROTON_KURO_KEEP_LAUNCHER`, `PROTON_NTE_HIDE_LAUNCHER`, `PROTON_NTE_HIDE_LAUNCHER_TIMEOUT`, `PROTON_WUWA_ENGINE_VARS` | `1` keeps the WuWa/PGR launcher open after game start or hides the NTE launcher, respectively. Both overrides default off. The NTE timeout is seconds, default `300`, with `0` waiting indefinitely. The WuWa override accepts comma-separated console `key=value` pairs and rewrites the INI when at least one pair is valid. | [Tagged game fixes](https://github.com/MrLGamer/proton-anime/blob/Anime-Proton11-7/GAMEFIXES.md) · [Kuro launcher implementation](https://github.com/MrLGamer/proton-anime/blob/Anime-Proton11-7/proton) · [NTE Wine patches](https://github.com/MrLGamer/proton-anime/tree/Anime-Proton11-7/patches/wine-hotfixes/proton-anime/nte) · [WuWa INI patch](https://github.com/MrLGamer/proton-anime/blob/Anime-Proton11-7/patches/protonfixes/0006-protonfixes-add-WuWa-UserEngine.ini-console-variable.patch) |

### Version-dependent HDR and upscaling

| Exact option | Accepted values and default | Supported builds |
| --- | --- | --- |
| `PROTON_ENABLE_HDR` (alias `PROTON_USE_HDR`) | `1` is the legacy HDR request and `0` disables HDR. Unset uses automatic detection in current GE and Anime builds. Those launchers translate the legacy enable to `DXVK_HDR=1` and have a separate `PROTON_FORCE_HDR=1` path. | GE-Proton11-14 and Anime-Proton11-7 retain the legacy read. EM HDRTEST removes its legacy read. Earlier releases can use the option to select Wine Wayland as well. [GE launcher](https://github.com/GloriousEggroll/proton-ge-custom/blob/GE-Proton11-14/proton) · [GE HDR documentation](https://github.com/GloriousEggroll/proton-ge-custom/blob/GE-Proton11-14/README.md#enable-hdr) · [EM additions](https://github.com/BananaWorks07/Proton/blob/em-10/docs/EM-ADDITIONS.md) |
| `PROTON_FSR4_UPGRADE` | `0` disables the explicit upgrade, `1` requests the build or manifest default, and a supported release version pins the DLL. GE and CachyOS upgrades opt in. Games and GPU drivers must support the selected DLL. | GE-Proton11-14 and cachyos-11.0-20261015-slr include the launcher hook. Check each upstream manifest for supported versions. [GE options](https://github.com/GloriousEggroll/proton-ge-custom/blob/GE-Proton11-14/README.md) · [CachyOS options](https://github.com/CachyOS/proton-cachyos/blob/cachyos_main/README.md) |
| `PROTON_FSR4_RDNA3_UPGRADE` | `0` or `1` for the older RDNA3 path, opt-in where implemented. GE-Proton11-14 uses the ordinary FSR 4 switch for RDNA3. | EM-10.0-37-HDR reads the key. GE-Proton11-14 documents it as obsolete. [EM launcher](https://github.com/BananaWorks07/Proton/blob/EM-10.0-37-HDR/proton) · [GE options](https://github.com/GloriousEggroll/proton-ge-custom/blob/GE-Proton11-14/README.md) |

### High process priority

| Exact option | Accepted values and default | Supported builds and catalog behavior |
| --- | --- | --- |
| `PROTON_PRIORITY_HIGH=1` | Historical editor token. An upstream consumer, accepted value range, and runtime default remain unverified. | No supporting build was established in the inspected Valve, GE, CachyOS, DW, Wineland, EM, RTSP or Anime launchers or in the checked Proton-Tkg template. CachyOS's [thread-priority documentation](https://github.com/CachyOS/proton-cachyos/blob/cachyos_main/docs/THREAD_PRIORITY.md) describes Wine's Windows-thread priority mapping and the OS nice limits. Preserve and allow explicit removal of the historical assignment. Keep new managed emission disabled. |

## Other compatibility tools

| Provider | Exact option and accepted values | Default, verified build and evidence |
| --- | --- | --- |
| Luxtorpeda | `LUX_DISABLE_DEFAULT_CONFIRM=0\|1` | `1` skips default-engine confirmation and `0` forces it back on. Unset uses `disable_default_confirm` from config, whose default is false. Applies when asking about a default engine. [v77.1.0 client](https://codeberg.org/luxtorpeda/luxtorpeda/src/tag/v77.1.0/src/client.rs) |
| Luxtorpeda | `LUX_WRITE_LOGGING=0\|1`, `LUX_STEAM_CLOUD=1` | Logging to file is off unless set to `1`. Steam Cloud defaults off and requires an engine package with Cloud support. The global `enable_steam_cloud` configuration exports `1`, so a per-game `0` cannot override that global enable. An engine launched through Proton can read the options supported by its own selected Proton build. [v77.1.0 command source](https://codeberg.org/luxtorpeda/luxtorpeda/src/tag/v77.1.0/src/command.rs) · [Runtime documentation](https://codeberg.org/luxtorpeda/luxtorpeda/src/tag/v77.1.0/README.md) |
| Boxtron | `BOXTRON_SIERRA_GAME=<game index>` (legacy alias `SDOS_SIERRA_GAME`) | Defaults to `1`. Accepted indices depend on the Sierra collection. DOSBox options and any engine-specific overrides require Boxtron as the selected compatibility tool. [v0.5.4 launcher source](https://github.com/dreamer/boxtron/blob/v0.5.4/fakesierralauncher.py) |
| Roberta | `LUX_SCUMMVM_CMD=<command>`, `LUX_USE_SCREEN=<display index>` | Unset uses per-game/global ScummVM command configuration and automatic or configured monitor selection. Index `0` is the primary screen. These are Roberta/ScummVM overrides despite the `LUX_` prefix. [v0.1.0 settings implementation](https://github.com/dreamer/roberta/blob/v0.1.0/settings.py) |
| Rosemary | `ROSEMARY_GLIBC=host\|bundled`, `ROSEMARY_LAUNCHER_TRACE` | Automatic glibc selection when unset, with `bundled` requiring a bundled loader. Trace is off by default and checks presence, so even `=0` enables it. These are diagnostic overrides for the macOS compatibility tool. [v0.5.0 launcher](https://github.com/microlift/rosemary/blob/v0.5.0/crates/launcher/src/main.rs) |
| TinkerGame | `tinkergame %command%`, compatibility-tool verbs `run` and `waitforexitandrun` | Wrapper and compatibility-tool entry points are opt-in by placement or tool selection. Its menus manage the underlying Proton/Wine options. ProtonPlus installs the compatibility-tool form for supported native Steam targets. [Pinned source](https://github.com/360900/tinkergame/tree/b8218f94fe179d8a388cadefa13930335ae790d8) · [Integration](integrations/tinkergame.md) |
| SteamTinkerLaunch | `steamtinkerlaunch %command%` or its Steam compatibility-tool entry point | Wrapper is off unless selected or prefixed. Managed Proton settings depend on the child tool and SteamTinkerLaunch's per-game settings. ProtonPlus retains this provider for existing installations. [v12.12 entry script](https://github.com/sonic2kk/steamtinkerlaunch/blob/v12.12/steamtinkerlaunch) |

## Kron4ek Wine builds

The four providers package Wine runners. Wine's runtime environment and a
launcher's own policies determine support. Even the Wine-Proton package has no
Steam Proton Python launcher. Inspecting `wine-proton-11.0-3-amd64` and
`wine-11.22-staging-tkg-amd64` confirmed that neither archive ships that launcher.
Do not grant `PROTON_*` launcher capabilities or assume DXVK and VKD3D-Proton
are installed from these package names. Wine's builtin DXGI is a separate
implementation.

| Provider | Exact option and accepted values | Default, verified build and evidence |
| --- | --- | --- |
| Wine-Vanilla | `WINEDEBUG=-all\|<comma-separated Wine channel rules>`, `WINEDLLOVERRIDES=<semicolon-separated DLL rules>`, for example `winegstreamer=` to disable that DLL | Wine defaults to error and FIXME channels and its normal DLL load order. Wine 11.22 attempts NTSync through `/dev/ntsync` when compiled with the required headers and the device is accessible. Plain amd64 and amd64-wow64 archives in 11.22 use WineHQ sources. [Builds](https://github.com/Kron4ek/Wine-Builds/releases/tag/11.22) · [Logging source](https://github.com/wine-mirror/wine/blob/wine-11.22/dlls/ntdll/unix/debug.c) · [DLL-loading source](https://github.com/wine-mirror/wine/blob/wine-11.22/dlls/ntdll/unix/loadorder.c) · [NTSync source](https://github.com/wine-mirror/wine/blob/wine-11.22/server/inproc_sync.c) |
| Wine-Staging | Same Wine logging and DLL override syntax as Vanilla | Same inherited defaults. 11.22 amd64 and amd64-wow64 add the Staging patchset. A Staging-specific variable requires the particular patch in the installed build. [Builds](https://github.com/Kron4ek/Wine-Builds/releases/tag/11.22) · [Build script](https://github.com/Kron4ek/Wine-Builds/blob/master/build_wine.sh) |
| Wine-Staging-Tkg | Same Wine logging and DLL override syntax as Vanilla | Same inherited defaults. The 11.22 amd64 archive includes `wine-tkg-config.txt` from the Staging-NTSync profile. Older TkG profiles use different sync patches. The profile and release need to be checked for each sync variable. [Builds](https://github.com/Kron4ek/Wine-Builds/releases/tag/11.22) · [TkG patch source](https://github.com/Kron4ek/wine-tkg) |
| Wine-Proton | Same Wine logging and DLL override syntax. `WINEFSYNC=0\|1` on the matching Valve Wine code path | FSync is off unless requested with a nonzero integer and supported by the host. Archive inspection covered proton-11.0-3 amd64. The release also publishes amd64-wow64 and x86 builds. Its build script compiles Valve Wine, whose sync backend can differ from the Steam launcher defaults. [Builds](https://github.com/Kron4ek/Wine-Builds/releases/tag/proton-11.0-3) · [FSync source](https://github.com/ValveSoftware/wine/blob/proton_11.0/server/fsync.c) |

`EXPERIMENTAL_WOW64` is a Kron4ek build-time switch. The installed archive
determines the WoW64 layout. A launch option cannot turn an ordinary Kron4ek
Wine archive into its `amd64-wow64` variant. `WINEESYNC`, `WINEFSYNC` and
`WINENTSYNC` do not share one cross-version convention. Keep those controls
dependent on the exact runner patches, the invocation path and kernel support.

## Graphics components

These settings apply to the component loaded in the game's prefix. A separately
installed archive can differ from the component actually bundled in Proton.
Recognize and preserve older syntax even when an installed component cannot be
identified.

| Provider | Exact option and accepted values | Default, verified build and evidence |
| --- | --- | --- |
| DXVK (doitsujin) | `DXVK_HDR=0\|1`, `DXVK_LOG_LEVEL=none\|error\|warn\|info\|debug\|trace`, `DXVK_CONFIG="dxvk.maxFrameRate = <integer>"` in current upstream | HDR checks for exactly `1` unless overridden by `dxgi.enableHDR` or an application workaround. Logging defaults to `info`. Frame limiter defaults to `0` (off), positive values cap FPS, and the config supports negative values for a conditional cap. A bare `DXVK_FRAME_RATE` cannot be offered generically. [v3.2 DXGI source](https://github.com/doitsujin/dxvk/blob/v3.2/src/dxgi/dxgi_options.cpp) · [Logging](https://github.com/doitsujin/dxvk/blob/v3.2/src/util/log/log.cpp) · [Configuration](https://github.com/doitsujin/dxvk/blob/v3.2/dxvk.conf) |
| DXVK (Sarek) | `DXVK_SHADER_COMPILATION_METHOD=dyasync\|async\|none`, or `dxvk.shaderCompilationMethod` in `dxvk.conf`, `DXVK_FRAME_RATE=<positive FPS>\|0` | Unified 1.14.1 defaults to `dyasync` and no FPS cap. Older releases have separate archives with different async behavior. `PROTON_DXVK_SAREK=1` selects the Sarek library only in a Proton launcher that ships it, such as the documented CachyOS bundle. [v1.14.1 docs](https://github.com/pythonlover02/DXVK-Sarek/blob/v1.14.1/README.md) · [Release variants](https://github.com/pythonlover02/DXVK-Sarek/releases) |
| DXVK GPL+Async (Ph42oN) | `DXVK_ASYNC=1` or `dxvk.enableAsync=true`, historical `DXVK_GPLASYNCCACHE=1` | Async opts in. GPL async state-cache option was removed in 2.7-1. Checked against current 3.1.1-1 documentation. No new managed `DXVK_ASYNC` from a generic Proton capability. [v3.1.1-1 runtime docs](https://gitlab.com/Ph42oN/dxvk-gplasync/-/blob/v3.1.1-1/README.md) |
| VKD3D-Proton | `VKD3D_DEBUG=none\|err\|warn\|fixme\|info\|trace`, `VKD3D_CONFIG=<comma-separated supported flags>`, `VKD3D_SHADER_CACHE_PATH=0\|<path>` | Logging defaults to `fixme`. Default config adds no explicit flags. Shader cache enabled with its normal path, exact `0` disables the internal cache. `VKD3D_SHADER_CACHE=1` and `VKD3D_GPUVA=1` have no documented consumer in v3.1. The curated flags and source links are in the [launch-options guide](launch-options.md#driver-flag-editors). [v3.1 runtime docs](https://github.com/HansKristian-Work/vkd3d-proton/blob/v3.1/README.md) · [Logging source](https://github.com/HansKristian-Work/vkd3d-proton/blob/v3.1/libs/vkd3d-common/debug.c) |
| VKD3D-Lutris | `VKD3D_DEBUG` and `VKD3D_SHADER_DEBUG` each accept `none\|err\|info\|fixme\|warn\|trace` | Both default to `fixme` in the v2.14 source. Legacy packages use this fork and its own runtime configuration. [v2.14 logging source](https://github.com/lutris/vkd3d/blob/v2.14/libs/vkd3d-common/debug.c) |

## Companion tools

| Tool | Exact option and accepted values | Default, supported source and conditions |
| --- | --- | --- |
| Gamescope | `gamescope [options] -- %command%`, `-f`/`--fullscreen`, `-W <width>`, `-H <height>`, `--hdr-enabled`, `--adaptive-sync`, `-r <Hz>`, `--framerate-limit <FPS>` | Backend and optional flags opt in. Width and height are pixel counts and computed when unset. `-r` is nested refresh and accepts nonnegative integers, with `0` leaving it unspecified. `--framerate-limit` is a separate refresh-divisor-based cap, off at `0`. HDR/VRR require appropriate display support. [Gamescope 3.16.17 option parser](https://github.com/ValveSoftware/gamescope/blob/3.16.17/src/main.cpp) |
| ScopeBuddy | `scopebuddy [options] -- %command%` (also `scb`); `SCB_AUTO_RES`, `SCB_AUTO_HDR`, `SCB_AUTO_VRR`, `SCB_AUTO_REFRESH`, `SCB_AUTO_FRAME_LIMIT` each `0\|1`, explicit resolution via `-W/-H` | 1.5.1 defaults auto flags to `0` before reading config. Numeric `1` activates supported detection. Manual `-r` is passed to Gamescope as nested refresh. `SCB_AUTO_FRAME_LIMIT` sets Gamescope's actual limiter. `SCB_W` and `SCB_H` are absent from the shipped script. [1.5.1 launcher](https://github.com/OpenGamingCollective/ScopeBuddy/blob/1.5.1/bin/scopebuddy) |
| MangoHud | `mangohud %command%`, `MANGOHUD=1` for Vulkan | Off absent configuration or activation. The wrapper supports Vulkan and OpenGL. Gamescope's separate `--mangoapp` path needs MangoApp. [MangoHud v0.8.4 launch documentation](https://github.com/flightlessmango/MangoHud/blob/v0.8.4/README.md#normal-usage) · [Gamescope 3.16.17 option parser](https://github.com/ValveSoftware/gamescope/blob/3.16.17/src/main.cpp) |
| GameMode | `gamemoderun %command%` | Opt-in wrapper with no per-game numeric switch required. The wrapper injects the GameMode client and requires the installed service/client. [GameMode 1.8.2 wrapper](https://github.com/FeralInteractive/gamemode/blob/1.8.2/data/gamemoderun) |
| CachyOS game-performance | `game-performance %command%`, `GAME_PERFORMANCE_SCREENSAVER_ON=1` | Opt-in wrapper. Any nonempty screensaver value skips inhibition. Performance profile requires `powerprofilesctl` or `tlpctl`. The scheduler profile change additionally requires CachyOS's patched power-profiles-daemon and active `scx_loader`. [Wrapper](https://github.com/CachyOS/CachyOS-Settings/blob/master/usr/bin/game-performance) · [Scheduler integration](https://github.com/CachyOS/wiki/blob/next/src/content/docs/configuration/sched-ext.mdx) |
| obs-vkcapture | `OBS_VKCAPTURE=1`, `obs-gamecapture %command%` | Capture opts in. The variable activates Vulkan capture, and the wrapper also enables OpenGL capture. Installed Vulkan layer, capture client and OBS plugin must match the environment. [obs-vkcapture v1.5.6 launch instructions](https://github.com/nowrep/obs-vkcapture/blob/v1.5.6/README.md#usage) |
| vkBasalt | `ENABLE_VKBASALT=1` | Vulkan layer off without activation. Requires a vkBasalt layer visible to the game. [vkBasalt v0.3.2.10 usage](https://github.com/DadSchoorse/vkBasalt/blob/v0.3.2.10/README.md#usage) |
| NVIDIA HDR WSI | `ENABLE_HDR_WSI=1` | Explicit opt-in for the installed legacy layer. Needed only with proprietary NVIDIA drivers older than 595 in the documented workaround. [HDR WSI layer](https://github.com/Zamundaaa/VK_hdr_layer) · [Flatpak layer documentation](https://github.com/niklaskorz/org.freedesktop.Platform.VulkanLayer.hdr) · [CachyOS launcher documentation](https://github.com/CachyOS/proton-cachyos?tab=readme-ov-file#proton-wayland-quirks) |
| OptiScaler and D7VK | `PROTON_USE_OPTISCALER=0\|1\|<release version>`, `PROTON_USE_D7VK=0\|1` | These particular keys are Proton launch integrations. OptiScaler opts in for supported builds. D7VK opts in where explicitly switched, including Anime-Proton11-7. Current GE-Proton runs it through its default DirectDraw setup. [Anime launcher](https://github.com/MrLGamer/proton-anime/blob/Anime-Proton11-7/proton) · [GE launcher](https://github.com/GloriousEggroll/proton-ge-custom/blob/GE-Proton11-14/proton) |

## Applying the matrix

- An actual read in the installed `proton` launcher is required for
  `PROTON_LOCAL_SHADER_CACHE`, D7VK, OptiScaler, legacy HDR, and FSR 4.
  D7VK uses `PROTON_USE_D7VK` or `PROTON_D7VK_DDRAW` according to the launcher.
  `PROTON_USE_HDR` is a legacy HDR alias. DXVK HDR and Wine ALSA switches
  are probed in their bundled drivers.
  Each game in a shared edit must resolve to a concrete qualifying tool.
  A README mention, a source comment, and a provider or display name supply
  insufficient evidence for these switches.
- Keep unverified historical priority assignments recognizable so the writer
  preserves them on unrelated edits and can remove a recognized assignment
  after an explicit edit. Preserve unresolved values as raw tokens.
- Luxtorpeda, Boxtron, Roberta, Rosemary and Wine runners have their own
  option contracts. Engine-specific and native Wine controls need an exact
  runtime and invocation check before the editor can offer them.
- Gamescope and ScopeBuddy use `-r` for nested refresh and
  `--framerate-limit` for the separate FPS cap. ScopeBuddy automatic
  resolution is `SCB_AUTO_RES=1`, and manual resolution is `-W/-H`.
