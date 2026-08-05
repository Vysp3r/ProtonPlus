namespace AppTests.LaunchOptionCapabilityResolverTest {
    using GLib;
    using Gee;
    using ProtonPlus.Models;
    using ProtonPlus.Utils;
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
        Test.add_func ("/launch-option-capabilities/documented-tool-feature-intersection", test_documented_tool_feature_intersection);
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
            "d7vk", "optiscaler", "discord-bridge", "winealsa-channels", "winealsa-spatial"
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
        var d7vk = new ActiveOption ();
        presentations.register ("d7vk", null, d7vk);
        presentations.apply_filter (LaunchOptionView.ALL, "", resolver, proton_amd);
        assert (presentations.lookup ("d7vk").currently_visible);
        assert (presentations.has_presentable_in_category (LaunchOptionCategory.PROTON));
        presentations.apply_filter (LaunchOptionView.ALL, "D7VK", resolver, proton_amd);
        assert (presentations.lookup ("d7vk").currently_visible);
        presentations.apply_filter (LaunchOptionView.PROTON, "", resolver, native_amd);
        assert (!presentations.lookup ("d7vk").currently_visible);
        assert (!presentations.has_presentable_in_category (LaunchOptionCategory.PROTON));
        d7vk.active = true;
        presentations.apply_filter (LaunchOptionView.ACTIVE, "", resolver, native_amd);
        assert (presentations.lookup ("d7vk").currently_visible);
    }

    private void test_documented_tool_feature_intersection () {
        var first_path = create_tool_fixture (
            "PROTON_ENABLE_HDR DXVK_NO_HDR PROTON_FSR4_UPGRADE PROTON_FSR4_RDNA3_UPGRADE "
            + "PROTON_MLFG_UPGRADE PROTON_DXVK_LOWLATENCY PROTON_VKD3D_LOWLATENCY "
            + "LOW_LATENCY_LAYER DXVK_NVAPI_VKREFLEX"
        );
        var second_path = create_tool_fixture (
            "PROTON_FSR4_UPGRADE PROTON_DXVK_LOWLATENCY LOW_LATENCY_LAYER"
        );
        var suffix_only_path = create_tool_fixture ("LOW_LATENCY_LAYER_REFLEX");
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
        assert (current.has (LaunchOptionCapability.PROTON_FSR4));
        assert (current.has (LaunchOptionCapability.PROTON_FSR4_RDNA3));
        assert (current.has (LaunchOptionCapability.PROTON_MLFG));
        assert (current.has (LaunchOptionCapability.PROTON_DXVK_LOW_LATENCY));
        assert (current.has (LaunchOptionCapability.PROTON_VKD3D_LOW_LATENCY));
        assert (current.has (LaunchOptionCapability.LOW_LATENCY_LAYER));
        assert (current.has (LaunchOptionCapability.VULKAN_REFLEX_LAYER));

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

        remove_tool_fixture (first_path);
        remove_tool_fixture (second_path);
        remove_tool_fixture (suffix_only_path);
    }

    private string create_tool_fixture (string documented_features) {
        string path;
        try {
            path = DirUtils.mkdtemp (Path.build_filename (
                Environment.get_tmp_dir (), "protonplus-launch-features-XXXXXX"
            ));
            FileUtils.set_contents (Path.build_filename (path, "README.md"), documented_features);
        } catch (FileError error) {
            assert_not_reached ();
        }
        return path;
    }

    private void remove_tool_fixture (string path) {
        FileUtils.remove (Path.build_filename (path, "README.md"));
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

        var proton = new LaunchCommandCapabilityContext ({ LaunchOptionCapability.PROTON });
        var variant = writer.prepare_source ("", { new LaunchCommandSelection ("d7vk") },
            { "d7vk" }, {}, proton);
        assert (variant.writing_allowed);
        assert (variant.launch_line == "PROTON_USE_D7VK=1 %command%");

        var native_variant = writer.prepare_source ("", { new LaunchCommandSelection ("d7vk") },
            { "d7vk" }, {}, native);
        assert (!native_variant.writing_allowed);
        assert (native_variant.writer_diagnostics.size == 1);
        assert (native_variant.writer_diagnostics[0].contains ("selected compatibility tool"));

        var unknown_variant = writer.prepare_source ("", { new LaunchCommandSelection ("d7vk") },
            { "d7vk" }, {}, new LaunchCommandCapabilityContext ({ LaunchOptionCapability.STEAM }));
        assert (!unknown_variant.writing_allowed);
        assert (unknown_variant.writer_diagnostics.size == 1);
        assert (unknown_variant.writer_diagnostics[0].contains ("selected compatibility tool"));

        var unmanaged_variant = writer.prepare_source ("", { new LaunchCommandSelection ("dxvk-async") },
            { "dxvk-async" }, {}, proton);
        assert (!unmanaged_variant.writing_allowed);
        assert (unmanaged_variant.writer_diagnostics.size == 1);
        assert (unmanaged_variant.writer_diagnostics[0].contains ("legacy option"));

        var missing_dependency = writer.prepare_source ("", {
            new LaunchCommandSelection ("winealsa-spatial")
        }, { "winealsa-spatial" }, {}, proton);
        assert (!missing_dependency.writing_allowed);
        assert (missing_dependency.composition_diagnostics.size == 1);
        assert (missing_dependency.composition_diagnostics[0].code
            == LaunchCommandCompositionDiagnosticCode.MISSING_DEPENDENCY);

        var with_dependency = writer.prepare_source ("", {
            new LaunchCommandSelection ("winealsa-channels", { "4" }),
            new LaunchCommandSelection ("winealsa-spatial")
        }, { "winealsa-channels", "winealsa-spatial" }, {}, proton);
        assert (with_dependency.writing_allowed);
        assert (with_dependency.launch_line == "WINEALSA_CHANNELS=4 WINEALSA_SPACIAL=1 %command%");
    }
}
