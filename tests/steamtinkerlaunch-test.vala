namespace AppTests.SteamTinkerLaunchTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;

    private class FixtureJob : ProtonPlus.Services.InstallJob {
        private string fixture_path;
        public FixtureJob (Tool tool, string home, string fixture_path) {
            base (new Release (
                "Steam Tinker Launch", "", "", Models.Assets.Asset.from_download_url ("https://fixtures.invalid/steamtinkerlaunch.zip"),
                "", 0, "fixture-stl", "fixture-stl", Release.Kind.STEAM_TINKER_LAUNCH
            ), tool, ProtonPlus.Services.InstallJob.Mode.STEAM_TINKER_LAUNCH, null, home);
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

    private class SequentialProcessQuery : Object, ProtonPlus.Services.CompatibilityProcessQueryBackend {
        private ProtonPlus.Services.CompatibilityProcessInspectionResult first;
        private ProtonPlus.Services.CompatibilityProcessInspectionResult second;
        public int calls { get; private set; default = 0; }

        public SequentialProcessQuery (
            ProtonPlus.Services.CompatibilityProcessInspectionResult first,
            ProtonPlus.Services.CompatibilityProcessInspectionResult second
        ) {
            this.first = first;
            this.second = second;
        }

        public async ProtonPlus.Services.CompatibilityProcessInspectionResult inspect_processes () {
            calls++;
            return calls == 1 ? first : second;
        }
    }

    private class CommandFailureWorkflow : ProtonPlus.Services.SteamTinkerLaunchWorkflow {
        private string failure_fragment;
        private bool system_available;
        private bool failure_triggered = false;

        public CommandFailureWorkflow (string failure_fragment, bool system_available = false) {
            this.failure_fragment = failure_fragment;
            this.system_available = system_available;
        }

        protected override async bool system_installation_available () {
            return system_available;
        }

        protected override async ProtonPlus.Utils.CommandResult run_command (string command) {
            if (!failure_triggered && command.contains (failure_fragment)) {
                failure_triggered = true;
                return new ProtonPlus.Utils.CommandResult ("", "fixture command failure", 23);
            }
            if (command.has_prefix ("chmod "))
                return yield base.run_command (command);
            return new ProtonPlus.Utils.CommandResult ("", "", 0);
        }
    }

    public void register_tests () {
        Test.add_func ("/steamtinkerlaunch/install-update-and-remove-managed-layout", test_install_update_and_remove_managed_layout);
        Test.add_func ("/steamtinkerlaunch/replacement-link-failure-rolls-back", test_replacement_link_failure_rolls_back);
        Test.add_func ("/steamtinkerlaunch/executable-preparation-failure-stops-before-replacement", test_executable_preparation_failure_stops_before_replacement);
        Test.add_func ("/steamtinkerlaunch/compat-del-failure-restores-external-and-managed-installs", test_compat_del_failure_restores_external_and_managed_installs);
        Test.add_func ("/steamtinkerlaunch/compat-add-failure-restores-external-and-managed-installs", test_compat_add_failure_restores_external_and_managed_installs);
        Test.add_func ("/steamtinkerlaunch/system-compat-del-failure-stops-before-backups", test_system_compat_del_failure_stops_before_backups);
        Test.add_func ("/steamtinkerlaunch/remove-compat-del-failure-preserves-installation", test_remove_compat_del_failure_preserves_installation);
        Test.add_func ("/steamtinkerlaunch/final-process-check-preserves-installations", test_final_process_check_preserves_installations);
        Test.add_func ("/steamtinkerlaunch/finalization-uses-launcher-capabilities", test_finalization_uses_launcher_capabilities);
        Test.add_func ("/steamtinkerlaunch/yad-version-classification", test_yad_version_classification);
    }

    private void test_yad_version_classification () {
        assert (Services.SteamTinkerLaunchYadCompatibility.classify_version_output ("7.1 (GTK+ 3.24.0)") ==
            Services.SteamTinkerLaunchYadCompatibility.Status.TOO_OLD);
        assert (Services.SteamTinkerLaunchYadCompatibility.classify_version_output ("7.2 (GTK+ 3.24.0)") ==
            Services.SteamTinkerLaunchYadCompatibility.Status.SUPPORTED);
        assert (Services.SteamTinkerLaunchYadCompatibility.classify_version_output ("14.1 (GTK+ 3.24.0)") ==
            Services.SteamTinkerLaunchYadCompatibility.Status.SUPPORTED);
        assert (Services.SteamTinkerLaunchYadCompatibility.classify_version_output ("15.0 (GTK+ 3.24.0)") ==
            Services.SteamTinkerLaunchYadCompatibility.Status.INCOMPATIBLE_15);
        assert (Services.SteamTinkerLaunchYadCompatibility.classify_version_output ("15,2 (GTK+ 3.24.0)") ==
            Services.SteamTinkerLaunchYadCompatibility.Status.INCOMPATIBLE_15);
        assert (Services.SteamTinkerLaunchYadCompatibility.classify_version_output ("16.0 (GTK+ 3.24.0)") ==
            Services.SteamTinkerLaunchYadCompatibility.Status.SUPPORTED);
        assert (Services.SteamTinkerLaunchYadCompatibility.classify_version_output ("unknown") ==
            Services.SteamTinkerLaunchYadCompatibility.Status.UNKNOWN);

        var nonzero_version_result = new Utils.CommandResult ("15.0 (GTK+ 3.24.50)\n", "", 252);
        assert (Services.SteamTinkerLaunchYadCompatibility.classify_version_result (nonzero_version_result) ==
            Services.SteamTinkerLaunchYadCompatibility.Status.INCOMPATIBLE_15);
    }

    private string temporary_directory () { try { return DirUtils.make_tmp ("protonplus-steamtinkerlaunch-test-XXXXXX"); } catch (FileError e) { critical ("Could not create test directory: %s", e.message); assert_not_reached (); } }
    private string fixture_archive (string root) {
        var encoded = ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename ("fixtures", "archives", "steamtinkerlaunch.zip.base64")).strip (); var path = Path.build_filename (root, "steamtinkerlaunch.zip");
        try { FileUtils.set_data (path, Base64.decode (encoded)); } catch (FileError e) { critical ("Could not write archive fixture: %s", e.message); assert_not_reached (); } return path;
    }
    private Tool tool (string root, Launcher? target_launcher = null) {
        assert (ProtonPlus.Utils.Filesystem.create_directory (root));
        Launcher launcher;
        if (target_launcher == null)
            launcher = new Launcher ("Test", Launcher.InstallationTypes.SYSTEM, "", { root });
        else
            launcher = (!) target_launcher;
        return new Models.Tools.SteamTinkerLaunch (new Group ("Test", "", "", launcher));
    }
    private ReturnCode install (FixtureJob job) { var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR; job.install.begin ((obj, res) => { code = job.install.end (res); loop.quit (); }); loop.run (); return code; }
    private ReturnCode install_replacement (FixtureJob job) { var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR; job.install_replacement.begin ((obj, res) => { code = job.install_replacement.end (res); loop.quit (); }); loop.run (); return code; }
    private ReturnCode update (FixtureJob job) { var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR; job.update.begin ((obj, res) => { code = job.update.end (res); loop.quit (); }); loop.run (); return code; }
    private ReturnCode remove (FixtureJob job) { var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR; job.remove.begin (false, (obj, res) => { code = job.remove.end (res); loop.quit (); }); loop.run (); return code; }
    private ReturnCode workflow_install (ProtonPlus.Services.SteamTinkerLaunchWorkflow workflow, FixtureJob job, bool replace_existing) { var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR; workflow.install.begin (job, replace_existing, (obj, res) => { code = workflow.install.end (res); loop.quit (); }); loop.run (); return code; }
    private ReturnCode workflow_remove (ProtonPlus.Services.SteamTinkerLaunchWorkflow workflow, FixtureJob job) { var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR; workflow.remove.begin (job, (obj, res) => { code = workflow.remove.end (res); loop.quit (); }); loop.run (); return code; }
    private bool delete_directory (string path) { var loop = new MainLoop (); var deleted = false; ProtonPlus.Utils.Filesystem.delete_directory.begin (path, (obj, result) => { deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (result); loop.quit (); }); loop.run (); return deleted; }
    private void no_entries (string directory, string prefix) { try { var entries = Dir.open (directory); string? name; while ((name = entries.read_name ()) != null) assert (!name.has_prefix (prefix)); } catch (FileError e) { critical ("Could not inspect temporary directory: %s", e.message); assert_not_reached (); } }
    private void test_replacement_link_failure_rolls_back () {
        var root = temporary_directory ();
        var cache = Path.build_filename (root, "cache");
        var tools = Path.build_filename (root, "tools");
        var base_location = Path.build_filename (root, ".local", "share", "steamtinkerlaunch");
        var link_parent = Path.build_filename (root, ".local", "bin");
        var link = Path.build_filename (link_parent, "steamtinkerlaunch");
        var external = Path.build_filename (root, "SteamTinkerLaunch");
        Globals.CACHE_PATH = cache;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache));
        assert (ProtonPlus.Utils.Filesystem.create_directory (base_location));
        assert (ProtonPlus.Utils.Filesystem.create_directory (link_parent));
        assert (ProtonPlus.Utils.Filesystem.create_directory (external));
        ProtonPlus.Utils.Filesystem.create_file (
            Path.build_filename (base_location, "marker.txt"), "previous managed\n"
        );
        ProtonPlus.Utils.Filesystem.create_file (
            Path.build_filename (external, "marker.txt"), "previous external\n"
        );
        ProtonPlus.Utils.Filesystem.create_file (link, "blocked link\n");
        var job = new FixtureJob (tool (tools), root, fixture_archive (root));
        assert (ProtonPlus.Services.InstallationService.instance
            .detect_steam_tinker_launch_external_installations (job));

        assert (install_replacement (job) == ReturnCode.FILESYSTEM_ERROR);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename (base_location, "marker.txt")
        ) == "previous managed\n");
        assert (ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename (external, "marker.txt")
        ) == "previous external\n");
        assert (FileUtils.test (link, FileTest.IS_REGULAR));
        no_entries (root, ".protonplus-stl-external-");
        no_entries (Path.get_dirname (base_location), ".protonplus-stl-stage-");
        no_entries (cache, ".protonplus-stl-");
        assert (delete_directory (root));
    }

    private void test_executable_preparation_failure_stops_before_replacement () {
        var root = temporary_directory ();
        var cache = Path.build_filename (root, "cache");
        var tools = Path.build_filename (root, "tools");
        Globals.CACHE_PATH = cache;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache));
        var job = new FixtureJob (tool (tools), root, fixture_archive (root));
        var workflow = new CommandFailureWorkflow ("chmod +x");

        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*prepare executable*");
        assert (workflow_install (workflow, job, false) == ReturnCode.FILESYSTEM_ERROR);
        Test.assert_expected_messages ();
        assert (!FileUtils.test (job.install_location, FileTest.EXISTS));
        assert (!FileUtils.test (Path.build_filename (root, ".local", "bin", "steamtinkerlaunch"), FileTest.EXISTS));
        assert (job.error_message == "Failed to prepare the SteamTinkerLaunch executable");
        no_entries (cache, ".protonplus-stl-");
        assert (delete_directory (root));
    }

    private void test_compat_del_failure_restores_external_and_managed_installs () {
        test_replacement_command_failure_restores_installations (" compat del", "unregister replacement compatibility tool");
    }

    private void test_compat_add_failure_restores_external_and_managed_installs () {
        test_replacement_command_failure_restores_installations (" compat add", "register replacement compatibility tool");
    }

    private void test_replacement_command_failure_restores_installations (string failure_fragment, string warning_fragment) {
        var root = temporary_directory ();
        var cache = Path.build_filename (root, "cache");
        var tools = Path.build_filename (root, "tools");
        var base_location = Path.build_filename (root, ".local", "share", "steamtinkerlaunch");
        var link = Path.build_filename (root, ".local", "bin", "steamtinkerlaunch");
        var external_one = Path.build_filename (root, "SteamTinkerLaunch");
        var external_two = Path.build_filename (root, "stl");
        Globals.CACHE_PATH = cache;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache));
        assert (ProtonPlus.Utils.Filesystem.create_directory (base_location));
        assert (ProtonPlus.Utils.Filesystem.create_directory (external_one));
        assert (ProtonPlus.Utils.Filesystem.create_directory (external_two));
        ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (base_location, "marker.txt"), "previous managed\n");
        ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (external_one, "marker.txt"), "previous external one\n");
        ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (external_two, "marker.txt"), "previous external two\n");
        var job = new FixtureJob (tool (tools), root, fixture_archive (root));
        var workflow = new CommandFailureWorkflow (failure_fragment);
        assert (workflow.detect_external_installations (job));

        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*%s*".printf (warning_fragment));
        assert (workflow_install (workflow, job, true) == ReturnCode.FILESYSTEM_ERROR);
        Test.assert_expected_messages ();
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (base_location, "marker.txt")) == "previous managed\n");
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (external_one, "marker.txt")) == "previous external one\n");
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (external_two, "marker.txt")) == "previous external two\n");
        assert (!FileUtils.test (link, FileTest.EXISTS));
        assert (job.error_message == "Failed to update SteamTinkerLaunch compatibility registration");
        no_entries (root, ".protonplus-stl-external-");
        no_entries (Path.get_dirname (base_location), ".protonplus-stl-");
        no_entries (cache, ".protonplus-stl-");
        assert (delete_directory (root));
    }

    private void test_system_compat_del_failure_stops_before_backups () {
        var root = temporary_directory ();
        var cache = Path.build_filename (root, "cache");
        var tools = Path.build_filename (root, "tools");
        var base_location = Path.build_filename (root, ".local", "share", "steamtinkerlaunch");
        var external = Path.build_filename (root, "SteamTinkerLaunch");
        Globals.CACHE_PATH = cache;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache));
        assert (ProtonPlus.Utils.Filesystem.create_directory (base_location));
        assert (ProtonPlus.Utils.Filesystem.create_directory (external));
        ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (base_location, "marker.txt"), "previous managed\n");
        ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (external, "marker.txt"), "previous external\n");
        var job = new FixtureJob (tool (tools), root, fixture_archive (root));
        var workflow = new CommandFailureWorkflow ("steamtinkerlaunch compat del", true);
        assert (workflow.detect_external_installations (job));

        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*unregister previous compatibility tool*");
        assert (workflow_install (workflow, job, true) == ReturnCode.FILESYSTEM_ERROR);
        Test.assert_expected_messages ();
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (base_location, "marker.txt")) == "previous managed\n");
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (external, "marker.txt")) == "previous external\n");
        no_entries (root, ".protonplus-stl-external-");
        no_entries (Path.get_dirname (base_location), ".protonplus-stl-");
        no_entries (cache, ".protonplus-stl-");
        assert (delete_directory (root));
    }

    private void test_remove_compat_del_failure_preserves_installation () {
        var root = temporary_directory ();
        var tools = Path.build_filename (root, "tools");
        var base_location = Path.build_filename (root, ".local", "share", "steamtinkerlaunch");
        var binary = Path.build_filename (base_location, "steamtinkerlaunch");
        var link_parent = Path.build_filename (root, ".local", "bin");
        var link = Path.build_filename (link_parent, "steamtinkerlaunch");
        assert (ProtonPlus.Utils.Filesystem.create_directory (base_location));
        assert (ProtonPlus.Utils.Filesystem.create_directory (link_parent));
        ProtonPlus.Utils.Filesystem.create_file (binary, "#!/bin/sh\nexit 0\n");
        assert (Posix.chmod (binary, 0755) == 0);
        var link_loop = new MainLoop ();
        var link_created = false;
        ProtonPlus.Utils.Filesystem.make_symlink.begin (link, binary, (obj, result) => {
            link_created = ProtonPlus.Utils.Filesystem.make_symlink.end (result);
            link_loop.quit ();
        });
        link_loop.run ();
        assert (link_created);
        var job = new FixtureJob (tool (tools), root, fixture_archive (root));
        var workflow = new CommandFailureWorkflow (" compat del");

        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*unregister compatibility tool before removal*");
        assert (workflow_remove (workflow, job) == ReturnCode.FILESYSTEM_ERROR);
        Test.assert_expected_messages ();
        assert (FileUtils.test (base_location, FileTest.IS_DIR));
        assert (FileUtils.test (binary, FileTest.IS_REGULAR));
        assert (FileUtils.test (link, FileTest.IS_SYMLINK));
        assert (delete_directory (root));
    }

    private void test_final_process_check_preserves_installations () {
        var root = temporary_directory ();
        var cache = Path.build_filename (root, "cache");
        var tools = Path.build_filename (root, "tools");
        var base_location = Path.build_filename (root, ".local", "share", "steamtinkerlaunch");
        var external = Path.build_filename (root, "SteamTinkerLaunch");
        Globals.CACHE_PATH = cache;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache));
        assert (ProtonPlus.Utils.Filesystem.create_directory (base_location));
        assert (ProtonPlus.Utils.Filesystem.create_directory (external));
        ProtonPlus.Utils.Filesystem.create_file (
            Path.build_filename (base_location, "marker.txt"), "previous managed\n"
        );
        ProtonPlus.Utils.Filesystem.create_file (
            Path.build_filename (external, "marker.txt"), "previous external\n"
        );
        var launcher = new RecordingLauncher (tools);
        var recorder = new RecordingRestartChange ();
        var job = new FixtureJob (tool (tools, launcher), root, fixture_archive (root));
        assert (ProtonPlus.Services.InstallationService.instance
            .detect_steam_tinker_launch_external_installations (job));

        var argv = new Gee.ArrayList<string> ();
        var executable = Path.build_filename (base_location, "steamtinkerlaunch");
        argv.add (executable);
        var records = new Gee.ArrayList<ProtonPlus.Services.CompatibilityProcessRecord> ();
        records.add (new ProtonPlus.Services.CompatibilityProcessRecord (7331, executable, argv));
        var query = new SequentialProcessQuery (
            ProtonPlus.Services.CompatibilityProcessInspectionResult.clear (),
            ProtonPlus.Services.CompatibilityProcessInspectionResult.clear (records)
        );
        ProtonPlus.Services.InstallationService.instance.configure_compatibility_process_guard (
            new ProtonPlus.Services.CompatibilityProcessGuard (query)
        );
        ProtonPlus.Services.InstallationService.instance.configure_steam_change_recorder (recorder);
        var history_events = 0;
        var history_handler = ProtonPlus.Utils.DownloadManager.instance.download_finished.connect (
            (finished_job, success) => { history_events++; }
        );

        assert (install_replacement (job) == ReturnCode.RUNNERS_IN_USE);
        assert (query.calls == 2);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename (base_location, "marker.txt")
        ) == "previous managed\n");
        assert (ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename (external, "marker.txt")
        ) == "previous external\n");
        assert (history_events == 0);
        assert (recorder.receipts.size == 0);
        no_entries (root, ".protonplus-stl-external-");
        no_entries (Path.get_dirname (base_location), ".protonplus-stl-stage-");
        no_entries (cache, ".protonplus-stl-");

        ProtonPlus.Utils.DownloadManager.instance.disconnect (history_handler);
        ProtonPlus.Services.InstallationService.reset_lifecycle_configuration_for_tests ();
        assert (delete_directory (root));
    }

    private void test_install_update_and_remove_managed_layout () {
        var root = temporary_directory (); var cache = Path.build_filename (root, "cache"); var tools = Path.build_filename (root, "tools"); var config = Path.build_filename (root, ".config", "steamtinkerlaunch");
        Globals.CACHE_PATH = cache; assert (ProtonPlus.Utils.Filesystem.create_directory (cache)); assert (ProtonPlus.Utils.Filesystem.create_directory (config)); ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (config, "settings.conf"), "settings\n");
        var launcher = new RecordingLauncher (tools);
        var recorder = new RecordingRestartChange ();
        ProtonPlus.Services.InstallationService.instance.configure_steam_change_recorder (recorder);
        var job = new FixtureJob (tool (tools, launcher), root, fixture_archive (root));
        assert (job.steam_tinker_launch_context != null);
        assert (install (job) == ReturnCode.RUNNER_INSTALLED);
        assert (recorder.receipts.size == 1);
        assert (recorder.receipts.get (0).kind == SteamChangeKind.STEAMTINKERLAUNCH_CHANGED);
        assert (recorder.receipts.get (0).target.id == launcher.get_steam_restart_target ().id);
        assert (FileUtils.test (Path.build_filename (job.install_location, "steamtinkerlaunch"), FileTest.IS_REGULAR));
        assert (FileUtils.test (Path.build_filename (job.install_location, "ProtonPlus.meta"), FileTest.IS_REGULAR));
        assert (update (job) == ReturnCode.RUNNER_UPDATED);
        assert (recorder.receipts.size == 2);
        assert (recorder.receipts.get (1).kind == SteamChangeKind.STEAMTINKERLAUNCH_CHANGED);
        var context = (!) job.steam_tinker_launch_context;
        context.user_requested_removal = true; context.remove_config = true;
        assert (remove (job) == ReturnCode.RUNNER_REMOVED);
        assert (recorder.receipts.size == 3);
        assert (recorder.receipts.get (2).kind == SteamChangeKind.STEAMTINKERLAUNCH_CHANGED);
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
        var workflow = new ProtonPlus.Services.SteamTinkerLaunchWorkflow ();
        var expected_path = "%s%s/SteamTinkerLaunch".printf (
            launcher.directory, job.tool.group.directory
        );

        workflow.finalize_install_success (job);
        assert (launcher.registered_path == expected_path);
        workflow.finalize_removal_success (job);
        assert (launcher.removed_path == expected_path);
        assert (delete_directory (root));
    }
}
