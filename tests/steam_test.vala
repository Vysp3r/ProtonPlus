namespace AppTests.SteamTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/steam/linux-runtime-detection", test_linux_runtime_detection);
        Test.add_func ("/steam/base-launcher-compatibility-tool-lifecycle-is-no-op", test_base_launcher_compatibility_tool_lifecycle);
        Test.add_func ("/steam/compatibility-tool-registration-deduplicates-and-sorts", test_compatibility_tool_registration);
        Test.add_func ("/steam/compatibility-tool-path-registration-loads-tool", test_compatibility_tool_path_registration);
    }

    private void test_linux_runtime_detection () {
        assert (ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("Steam Linux Runtime 1.0 (scout)"));
        assert (ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("Steam Linux Runtime 2.0 (soldier)"));
        assert (ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("steam linux runtime 3.0 (sniper)"));
        assert (ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("Runtime", "steamlinuxruntime_sniper"));
        assert (!ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("Proton 10.0"));
    }

    private void test_base_launcher_compatibility_tool_lifecycle () {
        var launcher = new ProtonPlus.Models.Launcher (
            "Fixture", ProtonPlus.Models.Launcher.InstallationTypes.SYSTEM, "", {}, "fixture"
        );

        launcher.register_compatibility_tool_from_path ("/tools/fixture");
        launcher.unregister_compatibility_tool_by_path ("/tools/fixture");
        assert (launcher.compatibility_tools.size == 0);
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

        steam.unregister_compatibility_tool_by_path ("/tools/proton-10");
        assert (steam.compatibility_tools.size == 2);
        assert (steam.compatibility_tools[0].display_title == "Proton 9.0");
        assert (steam.compatibility_tools[1].display_title == "Steam Linux Runtime 3.0");
    }

    private string temporary_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-steam-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create test directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private void test_compatibility_tool_path_registration () {
        var root = temporary_directory ();
        var path = Path.build_filename (root, "path-tool");
        assert (ProtonPlus.Utils.Filesystem.create_directory (path));
        var vdf = Path.build_filename (path, "compatibilitytool.vdf");
        ProtonPlus.Utils.Filesystem.create_file (
            vdf,
            "\"compat_tools\" // tools\n{\n  \"path_internal\" // Internal name of this tool\n  {\n    \"display_name\" \"Path Tool\"\n  }\n}\n"
        );
        var steam = new ProtonPlus.Models.Launchers.Steam (
            ProtonPlus.Models.Launcher.InstallationTypes.SNAP
        );
        steam.compatibility_tools.clear ();

        steam.register_compatibility_tool_from_path (path);
        assert (steam.compatibility_tools.size == 1);
        assert (steam.compatibility_tools[0].display_title == "Path Tool");
        assert (steam.compatibility_tools[0].internal_title == "path_internal");
        steam.unregister_compatibility_tool_by_path (path);
        assert (steam.compatibility_tools.size == 0);

        assert (FileUtils.remove (vdf) == 0);
        assert (DirUtils.remove (path) == 0);
        assert (FileUtils.remove (root) == 0);
    }
}
