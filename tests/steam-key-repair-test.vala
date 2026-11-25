namespace AppTests.SteamKeyRepairTest {
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Services;

    private const string HISTORICAL = "Fixture Latest";
    private const string VARIANT_KEY = "protonplus-fixture-latest-v3";
    private const string MANIFEST = "\"compatibilitytools\" { \"compat_tools\" { \"Fixture Latest\" { \"display_name\" \"Fixture\" } } }\n";
    private const string CONFIG = """
"InstallConfigStore"
{
    "Software" { "Valve" { "Steam" { "CompatToolMapping"
    {
        "0" { "name" "Fixture Latest" "priority" "75" }
        "42" { "name" "Fixture Latest" "config" "preserve me" }
        "9999" { "name" "Fixture Latest" }
        "25" { "name" "untouched" }
    }
    } } }
}
""";

    private class SessionFixture : Object, SteamSessionBackend {
        public string root;
        public string restart_after_manifest = "";
        public bool running = false;

        public SessionFixture (string root) { this.root = root; }

        public string? get_boot_id () { return "repair-fixture"; }
        public int64 get_monotonic_time_usec () { return 60 * 1000 * 1000; }
        public int64 get_clock_ticks_per_second () { return 100; }
        public NativeProcessQuery query_native_processes () {
            var processes = new Gee.ArrayList<SteamProcessRecord> ();
            if (running || (restart_after_manifest != "" && read (restart_after_manifest) != MANIFEST))
                processes.add (new SteamProcessRecord (101, Path.build_filename (root, "steam"), root, 100));
            return new NativeProcessQuery (true, processes);
        }
        public FlatpakProcessQuery query_flatpak_processes () { return new FlatpakProcessQuery (true); }
        public SteamDesktopEntry? find_desktop_entry (string? id) { return null; }
        public bool is_steamos_gaming_mode () { return false; }
    }

    private class Fixture : Object {
        public Launchers.Steam steam;
        public SessionFixture backend;
        public SteamRestartManager manager;
        public SteamConfigurationService configuration;
        public SteamKeyRepair repair;
        public string root;
        public string config;
        public string managed_root;
        public string system_root;
        public string variant_manifest;
        public string standard_manifest;
        public string state_path;
        public string journal;
        public Games.Steam inheriting;

        public Fixture () throws Error {
            root = DirUtils.make_tmp ("protonplus-steam-key-repair-XXXXXX");
            var steam_root = Path.build_filename (root, "steam");
            managed_root = Path.build_filename (steam_root, "compatibilitytools.d");
            system_root = Path.build_filename (root, "external");
            config = Path.build_filename (steam_root, "config", "config.vdf");
            journal = Path.build_filename (managed_root, ".protonplus-steam-key-repair");
            write (config, CONFIG);
            state_path = Path.build_filename (root, "state", "restart-state.json");
            var discovery = new SteamCompatibilityToolDiscovery (Launcher.InstallationTypes.SYSTEM, false, system_root);
            steam = new Launchers.Steam (Launcher.InstallationTypes.SYSTEM, null, discovery);
            steam.directory = steam_root;
            var group = new Group ("Fixture", "", "compatibilitytools.d", steam, "proton");
            group.tools = new Gee.LinkedList<Tool> ();
            steam.groups = { group };
            var definition = new ProviderDefinition (new ProviderConfig () {
                category = Category.PROTON,
                source_type = SourceType.GITHUB,
                provider_id = "fixture",
                title = "Fixture",
                endpoint = "https://example.test/releases",
                repository_url = "https://example.test/source",
                variants = {
                    new VariantDefinition ("standard", "Standard", "$release_name", true),
                    new VariantDefinition ("v3", "V3", "$release_name-v3", false)
                },
                install_layouts = { InstallLayout.template ("default", "$release_name") }
            });
            var tool = ProviderCatalog.create_tool (definition, group);
            assert (tool != null);
            group.tools.add (tool);
            standard_manifest = create_slot ("Standard", tool, "standard");
            variant_manifest = create_slot ("V3", tool, "v3");
            inheriting = new Games.Steam (100, "Inherited fixture", "fixture", 0, steam_root, steam);
            steam.games.append (inheriting);
            backend = new SessionFixture (steam_root);
            reopen ();
        }

        public void reopen () throws Error {
            var sessions = new SteamSessionService (backend);
            manager = new SteamRestartManager (sessions, new SteamRestartStateStore (state_path));
            configuration = new SteamConfigurationService (sessions, manager);
            repair = new SteamKeyRepair (steam, sessions, manager, configuration);
        }

        private string create_slot (string name, Tool tool, string variant) {
            var path = Path.build_filename (managed_root, name);
            var manifest = Path.build_filename (path, "compatibilitytool.vdf");
            write (manifest, MANIFEST);
            var metadata = new ProtonPlus.Utils.Metadata ();
            metadata.provider_id = tool.provider_id;
            metadata.tool_id = tool.id;
            metadata.launcher_id = steam.tool_target_id;
            metadata.variant_id = variant;
            metadata.install_mode = "latest";
            metadata.tag = "v1";
            assert (metadata.save (path));
            return manifest;
        }

        ~Fixture () {
            var loop = new MainLoop ();
            ProtonPlus.Utils.Filesystem.delete_directory.begin (root, (obj, result) => {
                assert (ProtonPlus.Utils.Filesystem.delete_directory.end (result));
                loop.quit ();
            });
            loop.run ();
        }
    }

    private string read (string path) {
        string content = "";
        try { FileUtils.get_contents (path, out content); }
        catch (Error e) { assert_not_reached (); }
        return content;
    }

    private void write (string path, string content) {
        assert (DirUtils.create_with_parents (Path.get_dirname (path), 0700) == 0);
        try { FileUtils.set_contents (path, content); }
        catch (Error e) { assert_not_reached (); }
    }

    private void assert_original (Fixture f) {
        assert (read (f.variant_manifest) == MANIFEST);
        assert (read (f.standard_manifest) == MANIFEST);
        assert (read (f.config) == CONFIG);
        assert (!FileUtils.test (f.journal, FileTest.EXISTS));
    }

    private void test_assignments () {
        try {
            var f = new Fixture ();
            var preview = f.repair.preview ();
            assert_original (f);
            assert (!FileUtils.test (Path.get_dirname (f.state_path), FileTest.EXISTS));
            assert (preview.claims.size == 2);
            assert (preview.mappings.get (0) == HISTORICAL && preview.mappings.get (9999) == HISTORICAL);
            assert (f.repair.owner_conflict (preview, HISTORICAL, "V3") != null);
            var assignments = new Gee.HashMap<string, string> ();
            assignments.set ("0", "V3");
            assignments.set ("9999", "V3");
            f.repair.apply (preview.token, HISTORICAL, "Standard", assignments);
            assert (read (f.standard_manifest) == MANIFEST);
            assert (read (f.variant_manifest) == MANIFEST.replace (HISTORICAL, VARIANT_KEY));
            var mappings = f.steam.compatibility_tool_hashtable;
            assert (mappings.get (0) == VARIANT_KEY && mappings.get (9999) == VARIANT_KEY);
            assert (mappings.get (42) == HISTORICAL && mappings.get (25) == "untouched");
            assert (!mappings.contains (100));
            assert (read (f.config).contains ("\"config\" \"preserve me\""));
            assert (f.inheriting.compatibility_tool == "Default");
            assert (f.steam.resolve_effective_compatibility_tool ("Default").internal_title == VARIANT_KEY);
            assert (!f.repair.preview ().recovery_available);
        } catch (Error e) {
            Test.message ("%s", e.message);
            assert_not_reached ();
        }
    }

    private void test_alternate_owner () {
        try {
            var f = new Fixture ();
            var legacy_key = "Old Fixture Latest";
            write (f.standard_manifest, MANIFEST.replace (HISTORICAL, legacy_key));
            write (f.variant_manifest, MANIFEST.replace (HISTORICAL, legacy_key));
            write (f.config, CONFIG.replace (HISTORICAL, legacy_key));
            var preview = f.repair.preview ();
            assert (f.repair.owner_conflict (preview, legacy_key, "V3") == null);
            var assignments = new Gee.HashMap<string, string> ();
            assignments.set ("42", "Standard");
            f.repair.apply (preview.token, legacy_key, "V3", assignments);
            assert (read (f.standard_manifest) == MANIFEST);
            assert (read (f.variant_manifest) == MANIFEST.replace (HISTORICAL, legacy_key));
            assert (f.steam.compatibility_tool_hashtable.get (0) == legacy_key);
            assert (f.steam.compatibility_tool_hashtable.get (42) == HISTORICAL);
            assert (f.steam.compatibility_tool_hashtable.get (9999) == legacy_key);
        } catch (Error e) {
            Test.message ("%s", e.message);
            assert_not_reached ();
        }
    }

    private void test_external_claims () {
        try {
            var f = new Fixture ();
            var path = Path.build_filename (f.system_root, "External", "compatibilitytool.vdf");
            write (path, "\"compat_tools\" { \"Another key\" {} \"Fixture Latest\" {} }");
            var preview = f.repair.preview ();
            assert (preview.claims.size == 4);
            assert (f.repair.owner_conflict (preview, HISTORICAL, "Standard") != null);
            assert_original (f);
            write (path, MANIFEST.replace (HISTORICAL, VARIANT_KEY));
            assert (f.repair.owner_conflict (f.repair.preview (), HISTORICAL, "Standard") != null);
            assert_original (f);
        } catch (Error e) {
            Test.message ("%s", e.message);
            assert_not_reached ();
        }
    }

    private void test_pending_and_stale_baselines () {
        try {
            var f = new Fixture ();
            var preview = f.repair.preview ();
            f.backend.running = true;
            var game = new Games.Steam (42, "Fixture game", "fixture", 0, f.root, f.steam);
            var result = f.configuration.change_game_compatibility_tool (game, "Default");
            assert (result.result == SteamConfigurationMutationResult.STAGED);
            f.backend.running = false;
            assert (f.repair.owner_conflict (f.repair.preview (), HISTORICAL, "Standard") != null);
            try {
                f.repair.apply (preview.token, HISTORICAL, "Standard", new Gee.HashMap<string, string> ());
                assert_not_reached ();
            } catch (IOError.BUSY e) {
                assert (e.message.contains ("42"));
            }
            assert_original (f);
            write (f.config, CONFIG.replace ("untouched", "edited"));
            try {
                f.repair.apply (preview.token, HISTORICAL, "Standard", new Gee.HashMap<string, string> ());
                assert_not_reached ();
            } catch (IOError.BUSY e) {
                assert (e.message.contains ("Preview"));
            }
            assert (!FileUtils.test (f.journal, FileTest.EXISTS));
        } catch (Error e) {
            Test.message ("%s", e.message);
            assert_not_reached ();
        }
    }

    private void test_interrupted_repair () {
        try {
            var f = new Fixture ();
            var assignments = new Gee.HashMap<string, string> ();
            assignments.set ("100", "V3");
            f.backend.restart_after_manifest = f.variant_manifest;
            var preview = f.repair.preview ();
            try {
                f.repair.apply (preview.token, HISTORICAL, "Standard", assignments);
                assert_not_reached ();
            } catch (IOError.BUSY e) {
                assert (read (f.config) == CONFIG);
                assert (read (f.variant_manifest) != MANIFEST);
                assert (FileUtils.test (f.journal, FileTest.IS_REGULAR));
            }
            var other = new Fixture ();
            var other_preview = other.repair.preview ();
            assert (!other_preview.recovery_available);
            assert_original (other);
            try {
                other.repair.apply (preview.token, HISTORICAL, "Standard", assignments);
                assert_not_reached ();
            } catch (IOError.BUSY e) {
                assert_original (other);
            }
            f.reopen ();
            assert (f.repair.preview ().recovery_available);
            f.backend.restart_after_manifest = "";
            write (f.config, CONFIG.replace ("\"42\" { \"name\" \"Fixture Latest\"",
                "\"42\" { \"name\" \"changed externally\""));
            try {
                f.repair.resume ();
                assert_not_reached ();
            } catch (IOError.BUSY e) {
                assert (e.message.contains ("42"));
                assert (f.repair.preview ().recovery_available);
            }
            write (f.config, CONFIG.replace ("untouched", "unrelated Steam change"));
            f.repair.resume ();
            assert (f.steam.compatibility_tool_hashtable.get (100) == VARIANT_KEY);
            assert (f.steam.compatibility_tool_hashtable.get (0) == HISTORICAL);
            assert (f.steam.compatibility_tool_hashtable.get (25) == "unrelated Steam change");
            assert (!f.repair.preview ().recovery_available);
        } catch (Error e) {
            Test.message ("%s", e.message);
            assert_not_reached ();
        }
    }

    public void register_tests () {
        Test.add_func ("/steam-key-repair/assignment-resolution", test_assignments);
        Test.add_func ("/steam-key-repair/alternate-owner", test_alternate_owner);
        Test.add_func ("/steam-key-repair/external-claims", test_external_claims);
        Test.add_func ("/steam-key-repair/pending-and-stale-baselines", test_pending_and_stale_baselines);
        Test.add_func ("/steam-key-repair/interruption-and-target-isolation", test_interrupted_repair);
    }
}
