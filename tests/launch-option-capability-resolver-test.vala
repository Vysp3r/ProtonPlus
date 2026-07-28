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
        Test.add_func ("/launch-option-capabilities/writer-preserves-active-unavailable", test_writer_preserves_active_unavailable);
    }

    private LaunchOptionInstalledComponents components (bool installed = false) {
        return new LaunchOptionInstalledComponents (installed, installed, installed, installed, installed);
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
        var variant = catalog.lookup ("d7vk");
        assert (variant != null);
        assert (resolver.evaluate (variant, proton).kind == LaunchOptionEligibilityKind.LEGACY_ACTIVE_ONLY);

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
    }
}
