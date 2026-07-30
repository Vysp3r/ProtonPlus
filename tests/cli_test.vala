namespace AppTests.CliTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Models.Tools;
    using ProtonPlus.Providers.Sources;
    using ProtonPlus.Services;

    private enum FixtureJobBehavior { NORMAL, CANCEL_DOWNLOAD, FAIL_PROMOTION }

    private class StaticReleaseSource : Object, ReleaseSource {
        private Release release;

        public StaticReleaseSource (Release release) {
            this.release = release;
        }

        public async ReleasePageResult fetch_page (
            ProviderDefinition definition, int requested_page, int limit
        ) {
            var releases = new Gee.LinkedList<Release> ();
            releases.add (release);
            return ReleasePageResult.success (new ReleasePage (releases, requested_page + 1, false));
        }
    }

    private class FixtureSteamLauncher : Launcher {
        private SteamRestartTarget target;

        public FixtureSteamLauncher (string root) {
            base ("Steam fixture", InstallationTypes.SYSTEM, "", { root }, "fixture-steam",
                null, root, "steam", "steam-system");
            target = SteamRestartTarget.for_native (root, "Steam", "steam.desktop");
        }

        public override SteamRestartTarget? get_steam_restart_target () {
            return target;
        }
    }

    private class RecordingSteamChange : Object, SteamChangeRecorder {
        public SteamRestartRecordResult next_result = SteamRestartRecordResult.ADDED;
        public Gee.List<SteamChangeReceipt> receipts = new Gee.ArrayList<SteamChangeReceipt> ();

        public SteamRestartRecordResult record (SteamChangeReceipt receipt) {
            receipts.add (receipt);
            return next_result;
        }
    }

    private class EmptyCompatibilityProcessQuery : Object, CompatibilityProcessQueryBackend {
        public Gee.List<CompatibilityProcessRecord> query_processes () {
            return new Gee.ArrayList<CompatibilityProcessRecord> ();
        }
    }

    private class FixtureJob : InstallJob {
        private FixtureJobBehavior behavior;

        public FixtureJob (
            Release release,
            ProviderTool tool,
            Mode mode,
            string? installation_location,
            FixtureJobBehavior behavior
        ) {
            base (release, tool, mode, installation_location);
            this.behavior = behavior;
        }

        public override async bool download_archive (string url, string path, out string? error_message) {
            if (behavior != FixtureJobBehavior.CANCEL_DOWNLOAD)
                return yield base.download_archive (url, path, out error_message);
            Utils.Filesystem.create_file (path, "partial fixture download");
            canceled = true;
            error_message = "Download canceled";
            return false;
        }

        public override async bool promote_staged_installation (string staged_install_path) {
            if (behavior == FixtureJobBehavior.FAIL_PROMOTION)
                return false;
            return yield base.promote_staged_installation (staged_install_path);
        }
    }

    private class FixtureHandler : ProtonPlus.CLI.Handler {
        private FixtureJobBehavior behavior;
        public InstallJob? last_job { get; private set; default = null; }

        public FixtureHandler (Gee.LinkedList<Launcher> launchers,
            FixtureJobBehavior behavior = FixtureJobBehavior.NORMAL) {
            base (launchers);
            this.behavior = behavior;
        }

        protected override InstallJob create_install_job (
            Release release,
            ProviderTool provider_tool,
            InstallJob.Mode mode,
            string? installation_location
        ) {
            var job = new FixtureJob (release, provider_tool, mode, installation_location, behavior);
            last_job = job;
            return job;
        }
    }

    public void register_tests () {
        Test.add_func ("/cli/exit-codes", test_exit_codes);
        Test.add_func ("/cli/steam-lifecycle-receipts", test_steam_lifecycle_receipts);
    }

    private int run_cli (string[] args, ProtonPlus.CLI.Handler? supplied_handler = null) {
        var loop = new MainLoop ();
        var handler = supplied_handler ?? new ProtonPlus.CLI.Handler ();
        var exit_code = -1;
        stdout.flush ();
        var saved_stdout = Posix.dup (Posix.STDOUT_FILENO);
        var null_stdout = Posix.open ("/dev/null", Posix.O_WRONLY);
        assert (saved_stdout >= 0 && null_stdout >= 0);
        assert (Posix.dup2 (null_stdout, Posix.STDOUT_FILENO) >= 0);

        try {
            handler.run.begin (args, (obj, result) => {
                exit_code = handler.run.end (result);
                loop.quit ();
            });
            loop.run ();
            stdout.flush ();
        } finally {
            assert (Posix.dup2 (saved_stdout, Posix.STDOUT_FILENO) >= 0);
            Posix.close (null_stdout);
            Posix.close (saved_stdout);
        }

        return exit_code;
    }

    private string temporary_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-cli-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create test directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private bool delete_directory (string path) {
        var loop = new MainLoop ();
        var deleted = false;
        Utils.Filesystem.delete_directory.begin (path, (obj, result) => {
            deleted = Utils.Filesystem.delete_directory.end (result);
            loop.quit ();
        });
        loop.run ();
        return deleted;
    }

    private Release release (string title, string tag, string url,
        VariantCompatibility? compatibility = null) {
        var value = new Release (title, "", "", new Models.Assets.Asset ("runner.zip", url),
            "", 0, "fixture-" + tag, tag);
        value.variants.add (new Models.Variant ("default", "Default", "", true, url, compatibility));
        return value;
    }

    private ProviderTool add_runner (
        FixtureSteamLauncher launcher,
        Group group,
        string provider_id,
        string title,
        Release value,
        VariantCompatibility? compatibility = null
    ) {
        var definition = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, provider_id, title, "",
            "https://fixtures.invalid/releases", 1,
            { new VariantDefinition ("default", "Default", "$release_name", true, compatibility) },
            { InstallLayout.template ("default", "$release_name") }
        );
        var runner = new ProviderTool.with_catalog (
            definition, new StaticReleaseSource (value), group,
            InstallLayout.template ("default", "$release_name")
        );
        group.tools.add (runner);
        return runner;
    }

    private FixtureSteamLauncher setup_launcher (
        string root,
        string provider_id,
        string title,
        Release value,
        out ProviderTool runner
    ) {
        assert (Utils.Filesystem.create_directory (root));
        assert (Utils.Filesystem.create_directory (Path.build_filename (root, "compatibilitytools.d")));
        var launcher = new FixtureSteamLauncher (root);
        var group = new Group ("Fixture", "", "/compatibilitytools.d", launcher, "fixture");
        group.tools = new Gee.LinkedList<Tool> ();
        launcher.groups = { group };
        runner = add_runner (launcher, group, provider_id, title, value);
        return launcher;
    }

    private Gee.LinkedList<Launcher> launcher_list (Launcher launcher) {
        var launchers = new Gee.LinkedList<Launcher> ();
        launchers.add (launcher);
        return launchers;
    }

    private void cache_archive (string cache, string url) {
        var archive_dir = Path.build_filename (cache, "archives");
        assert (Utils.Filesystem.create_directory (archive_dir));
        var path = Path.build_filename (archive_dir,
            "%s.zip".printf (Checksum.compute_for_string (ChecksumType.SHA256, url)));
        try {
            FileUtils.set_data (path, Base64.decode (Utils.Filesystem.get_file_content (
                Path.build_filename ("fixtures", "archives", "runner.zip.base64")
            ).strip ()));
        } catch (FileError e) {
            critical ("Could not seed cached archive: %s", e.message);
            assert_not_reached ();
        }
    }

    private void seed_latest_installation (ProviderTool runner, string tag) {
        var directory = Path.build_filename (runner.group.launcher.directory, runner.group.directory,
            "%s Latest".printf (runner.title));
        assert (Utils.Filesystem.create_directory (directory));
        var metadata = new Utils.Metadata ();
        metadata.tag = tag;
        metadata.provider_id = runner.provider_id;
        metadata.tool_id = runner.id;
        metadata.launcher_id = runner.group.launcher.tool_target_id;
        assert (metadata.save (directory));
    }

    private void configure_fixture_services (RecordingSteamChange recorder, string root) {
        InstallationService.instance.configure_steam_change_recorder (recorder);
        InstallationService.instance.configure_compatibility_process_guard (
            new CompatibilityProcessGuard (new EmptyCompatibilityProcessQuery ())
        );
        var sessions = new SteamSessionService ();
        var manager = new SteamRestartManager (sessions,
            new SteamRestartStateStore (Path.build_filename (root, "restart-state.json")));
        SteamConfigurationService.configure (new SteamConfigurationService (sessions, manager));
    }

    private void assert_single_receipt (
        RecordingSteamChange recorder,
        SteamChangeKind kind,
        FixtureSteamLauncher launcher,
        string install_location
    ) {
        assert (recorder.receipts.size == 1);
        var receipt = recorder.receipts.get (0);
        assert (receipt.kind == kind);
        var target = launcher.get_steam_restart_target ();
        assert (target != null);
        assert (receipt.target.id == ((!) target).id);
        assert (receipt.resource_key == Filename.canonicalize (install_location, null));
    }

    private void test_exit_codes () {
        assert (run_cli ({ "protonplus" }) == 1);
        assert (run_cli ({ "protonplus", "version" }) == 0);
        assert (run_cli ({ "protonplus", "help" }) == 0);
        assert (run_cli ({ "protonplus", "unknown" }) == 1);
    }

    private void test_steam_lifecycle_receipts () {
        var root = temporary_directory ();
        var previous_cache = Globals.CACHE_PATH;
        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CACHE_PATH = Path.build_filename (root, "cache");
        Globals.CPU_CAPABILITIES = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        InstallationService.reset_lifecycle_configuration_for_tests ();
        SteamConfigurationService.reset_configuration ();

        try {
            var install_url = "https://fixtures.invalid/install.zip";
            ProviderTool install_runner;
            var install_launcher = setup_launcher (Path.build_filename (root, "install"),
                "fixture-install", "Fixture Install", release ("v2", "v2", install_url), out install_runner);
            cache_archive (Globals.CACHE_PATH, install_url);
            var install_recorder = new RecordingSteamChange ();
            configure_fixture_services (install_recorder, root);
            var install_handler = new FixtureHandler (launcher_list (install_launcher));
            assert (run_cli ({ "protonplus", "install", install_launcher.instance_id,
                install_runner.provider_id, "latest" }, install_handler) == 0);
            assert (install_handler.last_job != null);
            assert_single_receipt (install_recorder, SteamChangeKind.COMPATIBILITY_TOOL_INSTALLED,
                install_launcher, ((!) install_handler.last_job).install_location);

            InstallationService.reset_lifecycle_configuration_for_tests ();
            SteamConfigurationService.reset_configuration ();
            var uninstall_recorder = new RecordingSteamChange ();
            configure_fixture_services (uninstall_recorder, root);
            var uninstall_handler = new FixtureHandler (launcher_list (install_launcher));
            assert (run_cli ({ "protonplus", "uninstall", install_launcher.instance_id,
                install_runner.provider_id, "all" }, uninstall_handler) == 0);
            assert (uninstall_handler.last_job != null);
            assert_single_receipt (uninstall_recorder, SteamChangeKind.COMPATIBILITY_TOOL_REMOVED,
                install_launcher, ((!) uninstall_handler.last_job).install_location);

            var update_url = "https://fixtures.invalid/update.zip";
            ProviderTool update_runner;
            var update_launcher = setup_launcher (Path.build_filename (root, "update"),
                "fixture-update", "Fixture Update", release ("v2", "v2", update_url), out update_runner);
            seed_latest_installation (update_runner, "v1");
            cache_archive (Globals.CACHE_PATH, update_url);
            InstallationService.reset_lifecycle_configuration_for_tests ();
            SteamConfigurationService.reset_configuration ();
            var update_recorder = new RecordingSteamChange ();
            configure_fixture_services (update_recorder, root);
            assert (run_cli ({ "protonplus", "update", update_launcher.instance_id,
                update_runner.provider_id }, new FixtureHandler (launcher_list (update_launcher))) == 0);
            var update_location = Path.build_filename (update_launcher.directory, "compatibilitytools.d",
                "%s Latest".printf (update_runner.title));
            assert_single_receipt (update_recorder,
                SteamChangeKind.COMPATIBILITY_TOOL_UPDATED_OR_REPLACED, update_launcher, update_location);
            assert (run_cli ({ "protonplus", "update", update_launcher.instance_id,
                update_runner.provider_id }, new FixtureHandler (launcher_list (update_launcher))) == 0);
            assert (update_recorder.receipts.size == 1);

            var rejected_handler = new FixtureHandler (launcher_list (update_launcher));
            assert (run_cli ({ "protonplus", "install", update_launcher.instance_id,
                "unknown-runner", "latest" }, rejected_handler) == 1);
            assert (update_recorder.receipts.size == 1);

            var incompatible_url = "https://fixtures.invalid/incompatible.zip";
            ProviderTool incompatible_runner;
            var incompatible_launcher = setup_launcher (Path.build_filename (root, "incompatible"),
                "fixture-incompatible", "Fixture Incompatible", release ("v2", "v2", incompatible_url,
                    VariantCompatibility.for_x86_64_level (X86_64Level.V3)), out incompatible_runner);
            assert (run_cli ({ "protonplus", "install", incompatible_launcher.instance_id,
                incompatible_runner.provider_id, "latest" }, new FixtureHandler (launcher_list (incompatible_launcher))) == 1);
            assert (update_recorder.receipts.size == 1);

            var cancel_url = "https://fixtures.invalid/cancel.zip";
            ProviderTool cancel_runner;
            var cancel_launcher = setup_launcher (Path.build_filename (root, "cancel"),
                "fixture-cancel", "Fixture Cancel", release ("v2", "v2", cancel_url), out cancel_runner);
            var cancel_handler = new FixtureHandler (launcher_list (cancel_launcher), FixtureJobBehavior.CANCEL_DOWNLOAD);
            assert (run_cli ({ "protonplus", "install", cancel_launcher.instance_id,
                cancel_runner.provider_id, "latest" }, cancel_handler) == 1);
            assert (cancel_handler.last_job != null && ((!) cancel_handler.last_job).canceled);
            assert (update_recorder.receipts.size == 1);

            var failed_url = "https://fixtures.invalid/failed.zip";
            ProviderTool failed_runner;
            var failed_launcher = setup_launcher (Path.build_filename (root, "failed"),
                "fixture-failed", "Fixture Failed", release ("v2", "v2", failed_url), out failed_runner);
            cache_archive (Globals.CACHE_PATH, failed_url);
            assert (run_cli ({ "protonplus", "install", failed_launcher.instance_id,
                failed_runner.provider_id, "latest" }, new FixtureHandler (launcher_list (failed_launcher),
                    FixtureJobBehavior.FAIL_PROMOTION)) == 1);
            assert (update_recorder.receipts.size == 1);

            var persistence_url = "https://fixtures.invalid/persistence.zip";
            ProviderTool persistence_runner;
            var persistence_launcher = setup_launcher (Path.build_filename (root, "persistence"),
                "fixture-persistence", "Fixture Persistence", release ("v2", "v2", persistence_url), out persistence_runner);
            cache_archive (Globals.CACHE_PATH, persistence_url);
            InstallationService.reset_lifecycle_configuration_for_tests ();
            SteamConfigurationService.reset_configuration ();
            var persistence_recorder = new RecordingSteamChange ();
            persistence_recorder.next_result = SteamRestartRecordResult.PERSISTENCE_FAILED;
            configure_fixture_services (persistence_recorder, root);
            var persistence_handler = new FixtureHandler (launcher_list (persistence_launcher));
            assert (run_cli ({ "protonplus", "install", persistence_launcher.instance_id,
                persistence_runner.provider_id, "latest" }, persistence_handler) == 0);
            assert (persistence_handler.last_job != null);
            assert (((!) persistence_handler.last_job).steam_restart_warning != null);
            assert (FileUtils.test (((!) persistence_handler.last_job).install_location, FileTest.IS_DIR));
            assert (persistence_recorder.receipts.size == 1);

            InstallationService.reset_lifecycle_configuration_for_tests ();
            SteamConfigurationService.reset_configuration ();
            assert (SteamConfigurationService.instance == null);
            var teardown_url = "https://fixtures.invalid/teardown.zip";
            ProviderTool teardown_runner;
            var teardown_launcher = setup_launcher (Path.build_filename (root, "teardown"),
                "fixture-teardown", "Fixture Teardown", release ("v2", "v2", teardown_url), out teardown_runner);
            cache_archive (Globals.CACHE_PATH, teardown_url);
            assert (run_cli ({ "protonplus", "install", teardown_launcher.instance_id,
                teardown_runner.provider_id, "latest" }, new FixtureHandler (launcher_list (teardown_launcher))) == 0);
            assert (persistence_recorder.receipts.size == 1);
        } finally {
            InstallationService.reset_lifecycle_configuration_for_tests ();
            SteamConfigurationService.reset_configuration ();
            Globals.CPU_CAPABILITIES = previous_capabilities;
            Globals.CACHE_PATH = previous_cache;
            assert (delete_directory (root));
        }
    }
}
