namespace AppTests.SteamTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Services;

    private class StoppedSessionFixture : Object, SteamSessionBackend {
        public string? get_boot_id () { return "steam-test-fixture"; }
        public int64 get_monotonic_time_usec () { return 60 * 1000 * 1000; }
        public int64 get_clock_ticks_per_second () { return 100; }
        public NativeProcessQuery query_native_processes () { return new NativeProcessQuery (true); }
        public FlatpakProcessQuery query_flatpak_processes () { return new FlatpakProcessQuery (true); }
        public SteamDesktopEntry? find_desktop_entry (string? id) { return null; }
        public bool is_steamos_gaming_mode () { return false; }
    }

    private class FixtureSteam : ProtonPlus.Models.Launchers.Steam {
        private bool library_result;

        public FixtureSteam (string root, bool library_result) {
            base (ProtonPlus.Models.Launcher.InstallationTypes.SNAP);
            directory = root;
            installed = true;
            groups = {};
            this.library_result = library_result;
        }

        public override async bool load_game_library () {
            games = new List<Game> ();
            compatibility_tool_hashtable = new HashTable<uint, string> (null, null);
            return library_result;
        }
    }

    public void register_tests () {
        Test.add_func ("/steam/linux-runtime-detection", test_linux_runtime_detection);
        Test.add_func ("/steam/base-launcher-compatibility-tool-lifecycle-is-no-op", test_base_launcher_compatibility_tool_lifecycle);
        Test.add_func ("/steam/compatibility-tool-registration-deduplicates-and-sorts", test_compatibility_tool_registration);
        Test.add_func ("/steam/effective-default-compatibility-tool", test_effective_default_compatibility_tool);
        Test.add_func ("/steam/compatibility-tool-path-registration-loads-tool", test_compatibility_tool_path_registration);
        Test.add_func ("/steam/text-vdf-writes-and-rejections", test_text_vdf_writes_and_rejections);
        Test.add_func ("/steam/localconfig-launch-options-writes-and-rejections", test_localconfig_launch_options_writes_and_rejections);
        Test.add_func ("/steam/profile-does-not-create-missing-shortcuts-file", test_profile_does_not_create_missing_shortcuts_file);
        Test.add_func ("/steam/profile-collections-are-eagerly-initialized", test_profile_collections_are_eagerly_initialized);
        Test.add_func ("/steam/profile-load-failures-are-filtered", test_profile_load_failures_are_filtered);
        Test.add_func ("/steam/library-failure-is-launcher-scoped", test_library_failure_is_launcher_scoped);
        Test.add_func ("/steam/profile-failure-is-launcher-scoped", test_profile_failure_is_launcher_scoped);
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

    private void test_effective_default_compatibility_tool () {
        var steam = new ProtonPlus.Models.Launchers.Steam (
            ProtonPlus.Models.Launcher.InstallationTypes.SNAP
        );
        steam.compatibility_tools.clear ();
        var cachyos = new ProtonPlus.Models.CompatibilityTool (
            "Proton-CachyOS", "proton-cachyos", "/tools/proton-cachyos",
            CompatibilityToolRuntimeKind.PROTON
        );
        steam.register_compatibility_tool (cachyos);
        steam.register_compatibility_tool (new ProtonPlus.Models.CompatibilityTool (
            "Proton 10", "proton-10", "/tools/proton-10",
            CompatibilityToolRuntimeKind.PROTON
        ));

        steam.default_compatibility_tool = "proton-cachyos";
        assert (steam.resolve_effective_compatibility_tool ("Default") == cachyos);
        assert (steam.resolve_effective_compatibility_tool ("proton-cachyos") == cachyos);

        steam.default_compatibility_tool = "missing-tool";
        assert (steam.resolve_effective_compatibility_tool ("Default") == null);
        steam.default_compatibility_tool = "Default";
        assert (steam.resolve_effective_compatibility_tool ("Default") == null);
        steam.default_compatibility_tool = "";
        assert (steam.resolve_effective_compatibility_tool ("Default") == null);
    }

    private string temporary_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-steam-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create test directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private bool setup_game_library (Launcher launcher) {
        var loop = new MainLoop ();
        var loaded = false;
        launcher.setup_profile_library_for_test.begin ((obj, result) => {
            loaded = launcher.setup_profile_library_for_test.end (result);
            loop.quit ();
        });
        loop.run ();
        return loaded;
    }

    private bool initialize_launchers (Gee.LinkedList<Launcher> launchers) {
        var loop = new MainLoop ();
        var initialized = false;
        Launcher.initialize_launchers.begin (launchers, new ProtonPlus.Models.Providers.ProviderRegistry (), (obj, result) => {
            initialized = Launcher.initialize_launchers.end (result);
            loop.quit ();
        });
        loop.run ();
        return initialized;
    }

    private bool delete_directory (string path) {
        var loop = new MainLoop ();
        var deleted = false;
        ProtonPlus.Utils.Filesystem.delete_directory.begin (path, (obj, result) => {
            deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (result);
            loop.quit ();
        });
        loop.run ();
        return deleted;
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

    private ProtonPlus.Models.Launchers.Steam fixture_steam (string root) {
        var steam = new ProtonPlus.Models.Launchers.Steam (
            ProtonPlus.Models.Launcher.InstallationTypes.SNAP
        );
        steam.directory = root;
        return steam;
    }

    private SteamConfigurationService configure_service (string root) {
        var sessions = new SteamSessionService (new StoppedSessionFixture ());
        var manager = new SteamRestartManager (sessions,
            new SteamRestartStateStore (Path.build_filename (root, "restart-state.json")));
        var service = new SteamConfigurationService (sessions, manager);
        manager.configure_configuration_reconciler (service);
        SteamConfigurationService.configure (service);
        return service;
    }

    private void test_text_vdf_writes_and_rejections () {
        var root = temporary_directory ();
        var config_directory = Path.build_filename (root, "config");
        var config_path = Path.build_filename (config_directory, "config.vdf");
        assert (ProtonPlus.Utils.Filesystem.create_directory (config_directory));
        var initial = "\"InstallConfigStore\"\n{\n\t\"Software\"\n\t{\n\t\t\"Valve\"\n\t\t{\n\t\t\t\"Steam\"\n\t\t\t{\n\t\t\t}\n\t\t}\n\t}\n}\n";
        assert (ProtonPlus.Utils.Filesystem.modify_file (config_path, initial));

        configure_service (root);
        var steam = fixture_steam (root);
        assert (steam.change_default_compatibility_tool ("proton_fixture"));
        var game = new ProtonPlus.Models.Games.Steam (42, "Fixture", "Fixture", 0, root, steam);
        assert (game.change_compatibility_tool ("proton_game"));
        assert (game.change_compatibility_tool ("proton_other"));
        assert (game.change_compatibility_tool ("Default"));
        var changed = ProtonPlus.Utils.Filesystem.get_file_content (config_path);
        assert (changed.contains ("\"0\""));
        assert (changed.contains ("proton_fixture"));
        assert (!changed.contains ("\"42\""));

        assert (steam.change_default_compatibility_tool ("proton_fixture"));
        assert (ProtonPlus.Utils.Filesystem.get_file_content (config_path) == changed);

        assert (ProtonPlus.Utils.Filesystem.modify_file (config_path, "not VDF"));
        assert (!steam.change_default_compatibility_tool ("proton_rejected"));
        assert (ProtonPlus.Utils.Filesystem.get_file_content (config_path) == "not VDF");

        assert (FileUtils.remove (config_path) == 0);
        SteamConfigurationService.reset_configuration ();
        assert (DirUtils.remove (config_directory) == 0);
        assert (DirUtils.remove (root) == 0);
    }

    private void test_localconfig_launch_options_writes_and_rejections () {
        var root = temporary_directory ();
        var config_path = Path.build_filename (root, "localconfig.vdf");
        var initial = "\"UserLocalConfigStore\"\n{\n\t\"Software\"\n\t{\n\t\t\"Valve\"\n\t\t{\n\t\t\t\"Steam\"\n\t\t\t{\n\t\t\t\t\"apps\"\n\t\t\t\t{\n\t\t\t\t\t\"42\"\n\t\t\t\t\t{\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}\n}\n";
        assert (ProtonPlus.Utils.Filesystem.modify_file (config_path, initial));

        configure_service (root);
        var steam = fixture_steam (root);
        var game = new ProtonPlus.Models.Games.Steam (42, "Fixture", "Fixture", 0, root, steam);
        assert (game.change_launch_options ("PROTON_LOG=1 %command%", config_path));
        assert (game.change_launch_options ("PROTON_LOG=0 %command%", config_path));
        assert (ProtonPlus.Utils.Filesystem.get_file_content (config_path).contains ("PROTON_LOG=0 %command%"));
        assert (game.change_launch_options ("", config_path));
        var changed = ProtonPlus.Utils.Filesystem.get_file_content (config_path);
        assert (!changed.contains ("LaunchOptions"));
        assert (game.change_launch_options ("", config_path));
        assert (ProtonPlus.Utils.Filesystem.get_file_content (config_path) == changed);

        assert (ProtonPlus.Utils.Filesystem.modify_file (config_path, "not VDF"));
        assert (!game.change_launch_options ("PROTON_LOG=1 %command%", config_path));
        assert (ProtonPlus.Utils.Filesystem.get_file_content (config_path) == "not VDF");
        assert (FileUtils.remove (config_path) == 0);

        SteamConfigurationService.reset_configuration ();
        assert (DirUtils.remove (root) == 0);
    }

    private void test_profile_does_not_create_missing_shortcuts_file () {
        var root = temporary_directory ();
        var userdata = Path.build_filename (root, "userdata");
        var config = Path.build_filename (userdata, "config");
        assert (ProtonPlus.Utils.Filesystem.create_directory (config));
        var steam = fixture_steam (root);
        var profile = new ProtonPlus.Models.SteamProfile (
            steam, "Fixture", "76561197960265729", userdata
        );
        var shortcuts_path = Path.build_filename (config, "shortcuts.vdf");
        assert (!FileUtils.test (shortcuts_path, FileTest.EXISTS));
        assert (profile.shortcuts != null);
        assert (DirUtils.remove (config) == 0);
        assert (DirUtils.remove (userdata) == 0);
        assert (DirUtils.remove (root) == 0);
    }

    private void test_profile_collections_are_eagerly_initialized () {
        var root = temporary_directory ();
        var userdata = Path.build_filename (root, "userdata", "1");
        var config = Path.build_filename (userdata, "config");
        assert (ProtonPlus.Utils.Filesystem.create_directory (config));
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (config, "localconfig.vdf"), "not VDF"
        ));

        var profile = new ProtonPlus.Models.SteamProfile (
            fixture_steam (root), "Fixture", "76561197960265729", userdata
        );
        assert (profile.launch_options_hashtable.size () == 0);
        assert (profile.non_steam_games.length () == 0);

        var loop = new MainLoop ();
        var loaded = true;
        profile.load_extra_data.begin ((obj, result) => {
            loaded = profile.load_extra_data.end (result);
            loop.quit ();
        });
        loop.run ();

        assert (!loaded);
        assert (profile.launch_options_hashtable.size () == 0);
        assert (profile.non_steam_games.length () == 0);
        assert (delete_directory (root));
    }

    private void test_profile_load_failures_are_filtered () {
        var root = temporary_directory ();
        var config = Path.build_filename (root, "config");
        var broken_config = Path.build_filename (root, "userdata", "1", "config");
        var valid_config = Path.build_filename (root, "userdata", "2", "config");
        var unrelated_userdata = Path.build_filename (root, "userdata", "not-a-profile");
        assert (ProtonPlus.Utils.Filesystem.create_directory (config));
        assert (ProtonPlus.Utils.Filesystem.create_directory (broken_config));
        assert (ProtonPlus.Utils.Filesystem.create_directory (valid_config));
        assert (ProtonPlus.Utils.Filesystem.create_directory (unrelated_userdata));
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (config, "loginusers.vdf"),
            "\"users\" { \"76561197960265729\" { \"PersonaName\" \"Broken\" } \"76561197960265730\" { \"PersonaName\" \"Valid\" } }"
        ));
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (broken_config, "localconfig.vdf"), "not VDF"
        ));
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (valid_config, "localconfig.vdf"),
            "\"UserLocalConfigStore\" { \"Software\" { \"Valve\" { \"Steam\" { \"apps\" { } } } } }"
        ));

        var steam = new FixtureSteam (root, true);
        assert (setup_game_library (steam));
        assert (steam.game_library_available);
        assert (steam.profiles.length () == 1);
        assert (steam.profiles.nth_data (0).username == "Valid");
        assert (steam.profile == steam.profiles.nth_data (0));
        assert (delete_directory (root));
    }

    private void test_library_failure_is_launcher_scoped () {
        var root = temporary_directory ();
        var steam = new FixtureSteam (root, false);
        var lutris = new ProtonPlus.Models.Launchers.Lutris (Launcher.InstallationTypes.SYSTEM);
        lutris.directory = root;
        lutris.installed = true;

        var launchers = new Gee.LinkedList<Launcher> ();
        launchers.add (steam);
        launchers.add (lutris);

        assert (initialize_launchers (launchers));
        assert (!steam.game_library_available);
        assert (steam.games.length () == 0);
        assert (steam.profiles.length () == 0);
        assert (steam.groups.length == 1);
        assert (lutris.groups.length == 4);
        assert (delete_directory (root));
    }

    private void test_profile_failure_is_launcher_scoped () {
        var root = temporary_directory ();
        var config = Path.build_filename (root, "config");
        var profile_config = Path.build_filename (root, "userdata", "1", "config");
        assert (ProtonPlus.Utils.Filesystem.create_directory (config));
        assert (ProtonPlus.Utils.Filesystem.create_directory (profile_config));
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (config, "loginusers.vdf"),
            "\"users\" { \"76561197960265729\" { \"PersonaName\" \"Broken\" } }"
        ));
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (profile_config, "localconfig.vdf"), "not VDF"
        ));

        var steam = new FixtureSteam (root, true);
        var lutris = new ProtonPlus.Models.Launchers.Lutris (Launcher.InstallationTypes.SYSTEM);
        lutris.directory = root;
        lutris.installed = true;

        var launchers = new Gee.LinkedList<Launcher> ();
        launchers.add (steam);
        launchers.add (lutris);

        assert (initialize_launchers (launchers));
        assert (!steam.game_library_available);
        assert (steam.profiles.length () == 0);
        assert (lutris.groups.length == 4);
        assert (delete_directory (root));
    }
}
