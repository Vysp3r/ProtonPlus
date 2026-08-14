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

    private class ManualAwacyGameSource : Object, ProtonPlus.Models.Games.AwacyGameSource {
        public int load_count { get; private set; }
        public bool cancellation_observed { get; private set; }
        private SourceFunc? pending_callback;
        private Gee.HashMap<uint, ProtonPlus.Models.Games.Steam.AwacyGame?> result;

        public ManualAwacyGameSource () {
            result = new Gee.HashMap<uint, ProtonPlus.Models.Games.Steam.AwacyGame?> ();
        }

        public void add_game (uint appid, string name, string status) {
            result.set (appid, new ProtonPlus.Models.Games.Steam.AwacyGame (appid, name, status));
        }

        public async Gee.HashMap<uint, ProtonPlus.Models.Games.Steam.AwacyGame?>? load (Cancellable? cancellable) {
            load_count++;
            if (cancellable != null && !((!) cancellable).is_cancelled ()) {
                var cancellation_handler = ((!) cancellable).cancelled.connect (() => {
                    cancellation_observed = true;
                    Idle.add (() => {
                        complete ();
                        return Source.REMOVE;
                    });
                });
                pending_callback = load.callback;
                yield;
                ((!) cancellable).disconnect (cancellation_handler);
            } else if (cancellable != null) {
                cancellation_observed = true;
            }
            return result;
        }

        public void complete () {
            if (pending_callback == null)
                return;
            var callback = (!) pending_callback;
            pending_callback = null;
            callback ();
        }
    }

    public void register_tests () {
        Test.add_func ("/steam/linux-runtime-detection", test_linux_runtime_detection);
        Test.add_func ("/steam/game-runtime-classification", test_game_runtime_classification);
        Test.add_func ("/steam/runtime-classification-follows-mapping-changes", test_runtime_classification_follows_mapping_changes);
        Test.add_func ("/steam/base-launcher-compatibility-tool-lifecycle-is-no-op", test_base_launcher_compatibility_tool_lifecycle);
        Test.add_func ("/steam/compatibility-tool-registration-deduplicates-and-sorts", test_compatibility_tool_registration);
        Test.add_func ("/steam/effective-default-compatibility-tool", test_effective_default_compatibility_tool);
        Test.add_func ("/steam/effective-proton-executable", test_effective_proton_executable);
        Test.add_func ("/steam/compatibility-tool-path-registration-loads-tool", test_compatibility_tool_path_registration);
        Test.add_func ("/steam/text-vdf-writes-and-rejections", test_text_vdf_writes_and_rejections);
        Test.add_func ("/steam/localconfig-launch-options-writes-and-rejections", test_localconfig_launch_options_writes_and_rejections);
        Test.add_func ("/steam/profile-does-not-create-missing-shortcuts-file", test_profile_does_not_create_missing_shortcuts_file);
        Test.add_func ("/steam/profile-collections-are-eagerly-initialized", test_profile_collections_are_eagerly_initialized);
        Test.add_func ("/steam/profile-load-failures-are-filtered", test_profile_load_failures_are_filtered);
        Test.add_func ("/steam/library-failure-is-launcher-scoped", test_library_failure_is_launcher_scoped);
        Test.add_func ("/steam/profile-failure-is-launcher-scoped", test_profile_failure_is_launcher_scoped);
        Test.add_func ("/steam/awacy-catalog-deduplicates-and-caches", test_awacy_catalog_deduplicates_and_caches);
        Test.add_func ("/steam/awacy-catalog-bounds-optional-request", test_awacy_catalog_bounds_optional_request);
        Test.add_func ("/steam/local-library-does-not-wait-for-awacy", test_local_library_does_not_wait_for_awacy);
        Test.add_func ("/steam/library-compatibility-tools-use-stable-identities", test_library_compatibility_tools_use_stable_identities);
    }

    private void test_linux_runtime_detection () {
        assert (ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("Steam Linux Runtime 1.0 (scout)"));
        assert (ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("Steam Linux Runtime 2.0 (soldier)"));
        assert (ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("steam linux runtime 3.0 (sniper)"));
        assert (ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("Runtime", "steamlinuxruntime_sniper"));
        assert (!ProtonPlus.Models.Launchers.Steam.is_steam_linux_runtime ("Proton 10.0"));
    }

    private void create_executable_fixture (string path, string contents) {
        try {
            FileUtils.set_contents (path, contents);
        } catch (FileError e) {
            critical ("Could not create executable fixture: %s", e.message);
            assert_not_reached ();
        }
        assert (Posix.chmod (path, 0755) == 0);
    }

    private void test_game_runtime_classification () {
        var root = temporary_directory ();
        var windows_directory = Path.build_filename (root, "steamapps", "common", "WindowsGame");
        var native_directory = Path.build_filename (root, "steamapps", "common", "NativeGame");
        assert (ProtonPlus.Utils.Filesystem.create_directory (windows_directory));
        assert (ProtonPlus.Utils.Filesystem.create_directory (native_directory));
        create_executable_fixture (Path.build_filename (windows_directory, "game.exe"), "MZfixture");
        create_executable_fixture (Path.build_filename (native_directory, "game"), "\x7f" + "ELFfixture");

        var steam = fixture_steam (root);
        steam.games = new List<Game> ();
        steam.compatibility_tools.clear ();
        steam.register_compatibility_tool (new CompatibilityTool (
            "Fixture Proton", "fixture-proton", "/tools/fixture-proton",
            CompatibilityToolRuntimeKind.PROTON
        ));
        steam.register_compatibility_tool (new CompatibilityTool (
            "Steam Linux Runtime 3.0", "steamlinuxruntime_sniper", "/tools/runtime",
            CompatibilityToolRuntimeKind.NATIVE
        ));

        var direct_shortcut = new ProtonPlus.Models.Games.Steam.non_steam (
            10, "Direct shortcut", "", "Default", steam
        );
        assert (direct_shortcut.is_native);
        assert (ProtonPlus.Models.Launchers.Steam.is_game_steam_linux_runtime_compatible (direct_shortcut));

        steam.update_game_compatibility_tool_mapping (11, "fixture-proton");
        var proton_shortcut = new ProtonPlus.Models.Games.Steam.non_steam (
            11, "Windows shortcut", "", "fixture-proton", steam
        );
        assert (proton_shortcut.is_non_steam);
        assert (!proton_shortcut.is_native);
        assert (ProtonPlus.Models.Launchers.Steam.is_game_steam_linux_runtime_compatible (proton_shortcut));

        steam.update_game_compatibility_tool_mapping (12, "steamlinuxruntime_sniper");
        var runtime_shortcut = new ProtonPlus.Models.Games.Steam.non_steam (
            12, "Runtime shortcut", "", "steamlinuxruntime_sniper", steam
        );
        assert (runtime_shortcut.is_native);

        steam.update_game_compatibility_tool_mapping (20, "fixture-proton");
        var mapped_windows_game = new ProtonPlus.Models.Games.Steam (
            20, "Mapped Windows game", "WindowsGame", 0, root, steam
        );
        mapped_windows_game.compatibility_tool = "fixture-proton";
        assert (!FileUtils.test (mapped_windows_game.prefixdir, FileTest.IS_DIR));
        assert (!mapped_windows_game.is_native);

        var unmapped_windows_game = new ProtonPlus.Models.Games.Steam (
            21, "Unmapped Windows game", "WindowsGame", 0, root, steam
        );
        unmapped_windows_game.compatibility_tool = "Default";
        assert (!FileUtils.test (unmapped_windows_game.prefixdir, FileTest.IS_DIR));
        assert (!unmapped_windows_game.is_native);

        var native_game = new ProtonPlus.Models.Games.Steam (
            22, "Native game", "NativeGame", 0, root, steam
        );
        native_game.compatibility_tool = "Default";
        assert (!FileUtils.test (native_game.prefixdir, FileTest.IS_DIR));
        assert (native_game.is_native);

        steam.games.append (proton_shortcut);
        steam.games.append (mapped_windows_game);
        assert (steam.get_compatibility_tool_usage_count ("fixture-proton") == 2);
        assert (delete_directory (root));
    }

    private void test_runtime_classification_follows_mapping_changes () {
        var root = temporary_directory ();
        var config_directory = Path.build_filename (root, "config");
        var game_directory = Path.build_filename (root, "steamapps", "common", "NativeGame");
        assert (ProtonPlus.Utils.Filesystem.create_directory (config_directory));
        assert (ProtonPlus.Utils.Filesystem.create_directory (game_directory));
        create_executable_fixture (Path.build_filename (game_directory, "game"), "\x7f" + "ELFfixture");
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (config_directory, "config.vdf"),
            "\"InstallConfigStore\"\n{\n\t\"Software\"\n\t{\n\t\t\"Valve\"\n\t\t{\n\t\t\t\"Steam\"\n\t\t\t{\n\t\t\t}\n\t\t}\n\t}\n}\n"
        ));

        configure_service (root);
        var steam = fixture_steam (root);
        steam.compatibility_tools.clear ();
        steam.register_compatibility_tool (new CompatibilityTool (
            "Fixture Proton", "fixture-proton", "/tools/fixture-proton",
            CompatibilityToolRuntimeKind.PROTON
        ));
        var game = new ProtonPlus.Models.Games.Steam (
            42, "Native game", "NativeGame", 0, root, steam
        );
        game.compatibility_tool = "Default";

        assert (game.is_native);
        assert (game.change_compatibility_tool ("fixture-proton"));
        assert (steam.has_explicit_compatibility_tool_mapping (42));
        assert (!game.is_native);

        assert (game.change_compatibility_tool ("Default"));
        assert (!steam.has_explicit_compatibility_tool_mapping (42));
        assert (game.is_native);

        SteamConfigurationService.reset_configuration ();
        assert (delete_directory (root));
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

    private void test_effective_proton_executable () {
        var root = temporary_directory ();
        var proton_path = Path.build_filename (root, "proton");
        try {
            FileUtils.set_contents (proton_path, "#!/bin/sh\nexit 0\n");
        } catch (FileError e) {
            critical ("Could not create Proton executable fixture: %s", e.message);
            assert_not_reached ();
        }
        assert (Posix.chmod (proton_path, 0755) == 0);

        var steam = new ProtonPlus.Models.Launchers.Steam (
            ProtonPlus.Models.Launcher.InstallationTypes.SNAP
        );
        steam.compatibility_tools.clear ();
        steam.register_compatibility_tool (new ProtonPlus.Models.CompatibilityTool (
            "Fixture Proton", "fixture-proton", root,
            CompatibilityToolRuntimeKind.PROTON
        ));

        steam.default_compatibility_tool = "fixture-proton";
        assert (steam.resolve_effective_proton_executable ("Default") == proton_path);
        assert (steam.resolve_effective_proton_executable ("fixture-proton") == proton_path);

        steam.default_compatibility_tool = "stale-proton";
        assert (steam.resolve_effective_proton_executable ("Default") == null);

        assert (Posix.chmod (proton_path, 0644) == 0);
        assert (steam.resolve_effective_proton_executable ("fixture-proton") == null);

        FileUtils.remove (proton_path);
        assert (steam.resolve_effective_proton_executable ("fixture-proton") == null);
        DirUtils.remove (root);
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

    private Gee.HashMap<uint, ProtonPlus.Models.Games.Steam.AwacyGame?> load_awacy_catalog (
        ProtonPlus.Models.Games.AwacyGameCatalog catalog
    ) {
        var loop = new MainLoop ();
        Gee.HashMap<uint, ProtonPlus.Models.Games.Steam.AwacyGame?>? games = null;
        var completed = false;
        catalog.get_games.begin ((obj, result) => {
            games = catalog.get_games.end (result);
            completed = true;
            if (loop.is_running ())
                loop.quit ();
        });
        if (!completed)
            loop.run ();
        return (!) games;
    }

    private bool load_steam_library (ProtonPlus.Models.Launchers.Steam steam) {
        var loop = new MainLoop ();
        var loaded = false;
        var completed = false;
        steam.load_game_library.begin ((obj, result) => {
            loaded = steam.load_game_library.end (result);
            completed = true;
            if (loop.is_running ())
                loop.quit ();
        });
        if (!completed)
            loop.run ();
        return loaded;
    }

    private void test_awacy_catalog_deduplicates_and_caches () {
        var source = new ManualAwacyGameSource ();
        source.add_game (42, "fixture-game", "Supported");
        var catalog = new ProtonPlus.Models.Games.AwacyGameCatalog (source, 0);
        var loop = new MainLoop ();
        var completed = 0;
        Gee.HashMap<uint, ProtonPlus.Models.Games.Steam.AwacyGame?>? first = null;
        Gee.HashMap<uint, ProtonPlus.Models.Games.Steam.AwacyGame?>? second = null;

        catalog.get_games.begin ((obj, result) => {
            first = catalog.get_games.end (result);
            completed++;
            if (completed == 2 && loop.is_running ())
                loop.quit ();
        });
        catalog.get_games.begin ((obj, result) => {
            second = catalog.get_games.end (result);
            completed++;
            if (completed == 2 && loop.is_running ())
                loop.quit ();
        });

        assert (source.load_count == 1);
        source.complete ();
        if (completed < 2)
            loop.run ();

        assert (((!) first).has_key (42));
        assert (((!) second).has_key (42));
        var cached = load_awacy_catalog (catalog);
        assert (cached.has_key (42));
        assert (source.load_count == 1);
    }

    private void test_awacy_catalog_bounds_optional_request () {
        var source = new ManualAwacyGameSource ();
        var catalog = new ProtonPlus.Models.Games.AwacyGameCatalog (source, 10);

        var games = load_awacy_catalog (catalog);

        assert (games.size == 0);
        assert (source.cancellation_observed);
        assert (source.load_count == 1);
        assert (load_awacy_catalog (catalog).size == 0);
        assert (source.load_count == 1);
    }

    private void test_local_library_does_not_wait_for_awacy () {
        var root = temporary_directory ();
        var config_directory = Path.build_filename (root, "config");
        var steamapps_directory = Path.build_filename (root, "steamapps");
        var game_directory = Path.build_filename (steamapps_directory, "common", "FixtureGame");
        var missing_game_directory = Path.build_filename (steamapps_directory, "common", "MissingGame");
        assert (ProtonPlus.Utils.Filesystem.create_directory (config_directory));
        assert (ProtonPlus.Utils.Filesystem.create_directory (game_directory));
        assert (ProtonPlus.Utils.Filesystem.create_directory (missing_game_directory));
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (config_directory, "config.vdf"),
            "\"InstallConfigStore\" { \"Software\" { \"Valve\" { \"Steam\" { } } } }"
        ));
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (steamapps_directory, "libraryfolders.vdf"),
            "\"libraryfolders\" { \"0\" { \"path\" \"%s\" \"apps\" { \"42\" \"1\" \"43\" \"1\" } } }".printf (root)
        ));
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (steamapps_directory, "appmanifest_42.acf"),
            "\"AppState\" { \"appid\" \"42\" \"name\" \"Fixture Game\" \"installdir\" \"FixtureGame\" }"
        ));
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (steamapps_directory, "appmanifest_43.acf"),
            "\"AppState\" { \"appid\" \"43\" \"name\" \"Missing Game\" \"installdir\" \"MissingGame\" }"
        ));

        var source = new ManualAwacyGameSource ();
        source.add_game (42, "fixture-game", "Running");
        var catalog = new ProtonPlus.Models.Games.AwacyGameCatalog (source, 0);
        var steam = new ProtonPlus.Models.Launchers.Steam (Launcher.InstallationTypes.SNAP, catalog);
        steam.directory = root;
        steam.groups = {};

        assert (load_steam_library (steam));
        assert (steam.games.length () == 2);
        ProtonPlus.Models.Games.Steam? matched_game = null;
        ProtonPlus.Models.Games.Steam? missing_game = null;
        foreach (var base_game in steam.games) {
            var steam_game = base_game as ProtonPlus.Models.Games.Steam;
            if (steam_game == null)
                continue;
            if (((!) steam_game).appid == 42)
                matched_game = (!) steam_game;
            else if (((!) steam_game).appid == 43)
                missing_game = (!) steam_game;
        }
        assert (matched_game != null);
        assert (missing_game != null);
        assert (((!) matched_game).awacy_status == null);
        assert (!((!) matched_game).awacy_lookup_complete);
        assert (!((!) missing_game).awacy_lookup_complete);

        while (MainContext.default ().pending ())
            MainContext.default ().iteration (false);
        assert (source.load_count == 1);
        assert (((!) matched_game).awacy_status == null);

        var status_notified = false;
        var missing_complete_notified = false;
        ((!) matched_game).notify["awacy-status"].connect (() => {
            status_notified = true;
        });
        ((!) missing_game).notify["awacy-lookup-complete"].connect (() => {
            missing_complete_notified = true;
        });
        source.complete ();
        while (MainContext.default ().pending ())
            MainContext.default ().iteration (false);

        assert (status_notified);
        assert (missing_complete_notified);
        assert (((!) matched_game).awacy_name == "fixture-game");
        assert (((!) matched_game).awacy_status == "Running");
        assert (((!) matched_game).awacy_lookup_complete);
        assert (((!) missing_game).awacy_name == null);
        assert (((!) missing_game).awacy_status == null);
        assert (((!) missing_game).awacy_lookup_complete);
        assert (delete_directory (root));
    }

    private void test_library_compatibility_tools_use_stable_identities () {
        var root = temporary_directory ();
        var config_directory = Path.build_filename (root, "config");
        var steamapps_directory = Path.build_filename (root, "steamapps");
        assert (ProtonPlus.Utils.Filesystem.create_directory (config_directory));
        assert (ProtonPlus.Utils.Filesystem.create_directory (
            Path.build_filename (steamapps_directory, "common")
        ));
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (config_directory, "config.vdf"),
            "\"InstallConfigStore\" { \"Software\" { \"Valve\" { \"Steam\" { } } } }"
        ));
        assert (ProtonPlus.Utils.Filesystem.modify_file (
            Path.build_filename (steamapps_directory, "libraryfolders.vdf"),
            "\"libraryfolders\" { \"0\" { \"path\" \"%s\" \"apps\" { \"4628710\" \"1\" \"2805730\" \"1\" \"4183110\" \"1\" } } }".printf (root)
        ));

        var appids = new uint[] { 4628710, 2805730, 4183110 };
        var names = new string[] { "Proton 11.0", "Proton 9.0", "Steam Linux Runtime 4.0" };
        var directories = new string[] { "Proton 11.0", "Proton 9.0 (Beta)", "SteamLinuxRuntime_4" };
        for (var index = 0; index < appids.length; index++) {
            assert (ProtonPlus.Utils.Filesystem.modify_file (
                Path.build_filename (steamapps_directory, "appmanifest_%u.acf".printf (appids[index])),
                "\"AppState\" { \"appid\" \"%u\" \"name\" \"%s\" \"installdir\" \"%s\" }".printf (
                    appids[index], names[index], directories[index]
                )
            ));
            var tool_path = Path.build_filename (steamapps_directory, "common", directories[index]);
            assert (ProtonPlus.Utils.Filesystem.create_directory (tool_path));
            assert (ProtonPlus.Utils.Filesystem.modify_file (
                Path.build_filename (tool_path, "toolmanifest.vdf"),
                "\"manifest\" { \"version\" \"2\" }"
            ));
            if (appids[index] != 4183110)
                create_executable_fixture (Path.build_filename (tool_path, "proton"), "#!/bin/sh\n");
        }

        var unavailable_system_root = Path.build_filename (root, "system-tools");
        var discovery = new SteamCompatibilityToolDiscovery (
            Launcher.InstallationTypes.SYSTEM, false,
            unavailable_system_root, unavailable_system_root, {}
        );
        var catalog = new ProtonPlus.Models.Games.AwacyGameCatalog (
            new ManualAwacyGameSource (), 0
        );
        var steam = new ProtonPlus.Models.Launchers.Steam (
            Launcher.InstallationTypes.SYSTEM, catalog, discovery
        );
        steam.directory = root;
        steam.groups = {};

        assert (load_steam_library (steam));
        var proton_11 = steam.find_compatibility_tool ("proton_11");
        var proton_9 = steam.find_compatibility_tool ("proton_9");
        var runtime = steam.find_compatibility_tool ("steamlinuxruntime_4");
        assert (proton_11 != null && ((!) proton_11).display_title == "Proton 11.0");
        assert (proton_9 != null && ((!) proton_9).display_title == "Proton 9.0");
        assert (runtime != null && ((!) runtime).runtime_kind == CompatibilityToolRuntimeKind.NATIVE);
        assert (steam.can_assign_compatibility_tool ("proton_11"));
        assert (steam.can_assign_compatibility_tool ("proton_9"));
        assert (steam.can_assign_compatibility_tool ("steamlinuxruntime_4"));
        assert (steam.get_assignable_compatibility_tools ().size == 3);
        assert (delete_directory (root));
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
