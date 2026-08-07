# Launch-option catalog and compatibility

The launch-options editor manages only options whose command semantics and
eligibility can be established without guessing. `LaunchCommandWriter` remains
the only serializer used by preview and Apply. Unknown source tokens stay raw,
in their original order and spelling, and an explicit Clear still replaces the
whole source.

## Eligibility model

Generic runtime and component capabilities come from the selected compatibility
tools, detected GPU vendor, and installed host/Flatpak components. Custom Proton
features use `LaunchOptionToolFeatureRule` in
`launch-option-capability-resolver.vala`.

Steam's `Default` selection is an alias, not an installed tool. Resolve it
through the launcher's app-ID-0 `CompatToolMapping` entry before probing. The
resolved internal title must match a discovered compatibility tool with a
concrete installation path. If the mapping is absent, stale, or points to a
missing installation, keep only generic Proton capabilities; never infer the
default from list order, a provider name, or the newest-looking version.

Each rule declares a capability and one or more exact source/documentation
markers. The resolver checks a bounded set of files in each installed tool and
grants the capability only when every selected tool advertises it. This makes
mass edit an intersection: an option supported by only some selected versions is
not offered. Active older options remain visible and removable, so persisted
launch commands stay backward compatible.

Do not infer custom features from a provider ID, display title, or version-name
pattern. To add a future custom-Proton feature:

1. Add its stable catalog ID, command semantics, dependencies, conflicts, and a
   dedicated capability when support is version-dependent.
2. Add one `LaunchOptionToolFeatureRule` with the exact marker emitted by the
   catalog.
3. Add the control to the relevant presentation group.
4. Test a supporting tool fixture, a non-supporting fixture, and a mixed-tool
   intersection. Also test writer output and dependencies/conflicts.

The probe currently reads `proton`, `README.md`, `CHANGELOG.md`,
`user_settings.sample.py`, `docs/FSR4.md`, and `docs/EM-ADDITIONS.md`. Extend
this bounded list when an upstream moves authoritative feature declarations;
do not recursively scan an installed Proton tree.

## Current source-backed options

The following behavior was checked against upstream branch heads on 2026-08-04.
Re-verify it before changing defaults because custom Proton behavior changes
quickly.

| Area | Managed behavior |
| --- | --- |
| HDR | `DXVK_HDR=1` is the current explicit DXVK HDR switch. Current Proton-CachyOS auto-enables HDR and documents `DXVK_NO_HDR=1` as its feature-probed opt-out; the opt-out conflicts with both enable paths. `PROTON_ENABLE_HDR=1` is kept only for installed custom Proton builds that still advertise the legacy path. Proton-GE also warns that its HDR/Wayland path breaks Steam Overlay and can affect Steam Input. `ENABLE_HDR_WSI=1` is labeled for NVIDIA proprietary drivers older than 595 only. Gamescope HDR remains `--hdr-enabled`. |
| FSR 4 | `PROTON_FSR4_UPGRADE=1` selects the installed build's default supported release. Do not hard-code a global FSR version because Proton-GE, Proton-CachyOS, and Proton-EM update on different schedules. `PROTON_FSR4_RDNA3_UPGRADE=1` is a legacy, feature-probed path: Proton-CachyOS removed it, while some Proton-GE builds retain it. |
| ML frame generation | `PROTON_MLFG_UPGRADE=1` depends on the current FSR 4 option. Proton-CachyOS requires FSR 4.0.3 or newer. The optional RDNA3 workaround is `DXIL_SPIRV_CONFIG=wmma_rdna3_workaround`. Proton-EM enables MLFG by default with FSR 4 and documents value `0` as the opt-out. |
| DX11 low latency | `PROTON_DXVK_LOWLATENCY=1` is exposed only when the selected custom Proton tool advertises it. |
| DX12 low latency | `PROTON_VKD3D_LOWLATENCY=1` is exposed only when advertised. The upstream implementation needs Reflex markers or waitable swapchains and does not support Intel GPUs or frame generation. |
| Vulkan low latency | `LOW_LATENCY_LAYER=1` exposes `VK_AMD_anti_lag`; `LOW_LATENCY_LAYER_REFLEX=1` switches to `VK_NV_low_latency2`. These help only games that already use the corresponding API. `DXVK_NVAPI_VKREFLEX=1` is the NVIDIA Vulkan-layer path advertised by Proton-CachyOS. |
| AMD Reflex compatibility | Try `DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1` first. The DXVK hide-AMD, forced-NVAPI, and low-latency-layer NVIDIA spoof presets are progressively more invasive and conflict with FSR 4/MLFG because upstream warns they can break those paths. |
| Monitoring/capture | `MANGOHUD=1` is Vulkan-only; the `mangohud` wrapper remains the OpenGL-capable choice, while Gamescope users should use MangoApp. `OBS_VKCAPTURE=1` requires the native obs-vkcapture build, or both `com.obsproject.Studio.Plugin.OBSVkCapture` and `org.freedesktop.Platform.VulkanLayer.OBSVkCapture` for Flatpak OBS/Steam. NVIDIA needs modesetting and driver 515.43.04 or newer. |
| CachyOS system profile | `game-performance %command%` requires the CachyOS helper and temporarily selects the performance power profile and gaming sched_ext profile. It conflicts with the separate GameMode wrapper. |

Primary references:

- [Proton-GE README](https://github.com/GloriousEggroll/proton-ge-custom)
- [Proton-CachyOS README](https://github.com/CachyOS/proton-cachyos)
- [Proton-CachyOS changelog](https://github.com/CachyOS/proton-cachyos/blob/cachyos_main/CHANGELOG.md)
- [Proton-EM FSR 4 documentation](https://github.com/Etaash-mathamsetty/Proton/blob/em-10/docs/FSR4.md)
- [Proton-EM additions](https://github.com/Etaash-mathamsetty/Proton/blob/em-10/docs/EM-ADDITIONS.md)
- [DXVK configuration](https://github.com/doitsujin/dxvk/blob/master/dxvk.conf)
- [DXVK driver support](https://github.com/doitsujin/dxvk/wiki/Driver-support)
- [VKD3D low-latency layer](https://github.com/netborg-afps/vkd3d-low-latency)
- [Vulkan low-latency layer](https://github.com/Korthos-Software/low_latency_layer)
- [DXVK-NVAPI](https://github.com/jp7677/dxvk-nvapi)
- [Gamescope](https://github.com/ValveSoftware/gamescope)
- [MangoHud](https://github.com/flightlessmango/MangoHud)
- [obs-vkcapture](https://github.com/nowrep/obs-vkcapture)
- [CachyOS gaming configuration](https://github.com/CachyOS/wiki/blob/next/src/content/docs/bg/configuration/gaming.mdx)

## Validation

Run the focused capability, catalog, composer, writer, and projection paths from
`tests/`, then the full Meson suite. GUI validation must separately exercise
single-game and mass-edit selection, active legacy options, long warning text,
preview equality, and Apply on disposable fixtures. A successful build does not
prove rendered placement or live driver/Proton behavior.
