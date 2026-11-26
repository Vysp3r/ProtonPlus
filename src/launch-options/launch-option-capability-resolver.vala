namespace ProtonPlus.LaunchOptions {
    using Gee;

    public enum LaunchOptionEligibilityKind {
        AVAILABLE,
        VARIANT_SELECTABLE_WITH_WARNING,
        UNAVAILABLE_RUNTIME,
        UNAVAILABLE_COMPONENT,
        UNAVAILABLE_HARDWARE,
        UNSUPPORTED,
        LEGACY_ACTIVE_ONLY,
        UNKNOWN_CONTEXT
    }

    /* Presentation eligibility is deliberately local to launch options.  It
     * describes what the editor may offer; the composer remains the final
     * validation boundary for command construction. */
    public class LaunchOptionEligibility : Object {
        public LaunchOptionEligibilityKind kind { get; construct; }
        public bool may_activate { get; construct; }
        public bool may_modify { get; construct; }
        public bool show_when_inactive { get; construct; }
        public bool keep_visible_when_active { get; construct; }
        public string reason { get; construct; }

        public LaunchOptionEligibility (
            LaunchOptionEligibilityKind kind, bool may_activate, bool may_modify,
            bool show_when_inactive, bool keep_visible_when_active, string reason = ""
        ) {
            Object (kind: kind, may_activate: may_activate, may_modify: may_modify,
                show_when_inactive: show_when_inactive,
                keep_visible_when_active: keep_visible_when_active, reason: reason);
        }
    }

    public class LaunchOptionInstalledComponents : Object {
        public bool mangohud { get; construct; }
        public bool mangoapp { get; construct; }
        public string scopebuddy_command { get; construct; }
        public bool gamemode { get; construct; }
        public bool gamescope { get; construct; }
        public bool scopebuddy { get; construct; }
        public bool vkbasalt { get; construct; }
        public bool game_performance { get; construct; }
        public bool obs_vkcapture { get; construct; }
        public bool obs_gamecapture { get; construct; }
        public bool amd_vulkan_switcher { get; construct; }

        public LaunchOptionInstalledComponents (
            bool mangohud = false, bool gamemode = false, bool gamescope = false,
            bool scopebuddy = false, bool vkbasalt = false,
            bool game_performance = false, bool obs_vkcapture = false,
            bool obs_gamecapture = false, bool amd_vulkan_switcher = false,
            bool mangoapp = false, string scopebuddy_command = ""
        ) {
            Object (mangohud: mangohud, gamemode: gamemode, gamescope: gamescope,
                scopebuddy: scopebuddy, vkbasalt: vkbasalt,
                game_performance: game_performance, obs_vkcapture: obs_vkcapture,
                obs_gamecapture: obs_gamecapture, amd_vulkan_switcher: amd_vulkan_switcher,
                mangoapp: mangoapp, scopebuddy_command: scopebuddy_command);
        }
    }

    class LaunchOptionToolFeatureRule : Object {
        public LaunchOptionCapability capability { get; construct; }
        public string[] keys { get; construct; }
        public string? option_id { get; construct; }
        public string[] binaries { get; private set; default = {}; }
        public string? source_path { get; construct; }
        public string? executable_path { get; construct; }
        public string? required_directory { get; construct; }
        public bool integration_table { get; construct; }
        public bool requires_proton { get; construct; default = true; }

        public LaunchOptionToolFeatureRule (
            LaunchOptionCapability capability, string key, string option_id = "", string[] binaries = {},
            string? required_directory = null
        ) {
            Object (capability: capability, option_id: option_id, source_path: "proton",
                required_directory: required_directory, requires_proton: true,
                keys: option_id == "" ? new string[] { key } : LaunchOptionCatalog.build_environment_keys (option_id));
            // A GObject string-vector property expects a NULL sentinel. Copy by the Vala array length.
            this.binaries = binaries;
        }
        public LaunchOptionToolFeatureRule.for_script (
            LaunchOptionCapability capability, string key, string source_path, bool requires_proton = true, bool integration_table = false
        ) {
            Object (capability: capability, keys: new string[] { key },
                source_path: source_path, requires_proton: requires_proton, integration_table: integration_table);
        }

        public LaunchOptionToolFeatureRule.for_executable (
            LaunchOptionCapability capability, string key, string executable_path
        ) {
            Object (capability: capability, keys: new string[] { key }, executable_path: executable_path, requires_proton: false);
        }
    }

    public class LaunchOptionCapabilityResolver : Object {
        LaunchOptionCatalog catalog;
        LaunchOptionToolFeatureRule[] tool_feature_rules;

        const string[] DXVK_DXGI_PATHS = {
            "lib/wine/dxvk/x86_64-windows/dxgi.dll", "lib/wine/dxvk/i386-windows/dxgi.dll",
            "lib/wine/dxvk/aarch64-windows/dxgi.dll", "lib64/wine/dxvk/dxgi.dll",
            "lib/wine/dxvk/dxgi.dll"
        };
        const string[] DXVK_D3D11_PATHS = {
            "lib/wine/dxvk/x86_64-windows/d3d11.dll", "lib/wine/dxvk/i386-windows/d3d11.dll",
            "lib/wine/dxvk/aarch64-windows/d3d11.dll", "lib64/wine/dxvk/d3d11.dll",
            "lib/wine/dxvk/d3d11.dll"
        };
        const string[] VKD3D_PATHS = {
            "lib/wine/vkd3d-proton/x86_64-windows/d3d12.dll", "lib/wine/vkd3d-proton/x86_64-windows/d3d12core.dll",
            "lib/wine/vkd3d-proton/i386-windows/d3d12.dll", "lib/wine/vkd3d-proton/i386-windows/d3d12core.dll",
            "lib/wine/vkd3d-proton/aarch64-windows/d3d12.dll", "lib/wine/vkd3d-proton/aarch64-windows/d3d12core.dll",
            "lib64/wine/vkd3d-proton/d3d12.dll", "lib64/wine/vkd3d-proton/d3d12core.dll",
            "lib/wine/vkd3d-proton/d3d12.dll", "lib/wine/vkd3d-proton/d3d12core.dll"
        };
        const string[] WINE_KERNELBASE_PATHS = {
            "lib/wine/x86_64-windows/kernelbase.dll", "lib/wine/i386-windows/kernelbase.dll",
            "lib/wine/aarch64-windows/kernelbase.dll", "lib64/wine/x86_64-windows/kernelbase.dll"
        };
        const string[] WINE_ALSA_PATHS = {
            "lib/wine/x86_64-unix/winealsa.so", "lib64/wine/x86_64-unix/winealsa.so",
            "lib/wine/i386-unix/winealsa.so", "lib/wine/aarch64-unix/winealsa.so",
            "lib64/wine/aarch64-unix/winealsa.so"
        };

        public LaunchOptionCapabilityResolver (LaunchOptionCatalog? catalog = null) {
            this.catalog = catalog ?? new LaunchOptionCatalog ();
            tool_feature_rules = {
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_ESYNC, "PROTON_NO_ESYNC"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_FSYNC, "PROTON_NO_FSYNC"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_NTSYNC, "PROTON_NO_NTSYNC"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_NO_D3D11, "PROTON_NO_D3D11"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_NO_D3D10, "PROTON_NO_D3D10"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_DISABLE_NVAPI, "PROTON_DISABLE_NVAPI"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_LOG_DIR, "PROTON_LOG_DIR"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.DXVK_FRAME_CONFIG, "dxvk.maxFrameRate", "", DXVK_DXGI_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.DXVK_DEVICE_FILTER, "DXVK_FILTER_DEVICE_NAME", "", DXVK_D3D11_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.DXVK_LOG_PATH, "DXVK_LOG_PATH", "", DXVK_D3D11_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.DXVK_SHADER_CACHE, "DXVK_SHADER_CACHE", "", DXVK_D3D11_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.DXVK_SHADER_CACHE_PATH, "DXVK_SHADER_CACHE_PATH", "", DXVK_D3D11_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.VKD3D_DEVICE_FILTER, "VKD3D_FILTER_DEVICE_NAME", "", VKD3D_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.VKD3D_DEVICE_INDEX, "VKD3D_VULKAN_DEVICE", "", VKD3D_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.VKD3D_FRAME_RATE, "VKD3D_FRAME_RATE", "", VKD3D_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.VKD3D_LOG_FILE, "VKD3D_LOG_FILE", "", VKD3D_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.VKD3D_SHADER_CACHE_PATH, "VKD3D_SHADER_CACHE_PATH", "", VKD3D_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_SDL, "", "prefer-sdl"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_WAYLAND, "PROTON_ENABLE_WAYLAND"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_WOW64, "PROTON_USE_WOW64"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_PIPEWIRE, "PROTON_USE_PIPEWIRE"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_SAREK, "PROTON_DXVK_SAREK", "", {}, "files/lib/wine/dxvk-sarek"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_FSR4_INDICATOR, "PROTON_FSR4_INDICATOR"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_HEVC_DEFAULTS, "PROTON_HEVC_DEFAULTS"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_TKG_NVAPI, "PROTON_NVAPI_DISABLE"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_TKG_WINEDBG, "PROTON_WINEDBG_DISABLE"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_TKG_PULSE, "PROTON_PULSE_LOWLATENCY"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_TKG_D3D9, "PROTON_USE_CUSTOMD3D9"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_TKG_WINETRICKS, "PROTON_WINETRICKS"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_ANIME_HSR, "PROTON_HSR_FPS"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_ANIME_KURO, "PROTON_KURO_KEEP_LAUNCHER"),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.BOXTRON_SIERRA, "BOXTRON_SIERRA_GAME", "fakesierralauncher.py", false),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.ROBERTA_COMMAND, "LUX_SCUMMVM_CMD", "settings.py", false),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.ROBERTA_SCREEN, "LUX_USE_SCREEN", "settings.py", false),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.PROTON_ANIME_RESHADE, "PROTON_USE_RESHADE", "protonfixes/reshade.py"),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.PROTON_ANIME_RESHADE_PATH, "PROTON_RESHADE_PATH", "protonfixes/reshade.py"),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.PROTON_ANIME_WUWA, "PROTON_WUWA_ENGINE_VARS", "protonfixes/gamefixes-steam/3513350.py"),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.PROTON_WINELAND_UPSCALER, "PROTON_UPSCALER_UPGRADE", "upscalers/__init__.py"),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.PROTON_ANIME_XXMI, "PROTON_USE_XXMI", "protonfixes/xxmi.py", true, true),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.PROTON_ANIME_GIMI, "PROTON_USE_GIMI", "protonfixes/xxmi.py", true, true),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.PROTON_ANIME_SRMI, "PROTON_USE_SRMI", "protonfixes/xxmi.py", true, true),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.PROTON_ANIME_ZZMI, "PROTON_USE_ZZMI", "protonfixes/xxmi.py", true, true),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.PROTON_ANIME_HIMI, "PROTON_USE_HIMI", "protonfixes/xxmi.py", true, true),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.PROTON_ANIME_WWMI, "PROTON_USE_WWMI", "protonfixes/xxmi.py", true, true),
                new LaunchOptionToolFeatureRule.for_script (LaunchOptionCapability.PROTON_ANIME_EFMI, "PROTON_USE_EFMI", "protonfixes/xxmi.py", true, true),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_ANIME_GI, "PROTON_GI_FPS", "", WINE_KERNELBASE_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_ANIME_NTE, "PROTON_NTE_HIDE_LAUNCHER", "", WINE_KERNELBASE_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_ANIME_NTE_TIMEOUT, "PROTON_NTE_HIDE_LAUNCHER_TIMEOUT", "", WINE_KERNELBASE_PATHS),
                new LaunchOptionToolFeatureRule.for_executable (LaunchOptionCapability.LUX_CONFIRM, "LUX_DISABLE_DEFAULT_CONFIRM", "luxtorpeda.x86_64"),
                new LaunchOptionToolFeatureRule.for_executable (LaunchOptionCapability.LUX_LOGGING, "LUX_WRITE_LOGGING", "luxtorpeda.x86_64"),
                new LaunchOptionToolFeatureRule.for_executable (LaunchOptionCapability.LUX_CLOUD, "LUX_STEAM_CLOUD", "luxtorpeda.x86_64"),
                new LaunchOptionToolFeatureRule.for_executable (LaunchOptionCapability.ROSEMARY_GLIBC, "ROSEMARY_GLIBC", "bin/rosemary"),
                new LaunchOptionToolFeatureRule.for_executable (LaunchOptionCapability.ROSEMARY_TRACE, "ROSEMARY_LAUNCHER_TRACE", "bin/rosemary"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.LEGACY_PROTON_HDR, "", "proton-hdr"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_DXVK_HDR, "DXVK_HDR", "", DXVK_DXGI_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_AUTO_HDR_CONTROL, "DXVK_NO_HDR", "", DXVK_DXGI_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_FSR4, "PROTON_FSR4_UPGRADE"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_FSR4_RDNA3, "PROTON_FSR4_RDNA3_UPGRADE"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_MLFG, "PROTON_MLFG_UPGRADE"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_DXVK_LOW_LATENCY, "PROTON_DXVK_LOWLATENCY"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_VKD3D_LOW_LATENCY, "PROTON_VKD3D_LOWLATENCY"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.LOW_LATENCY_LAYER, "LOW_LATENCY_LAYER"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.VULKAN_REFLEX_LAYER, "DXVK_NVAPI_VKREFLEX"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_LOCAL_SHADER_CACHE, "PROTON_LOCAL_SHADER_CACHE"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_D7VK, "", "d7vk"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.PROTON_OPTISCALER, "PROTON_USE_OPTISCALER"),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.WINEALSA_CHANNELS, "WINEALSA_CHANNELS", "", WINE_ALSA_PATHS),
                new LaunchOptionToolFeatureRule (LaunchOptionCapability.WINEALSA_SPATIAL, "", "winealsa-spatial", WINE_ALSA_PATHS)
            };
        }

        public LaunchCommandCapabilityContext resolve (
            Models.CompatibilityToolRuntimeKind[] runtimes, bool all_steam,
            LaunchOptionInstalledComponents components, Utils.GpuVendor gpu_vendor,
            Models.CompatibilityTool[] tools = {}, string[] native_steam_tool_roots = {}
        ) {
            LaunchOptionCapability[] values = {};
            if (all_steam)
                values = append_capability (values, LaunchOptionCapability.STEAM);

            var all_native = runtimes.length > 0;
            var all_proton = runtimes.length > 0;
            foreach (var runtime in runtimes) {
                all_native = all_native && runtime == Models.CompatibilityToolRuntimeKind.NATIVE;
                all_proton = all_proton && runtime == Models.CompatibilityToolRuntimeKind.PROTON;
            }
            if (all_native)
                values = append_capability (values, LaunchOptionCapability.NATIVE_LINUX);
            if (all_proton) {
                values = append_capability (values, LaunchOptionCapability.PROTON);
                /* These are standard, confirmed Proton-bundled facilities,
                 * not claims about a named custom variant. */
                values = append_capability (values, LaunchOptionCapability.DXVK);
                values = append_capability (values, LaunchOptionCapability.VKD3D_PROTON);
            }

            if (components.mangoapp) values = append_capability (values, LaunchOptionCapability.MANGOAPP);
            if (components.mangohud) values = append_capability (values, LaunchOptionCapability.MANGOHUD);
            if (components.gamemode) values = append_capability (values, LaunchOptionCapability.GAMEMODE);
            if (components.gamescope) values = append_capability (values, LaunchOptionCapability.GAMESCOPE);
            if (components.scopebuddy) values = append_capability (values, LaunchOptionCapability.SCOPEBUDDY);
            if (components.vkbasalt) values = append_capability (values, LaunchOptionCapability.VKBASALT);
            if (components.game_performance) values = append_capability (values, LaunchOptionCapability.GAME_PERFORMANCE);
            if (components.obs_vkcapture) values = append_capability (values, LaunchOptionCapability.OBS_VKCAPTURE);
            if (components.obs_gamecapture) values = append_capability (values, LaunchOptionCapability.OBS_GAMECAPTURE);
            if (components.amd_vulkan_switcher) values = append_capability (values, LaunchOptionCapability.AMD_VULKAN_SWITCHER);
            var environment_keys = new HashMap<string, string> ();
            if (all_steam && tools.length == runtimes.length) {
                var paths = new HashSet<string> ();
                foreach (var tool in tools) {
                    if (tool.inspection_path.strip () == "") {
                        paths.clear ();
                        break;
                    }
                    paths.add (tool.inspection_path);
                }
                if (!paths.is_empty) {
                    var probe = new LaunchOptionToolProbe ();
                    foreach (var rule in tool_feature_rules) {
                        if (rule.requires_proton && !all_proton)
                            continue;
                        foreach (var key in rule.keys) {
                            if (!probe.all_support (paths, rule, key))
                                continue;
                            values = append_capability (values, rule.capability);
                            if (rule.option_id != null && rule.option_id != "")
                                environment_keys.set (rule.option_id, key);
                            break;
                        }
                    }
                }
            }
            switch (gpu_vendor) {
                case Utils.GpuVendor.AMD: values = append_capability (values, LaunchOptionCapability.AMD); break;
                case Utils.GpuVendor.NVIDIA: values = append_capability (values, LaunchOptionCapability.NVIDIA); break;
                case Utils.GpuVendor.INTEL: values = append_capability (values, LaunchOptionCapability.INTEL); break;
                default: break;
            }
            var wrapper_executables = new HashMap<string, string> ();
            if (components.scopebuddy && components.scopebuddy_command == "scb")
                wrapper_executables.set ("scopebuddy", "scb");
            if (all_native && all_steam && native_steam_tool_roots.length > 0) {
                var tinker_game = native_wrapper_executable ("tinkergame", "TinkerGame", native_steam_tool_roots);
                var steam_tinker_launch = native_wrapper_executable ("steamtinkerlaunch", "SteamTinkerLaunch", native_steam_tool_roots);
                if (tinker_game != null) {
                    wrapper_executables.set ("tinkergame", tinker_game);
                    values = append_capability (values, LaunchOptionCapability.TINKERGAME);
                }
                if (steam_tinker_launch != null) {
                    wrapper_executables.set ("steamtinkerlaunch", steam_tinker_launch);
                    values = append_capability (values, LaunchOptionCapability.STEAMTINKERLAUNCH);
                }
            }
            return new LaunchCommandCapabilityContext.with_resolved_values (
                values, (owned) environment_keys, (owned) wrapper_executables, runtimes.length > 1
            );
        }

        string? native_wrapper_executable (string command, string directory, string[] roots) {
            // One shared selection must launch through the same path for the entire batch.
            if (roots.length == 1) {
                var managed = Path.build_filename (roots[0], directory, command);
                if (is_executable (managed))
                    return managed;
            }
            if (command == "steamtinkerlaunch") {
                var home = Environment.get_home_dir ();
                var legacy = Globals.IS_STEAM_OS
                    ? Path.build_filename (home, "stl", "prefix", command)
                    : Path.build_filename (home, ".local", "share", "steamtinkerlaunch", command);
                if (is_executable (legacy))
                    return legacy;
            }
            return Utils.System.find_host_executable (command);
        }

        bool is_executable (string path) {
            return FileUtils.test (path, FileTest.IS_REGULAR) && FileUtils.test (path, FileTest.IS_EXECUTABLE);
        }

        public Models.CompatibilityToolRuntimeKind runtime_for_tool (Models.CompatibilityTool? tool) {
            return Models.Launchers.Steam.get_compatibility_tool_runtime_kind (tool);
        }

        public LaunchOptionEligibility evaluate (
            LaunchOptionMetadata metadata, LaunchCommandCapabilityContext? context, bool active = false
        ) {
            var semantics = metadata.semantics;
            if (semantics == null || semantics.support == LaunchOptionSupport.UNSUPPORTED
                || semantics.support == LaunchOptionSupport.UNKNOWN_UNVERIFIED) {
                return unavailable (LaunchOptionEligibilityKind.UNSUPPORTED, active,
                    _("This option is unsupported and cannot be newly enabled."));
            }
            if (semantics.support == LaunchOptionSupport.LEGACY_DEPRECATED
                || !semantics.managed_emission
                || semantics.kind == LaunchOptionSemanticKind.OPAQUE_CONTEXT_DEPENDENT
                || semantics.kind == LaunchOptionSemanticKind.COMMAND_BOUNDARY) {
                return unavailable (LaunchOptionEligibilityKind.LEGACY_ACTIVE_ONLY, active,
                    _("This legacy option is preserved but cannot be newly enabled."));
            }
            if (context == null)
                return unavailable (LaunchOptionEligibilityKind.UNKNOWN_CONTEXT, active,
                    _("Compatibility-tool capabilities are not known yet."));

            foreach (var capability in required_capabilities (metadata)) {
                if (!context.has (capability))
                    return unavailable (kind_for (capability), active, reason_for (capability));
            }
            if (semantics.kind == LaunchOptionSemanticKind.WRAPPER_SELECTOR) {
                var has_available_wrapper = false;
                foreach (var id in semantics.selectable_wrapper_ids) {
                    var wrapper = catalog.lookup_wrapper (id);
                    if (wrapper != null && context.has (wrapper.required_capability)) {
                        has_available_wrapper = true;
                        break;
                    }
                }
                if (!has_available_wrapper)
                    return unavailable (LaunchOptionEligibilityKind.UNAVAILABLE_COMPONENT, active,
                        metadata.id == "native-game-wrapper"
                            ? _("Requires an installed native game wrapper.")
                            : _("Requires an available launch backend."));
            }
            if (semantics.support == LaunchOptionSupport.VARIANT_SPECIFIC) {
                if (context.is_mass_edit)
                    return unavailable (LaunchOptionEligibilityKind.UNAVAILABLE_RUNTIME, active,
                        _("Support must be confirmed for every selected compatibility tool."));
                /* Confirming Proton establishes that managed emission is safe,
                 * but deliberately does not claim support by a named variant. */
                return new LaunchOptionEligibility (
                    LaunchOptionEligibilityKind.VARIANT_SELECTABLE_WITH_WARNING,
                    true, true, true, true,
                    _("Requires a compatible Proton variant.")
                );
            }
            return new LaunchOptionEligibility (LaunchOptionEligibilityKind.AVAILABLE,
                true, true, true, true);
        }

        public LaunchOptionEligibility evaluate_selection (
            LaunchOptionMetadata metadata, LaunchCommandSelection selection,
            LaunchCommandCapabilityContext? context, bool active = false
        ) {
            var eligibility = evaluate (metadata, context, active);
            if (!eligibility.may_activate || selection.wrapper_id == "")
                return eligibility;
            var wrapper = catalog.lookup_wrapper (selection.wrapper_id);
            if (wrapper == null)
                return unavailable (LaunchOptionEligibilityKind.UNSUPPORTED, active,
                    _("The selected launch backend is not supported."));
            if (context == null || !context.has (wrapper.required_capability))
                return unavailable (kind_for (wrapper.required_capability), active,
                    reason_for (wrapper.required_capability));
            return eligibility;
        }

        LaunchOptionEligibility unavailable (LaunchOptionEligibilityKind kind, bool active, string reason) {
            return new LaunchOptionEligibility (kind, false, false, false, active, reason);
        }

        LaunchOptionCapability[] required_capabilities (LaunchOptionMetadata metadata) {
            LaunchOptionCapability[] values = {};
            var semantics = metadata.semantics;
            if (semantics == null)
                return values;
            foreach (var capability in semantics.get_required_capabilities ())
                if (!(capability in values))
                    values = append_capability (values, capability);
            if (semantics.wrapper_id != "") {
                var wrapper = catalog.lookup_wrapper (semantics.wrapper_id);
                if (wrapper != null && !(wrapper.required_capability in values))
                    values = append_capability (values, wrapper.required_capability);
            }
            return values;
        }

        LaunchOptionCapability[] append_capability (
            LaunchOptionCapability[] values, LaunchOptionCapability capability
        ) {
            var expanded = new LaunchOptionCapability[values.length + 1];
            for (var index = 0; index < values.length; index++)
                expanded[index] = values[index];
            expanded[values.length] = capability;
            return expanded;
        }

        LaunchOptionEligibilityKind kind_for (LaunchOptionCapability capability) {
            switch (capability) {
                case LaunchOptionCapability.AMD:
                case LaunchOptionCapability.NVIDIA:
                case LaunchOptionCapability.INTEL:
                    return LaunchOptionEligibilityKind.UNAVAILABLE_HARDWARE;
                case LaunchOptionCapability.MANGOAPP:
                case LaunchOptionCapability.TINKERGAME:
                case LaunchOptionCapability.STEAMTINKERLAUNCH:
                case LaunchOptionCapability.MANGOHUD:
                case LaunchOptionCapability.GAMEMODE:
                case LaunchOptionCapability.GAME_PERFORMANCE:
                case LaunchOptionCapability.OBS_GAMECAPTURE:
                case LaunchOptionCapability.AMD_VULKAN_SWITCHER:
                case LaunchOptionCapability.OBS_VKCAPTURE:
                case LaunchOptionCapability.GAMESCOPE:
                case LaunchOptionCapability.SCOPEBUDDY:
                case LaunchOptionCapability.VKBASALT:
                    return LaunchOptionEligibilityKind.UNAVAILABLE_COMPONENT;
                case LaunchOptionCapability.PROTON:
                case LaunchOptionCapability.DXVK:
                case LaunchOptionCapability.VKD3D_PROTON:
                case LaunchOptionCapability.NATIVE_LINUX:
                case LaunchOptionCapability.WINEALSA_CHANNELS:
                case LaunchOptionCapability.WINEALSA_SPATIAL:
                case LaunchOptionCapability.PROTON_DXVK_HDR:
                case LaunchOptionCapability.LEGACY_PROTON_HDR:
                case LaunchOptionCapability.PROTON_AUTO_HDR_CONTROL:
                case LaunchOptionCapability.PROTON_FSR4:
                case LaunchOptionCapability.PROTON_FSR4_RDNA3:
                case LaunchOptionCapability.PROTON_MLFG:
                case LaunchOptionCapability.PROTON_DXVK_LOW_LATENCY:
                case LaunchOptionCapability.PROTON_VKD3D_LOW_LATENCY:
                case LaunchOptionCapability.LOW_LATENCY_LAYER:
                case LaunchOptionCapability.VULKAN_REFLEX_LAYER:
                case LaunchOptionCapability.PROTON_LOCAL_SHADER_CACHE:
                case LaunchOptionCapability.PROTON_D7VK:
                case LaunchOptionCapability.PROTON_OPTISCALER:
                    return LaunchOptionEligibilityKind.UNAVAILABLE_RUNTIME;
                default:
                    foreach (var rule in tool_feature_rules) {
                        if (rule.capability == capability)
                            return LaunchOptionEligibilityKind.UNAVAILABLE_RUNTIME;
                    }
                    return LaunchOptionEligibilityKind.UNKNOWN_CONTEXT;
            }
        }

        string reason_for (LaunchOptionCapability capability) {
            switch (capability) {
                case LaunchOptionCapability.AMD: return _("Requires an AMD GPU.");
                case LaunchOptionCapability.NVIDIA: return _("Requires an NVIDIA GPU.");
                case LaunchOptionCapability.INTEL: return _("Requires an Intel GPU.");
                case LaunchOptionCapability.MANGOAPP: return _("Requires the mangoapp executable.");
                case LaunchOptionCapability.TINKERGAME: return _("Requires an installed TinkerGame executable.");
                case LaunchOptionCapability.STEAMTINKERLAUNCH: return _("Requires an installed SteamTinkerLaunch executable.");
                case LaunchOptionCapability.MANGOHUD: return _("Requires MangoHud, which is not available.");
                case LaunchOptionCapability.GAMEMODE: return _("Requires GameMode, which is not available.");
                case LaunchOptionCapability.GAME_PERFORMANCE: return _("Requires the CachyOS game-performance command, which is not available.");
                case LaunchOptionCapability.OBS_GAMECAPTURE: return _("Requires the obs-gamecapture command.");
                case LaunchOptionCapability.AMD_VULKAN_SWITCHER: return _("Requires the AMD Vulkan switchable graphics layer.");
                case LaunchOptionCapability.OBS_VKCAPTURE: return _("Requires obs-vkcapture, which is not available.");
                case LaunchOptionCapability.GAMESCOPE: return _("Requires Gamescope, which is not available.");
                case LaunchOptionCapability.SCOPEBUDDY: return _("Requires ScopeBuddy, which is not available.");
                case LaunchOptionCapability.VKBASALT: return _("Requires vkBasalt, which is not available.");
                case LaunchOptionCapability.DXVK: return _("Requires DXVK from the selected compatibility tool.");
                case LaunchOptionCapability.VKD3D_PROTON: return _("Requires VKD3D-Proton from the selected compatibility tool.");
                case LaunchOptionCapability.NATIVE_LINUX: return _("Not supported by the selected compatibility tool.");
                case LaunchOptionCapability.PROTON_DXVK_HDR: return _("The selected Proton build does not expose the DXVK HDR switch.");
                case LaunchOptionCapability.WINEALSA_CHANNELS: return _("The selected Proton build does not expose Wine ALSA channel overrides.");
                case LaunchOptionCapability.WINEALSA_SPATIAL: return _("The selected Proton builds need a common Wine ALSA spatial downmix switch.");
                case LaunchOptionCapability.LEGACY_PROTON_HDR: return _("The selected Proton build does not expose legacy PROTON_ENABLE_HDR support.");
                case LaunchOptionCapability.PROTON_AUTO_HDR_CONTROL: return _("The selected Proton build does not expose automatic-HDR opt-out support.");
                case LaunchOptionCapability.PROTON_FSR4: return _("The selected Proton build does not expose PROTON_FSR4_UPGRADE support.");
                case LaunchOptionCapability.PROTON_FSR4_RDNA3: return _("The selected Proton build does not expose the legacy RDNA3 FSR 4 switch.");
                case LaunchOptionCapability.PROTON_MLFG: return _("The selected Proton build does not expose PROTON_MLFG_UPGRADE support.");
                case LaunchOptionCapability.PROTON_DXVK_LOW_LATENCY: return _("The selected Proton build does not expose its DXVK low-latency option.");
                case LaunchOptionCapability.PROTON_VKD3D_LOW_LATENCY: return _("The selected Proton build does not expose its VKD3D-Proton low-latency option.");
                case LaunchOptionCapability.LOW_LATENCY_LAYER: return _("The selected Proton build does not expose the low-latency Vulkan layer.");
                case LaunchOptionCapability.VULKAN_REFLEX_LAYER: return _("The selected Proton build does not expose its Vulkan Reflex layer.");
                case LaunchOptionCapability.PROTON_LOCAL_SHADER_CACHE: return _("The selected Proton build does not expose a per-game shader cache switch.");
                case LaunchOptionCapability.PROTON_D7VK: return _("The selected Proton build does not expose a D7VK switch.");
                case LaunchOptionCapability.PROTON_OPTISCALER: return _("The selected Proton build does not expose an OptiScaler switch.");
                default: return _("Not supported by the selected compatibility tool.");
            }
        }
    }

    class LaunchOptionToolProbe : Object {
        HashMap<string, Bytes?> files = new HashMap<string, Bytes?> ();

        public bool all_support (Set<string> paths, LaunchOptionToolFeatureRule rule, string key) {
            foreach (var path in paths) {
                if (!supports (path, rule, key))
                    return false;
            }
            return true;
        }

        bool supports (string path, LaunchOptionToolFeatureRule rule, string key) {
            if (rule.required_directory != null && !FileUtils.test (Path.build_filename (path, rule.required_directory), FileTest.IS_DIR))
                return false;
            if (rule.executable_path != null)
                return native_binary_contains (Path.build_filename (path, rule.executable_path), key);
            if (rule.binaries.length > 0)
                return binary_contains (path, rule.binaries, key);
            if (rule.source_path == null)
                return false;
            if (script_reads (Path.build_filename (path, rule.source_path), key, rule.integration_table))
                return true;
            // The HEVC defaults wrapper dispatches to the original Proton launcher.
            return rule.source_path == "proton"
                && script_reads (Path.build_filename (path, "proton"), "PROTON_HEVC_DEFAULTS", false)
                && script_reads (Path.build_filename (path, "proton-original"), key, false);
        }

        bool script_reads (string path, string key, bool integration_table) {
            var launcher = read_file (path, 2 * 1024 * 1024);
            if (launcher == null)
                return false;
            try {
                var quoted = "[\"']%s[\"']".printf (Regex.escape_string (key));
                var call = "\\b(?:check_environment|getenv|(?:env|environ)\\.get)\\(\\s*" + quoted + "\\s*[,)]";
                var lookup = "\\b(?:env|environ)\\[\\s*" + quoted + "\\s*\\](?![ \\t]*=(?!=))";
                // Skip Python comments and strings before looking for environment reads.
                var skip = """(?:#[^\r\n]*|(?s:'{3}.*?'{3}|"{3}.*?"{3})|'(?:\\.|[^'\\\r\n])*'|"(?:\\.|[^"\\\r\n])*")(*SKIP)(*F)|""";
                var pattern = skip + call + "|" + lookup;
                if (integration_table)
                    pattern = "(?m)^[ \\t]*(?:['\"]env_var['\"][ \\t]*:|env_var[ \\t]*=)[ \\t]*" + quoted;
                var matcher = new Regex (pattern, RegexCompileFlags.RAW);
                return matcher.match_full ((string) launcher.get_data (), (ssize_t) launcher.get_size ());
            } catch (RegexError error) {
                return false;
            }
        }

        bool native_binary_contains (string path, string key) {
            var binary = read_file (path, 128 * 1024 * 1024);
            if (binary == null || binary.get_size () < 4)
                return false;
            unowned uint8[] data = binary.get_data ();
            if (data[0] != '\x7f' || data[1] != 'E' || data[2] != 'L' || data[3] != 'F')
                return false;
            // Rust string slices in these launchers need no NUL terminator.
            try {
                var marker = new Regex (Regex.escape_string (key) + "(?!_)", RegexCompileFlags.RAW);
                return marker.match_full ((string) data, (ssize_t) binary.get_size ());
            } catch (RegexError error) {
                return false;
            }
        }

        bool binary_contains (string path, string[] binaries, string key) {
            try {
                var marker = new Regex ("\\x00" + Regex.escape_string (key) + "\\x00",
                    RegexCompileFlags.RAW);
                foreach (var root in new string[] { "files", "dist" }) {
                    foreach (var relative_path in binaries) {
                        var binary = read_file (Path.build_filename (path, root, relative_path), 128 * 1024 * 1024);
                        if (binary == null || binary.get_size () < 4)
                            continue;
                        unowned uint8[] data = binary.get_data ();
                        bool elf = data[0] == '\x7f' && data[1] == 'E' && data[2] == 'L' && data[3] == 'F';
                        bool pe = data[0] == 'M' && data[1] == 'Z';
                        if ((elf || pe) && marker.match_full ((string) data, (ssize_t) binary.get_size ()))
                            return true;
                    }
                }
            } catch (RegexError error) {
                return false;
            }
            return false;
        }

        Bytes? read_file (string path, size_t limit) {
            if (!files.has_key (path))
                files.set (path, read_regular_file (path, limit));
            return files.get (path);
        }

        Bytes? read_regular_file (string path, size_t limit) {
            var fd = Posix.open (path, Posix.O_RDONLY | Posix.O_CLOEXEC | Posix.O_NONBLOCK);
            if (fd < 0)
                return null;

            // Installed builds can link shared DLLs or swap files during an update.
            var stream = new UnixInputStream (fd, true);
            Posix.Stat info;
            if (Posix.fstat (fd, out info) != 0 || !Posix.S_ISREG (info.st_mode)
                || info.st_size <= 0 || info.st_size > limit)
                return null;

            var buffer = new uint8[(int) info.st_size];
            try {
                size_t size;
                if (stream.read_all (buffer, out size) && size == buffer.length)
                    return new Bytes.take ((owned) buffer);
            } catch (Error error) {
                // Ignore files that disappeared or became unreadable during inspection.
            }
            return null;
        }
    }
}
