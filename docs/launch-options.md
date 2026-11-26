# Launch-option catalog and compatibility

The launch-options editor manages only options whose command semantics and
eligibility can be established without guessing. `LaunchCommandWriter` remains
the only serializer used by preview and Apply. Unknown source tokens stay raw,
in their original order and spelling, and an explicit Clear still replaces the
whole source.

The [launch-option verification matrix](launch-option-matrix.md) records
upstream values, defaults, and release evidence for providers and companion
tools. Use it when deciding which catalog entries to emit and which
capabilities the installed build must supply.

## Custom wrappers

Under **Game arguments**, enter an absolute executable path or a relative path
starting with `./` or `../` in **Custom wrapper**. Quote paths with spaces.
You can also paste a command such as `"/path with spaces/bgmod" %command%`.
ProtonPlus supplies one `%command%` and places the wrapper immediately before
it, inside any selected Gamescope or ScopeBuddy backend. Game arguments stay
after `%command%`.

With several games selected, each game's preview uses its own launch options.
If different source commands already contain different custom wrappers, edit
the conflicting game individually before applying a shared wrapper.

For native games on native Steam, **Native game wrapper** offers installed
TinkerGame and SteamTinkerLaunch executables. ProtonPlus uses a managed
installation for the selected Steam instance when available, then looks for
the legacy SteamTinkerLaunch installation or a command on the host PATH.
New named wrappers use absolute paths and run inside the display backend.
A batch needs an executable path shared by the selected games.

## Adding or changing a control

`LaunchOptionCatalog` in [`src/launch-options/`](../src/launch-options/) owns
titles, descriptions, recognition tokens, and command semantics. Simple
toggles in presentation groups and wrappers under
[`src/widgets/games/launch-options-editor/`](../src/widgets/games/launch-options-editor/) use
`create_tile("stable-option-id")`; keep their order and legacy advanced flag in
the group, without repeating catalog metadata. They use the editor's shared
catalog, so changing a definition also updates the control and its tooltip.

Dynamic value, spin, and custom editors remain explicit because their input
behavior differs. They still register their stable catalog ID and route preview
and Apply through `LaunchCommandWriter`. Recognition tokens may include legacy
off/on pairs; do not replace them with canonical emitted tokens.

## Eligibility model

Generic runtime and component capabilities come from the selected compatibility
tools, detected GPU vendor, and installed host/Flatpak components. Custom Proton
features use `LaunchOptionToolFeatureRule` in
[`launch-option-capability-resolver.vala`](../src/launch-options/launch-option-capability-resolver.vala).

Steam's `Default` selection is an alias, not an installed tool. Resolve it
through the launcher's app-ID-0 `CompatToolMapping` entry before probing. The
resolved internal title must match a discovered compatibility tool with a
concrete installation path. If the mapping is absent, stale, or points to a
missing installation, keep only generic Proton capabilities; never infer the
default from list order, a provider name, or the newest-looking version.
When ProtonPlus runs in Flatpak while controlling native Steam, the tool's
launcher path remains the host `/usr/...` path, while bounded build probes use its `/run/host/usr/...` inspection path. Never persist or
pass the inspection alias to a host-side command.

Each rule declares a capability and the markers to check in the installed
files. Proton options use environment reads in the launcher or an integration
script. Driver options check the relevant bundled DXVK, VKD3D-Proton, or Wine
binary. Standalone compatibility tools are checked in their own installed
scripts or executables. The probes skip documentation and launcher comments.
Mass edit requires a common supported setting across the selected builds.
Saved options remain visible and removable, including earlier spellings.

Do not infer custom features from a provider ID, display title, or version-name
pattern. To add a future custom-Proton feature:

1. Add its stable catalog ID, command semantics, dependencies, conflicts, and a
   dedicated capability when support is version-dependent.
2. Add one `LaunchOptionToolFeatureRule` with the exact marker emitted by the
   catalog.
3. Add the control to the relevant presentation group.
4. Test a supporting tool fixture, a non-supporting fixture, and a mixed-tool
   intersection. Also test writer output and dependencies/conflicts.

The probe uses bounded, known installation paths. It runs off the GTK thread
and rechecks the selected tools before displaying the results.

## Current source-backed options

The [verification matrix](launch-option-matrix.md) records upstream sources
for runtime values and defaults.

### Shared runtime controls

- On supported builds, disable ESync, FSync, or NTSync independently. The
  WineD3D fallback and the Direct3D 10/11 disable switches are separate.
