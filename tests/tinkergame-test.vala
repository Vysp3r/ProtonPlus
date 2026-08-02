namespace AppTests.TinkerGameTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;

    private class FixtureJob : ProtonPlus.Services.InstallJob {
        private string fixture_path;
        public FixtureJob (Tool tool, string home, string fixture_path) {
            base (new Release (
                "TinkerGame", "", "", Models.Assets.Asset.from_download_url ("https://fixtures.invalid/tinkergame.zip"),
                "", 0, "fixture-tg", "fixture-tg", Release.Kind.TINKERGAME
            ), tool, ProtonPlus.Services.InstallJob.Mode.TINKERGAME, null, home);
            this.fixture_path = fixture_path;
        }
        public override async bool download_archive (string url, string path, out string? error_message) {
            var copied = yield ProtonPlus.Utils.Filesystem.copy_file (fixture_path, path);
            error_message = copied ? null : "Could not copy fixture";
            return copied;
        }
    }

    private class RecordingLauncher : Launcher {
        public string registered_path { get; private set; default = ""; }
        public string removed_path { get; private set; default = ""; }
        private SteamRestartTarget restart_target;

        public RecordingLauncher (string root) {
            base ("Recording launcher", InstallationTypes.SYSTEM, "", { root }, "recording");
            restart_target = SteamRestartTarget.for_native (root);
        }

        public override SteamRestartTarget? get_steam_restart_target () { return restart_target; }

        public override void register_compatibility_tool_from_path (string tool_path) {
            registered_path = tool_path;
        }

        public override void unregister_compatibility_tool_by_path (string tool_path) {
            removed_path = tool_path;
        }
    }

    private class RecordingRestartChange : Object, ProtonPlus.Services.SteamChangeRecorder {
        public Gee.List<SteamChangeReceipt> receipts = new Gee.ArrayList<SteamChangeReceipt> ();
        public ProtonPlus.Services.SteamRestartRecordResult record (SteamChangeReceipt receipt) {
            receipts.add (receipt);
            return ProtonPlus.Services.SteamRestartRecordResult.ADDED;
        }
    }

    public void register_tests () {
        Test.add_func ("/tinkergame/install-update-and-remove-managed-layout", test_install_update_and_remove_managed_layout);
        Test.add_func ("/tinkergame/replacement-link-failure-rolls-back", test_replacement_link_failure_rolls_back);
        Test.add_func ("/tinkergame/finalization-uses-launcher-capabilities", test_finalization_uses_launcher_capabilities);
    }
    private string temporary_directory () { try { return DirUtils.make_tmp ("protonplus-tinkergame-test-XXXXXX"); } catch (FileError e) { critical ("Could not create test directory: %s", e.message); assert_not_reached (); } }
    private string fixture_archive (string root) {
        var encoded = ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename ("fixtures", "archives", "tinkergame.zip.base64")).strip (); var path = Path.build_filename (root, "tinkergame.zip");
        try { FileUtils.set_data (path, Base64.decode (encoded)); } catch (FileError e) { critical ("Could not write archive fixture: %s", e.message); assert_not_reached (); } return path;
    }
    private Tool tool (string root, Launcher? target_launcher = null) {
        assert (ProtonPlus.Utils.Filesystem.create_directory (root));
        Launcher launcher;
        if (target_launcher == null)
            launcher = new Launcher ("Test", Launcher.InstallationTypes.SYSTEM, "", { root });
        else
            launcher = (!) target_launcher;
        return new Models.Tools.TinkerGame (new Group ("Test", "", "", launcher));
    }
    private ReturnCode install (FixtureJob job) { var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR; job.install.begin ((obj, res) => { code = job.install.end (res); loop.quit (); }); loop.run (); return code; }
    private ReturnCode install_replacement (FixtureJob job) { var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR; job.install_replacement.begin ((obj, res) => { code = job.install_replacement.end (res); loop.quit (); }); loop.run (); return code; }
    private ReturnCode update (FixtureJob job) { var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR; job.update.begin ((obj, res) => { code = job.update.end (res); loop.quit (); }); loop.run (); return code; }
    private ReturnCode remove (FixtureJob job) { var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR; job.remove.begin (false, (obj, res) => { code = job.remove.end (res); loop.quit (); }); loop.run (); return code; }
    private bool delete_directory (string path) { var loop = new MainLoop (); var deleted = false; ProtonPlus.Utils.Filesystem.delete_directory.begin (path, (obj, result) => { deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (result); loop.quit (); }); loop.run (); return deleted; }
    private void no_entries (string directory, string prefix) { try { var entries = Dir.open (directory); string? name; while ((name = entries.read_name ()) != null) assert (!name.has_prefix (prefix)); } catch (FileError e) { critical ("Could not inspect temporary directory: %s", e.message); assert_not_reached (); } }
    private void test_replacement_link_failure_rolls_back () {
        var root = temporary_directory (); var cache = Path.build_filename (root, "cache"); var tools = Path.build_filename (root, "tools"); var base_location = Path.build_filename (root, ".local", "share", "tinkergame"); var link_parent = Path.build_filename (root, ".local", "bin"); var link = Path.build_filename (link_parent, "tinkergame");
        Globals.CACHE_PATH = cache; assert (ProtonPlus.Utils.Filesystem.create_directory (cache)); assert (ProtonPlus.Utils.Filesystem.create_directory (base_location)); assert (ProtonPlus.Utils.Filesystem.create_directory (link_parent)); ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (base_location, "marker.txt"), "previous tg\n"); ProtonPlus.Utils.Filesystem.create_file (link, "blocked link\n");
        var job = new FixtureJob (tool (tools), root, fixture_archive (root));
        assert (install_replacement (job) == ReturnCode.FILESYSTEM_ERROR); assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (base_location, "marker.txt")) == "previous tg\n"); assert (FileUtils.test (link, FileTest.IS_REGULAR)); no_entries (Path.get_dirname (base_location), ".protonplus-tg-stage-"); no_entries (cache, ".protonplus-tg-"); assert (delete_directory (root));
    }

    private void test_install_update_and_remove_managed_layout () {
        var root = temporary_directory (); var cache = Path.build_filename (root, "cache"); var tools = Path.build_filename (root, "tools"); var config = Path.build_filename (root, ".config", "tinkergame");
        Globals.CACHE_PATH = cache; assert (ProtonPlus.Utils.Filesystem.create_directory (cache)); assert (ProtonPlus.Utils.Filesystem.create_directory (config)); ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (config, "settings.conf"), "settings\n");
        var launcher = new RecordingLauncher (tools);
        var recorder = new RecordingRestartChange ();
        ProtonPlus.Services.InstallationService.instance.configure_steam_change_recorder (recorder);
        var job = new FixtureJob (tool (tools, launcher), root, fixture_archive (root));
        assert (job.tinker_game_context != null);
        assert (install (job) == ReturnCode.RUNNER_INSTALLED);
        assert (recorder.receipts.size == 1);
        assert (recorder.receipts.get (0).kind == SteamChangeKind.TINKERGAME_CHANGED);
        assert (recorder.receipts.get (0).target.id == launcher.get_steam_restart_target ().id);
        assert (FileUtils.test (Path.build_filename (job.install_location, "tinkergame"), FileTest.IS_REGULAR));
        assert (FileUtils.test (Path.build_filename (job.install_location, "ProtonPlus.meta"), FileTest.IS_REGULAR));
        assert (update (job) == ReturnCode.RUNNER_UPDATED);
        assert (recorder.receipts.size == 2);
        assert (recorder.receipts.get (1).kind == SteamChangeKind.TINKERGAME_CHANGED);
        var context = (!) job.tinker_game_context;
        context.user_requested_removal = true; context.remove_config = true;
        assert (remove (job) == ReturnCode.RUNNER_REMOVED);
        assert (recorder.receipts.size == 3);
        assert (recorder.receipts.get (2).kind == SteamChangeKind.TINKERGAME_CHANGED);
        assert (!FileUtils.test (job.install_location, FileTest.EXISTS));
        assert (!FileUtils.test (config, FileTest.EXISTS));
        ProtonPlus.Services.InstallationService.reset_lifecycle_configuration_for_tests ();
        assert (delete_directory (root));
    }

    private void test_finalization_uses_launcher_capabilities () {
        var root = temporary_directory ();
        var tools = Path.build_filename (root, "tools");
        assert (ProtonPlus.Utils.Filesystem.create_directory (tools));
        var launcher = new RecordingLauncher (tools);
        var job = new FixtureJob (tool (tools, launcher), root, fixture_archive (root));
        var workflow = new ProtonPlus.Services.TinkerGameWorkflow ();
        var expected_path = "%s%s/TinkerGame".printf (
            launcher.directory, job.tool.group.directory
        );

        workflow.finalize_install_success (job);
        assert (launcher.registered_path == expected_path);
        workflow.finalize_removal_success (job);
        assert (launcher.removed_path == expected_path);
        assert (delete_directory (root));
    }
}
