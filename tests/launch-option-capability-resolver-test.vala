namespace AppTests.LaunchOptionCapabilityResolverTest {
    using GLib;
    using Gee;
    using ProtonPlus.Models;
    using ProtonPlus.Utils;
    using ProtonPlus.LaunchOptions;
    using ProtonPlus.Widgets.Games.LaunchOptionsEditor;

    private class ActiveOption : Object, ILaunchOption {
        public LaunchLineType line_type { get; set; default = LaunchLineType.ENVIRONMENT; }
        public bool is_advanced { get; set; default = false; }
        public bool active { get; set; default = false; }
        public void add_child (ILaunchOption child) {}
        public void parse_tokens (string[] tokens, bool[] consumed) {}
        public void clear () { active = false; }
        public void append_command_segments (LinkedList<string> segments) {}
        public bool is_active () { return active; }
    }

    public void register_tests () {
        Test.add_func ("/launch-option-capabilities/runtime-and-components", test_runtime_and_components);
        Test.add_func ("/launch-option-capabilities/eligibility-and-presentation", test_eligibility_and_presentation);
        Test.add_func ("/launch-option-capabilities/variant-specific-policy", test_variant_specific_policy);
        Test.add_func ("/launch-option-capabilities/installed-tool-feature-intersection", test_installed_tool_feature_intersection);
        Test.add_func ("/launch-option-capabilities/launcher-feature-intersection", test_launcher_feature_intersection);
        Test.add_func ("/launch-option-capabilities/runtime-control-intersection", test_runtime_control_intersection);
        Test.add_func ("/launch-option-capabilities/standalone-tool-controls", test_standalone_tool_controls);
        Test.add_func ("/launch-option-capabilities/build-specific-environment-keys", test_build_specific_environment_keys);
        Test.add_func ("/launch-option-capabilities/writer-preserves-active-unavailable", test_writer_preserves_active_unavailable);
    }

    private LaunchOptionInstalledComponents components (bool installed = false) {
        return new LaunchOptionInstalledComponents (
            installed, installed, installed, installed, installed, installed, installed
        );
    }

    private void test_runtime_and_components () {
        var resolver = new LaunchOptionCapabilityResolver ();
        var proton = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true, components (true), GpuVendor.AMD);
        assert (proton.has (LaunchOptionCapability.STEAM));
        assert (proton.has (LaunchOptionCapability.PROTON));
        assert (proton.has (LaunchOptionCapability.DXVK));
        assert (proton.has (LaunchOptionCapability.VKD3D_PROTON));
        assert (proton.has (LaunchOptionCapability.MANGOHUD));
        assert (proton.has (LaunchOptionCapability.GAMESCOPE));
        assert (proton.has (LaunchOptionCapability.VKBASALT));
        assert (proton.has (LaunchOptionCapability.GAME_PERFORMANCE));
        assert (proton.has (LaunchOptionCapability.OBS_VKCAPTURE));
        assert (proton.has (LaunchOptionCapability.AMD));

        var native = resolver.resolve ({ CompatibilityToolRuntimeKind.NATIVE }, true, components (), GpuVendor.NVIDIA);
        assert (native.has (LaunchOptionCapability.NATIVE_LINUX));
        assert (!native.has (LaunchOptionCapability.PROTON));
        assert (!native.has (LaunchOptionCapability.DXVK));
        assert (native.has (LaunchOptionCapability.NVIDIA));

        var unknown = resolver.resolve ({ CompatibilityToolRuntimeKind.UNKNOWN }, true, components (), GpuVendor.UNKNOWN);
        assert (!unknown.has (LaunchOptionCapability.PROTON));
        assert (!unknown.has (LaunchOptionCapability.DXVK));
        assert (!unknown.has (LaunchOptionCapability.VKD3D_PROTON));

        var mixed = resolver.resolve ({ CompatibilityToolRuntimeKind.NATIVE, CompatibilityToolRuntimeKind.PROTON }, true,
            components (), GpuVendor.INTEL);
        assert (!mixed.has (LaunchOptionCapability.NATIVE_LINUX));
        assert (!mixed.has (LaunchOptionCapability.PROTON));
        assert (mixed.has (LaunchOptionCapability.INTEL));

        assert (resolver.runtime_for_tool (new CompatibilityTool ("Default", "Default"))
            == CompatibilityToolRuntimeKind.PROTON);
        assert (resolver.runtime_for_tool (new CompatibilityTool ("Steam Linux Runtime 3.0"))
            == CompatibilityToolRuntimeKind.NATIVE);
        assert (resolver.runtime_for_tool (new CompatibilityTool ("Custom", "custom"))
            == CompatibilityToolRuntimeKind.UNKNOWN);
    }

    private void test_eligibility_and_presentation () {
        var catalog = new LaunchOptionCatalog ();
        var resolver = new LaunchOptionCapabilityResolver (catalog);
        var proton = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true, components (), GpuVendor.UNKNOWN);
        var native = resolver.resolve ({ CompatibilityToolRuntimeKind.NATIVE }, true, components (), GpuVendor.UNKNOWN);
        var wined3d = catalog.lookup ("wined3d");
        assert (wined3d != null);
        assert (resolver.evaluate (wined3d, proton).kind == LaunchOptionEligibilityKind.AVAILABLE);
        var inactive = resolver.evaluate (wined3d, native);
        assert (inactive.kind == LaunchOptionEligibilityKind.UNAVAILABLE_RUNTIME);
        assert (!inactive.show_when_inactive);
        var active = resolver.evaluate (wined3d, native, true);
        assert (active.keep_visible_when_active);
        assert (!active.may_activate);
        assert (active.reason.contains ("selected compatibility tool"));

        var unsupported = catalog.lookup ("dxvk-frame-limit");
        assert (unsupported != null);
        assert (resolver.evaluate (unsupported, proton).kind == LaunchOptionEligibilityKind.UNSUPPORTED);

        var overlay = catalog.lookup ("performance-overlay");
        assert (overlay != null);
        assert (resolver.evaluate (overlay, native).kind == LaunchOptionEligibilityKind.UNAVAILABLE_COMPONENT);
        string[] missing_components = { "gamemode", "launch-backend", "vkbasalt" };
        foreach (var id in missing_components) {
            var option = catalog.lookup (id);
            assert (option != null);
            assert (resolver.evaluate (option, native).kind == LaunchOptionEligibilityKind.UNAVAILABLE_COMPONENT);
        }
        var presentations = new LaunchOptionPresentationRegistry (catalog);
        var option = new ActiveOption ();
        presentations.register ("wined3d", null, option);
        presentations.apply_filter (LaunchOptionView.ALL, "", resolver, native);
        assert (!presentations.has_visible_in_category (LaunchOptionCategory.PROTON));
        assert (!presentations.has_presentable_in_category (LaunchOptionCategory.PROTON));
        option.active = true;
        presentations.apply_filter (LaunchOptionView.ACTIVE, "", resolver, native);
        assert (presentations.has_visible_in_category (LaunchOptionCategory.PROTON));
        assert (presentations.lookup ("wined3d").eligibility.keep_visible_when_active);
    }

    private void test_variant_specific_policy () {
        var catalog = new LaunchOptionCatalog ();
        var resolver = new LaunchOptionCapabilityResolver (catalog);
        var proton_amd = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true, components (), GpuVendor.AMD);
        var proton_nvidia = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true, components (), GpuVendor.NVIDIA);
        var proton_intel = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true, components (), GpuVendor.INTEL);
        var proton_unknown_gpu = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true, components (), GpuVendor.UNKNOWN);
        var native_amd = resolver.resolve ({ CompatibilityToolRuntimeKind.NATIVE }, true, components (), GpuVendor.AMD);
        var unknown_amd = resolver.resolve ({ CompatibilityToolRuntimeKind.UNKNOWN }, true, components (), GpuVendor.AMD);

        string[] proton_variants = {
            "discord-bridge"
        };
        foreach (var id in proton_variants) {
            var metadata = catalog.lookup (id);
            assert (metadata != null);
            var eligibility = resolver.evaluate (metadata, proton_amd);
            assert (eligibility.kind == LaunchOptionEligibilityKind.VARIANT_SELECTABLE_WITH_WARNING);
            assert (eligibility.may_activate && eligibility.may_modify && eligibility.show_when_inactive);
            assert (eligibility.reason == "Requires a compatible Proton variant.");
            assert (!resolver.evaluate (metadata, native_amd).show_when_inactive);
            assert (!resolver.evaluate (metadata, unknown_amd).show_when_inactive);
        }

        string[] amd_documented_features = { "amd-fsr4", "amd-fsr4-rdna3", "amd-mlfg" };
        foreach (var id in amd_documented_features) {
            var metadata = catalog.lookup (id);
            assert (metadata != null);
            assert (resolver.evaluate (metadata, proton_amd).kind
                == LaunchOptionEligibilityKind.UNAVAILABLE_RUNTIME);
            assert (resolver.evaluate (metadata, proton_unknown_gpu).kind
                == LaunchOptionEligibilityKind.UNAVAILABLE_HARDWARE);
            assert (resolver.evaluate (metadata, native_amd).kind
                == LaunchOptionEligibilityKind.UNAVAILABLE_RUNTIME);
        }

        string[] nvidia_variants = { "nvidia-dlss-updater", "nvidia-dlss-indicator", "nvidia-libraries" };
        foreach (var id in nvidia_variants) {
            var metadata = catalog.lookup (id);
            assert (metadata != null);
            assert (resolver.evaluate (metadata, proton_nvidia).kind
                == LaunchOptionEligibilityKind.VARIANT_SELECTABLE_WITH_WARNING);
            assert (resolver.evaluate (metadata, proton_unknown_gpu).kind
                == LaunchOptionEligibilityKind.UNAVAILABLE_HARDWARE);
        }
        var xess = catalog.lookup ("intel-xess");
        assert (xess != null);
        assert (resolver.evaluate (xess, proton_intel).kind
            == LaunchOptionEligibilityKind.VARIANT_SELECTABLE_WITH_WARNING);
        assert (resolver.evaluate (xess, proton_unknown_gpu).kind
            == LaunchOptionEligibilityKind.UNAVAILABLE_HARDWARE);

        var dxvk_async = catalog.lookup ("dxvk-async");
        assert (dxvk_async != null);
        assert (resolver.evaluate (dxvk_async, proton_amd).kind == LaunchOptionEligibilityKind.LEGACY_ACTIVE_ONLY);
        string[] inactive_only = {
            "dxvk-frame-limit", "nvidia-nvapi", "raw-launch-options", "steam-command"
        };
        foreach (var id in inactive_only) {
            var metadata = catalog.lookup (id);
            assert (metadata != null);
            assert (!resolver.evaluate (metadata, proton_amd).may_activate);
        }

        var presentations = new LaunchOptionPresentationRegistry (catalog);
        var discord = new ActiveOption ();
        presentations.register ("discord-bridge", null, discord);
        presentations.apply_filter (LaunchOptionView.ALL, "", resolver, proton_amd);
        assert (presentations.lookup ("discord-bridge").currently_visible);
        assert (presentations.has_presentable_in_category (LaunchOptionCategory.PROTON));
        presentations.apply_filter (LaunchOptionView.ALL, "Discord", resolver, proton_amd);
        assert (presentations.lookup ("discord-bridge").currently_visible);
        presentations.apply_filter (LaunchOptionView.PROTON, "", resolver, native_amd);
        assert (!presentations.lookup ("discord-bridge").currently_visible);
        assert (!presentations.has_presentable_in_category (LaunchOptionCategory.PROTON));
        discord.active = true;
        presentations.apply_filter (LaunchOptionView.ACTIVE, "", resolver, native_amd);
        assert (presentations.lookup ("discord-bridge").currently_visible);
    }

    private void test_installed_tool_feature_intersection () {
        var common_reads = """
self.check_environment("PROTON_FSR4_UPGRADE", "fsr4")
self.check_environment("PROTON_DXVK_LOWLATENCY", "dxvklowlatency")
self.check_environment("LOW_LATENCY_LAYER", "lowlatencylayer")
""";
        var first_path = create_tool_fixture ("", common_reads + """
self.check_environment("PROTON_ENABLE_HDR", "hdr")
self.check_environment("PROTON_FSR4_RDNA3_UPGRADE", "fsr4rdna3")
self.check_environment("PROTON_MLFG_UPGRADE", "mlfg")
self.check_environment("PROTON_VKD3D_LOWLATENCY", "vkd3dlowlatency")
self.check_environment("DXVK_NVAPI_VKREFLEX", "vkreflex")
""");
        var second_path = create_tool_fixture (
            "PROTON_ENABLE_HDR DXVK_HDR DXVK_NO_HDR PROTON_FSR4_RDNA3_UPGRADE",
            common_reads + "# self.check_environment('PROTON_FSR4_RDNA3_UPGRADE', 'fsr4rdna3')"
        );
        var suffix_only_path = create_tool_fixture ("LOW_LATENCY_LAYER",
            "self.check_environment('LOW_LATENCY_LAYER_REFLEX', 'reflex')");
        write_probe_binary (first_path, "files/lib/wine/dxvk/x86_64-windows/dxgi.dll",
            "MZ", { "DXVK_HDR", "DXVK_NO_HDR" });
        var first = new CompatibilityTool (
            "Current custom Proton", "current", first_path, CompatibilityToolRuntimeKind.PROTON
        );
        var second = new CompatibilityTool (
            "Older custom Proton", "older", second_path, CompatibilityToolRuntimeKind.PROTON
        );
        var resolver = new LaunchOptionCapabilityResolver ();

        var current = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true,
            components (), GpuVendor.AMD, { first });
        assert (current.has (LaunchOptionCapability.LEGACY_PROTON_HDR));
        assert (current.has (LaunchOptionCapability.PROTON_AUTO_HDR_CONTROL));
        assert (current.has (LaunchOptionCapability.PROTON_DXVK_HDR));
        assert (current.has (LaunchOptionCapability.PROTON_FSR4));
        assert (current.has (LaunchOptionCapability.PROTON_FSR4_RDNA3));
        assert (current.has (LaunchOptionCapability.PROTON_MLFG));
        assert (current.has (LaunchOptionCapability.PROTON_DXVK_LOW_LATENCY));
        assert (current.has (LaunchOptionCapability.PROTON_VKD3D_LOW_LATENCY));
        assert (current.has (LaunchOptionCapability.LOW_LATENCY_LAYER));
        assert (current.has (LaunchOptionCapability.VULKAN_REFLEX_LAYER));

        var host_mapped = new CompatibilityTool (
            "Host mapped Proton", "host-mapped",
            "/usr/share/steam/compatibilitytools.d/HostMapped",
            CompatibilityToolRuntimeKind.PROTON, first_path, true
        );
        var host_mapped_context = resolver.resolve (
            { CompatibilityToolRuntimeKind.PROTON }, true,
            components (), GpuVendor.AMD, { host_mapped }
        );
        assert (host_mapped_context.has (LaunchOptionCapability.PROTON_FSR4));
        assert (host_mapped_context.has (LaunchOptionCapability.PROTON_MLFG));

        var steam = new ProtonPlus.Models.Launchers.Steam (
            ProtonPlus.Models.Launcher.InstallationTypes.SNAP
        );
        steam.compatibility_tools.clear ();
        steam.register_compatibility_tool (first);
        steam.default_compatibility_tool = first.internal_title;
        var effective_default = steam.resolve_effective_compatibility_tool ("Default");
        assert (effective_default == first);
        var default_context = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true,
            components (), GpuVendor.AMD, { (!) effective_default });
        assert (default_context.has (LaunchOptionCapability.PROTON_FSR4));
        assert (default_context.has (LaunchOptionCapability.PROTON_MLFG));
        assert (default_context.has (LaunchOptionCapability.PROTON_VKD3D_LOW_LATENCY));

        var intersection = resolver.resolve (
            { CompatibilityToolRuntimeKind.PROTON, CompatibilityToolRuntimeKind.PROTON },
            true, components (), GpuVendor.AMD, { first, second }
        );
        assert (intersection.has (LaunchOptionCapability.PROTON_FSR4));
        assert (intersection.has (LaunchOptionCapability.PROTON_DXVK_LOW_LATENCY));
        assert (intersection.has (LaunchOptionCapability.LOW_LATENCY_LAYER));
        assert (!intersection.has (LaunchOptionCapability.LEGACY_PROTON_HDR));
        assert (!intersection.has (LaunchOptionCapability.PROTON_AUTO_HDR_CONTROL));
        assert (!intersection.has (LaunchOptionCapability.PROTON_DXVK_HDR));
        assert (!intersection.has (LaunchOptionCapability.PROTON_FSR4_RDNA3));
        assert (!intersection.has (LaunchOptionCapability.PROTON_MLFG));
        assert (!intersection.has (LaunchOptionCapability.PROTON_VKD3D_LOW_LATENCY));
        assert (!intersection.has (LaunchOptionCapability.VULKAN_REFLEX_LAYER));

        var suffix_only = new CompatibilityTool (
            "Suffix-only marker", "suffix", suffix_only_path,
            CompatibilityToolRuntimeKind.PROTON
        );
        var exact_markers = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true,
            components (), GpuVendor.AMD, { suffix_only });
        assert (!exact_markers.has (LaunchOptionCapability.LOW_LATENCY_LAYER));

        var catalog = new LaunchOptionCatalog ();
        assert (resolver.evaluate (catalog.lookup ("amd-fsr4"), intersection).kind
            == LaunchOptionEligibilityKind.AVAILABLE);
        assert (resolver.evaluate (catalog.lookup ("amd-mlfg"), intersection).kind
            == LaunchOptionEligibilityKind.UNAVAILABLE_RUNTIME);

        remove_probe_binary (first_path, "files/lib/wine/dxvk/x86_64-windows/dxgi.dll");
        remove_tool_fixture (first_path);
        remove_tool_fixture (second_path);
        remove_tool_fixture (suffix_only_path);
    }

    private void test_launcher_feature_intersection () {
        var anime_path = create_tool_fixture ("", """
g_session.check_environment("PROTON_LOCAL_SHADER_CACHE", "localshadercache")
g_session.check_environment("PROTON_USE_OPTISCALER", "optiscaler")
g_compatdata.setup_ddraw("PROTON_USE_D7VK" in g_session.env
        and nonzero(g_session.env["PROTON_USE_D7VK"]))
""");
        var generic_path = create_tool_fixture (
            "PROTON_LOCAL_SHADER_CACHE PROTON_USE_D7VK PROTON_USE_OPTISCALER PROTON_PRIORITY_HIGH",
            "# g_session.check_environment(\"PROTON_USE_D7VK\", \"d7vk\")\n"
            + "log(\"PROTON_USE_OPTISCALER\")\n"
            + "self.env[\"PROTON_LOCAL_SHADER_CACHE\"] = \"1\"\n"
            + "log('self.check_environment(\"PROTON_USE_D7VK\", \"d7vk\")')\n"
        );
        var anime = new CompatibilityTool ("Custom build", "a", anime_path, CompatibilityToolRuntimeKind.PROTON);
        var generic = new CompatibilityTool ("Custom build", "b", generic_path, CompatibilityToolRuntimeKind.PROTON);
        var catalog = new LaunchOptionCatalog ();
        var resolver = new LaunchOptionCapabilityResolver (catalog);
        var supported = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true,
            components (), GpuVendor.UNKNOWN, { anime });
        var generic_context = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true,
            components (), GpuVendor.UNKNOWN, { generic });
        var mixed = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON, CompatibilityToolRuntimeKind.PROTON },
            true, components (), GpuVendor.UNKNOWN, { anime, generic });
        var incomplete = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON, CompatibilityToolRuntimeKind.PROTON },
            true, components (), GpuVendor.UNKNOWN, { anime });
        foreach (var id in new string[] { "per-game-shader-cache", "d7vk", "optiscaler" }) {
            var option = catalog.lookup (id);
            assert (resolver.evaluate (option, supported).may_activate);
            assert (!resolver.evaluate (option, generic_context).may_activate);
            assert (!resolver.evaluate (option, mixed).may_activate);
            assert (!resolver.evaluate (option, incomplete).may_activate);
        }
        var priority = catalog.lookup ("high-process-priority");
        assert (!resolver.evaluate (priority, generic_context).may_activate);
        assert (resolver.evaluate (priority, generic_context, true).keep_visible_when_active);
        remove_tool_fixture (anime_path);
        remove_tool_fixture (generic_path);
    }

    private void test_build_specific_environment_keys () {
        const string ALSA = "files/lib/wine/x86_64-unix/winealsa.so";
        var current_path = create_tool_fixture ("WINEALSA_SPACIAL", """
self.check_environment("PROTON_D7VK_DDRAW", "d7vkddraw")
self.check_environment("PROTON_USE_HDR", "hdr")
""");
        var older_path = create_tool_fixture ("WINEALSA_SPATIAL", """
self.check_environment("PROTON_USE_D7VK", "d7vk")
""");
        write_probe_binary (current_path, ALSA, "\x7f" + "ELF", { "WINEALSA_CHANNELS", "WINEALSA_SPATIAL" });
        // Synthetic build to exercise fallback if an installed driver really consumes the older spelling.
        write_probe_binary (older_path, ALSA, "\x7f" + "ELF", { "WINEALSA_CHANNELS", "WINEALSA_SPACIAL" });
        var current = new CompatibilityTool ("Custom", "current", current_path, CompatibilityToolRuntimeKind.PROTON);
        var older = new CompatibilityTool ("Custom", "older", older_path, CompatibilityToolRuntimeKind.PROTON);
        var resolver = new LaunchOptionCapabilityResolver ();
        var current_context = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true, components (),
            GpuVendor.AMD, { current });
        var older_context = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON }, true, components (),
            GpuVendor.AMD, { older });
        var mixed_context = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON, CompatibilityToolRuntimeKind.PROTON },
            true, components (), GpuVendor.AMD, { current, older });
        assert (current_context.has (LaunchOptionCapability.WINEALSA_CHANNELS));
        assert (mixed_context.has (LaunchOptionCapability.WINEALSA_CHANNELS));
        assert (!mixed_context.has (LaunchOptionCapability.WINEALSA_SPATIAL));
        assert (!mixed_context.has (LaunchOptionCapability.PROTON_D7VK));

        var writer = new LaunchCommandWriter ();
        LaunchCommandSelection[] audio = {
            new LaunchCommandSelection ("winealsa-channels", { "4" }),
            new LaunchCommandSelection ("winealsa-spatial")
        };
        var write = writer.prepare_source ("", audio, { "winealsa-channels", "winealsa-spatial" }, {}, current_context);
        assert (write.writing_allowed && write.launch_line == "WINEALSA_CHANNELS=4 WINEALSA_SPATIAL=1 %command%");
        write = writer.prepare_source ("", audio, { "winealsa-channels", "winealsa-spatial" }, {}, older_context);
        assert (write.writing_allowed && write.launch_line == "WINEALSA_CHANNELS=4 WINEALSA_SPACIAL=1 %command%");

        write = writer.prepare_source ("", { new LaunchCommandSelection ("d7vk"), new LaunchCommandSelection ("proton-hdr") },
            { "d7vk", "proton-hdr" }, {}, current_context);
        assert (write.writing_allowed && write.launch_line == "PROTON_D7VK_DDRAW=1 PROTON_USE_HDR=1 %command%");
        var saved = "WINEALSA_SPACIAL='1' AMD_ICD=AMDVLK %command%";
        write = writer.prepare_source (saved, { new LaunchCommandSelection ("d7vk") }, { "d7vk" }, {}, current_context);
        assert (write.writing_allowed && write.launch_line == "WINEALSA_SPACIAL='1' AMD_ICD=AMDVLK PROTON_D7VK_DDRAW=1 %command%");
        write = writer.prepare_source (saved, {}, { "winealsa-spatial", "amd-vulkan-driver" }, {}, current_context);
        assert (write.writing_allowed && write.launch_line == "");

        var catalog = new LaunchOptionCatalog ();
        var driver = catalog.lookup ("amd-vulkan-driver");
        assert (!resolver.evaluate (driver, current_context).may_activate);
        assert (resolver.evaluate (driver, current_context, true).keep_visible_when_active);
        var with_switcher = resolver.resolve ({ CompatibilityToolRuntimeKind.NATIVE }, true,
            new LaunchOptionInstalledComponents (false, false, false, false, false, false, false, true, true), GpuVendor.AMD);
        assert (resolver.evaluate (driver, with_switcher).may_activate);
        assert (resolver.evaluate (catalog.lookup ("obs-gamecapture"), with_switcher).may_activate);
        assert (!resolver.evaluate (catalog.lookup ("obs-vkcapture"), with_switcher).may_activate);

        remove_probe_binary (current_path, ALSA);
        remove_probe_binary (older_path, ALSA);
        remove_tool_fixture (current_path);
        remove_tool_fixture (older_path);
    }

    private void test_runtime_control_intersection () {
        var common = "self.check_environment('PROTON_NO_FSYNC', 'nofsync')\n"
            + "self.check_environment('PROTON_USE_SDL', 'sdlinput')\n";
        var current_path = create_tool_fixture ("", common
            + "self.check_environment('PROTON_NO_NTSYNC', 'nontsync')\n"
            + "self.check_environment('PROTON_USE_OPTISCALER', 'optiscaler')\n");
        var previous_path = create_tool_fixture ("", common + "# PROTON_SHADER_CACHE\n");
        const string DXVK = "files/lib/wine/dxvk/x86_64-windows/d3d11.dll";
        const string DXGI = "files/lib/wine/dxvk/x86_64-windows/dxgi.dll";
        const string VKD3D = "files/lib/wine/vkd3d-proton/x86_64-windows/d3d12core.dll";
        write_probe_binary (current_path, DXGI, "MZ", { "dxvk.maxFrameRate" });
        write_probe_binary (current_path, DXVK, "MZ", { "DXVK_SHADER_CACHE" });
        write_probe_binary (previous_path, DXVK, "MZ", { "DXVK_FRAME_RATE", "NOT_DXVK_SHADER_CACHE" });
        write_probe_binary (current_path, VKD3D, "MZ", { "VKD3D_FRAME_RATE" });
        write_probe_binary (previous_path, VKD3D, "MZ", { "VKD3D_FRAME_RATE" });
        var current = new CompatibilityTool ("Current", "current", current_path, CompatibilityToolRuntimeKind.PROTON);
        var previous = new CompatibilityTool ("Previous", "previous", previous_path, CompatibilityToolRuntimeKind.PROTON);
        var catalog = new LaunchOptionCatalog ();
        var resolver = new LaunchOptionCapabilityResolver (catalog);
        var single = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON },
            true, components (), GpuVendor.UNKNOWN, { current });
        var mixed = resolver.resolve ({ CompatibilityToolRuntimeKind.PROTON, CompatibilityToolRuntimeKind.PROTON },
            true, components (), GpuVendor.UNKNOWN, { current, previous });
        foreach (var id in new string[] { "ntsync-mode", "optiscaler", "dxvk-config-frame-limit", "dxvk-disable-shader-cache" }) {
            var option = catalog.lookup (id);
            assert (resolver.evaluate (option, single).may_modify);
            assert (!resolver.evaluate (option, mixed).show_when_inactive);
        }
        assert (!resolver.evaluate (catalog.lookup ("discord-bridge"), mixed).show_when_inactive);
        foreach (var id in new string[] { "proton-fsync", "vkd3d-frame-limit", "prefer-sdl" })
            assert (resolver.evaluate (catalog.lookup (id), mixed).may_modify);
        var writer = new LaunchCommandWriter ();
        var optiscaler = new LaunchCommandSelection ("optiscaler", { "v0.9.0" });
        var pinned = writer.prepare_source ("", { optiscaler }, { optiscaler.option_id }, {}, single);
        assert (pinned.writing_allowed && pinned.launch_line == "PROTON_USE_OPTISCALER=v0.9.0 %command%");
        var rejected = writer.prepare_source ("", { optiscaler }, { optiscaler.option_id }, {}, mixed);
        assert (rejected.status == LaunchCommandWriteStatus.BLOCKED_INVALID_SELECTIONS && !rejected.requires_persistence);

        string[] sources = {
            "PROTON_USE_OPTISCALER='v0.8.1' %command% --tag --tag",
            "LOCAL=\"keep spacing\" %command% --other"
        };
        string[] expected = {
            "PROTON_USE_OPTISCALER='v0.8.1' PROTON_USE_SDL=0 %command% --tag --tag",
            "LOCAL=\"keep spacing\" PROTON_USE_SDL=0 %command% --other"
        };
        for (var i = 0; i < sources.length; i++) {
            var written = writer.prepare_source (sources[i], { new LaunchCommandSelection ("prefer-sdl", { "0" }) },
                { "prefer-sdl" }, {}, mixed);
            assert (written.writing_allowed && written.launch_line == expected[i]);
        }
        remove_probe_binary (current_path, DXGI);
        remove_probe_binary (current_path, DXVK);
        remove_probe_binary (previous_path, DXVK);
        remove_probe_binary (current_path, VKD3D);
        remove_probe_binary (previous_path, VKD3D);
        remove_tool_fixture (current_path);
        remove_tool_fixture (previous_path);
    }

    private void test_standalone_tool_controls () {
        var lux_path = create_tool_fixture ("LUX_DISABLE_DEFAULT_CONFIRM LUX_WRITE_LOGGING");
        var roberta_path = create_tool_fixture ("");
        var empty_path = create_tool_fixture ("");
        const string LUX = "luxtorpeda.x86_64";
        write_probe_binary (lux_path, LUX, "\x7f" + "ELF", { "LUX_WRITE_LOGGING", "LUX_STEAM_CLOUD" });
        try {
            FileUtils.set_contents (Path.build_filename (roberta_path, "settings.py"),
                "cmd = os.environ.get('LUX_SCUMMVM_CMD', scummvm_cmd)\n"
                + "# os.environ.get('LUX_USE_SCREEN', screen)\n");
        } catch (FileError error) {
            assert_not_reached ();
        }
        var lux = new CompatibilityTool ("Tool A", "tool-a", lux_path);
        var roberta = new CompatibilityTool ("Tool B", "tool-b", roberta_path);
        var unverified = new CompatibilityTool ("Luxtorpeda", "luxtorpeda", empty_path);
        var resolver = new LaunchOptionCapabilityResolver ();
        var single = resolver.resolve ({ CompatibilityToolRuntimeKind.UNKNOWN }, true, components (),
            GpuVendor.UNKNOWN, { lux });
        assert (single.has (LaunchOptionCapability.LUX_LOGGING));
        assert (single.has (LaunchOptionCapability.LUX_CLOUD));
        assert (!single.has (LaunchOptionCapability.LUX_CONFIRM));
        var mixed = resolver.resolve ({ CompatibilityToolRuntimeKind.UNKNOWN, CompatibilityToolRuntimeKind.UNKNOWN },
            true, components (), GpuVendor.UNKNOWN, { lux, unverified });
        assert (!mixed.has (LaunchOptionCapability.LUX_LOGGING));
        var scummvm = resolver.resolve ({ CompatibilityToolRuntimeKind.UNKNOWN }, true, components (),
            GpuVendor.UNKNOWN, { roberta });
        assert (scummvm.has (LaunchOptionCapability.ROBERTA_COMMAND));
        assert (!scummvm.has (LaunchOptionCapability.ROBERTA_SCREEN));
        remove_probe_binary (lux_path, LUX);
        FileUtils.remove (Path.build_filename (roberta_path, "settings.py"));
        remove_tool_fixture (lux_path);
        remove_tool_fixture (roberta_path);
        remove_tool_fixture (empty_path);
    }

    private void write_probe_binary (string root, string relative_path, string header, string[] markers) {
        var path = Path.build_filename (root, relative_path);
        assert (DirUtils.create_with_parents (Path.get_dirname (path), 0700) == 0);
        var data = new StringBuilder (header);
        data.append_c ('\0');
        foreach (var marker in markers) {
            data.append (marker);
            data.append_c ('\0');
        }
        try {
            FileUtils.set_contents (path, data.str, (ssize_t) data.len);
        } catch (FileError error) {
            assert_not_reached ();
        }
    }

    private void remove_probe_binary (string root, string relative_path) {
        var path = Path.build_filename (root, relative_path);
        FileUtils.remove (path);
        for (var directory = Path.get_dirname (path); directory != root; directory = Path.get_dirname (directory))
            DirUtils.remove (directory);
    }

    private string create_tool_fixture (string documented_features, string? launcher = null) {
        string path;
        try {
            path = DirUtils.mkdtemp (Path.build_filename (
                Environment.get_tmp_dir (), "protonplus-launch-features-XXXXXX"
            ));
            FileUtils.set_contents (Path.build_filename (path, "README.md"), documented_features);
            if (launcher != null)
                FileUtils.set_contents (Path.build_filename (path, "proton"), launcher);
        } catch (FileError error) {
            assert_not_reached ();
        }
        return path;
    }

    private void remove_tool_fixture (string path) {
        FileUtils.remove (Path.build_filename (path, "README.md"));
        FileUtils.remove (Path.build_filename (path, "proton"));
        DirUtils.remove (path);
    }

    private void test_writer_preserves_active_unavailable () {
        var writer = new LaunchCommandWriter ();
        var native = new LaunchCommandCapabilityContext ({ LaunchOptionCapability.NATIVE_LINUX,
            LaunchOptionCapability.GAMEMODE });
        var preserved = writer.prepare_source ("PROTON_LOG=1 %command% --custom", {
            new LaunchCommandSelection ("gamemode")
        }, { "gamemode" }, {}, native);
        assert (preserved.writing_allowed);
        assert (preserved.launch_line == "PROTON_LOG=1 gamemoderun %command% --custom");

        var rejected = writer.prepare_source ("", { new LaunchCommandSelection ("wined3d") },
            { "wined3d" }, {}, native);
        assert (!rejected.writing_allowed);
        assert (rejected.status == LaunchCommandWriteStatus.BLOCKED_INVALID_SELECTIONS);
        assert (rejected.writer_diagnostics.size == 1);
        assert (rejected.writer_diagnostics[0].contains ("selected compatibility tool"));

        var proton = new LaunchCommandCapabilityContext ({ LaunchOptionCapability.PROTON,
            LaunchOptionCapability.PROTON_D7VK });
        var variant = writer.prepare_source ("", { new LaunchCommandSelection ("d7vk") },
            { "d7vk" }, {}, proton);
        assert (variant.writing_allowed);
        assert (variant.launch_line == "PROTON_USE_D7VK=1 %command%");

        var priority_source = "PROTON_PRIORITY_HIGH='1' TEST_ENV=original %command% --custom";
        var priority = writer.prepare_source (priority_source, { new LaunchCommandSelection ("gamemode") },
            { "gamemode" }, {}, native);
        assert (priority.launch_line == "PROTON_PRIORITY_HIGH='1' TEST_ENV=original gamemoderun %command% --custom");
        var new_priority = writer.prepare_source ("", { new LaunchCommandSelection ("high-process-priority") },
            { "high-process-priority" }, {}, proton);
        assert (!new_priority.writing_allowed);
        var removed_priority = writer.prepare_source (priority_source, {}, { "high-process-priority" }, {}, native);
        assert (removed_priority.writing_allowed);
        assert (removed_priority.launch_line == "TEST_ENV=original %command% --custom");

        var nvidia_proton = new LaunchCommandCapabilityContext ({
            LaunchOptionCapability.PROTON, LaunchOptionCapability.NVIDIA
        });
        var dlss_update = writer.prepare_source ("", {
            new LaunchCommandSelection ("nvidia-dlss-updater")
        }, { "nvidia-dlss-updater" }, {}, nvidia_proton);
        assert (dlss_update.writing_allowed);
        assert (dlss_update.launch_line == "PROTON_ENABLE_NGX_UPDATER=1 %command%");

        var legacy_nvapi = writer.prepare_source ("", {
            new LaunchCommandSelection ("nvidia-nvapi")
        }, { "nvidia-nvapi" }, {}, nvidia_proton);
        assert (!legacy_nvapi.writing_allowed);
        assert (legacy_nvapi.writer_diagnostics.size == 1);
        assert (legacy_nvapi.writer_diagnostics[0].contains ("legacy option"));

        var native_variant = writer.prepare_source ("", { new LaunchCommandSelection ("d7vk") },
            { "d7vk" }, {}, native);
        assert (!native_variant.writing_allowed);
        assert (native_variant.writer_diagnostics.size == 1);
        assert (native_variant.writer_diagnostics[0].contains ("D7VK"));

        var unknown_variant = writer.prepare_source ("", { new LaunchCommandSelection ("d7vk") },
            { "d7vk" }, {}, new LaunchCommandCapabilityContext ({ LaunchOptionCapability.STEAM }));
        assert (!unknown_variant.writing_allowed);
        assert (unknown_variant.writer_diagnostics.size == 1);
        assert (unknown_variant.writer_diagnostics[0].contains ("D7VK"));

        var unmanaged_variant = writer.prepare_source ("", { new LaunchCommandSelection ("dxvk-async") },
            { "dxvk-async" }, {}, proton);
        assert (!unmanaged_variant.writing_allowed);
        assert (unmanaged_variant.writer_diagnostics.size == 1);
        assert (unmanaged_variant.writer_diagnostics[0].contains ("legacy option"));

        var alsa = new LaunchCommandCapabilityContext ({
            LaunchOptionCapability.PROTON, LaunchOptionCapability.WINEALSA_CHANNELS, LaunchOptionCapability.WINEALSA_SPATIAL
        });
        var missing_dependency = writer.prepare_source ("", {
            new LaunchCommandSelection ("winealsa-spatial")
        }, { "winealsa-spatial" }, {}, alsa);
        assert (!missing_dependency.writing_allowed);
        assert (missing_dependency.composition_diagnostics.size == 1);
        assert (missing_dependency.composition_diagnostics[0].code
            == LaunchCommandCompositionDiagnosticCode.MISSING_DEPENDENCY);

        var with_dependency = writer.prepare_source ("", {
            new LaunchCommandSelection ("winealsa-channels", { "4" }),
            new LaunchCommandSelection ("winealsa-spatial")
        }, { "winealsa-channels", "winealsa-spatial" }, {}, alsa);
        assert (with_dependency.writing_allowed);
        assert (with_dependency.launch_line == "WINEALSA_CHANNELS=4 WINEALSA_SPATIAL=1 %command%");
    }
}