- DXVK and VKD3D-Proton have independent GPU filters, log settings, frame
  limiters, and shader-cache controls. The current DXVK limiter uses
  `DXVK_CONFIG` with `dxvk.maxFrameRate`. An existing compound
  `DXVK_CONFIG` stays intact and must be edited directly before adding a
  conflicting frame-limiter assignment.
- FSR 4 and OptiScaler accept pinned versions documented by the installed
  build. An unset control inherits runtime defaults. Explicit off values
  are available for options such as Wayland, ML frame generation, and
  Proton-HEVC defaults.

### HDR

- `DXVK_HDR=1` explicitly enables DXVK HDR. Proton-CachyOS can enable HDR
  automatically. On builds that advertise `DXVK_NO_HDR=1`, that switch
  disables automatic HDR and conflicts with explicit enable options.
- `PROTON_ENABLE_HDR=1` is available for builds that still advertise it.
  Newer Proton-GE uses automatic HDR detection. The legacy switch still has
  an effect in builds that read it, with behavior that varies by release.
- `ENABLE_HDR_WSI=1` is for proprietary NVIDIA drivers older than 595.
  Gamescope uses `--hdr-enabled`.

### FSR 4 and frame generation

- `PROTON_FSR4_UPGRADE=1` selects the installed build's supported default.
  Proton-GE, Proton-CachyOS, and Proton-EM update on different schedules.
- `PROTON_FSR4_RDNA3_UPGRADE=1` is feature-probed for older builds. Some
  Proton-GE builds retain it after Proton-CachyOS removed it.
- `PROTON_MLFG_UPGRADE=1` depends on FSR 4. Proton-CachyOS requires FSR
  4.0.3 or newer. The optional RDNA3 workaround is
  `DXIL_SPIRV_CONFIG=wmma_rdna3_workaround`. Proton-EM enables MLFG with
  FSR 4 by default and documents value `0` as the opt-out.

### Low latency

- `PROTON_DXVK_LOWLATENCY=1` and `PROTON_VKD3D_LOWLATENCY=1` require
  support from the installed build. The DX12 implementation requires Reflex
  markers or waitable swapchains and excludes Intel GPUs and frame generation.
- `LOW_LATENCY_LAYER=1` exposes `VK_AMD_anti_lag` in builds that include
  the layer, such as Proton-CachyOS and GE-Proton11-14. Set
  `LOW_LATENCY_LAYER_REFLEX=1` to switch to `VK_NV_low_latency2`. The game
  must use the corresponding API. Both builds also expose
  `DXVK_NVAPI_VKREFLEX=1` for the separate NVIDIA Vulkan layer.
- For AMD Reflex compatibility, try `DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1`
  first. The hide-AMD, forced-NVAPI, and NVIDIA spoof presets conflict with
  FSR 4 and MLFG because they can break those paths.

### Gamescope and ScopeBuddy

- Nested refresh rate emits `-r` in Hz. Frame limit emits
  `--framerate-limit` in FPS. The existing `*-frame-limit` IDs retain their
  original `-r` meaning for saved commands.
