namespace AppTests.SteamConfigurationServiceTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Services;

    private class SessionFixture : Object, SteamSessionBackend {
        public NativeProcessQuery native_query = new NativeProcessQuery (true);
        public FlatpakProcessQuery flatpak_query = new FlatpakProcessQuery (true);
        public string? get_boot_id () { return "configuration-fixture"; }
        public int64 get_monotonic_time_usec () { return 60 * 1000 * 1000; }
        public int64 get_clock_ticks_per_second () { return 100; }
        public NativeProcessQuery query_native_processes () { return native_query; }
        public FlatpakProcessQuery query_flatpak_processes () { return flatpak_query; }
        public SteamDesktopEntry? find_desktop_entry (string? id) { return null; }
    }

    private class ShortcutFixture : Object, SteamShortcutMutator {
        public int installs = 0;
        public int removals = 0;
        public bool install_result = true;
        public bool remove_result = true;
        public bool install (ProtonPlus.Utils.VDF.Shortcuts shortcuts) {
            installs++;
            if (!install_result) return false;
            if (!shortcuts.get_installed_status ()) {
                ProtonPlus.Utils.VDF.Shortcut shortcut = {};
                shortcut.AppName = "ProtonPlus";
                shortcut.DevkitGameID = "";
                shortcut.Exe = "";
                shortcut.FlatpakAppID = "";
                shortcut.LaunchOptions = "";
                shortcut.ShortcutPath = "";
                shortcut.StartDir = "";
                shortcut.Icon = "";
                shortcuts.append_shortcut (shortcut);
            }
            return true;
        }
        public bool remove (ProtonPlus.Utils.VDF.Shortcuts shortcuts) {
            removals++;
            if (!remove_result) return false;
            if (!shortcuts.get_installed_status ()) return true;
            try { shortcuts.remove_shortcut_by_name ("ProtonPlus"); }
            catch (Error e) { return false; }
            return true;
        }
    }

    private class FailingStateStore : SteamRestartStateStore {
        public bool fail_saves = false;
        public FailingStateStore (string path) { base (path); }
        public override bool save (Gee.Collection<SteamRestartPendingRecord> records) {
            return !fail_saves && base.save (records);
        }
    }

    private const string CONFIG = "\"InstallConfigStore\"\n{\n\t\"Software\"\n\t{\n\t\t\"Valve\"\n\t\t{\n\t\t\t\"Steam\"\n\t\t\t{\n\t\t\t}\n\t\t}\n\t}\n}\n";
    private const string LOCALCONFIG = "\"UserLocalConfigStore\"\n{\n\t\"Software\"\n\t{\n\t\t\"Valve\"\n\t\t{\n\t\t\t\"Steam\"\n\t\t\t{\n\t\t\t\t\"apps\"\n\t\t\t\t{\n\t\t\t\t\t\"42\"\n\t\t\t\t\t{\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}\n}\n";

    private string temporary_root () {
        return DirUtils.mkdtemp (Path.build_filename (Environment.get_tmp_dir (), "protonplus-steam-config-XXXXXX"));
    }

    private void make_directory (string path) {
        try { File.new_for_path (path).make_directory_with_parents (null); }
        catch (Error e) { assert (FileUtils.test (path, FileTest.IS_DIR)); }
    }

    private void write (string path, string content) {
        try { FileUtils.set_contents (path, content); }
        catch (FileError e) { assert_not_reached (); }
    }

    private string read (string path) {
        string content = "";
        try { FileUtils.get_contents (path, out content); }
        catch (FileError e) { assert_not_reached (); }
        return content;
    }

    private void create_shortcut_file (string path, uint appid, string launch_options) {
        try {
            ProtonPlus.Utils.VDF.Shortcuts.create_new_shortcuts_file_at (path);
            var shortcuts = ProtonPlus.Utils.VDF.Shortcuts.load (path);
            ProtonPlus.Utils.VDF.Shortcut shortcut = {};
            shortcut.AppID = (int32) appid;
            shortcut.AllowDesktopConfig = true;
            shortcut.AllowOverlay = true;
            shortcut.AppName = "Fixture shortcut";
            shortcut.DevkitGameID = "";
            shortcut.Exe = "";
            shortcut.FlatpakAppID = "";
            shortcut.LaunchOptions = launch_options;
            shortcut.ShortcutPath = "";
            shortcut.StartDir = "";
            shortcut.Icon = "";
            shortcuts.append_shortcut (shortcut);
            shortcuts.save ();
        } catch (Error e) {
            assert_not_reached ();
        }
    }

    private Launchers.Steam steam (string root) {
        var launcher = new Launchers.Steam (Launcher.InstallationTypes.SNAP);
        launcher.directory = root;
        return launcher;
    }

    private void set_running (SessionFixture backend, SteamRestartTarget target) {
        var processes = new Gee.ArrayList<SteamProcessRecord> ();
        processes.add (new SteamProcessRecord (101, Path.build_filename (target.data_root, "steam"), target.data_root, 100));
        backend.native_query = new NativeProcessQuery (true, processes);
    }

    private SteamConfigurationService service_for (string root, SessionFixture backend,
        out SteamRestartManager manager, ShortcutFixture? shortcuts = null,
        SteamRestartStateStore? state_store = null) {
        var sessions = new SteamSessionService (backend);
        manager = new SteamRestartManager (sessions, state_store
            ?? new SteamRestartStateStore (Path.build_filename (root, "restart-state.json")));
        var service = new SteamConfigurationService (sessions, manager, shortcuts);
        manager.configure_configuration_reconciler (service);
        return service;
    }

    private void prepare_text_files (string root, out string config, out string localconfig) {
        make_directory (Path.build_filename (root, "config"));
        make_directory (Path.build_filename (root, "userdata", "1", "config"));
        config = Path.build_filename (root, "config", "config.vdf");
        localconfig = Path.build_filename (root, "userdata", "1", "config", "localconfig.vdf");
        write (config, CONFIG);
        write (localconfig, LOCALCONFIG);
    }

    private void test_default_and_game_compatibility_lifecycle () {
        var root = temporary_root (); string config; string localconfig;
        prepare_text_files (root, out config, out localconfig);
        var backend = new SessionFixture (); SteamRestartManager manager;
        var service = service_for (root, backend, out manager);
        var launcher = steam (root);

        assert (service.change_default_compatibility_tool (launcher, "proton-a").result == SteamConfigurationMutationResult.CHANGED);
        assert (read (config).contains ("proton-a"));
        assert (service.change_default_compatibility_tool (launcher, "proton-a").result == SteamConfigurationMutationResult.UNCHANGED);

        var game = new Games.Steam (42, "Fixture", "Fixture", 0, root, launcher);
        assert (service.change_game_compatibility_tool (game, "proton-b").result == SteamConfigurationMutationResult.CHANGED);
        assert (read (config).contains ("proton-b"));
        assert (service.change_game_compatibility_tool (game, "Default").result == SteamConfigurationMutationResult.CHANGED);
        assert (!read (config).contains ("\"42\""));

        write (config, "not VDF");
        assert (service.change_default_compatibility_tool (launcher, "proton-c").result == SteamConfigurationMutationResult.FAILED);
        assert (read (config) == "not VDF");
    }

    private void test_staged_configuration_reconciles_or_detects_conflict () {
        var root = temporary_root (); string config; string localconfig;
        prepare_text_files (root, out config, out localconfig);
        var backend = new SessionFixture (); var launcher = steam (root); set_running (backend, launcher.get_steam_restart_target ());
        SteamRestartManager manager; var service = service_for (root, backend, out manager);
        var game = new Games.Steam (42, "Fixture", "Fixture", 0, root, launcher);
        var original = read (config);

        assert (service.change_game_compatibility_tool (game, "proton-b").result == SteamConfigurationMutationResult.STAGED);
        assert (read (config) == original);
        backend.native_query = new NativeProcessQuery (true);
        assert (service.reconcile_target (launcher.get_steam_restart_target ()).result == SteamConfigurationMutationResult.CHANGED);
        assert (read (config).contains ("proton-b"));
        assert (manager.clear_verified_configuration (manager.get_pending_changes ().get (0)));

        set_running (backend, launcher.get_steam_restart_target ());
        assert (service.change_game_compatibility_tool (game, "proton-c").result == SteamConfigurationMutationResult.STAGED);
        write (config, read (config).replace ("proton-b", "proton-c"));
        backend.native_query = new NativeProcessQuery (true);
        assert (service.reconcile_target (launcher.get_steam_restart_target ()).result == SteamConfigurationMutationResult.UNCHANGED);
        assert (manager.clear_verified_configuration (manager.get_pending_changes ().get (0)));

        set_running (backend, launcher.get_steam_restart_target ());
        assert (service.change_game_compatibility_tool (game, "proton-d").result == SteamConfigurationMutationResult.STAGED);
        write (config, read (config) + "// unrelated edit\n");
        backend.native_query = new NativeProcessQuery (true);
        assert (service.reconcile_target (launcher.get_steam_restart_target ()).result == SteamConfigurationMutationResult.CHANGED);
        assert (read (config).contains ("proton-d"));
        assert (read (config).contains ("unrelated edit"));
        assert (manager.clear_verified_configuration (manager.get_pending_changes ().get (0)));

        set_running (backend, launcher.get_steam_restart_target ());
        assert (service.change_game_compatibility_tool (game, "proton-e").result == SteamConfigurationMutationResult.STAGED);
        var externally_changed = read (config).replace ("proton-d", "external-tool");
        write (config, externally_changed);
        backend.native_query = new NativeProcessQuery (true);
        assert (service.reconcile_target (launcher.get_steam_restart_target ()).result == SteamConfigurationMutationResult.CONFLICT);
        assert (read (config).contains ("external-tool"));
        assert (read (config).contains ("unrelated edit"));
    }

    private void test_unconfirmed_states_never_apply_pending_configuration () {
        var root = temporary_root (); string config; string localconfig;
        prepare_text_files (root, out config, out localconfig);
        var backend = new SessionFixture (); var launcher = steam (root);
        var target = launcher.get_steam_restart_target (); set_running (backend, target);
        SteamRestartManager manager; var service = service_for (root, backend, out manager);
        var game = new Games.Steam (42, "Fixture", "Fixture", 0, root, launcher);
        var baseline = read (config);

        assert (service.change_game_compatibility_tool (game, "proton-b").result == SteamConfigurationMutationResult.STAGED);
        assert (manager.pending_count () == 1);
        assert (service.reconcile_target (target).result == SteamConfigurationMutationResult.STAGED);
        assert (read (config) == baseline);

        backend.native_query = new NativeProcessQuery (false, null, "fixture unavailable");
        assert (service.reconcile_target (target).result == SteamConfigurationMutationResult.STAGED);
        assert (read (config) == baseline);

        backend.native_query = new NativeProcessQuery (true);
        assert (service.reconcile_target (target).result == SteamConfigurationMutationResult.CHANGED);
        assert (read (config).contains ("proton-b"));
    }

    private void test_missing_and_unconfigured_entry_points_do_not_write () {
        var root = temporary_root (); string config; string localconfig;
        prepare_text_files (root, out config, out localconfig);
        var launcher = steam (root);
        var game = new Games.Steam (42, "Fixture", "Fixture", 0, root, launcher);
        var config_before = read (config); var localconfig_before = read (localconfig);

        SteamConfigurationService.reset_configuration ();
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*SteamConfigurationService is not configured*");
        assert (!launcher.change_default_compatibility_tool ("proton-a"));
        Test.assert_expected_messages ();
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*SteamConfigurationService is not configured*");
        assert (!game.change_compatibility_tool ("proton-b"));
        Test.assert_expected_messages ();
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*SteamConfigurationService is not configured*");
        assert (!game.change_launch_options ("PROTON_LOG=1", localconfig));
        Test.assert_expected_messages ();
        assert (read (config) == config_before);
        assert (read (localconfig) == localconfig_before);

        var backend = new SessionFixture (); SteamRestartManager manager;
        var service = service_for (root, backend, out manager);
        FileUtils.remove (config);
        assert (service.change_default_compatibility_tool (launcher, "proton-a").result == SteamConfigurationMutationResult.FAILED);
        assert (!FileUtils.test (config, FileTest.EXISTS));
        FileUtils.remove (localconfig);
        assert (service.change_game_launch_options (game, "PROTON_LOG=1", localconfig).result == SteamConfigurationMutationResult.FAILED);
        assert (!FileUtils.test (localconfig, FileTest.EXISTS));

        var non_steam = new Games.Steam.non_steam (9, "Fixture shortcut", "", "Default", launcher);
        assert (service.change_game_launch_options (non_steam, "PROTON_LOG=1", localconfig).result == SteamConfigurationMutationResult.FAILED);
        var shortcuts = Path.build_filename (root, "userdata", "1", "config", "shortcuts.vdf");
        assert (!FileUtils.test (shortcuts, FileTest.EXISTS));
        write (shortcuts, "not a binary VDF");
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Unexpected byte*");
        var profile = new SteamProfile (launcher, "Fixture", "76561197960265729",
            Path.build_filename (root, "userdata", "1"));
        Test.assert_expected_messages ();
        launcher.profile = profile;
        assert (service.change_game_launch_options (non_steam, "PROTON_LOG=1", localconfig).result
            == SteamConfigurationMutationResult.FAILED);
        assert (read (shortcuts) == "not a binary VDF");
    }

    private void test_launch_options_preserve_raw_values_and_absence () {
        var root = temporary_root (); string config; string localconfig;
        prepare_text_files (root, out config, out localconfig);
        var backend = new SessionFixture (); SteamRestartManager manager;
        var service = service_for (root, backend, out manager);
        var launcher = steam (root); var game = new Games.Steam (42, "Fixture", "Fixture", 0, root, launcher);
        var opaque = "PROTON_LOG=1 \"quoted value\" %command%";
        assert (service.change_game_launch_options (game, opaque, localconfig).result == SteamConfigurationMutationResult.CHANGED);
        assert (read (localconfig).contains ("\\\"quoted value\\\""));
        assert (service.change_game_launch_options (game, opaque, localconfig).result == SteamConfigurationMutationResult.UNCHANGED);
        assert (service.change_game_launch_options (game, "", localconfig).result == SteamConfigurationMutationResult.CHANGED);
        assert (!read (localconfig).contains ("LaunchOptions"));
        write (localconfig, "not VDF");
        assert (service.change_game_launch_options (game, opaque, localconfig).result == SteamConfigurationMutationResult.FAILED);
        assert (read (localconfig) == "not VDF");
    }

    private void test_non_steam_launch_options_stage_and_reconcile_exactly () {
        var root = temporary_root (); string config; string localconfig;
        prepare_text_files (root, out config, out localconfig);
        var shortcut_path = Path.build_filename (root, "userdata", "1", "config", "shortcuts.vdf");
        create_shortcut_file (shortcut_path, 9, "OLD=1");
        var launcher = steam (root);
        var profile = new SteamProfile (launcher, "Fixture", "76561197960265729", Path.build_filename (root, "userdata", "1"));
        launcher.profile = profile;
        var game = new Games.Steam.non_steam (9, "Fixture shortcut", "OLD=1", "Default", launcher);
        var backend = new SessionFixture (); var target = launcher.get_steam_restart_target (); set_running (backend, target);
        SteamRestartManager manager; var service = service_for (root, backend, out manager);
        var opaque = "PROTON_LOG=1 \"two words\" %command%";
        var before = read (shortcut_path);

        var outcome = service.change_game_launch_options (game, opaque, localconfig);
        assert (outcome.result == SteamConfigurationMutationResult.STAGED);
        assert (manager.pending_count () == 1);
        assert (read (shortcut_path) == before);
        backend.native_query = new NativeProcessQuery (true);
        assert (service.reconcile_target (target).result == SteamConfigurationMutationResult.CHANGED);
        try {
            assert (ProtonPlus.Utils.VDF.Shortcuts.load (shortcut_path).get_shortcut_by_appid (9).LaunchOptions
                == opaque.replace ("\"", "\\\""));
        } catch (Error e) {
            assert_not_reached ();
        }
    }

    private void test_persistence_failure_preserves_configuration_state () {
        var root = temporary_root (); string config; string localconfig;
        prepare_text_files (root, out config, out localconfig);
        var launcher = steam (root); var target = launcher.get_steam_restart_target ();
        var backend = new SessionFixture (); set_running (backend, target);
        var store = new FailingStateStore (Path.build_filename (root, "restart-state.json"));
        store.fail_saves = true;
        SteamRestartManager manager;
        var service = service_for (root, backend, out manager, null, store);
        var game = new Games.Steam (42, "Fixture", "Fixture", 0, root, launcher);
        var baseline = read (config);

        assert (service.change_game_compatibility_tool (game, "proton-b").result
            == SteamConfigurationMutationResult.PERSISTENCE_FAILED);
        assert (manager.pending_count () == 0);
        assert (read (config) == baseline);

        store.fail_saves = false;
        assert (service.change_game_compatibility_tool (game, "proton-b").result
            == SteamConfigurationMutationResult.STAGED);
        backend.native_query = new NativeProcessQuery (true);
        assert (service.reconcile_target (target).result == SteamConfigurationMutationResult.CHANGED);
        store.fail_saves = true;
        assert (!service.verify_target_after_session (target));
        assert (manager.pending_count () == 1);
        assert (manager.get_pending_changes ().get (0).receipt.configuration_intent.desired == "proton-b");
    }

    private void test_all_persisted_intents_overlay_after_service_reload () {
        var root = temporary_root (); string config; string localconfig;
        prepare_text_files (root, out config, out localconfig);
        var shortcut_path = Path.build_filename (root, "userdata", "1", "config", "shortcuts.vdf");
        create_shortcut_file (shortcut_path, 9, "OLD=1");
        var launcher = steam (root);
        var profile = new SteamProfile (launcher, "Fixture", "76561197960265729",
            Path.build_filename (root, "userdata", "1"));
        launcher.profile = profile;
        var target = launcher.get_steam_restart_target ();
        var backend = new SessionFixture (); set_running (backend, target);
        SteamRestartManager manager; var service = service_for (root, backend, out manager);
        var game = new Games.Steam (42, "Fixture", "Fixture", 0, root, launcher);
        var non_steam = new Games.Steam.non_steam (9, "Fixture shortcut", "OLD=1", "Default", launcher);
        var normal_options = "PROTON_LOG=1 \"ordinary value\" %command%";
        var shortcut_options = "PROTON_LOG=1 \"shortcut value\" %command%";
        var config_before = read (config); var localconfig_before = read (localconfig);

        assert (service.change_default_compatibility_tool (launcher, "proton-b").result
            == SteamConfigurationMutationResult.STAGED);
        assert (service.change_game_launch_options (game, normal_options, localconfig).result
            == SteamConfigurationMutationResult.STAGED);
        assert (service.change_game_launch_options (non_steam, shortcut_options, localconfig).result
            == SteamConfigurationMutationResult.STAGED);
        assert (run_shortcut_install (service, profile).result == SteamConfigurationMutationResult.STAGED);
        assert (manager.pending_count () == 4);

        var restored_backend = new SessionFixture (); set_running (restored_backend, target);
        SteamRestartManager restored_manager;
        var restored = service_for (root, restored_backend, out restored_manager);
        var restored_launcher = steam (root);
        restored_launcher.compatibility_tool_hashtable = new HashTable<uint, string> (null, null);
        var restored_profile = new SteamProfile (restored_launcher, "Fixture", "76561197960265729",
            Path.build_filename (root, "userdata", "1"));
        restored_launcher.profile = restored_profile;
        restored_profile.launch_options_hashtable = new HashTable<uint, string> (null, null);
        restored_profile.non_steam_games = new List<Games.Steam> ();
        var restored_non_steam = new Games.Steam.non_steam (9, "Fixture shortcut", "OLD=1", "Default", restored_launcher);
        restored_profile.non_steam_games.append (restored_non_steam);

        restored.overlay_launcher_effective_state (restored_launcher);
        restored.overlay_profile_effective_state (restored_profile);
        assert (restored_manager.pending_count () == 4);
        assert (restored_launcher.compatibility_tool_hashtable.get (0) == "proton-b");
        assert (restored_profile.launch_options_hashtable.get (42) == normal_options);
        assert (restored_non_steam.launch_options == shortcut_options);
        assert (restored.protonplus_shortcut_is_effectively_installed (restored_profile));
        assert (read (config) == config_before);
        assert (read (localconfig) == localconfig_before);
    }

    private void test_reopened_manager_applies_after_manual_stop_and_verifies_new_session () {
        var root = temporary_root (); string config; string localconfig;
        prepare_text_files (root, out config, out localconfig);
        var launcher = steam (root); var target = launcher.get_steam_restart_target ();
        var backend = new SessionFixture (); set_running (backend, target);
        SteamRestartManager manager; var service = service_for (root, backend, out manager);
        var game = new Games.Steam (42, "Fixture", "Fixture", 0, root, launcher);
        assert (service.change_game_compatibility_tool (game, "proton-b").result
            == SteamConfigurationMutationResult.STAGED);

        SteamRestartManager reopened_manager;
        service_for (root, backend, out reopened_manager);
        assert (reopened_manager.pending_count () == 1);
        backend.native_query = new NativeProcessQuery (true);
        reopened_manager.reconcile_target (target);
        assert (read (config).contains ("proton-b"));
        assert (reopened_manager.pending_count () == 1);

        var processes = new Gee.ArrayList<SteamProcessRecord> ();
        processes.add (new SteamProcessRecord (102, Path.build_filename (target.data_root, "steam"),
            target.data_root, 200));
        backend.native_query = new NativeProcessQuery (true, processes);
        reopened_manager.reconcile_target (target);
        assert (reopened_manager.pending_count () == 0);
    }

    private void test_effective_state_survives_service_reload_without_writing_disk () {
        var root = temporary_root (); string config; string localconfig;
        prepare_text_files (root, out config, out localconfig);
        var launcher = steam (root); var backend = new SessionFixture (); var target = launcher.get_steam_restart_target ();
        SteamRestartManager manager; var service = service_for (root, backend, out manager);
        assert (service.change_default_compatibility_tool (launcher, "proton-a").result == SteamConfigurationMutationResult.CHANGED);
        set_running (backend, target);
        assert (service.change_default_compatibility_tool (launcher, "proton-b").result == SteamConfigurationMutationResult.STAGED);
        var on_disk = read (config);

        var restored_backend = new SessionFixture (); set_running (restored_backend, target);
        SteamRestartManager restored_manager;
        var restored = service_for (root, restored_backend, out restored_manager);
        var reloaded_launcher = steam (root);
        reloaded_launcher.compatibility_tool_hashtable = new HashTable<uint, string> (null, null);
        restored.overlay_launcher_effective_state (reloaded_launcher);
        assert (reloaded_launcher.compatibility_tool_hashtable.get (0) == "proton-b");
        assert (read (config) == on_disk);
        assert (restored.change_default_compatibility_tool (reloaded_launcher, "proton-a").result == SteamConfigurationMutationResult.UNCHANGED);
        assert (restored_manager.pending_count () == 0);
        assert (read (config) == on_disk);
    }

    private void test_shortcut_presence_is_host_independent_and_coalesces () {
        var root = temporary_root (); string config; string localconfig;
        prepare_text_files (root, out config, out localconfig);
        var launcher = steam (root);
        var profile = new SteamProfile (launcher, "Fixture", "76561197960265729", Path.build_filename (root, "userdata", "1"));
        launcher.profile = profile;
        var backend = new SessionFixture (); var target = launcher.get_steam_restart_target (); set_running (backend, target);
        var shortcuts = new ShortcutFixture (); SteamRestartManager manager;
        var service = service_for (root, backend, out manager, shortcuts);
        assert (run_shortcut_install (service, profile).result == SteamConfigurationMutationResult.STAGED);
        assert (run_shortcut_install (service, profile).result == SteamConfigurationMutationResult.UNCHANGED);
        assert (manager.pending_count () == 1);
        assert (run_shortcut_remove (service, profile).result == SteamConfigurationMutationResult.UNCHANGED);
        assert (manager.pending_count () == 0);
        assert (!FileUtils.test (Path.build_filename (profile.userdata_path, "config", "shortcuts.vdf"), FileTest.EXISTS));
        backend.native_query = new NativeProcessQuery (true);
        shortcuts.install_result = false;
        assert (run_shortcut_install (service, profile).result == SteamConfigurationMutationResult.FAILED);
        assert (shortcuts.installs == 1);
        assert (!FileUtils.test (Path.build_filename (profile.userdata_path, "config", "shortcuts.vdf"), FileTest.EXISTS));
        shortcuts.install_result = true;
        assert (run_shortcut_install (service, profile).result == SteamConfigurationMutationResult.CHANGED);
        assert (shortcuts.installs == 2);
        assert (service.protonplus_shortcut_is_effectively_installed (profile));
        assert (run_shortcut_remove (service, profile).result == SteamConfigurationMutationResult.CHANGED);
        assert (shortcuts.removals == 1);
        assert (!service.protonplus_shortcut_is_effectively_installed (profile));
    }

    private SteamConfigurationMutation run_shortcut_install (SteamConfigurationService service, SteamProfile profile) {
        var loop = new MainLoop (); SteamConfigurationMutation? result = null;
        service.install_protonplus_shortcut.begin (profile, (obj, response) => { result = service.install_protonplus_shortcut.end (response); loop.quit (); });
        loop.run (); return (!) result;
    }

    private SteamConfigurationMutation run_shortcut_remove (SteamConfigurationService service, SteamProfile profile) {
        var loop = new MainLoop (); SteamConfigurationMutation? result = null;
        service.remove_protonplus_shortcut.begin (profile, (obj, response) => { result = service.remove_protonplus_shortcut.end (response); loop.quit (); });
        loop.run (); return (!) result;
    }

    public void register_tests () {
        Test.add_func ("/steam-configuration/default-and-game-compatibility-lifecycle", test_default_and_game_compatibility_lifecycle);
        Test.add_func ("/steam-configuration/staged-reconciliation-and-conflict", test_staged_configuration_reconciles_or_detects_conflict);
        Test.add_func ("/steam-configuration/unconfirmed-states-never-apply", test_unconfirmed_states_never_apply_pending_configuration);
        Test.add_func ("/steam-configuration/missing-and-unconfigured-entry-points-do-not-write", test_missing_and_unconfigured_entry_points_do_not_write);
        Test.add_func ("/steam-configuration/launch-options-raw-values-and-absence", test_launch_options_preserve_raw_values_and_absence);
        Test.add_func ("/steam-configuration/non-steam-launch-options-stage-and-reconcile", test_non_steam_launch_options_stage_and_reconcile_exactly);
        Test.add_func ("/steam-configuration/persistence-failure-preserves-configuration-state", test_persistence_failure_preserves_configuration_state);
        Test.add_func ("/steam-configuration/all-persisted-intents-overlay-after-reload", test_all_persisted_intents_overlay_after_service_reload);
        Test.add_func ("/steam-configuration/reopened-manager-manual-stop-and-new-session", test_reopened_manager_applies_after_manual_stop_and_verifies_new_session);
        Test.add_func ("/steam-configuration/effective-state-reload-does-not-write", test_effective_state_survives_service_reload_without_writing_disk);
        Test.add_func ("/steam-configuration/shortcut-presence-host-independent", test_shortcut_presence_is_host_independent_and_coalesces);
    }
}
