namespace AppTests.SteamTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/steam/linux-runtime-detection", test_linux_runtime_detection);
        Test.add_func ("/steam/compatibility-tool-registration-deduplicates-and-sorts", test_compatibility_tool_registration);
    }

    private void test_linux_runtime_detection () {
        assert (ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("Steam Linux Runtime 1.0 (scout)"));
        assert (ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("Steam Linux Runtime 2.0 (soldier)"));
        assert (ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("steam linux runtime 3.0 (sniper)"));
        assert (ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("Runtime", "steamlinuxruntime_sniper"));
        assert (!ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("Proton 10.0"));
    }

    private void test_compatibility_tool_registration () {
        var steam = new ProtonPlus.Models.Launchers.Steam (
            ProtonPlus.Models.Launcher.InstallationTypes.SNAP
        );
        steam.compatibility_tools.clear ();

        steam.register_compatibility_tool (new ProtonPlus.Models.CompatibilityTool (
            "Proton 9.0", "proton_9", "/tools/proton-9"
        ));
        steam.register_compatibility_tool (new ProtonPlus.Models.CompatibilityTool (
            "Proton 10.0", "proton_10", "/tools/proton-10"
        ));
        steam.register_compatibility_tool (new ProtonPlus.Models.CompatibilityTool (
            "Duplicate path", "duplicate_path", "/tools/proton-10"
        ));
        steam.register_compatibility_tool (new ProtonPlus.Models.CompatibilityTool (
            "Duplicate internal title", "proton_10", "/tools/duplicate-internal"
        ));
        steam.register_compatibility_tool (new ProtonPlus.Models.CompatibilityTool (
            "Steam Linux Runtime 3.0", "steamlinuxruntime_sniper", "/tools/runtime"
        ));

        assert (steam.compatibility_tools.size == 3);
        assert (steam.compatibility_tools[0].display_title == "Proton 10.0");
        assert (steam.compatibility_tools[1].display_title == "Proton 9.0");
        assert (steam.compatibility_tools[2].display_title == "Steam Linux Runtime 3.0");
    }
}
