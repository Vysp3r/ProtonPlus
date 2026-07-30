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
        public bool install (ProtonPlus.Utils.VDF.Shortcuts shortcuts) { installs++; return install_result; }
        public bool remove (ProtonPlus.Utils.VDF.Shortcuts shortcuts) { removals++; return remove_result; }
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
        out SteamRestartManager manager, ShortcutFixture? shortcuts = null) {
        var sessions = new SteamSessionService (backend);
        manager = new SteamRestartManager (sessions, new SteamRestartStateStore (Path.build_filename (root, "restart-state.json")));
        return new SteamConfigurationService (sessions, manager, shortcuts);
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

        set_running (backend, launcher.get_steam_restart_target ());
        assert (service.change_game_compatibility_tool (game, "proton-c").result == SteamConfigurationMutationResult.STAGED);
        var externally_changed = read (config).replace ("proton-b", "external-tool");
        write (config, externally_changed + "// unrelated edit\n");
        backend.native_query = new NativeProcessQuery (true);
        assert (service.reconcile_target (launcher.get_steam_restart_target ()).result == SteamConfigurationMutationResult.CONFLICT);
        assert (read (config).contains ("external-tool"));
        assert (read (config).contains ("unrelated edit"));
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
        assert (run_shortcut_install (service, profile).result == SteamConfigurationMutationResult.CHANGED);
        assert (shortcuts.installs == 1);
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
        Test.add_func ("/steam-configuration/launch-options-raw-values-and-absence", test_launch_options_preserve_raw_values_and_absence);
        Test.add_func ("/steam-configuration/effective-state-reload-does-not-write", test_effective_state_survives_service_reload_without_writing_disk);
        Test.add_func ("/steam-configuration/shortcut-presence-host-independent", test_shortcut_presence_is_host_independent_and_coalesces);
    }
}