- Gamescope exposes internal and output resolution separately, along with
  scaling mode and filter, output selection, cursor behavior, HDR luminance
  and inverse tone mapping. MangoApp uses `--mangoapp` and requires the
  `mangoapp` executable. [Gamescope command-line options](https://github.com/ValveSoftware/gamescope/blob/3.16.17/src/main.cpp)
- ScopeBuddy accepts a profile filename through `SCB_CONF` and an application
  config ID through `SCB_APPID`. ScopeBuddy loads the profile and then any
  matching `AppID/<id>.conf`. Environment-only mode sets `SCB_NOSCOPE=1`.
  Automatic refresh and frame limiting use `SCB_AUTO_REFRESH` and
  `SCB_AUTO_FRAME_LIMIT`. [ScopeBuddy launcher](https://github.com/OpenGamingCollective/ScopeBuddy/blob/main/bin/scopebuddy)
- ScopeBuddy's append mode places configured Gamescope arguments first and
  explicit launch arguments last. Fallback mode uses the configured arguments
  when the launch supplies none. `SCB_DEBUG=1` writes the resolved command to
  `scopebuddy.log` in the ScopeBuddy config directory. Both display backends
  retain an additional arguments field. [ScopeBuddy launcher](https://github.com/OpenGamingCollective/ScopeBuddy/blob/main/bin/scopebuddy)

### Wine ALSA and AMD Vulkan drivers

- The Wine ALSA driver shipped by the inspected GE-Proton and CachyOS builds
  reads `WINEALSA_CHANNELS` and `WINEALSA_SPATIAL`. The GE-Proton11-1 release
  notes spell the latter `WINEALSA_SPACIAL`. Saved assignments with either
  spelling are recognized. [GE-Proton11-1 patch](https://github.com/GloriousEggroll/proton-ge-custom/blob/GE-Proton11-1/patches/proton/winealsa-override-channel-count.patch) · [CachyOS Wine driver](https://github.com/CachyOS/wine-cachyos/blob/cd14106e4fc0f96006005b07985e49cc1517e9c0/dlls/winealsa.drv/alsa.c)
- The AMD Vulkan driver selector requires an AMD GPU and AMDVLK's switchable
  graphics layer for native Steam.

### Overlays, capture, and performance profiles

- `MANGOHUD=1` works for Vulkan. Use the `mangohud` wrapper for OpenGL
  or MangoApp with Gamescope.
- `OBS_VKCAPTURE=1` enables Vulkan capture. The `obs-gamecapture` wrapper
  supports Vulkan and OpenGL. The editor checks for the native capture layer
  and wrapper separately. Flatpak Steam uses
  `org.freedesktop.Platform.VulkanLayer.OBSVkCapture`. Flatpak OBS itself uses
  `com.obsproject.Studio.Plugin.OBSVkCapture`. For NVIDIA, enable modesetting
  and use driver 515.43.04 or newer.
- `game-performance %command%` temporarily requests the performance power
  profile. The gaming sched_ext profile also requires CachyOS's
  power-profiles-daemon integration and a running `scx_loader`. Set
  `GAME_PERFORMANCE_SCREENSAVER_ON=1` to allow the screensaver to activate
  during play. The helper conflicts with GameMode.

### Upstream references

- [Proton-GE README](https://github.com/GloriousEggroll/proton-ge-custom)
- [Proton-CachyOS README](https://github.com/CachyOS/proton-cachyos)
- [Proton-CachyOS changelog](https://github.com/CachyOS/proton-cachyos/blob/cachyos_main/CHANGELOG.md)
- [Proton-EM FSR 4 documentation](https://github.com/BananaWorks07/Proton/blob/em-10/docs/FSR4.md)
- [Proton-EM additions](https://github.com/BananaWorks07/Proton/blob/em-10/docs/EM-ADDITIONS.md)
- [DXVK configuration](https://github.com/doitsujin/dxvk/blob/master/dxvk.conf)
- [DXVK driver support](https://github.com/doitsujin/dxvk/wiki/Driver-support)
- [VKD3D low-latency layer](https://github.com/netborg-afps/vkd3d-low-latency)
- [Vulkan low-latency layer](https://github.com/Korthos-Software/low_latency_layer)
- [DXVK-NVAPI](https://github.com/jp7677/dxvk-nvapi)
- [Gamescope](https://github.com/ValveSoftware/gamescope)
- [MangoHud](https://github.com/flightlessmango/MangoHud)
- [obs-vkcapture](https://github.com/nowrep/obs-vkcapture)
- [CachyOS gaming configuration](https://github.com/CachyOS/wiki/blob/next/src/content/docs/bg/configuration/gaming.mdx)

## Driver flag editors

`LaunchOptionFlags` owns the selectable keys and translated descriptions for
VKD3D configuration, RADV performance tests, RADV debugging, and ACO debugging.
Both the catalog and widgets consume these definitions. Do not add a separate
widget list or accept obsolete values merely to make a control pass validation.

Descriptions and offered flags were checked on 2026-10-24 against the
[Mesa environment-variable documentation](https://docs.mesa3d.org/envvars.html)
and the [VKD3D-Proton README](https://github.com/HansKristian-Work/vkd3d-proton/blob/master/README.md).
These are curated subsets, not every upstream debugging switch. Support still
depends on the installed driver or bundled VKD3D version. ACO uses `validateir`;
old `validate`/`nowave32` and removed RADV debug flags are not offered for new edits.

Constrained flag editors do not offer arbitrary custom additions. Existing
unknown or legacy flags can still load and be removed. Unrelated edits preserve
the original raw command through `LaunchCommandWriter`; explicit Clear still
removes the whole command. Loading a new list replaces all old selections,
including custom rows. An enabled editor with no selected flags emits no option.
DLL overrides retain their custom-entry control.

The widget regression executable checks descriptions, selection/composition,
legacy loading, replacement, and clearing. Meson uses an isolated Xvfb display
when available; otherwise it needs a display and skips when none is available.
On Arch, `xorg-server-xvfb` provides Xvfb.

## Validation

Run the focused capability, catalog, composer, writer, and projection paths from
`tests/`, then the full Meson suite. GUI validation must separately exercise
single-game and mass-edit selection, active legacy options, long warning text,
preview equality, and Apply on disposable fixtures. A successful build does not
prove rendered placement or live driver/Proton behavior.
