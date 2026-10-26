namespace AppTests.TinkerGameTest {
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Services;

    private class FixtureSource : Object, ProtonPlus.Providers.Sources.ReleaseSource {
        public Release? latest_release;
        public bool fail = false;
        public async Models.Tools.ReleasePageResult fetch_page (
            Models.Providers.ProviderDefinition definition, int page, int limit
        ) {
            if (fail)
                return Models.Tools.ReleasePageResult.failure (ReturnCode.REQUEST_FAILED);
            var releases = new Gee.LinkedList<Release> ();
            if (latest_release != null)
                releases.add (latest_release);
            return Models.Tools.ReleasePageResult.success (new Models.Tools.ReleasePage (releases, page + 1, false));
        }
    }

    private class FixtureWorkflow : TinkerGameWorkflow {
        public bool registration_failure = false;
        public bool revoke_ownership = false;
        public bool incomplete = false;
        public bool unsafe_manifest = false;
        public bool cancel_after_preparation = false;
        protected override async string missing_dependencies () { return ""; }
        protected override async bool write_registration (string path) {
            if (registration_failure)
                return false;
            return yield base.write_registration (path);
        }
        protected override async ReturnCode prepare_staged_installation (InstallJob job, string path) {
            if (incomplete)
                FileUtils.remove (Path.build_filename (path, "lib", "core", "common.sh"));
            if (unsafe_manifest)
                assert (yield Utils.Filesystem.make_symlink (Path.build_filename (path, "compatibilitytool.vdf"),
                    Path.build_filename (Path.get_dirname (job.install_location), "untouched")));
            var result = yield base.prepare_staged_installation (job, path);
            if (cancel_after_preparation)
                job.canceled = true;
            if (revoke_ownership) {
                var metadata = Utils.Metadata.load (job.install_location);
                metadata.tool_id = "external-owner";
                assert (metadata.save (job.install_location));
            }
            return result;
        }
    }

    private class FixtureJob : InstallJob {
        private string archive;
        public bool fail_promotion = false;
        public bool cancel_after_download = false;
        public FixtureJob (Tool tool, string archive, string revision = "fixture-1") {
            base (new Release ("TinkerGame", "", "", new Models.Assets.Asset ("fixture.zip",
                "https://fixtures.invalid/" + revision + ".zip"), "", 0, revision, revision, Release.Kind.TINKER_GAME), tool);
            this.archive = archive;
        }
        public override async bool download_archive (string url, string path, out string? error_message) {
            error_message = null;
            var result = yield Utils.Filesystem.copy_file (archive, path);
            if (cancel_after_download)
                canceled = true;
            return result;
        }
        public override async bool promote_staged_installation (string path) {
            return !fail_promotion && (yield base.promote_staged_installation (path));
        }
    }

    private class RecordingLauncher : Launcher {
        private string target_root;
        public RecordingLauncher (string root) {
            base ("Test", InstallationTypes.SYSTEM, "", { root }, "steam");
            target_root = root;
        }
        public override SteamRestartTarget? get_steam_restart_target () {
            return SteamRestartTarget.for_native (target_root);
        }
        public override void register_compatibility_tool_from_path (string path) {}
        public override void unregister_compatibility_tool_by_path (string path) {}
    }

    private class Recorder : Object, SteamChangeRecorder {
        public Gee.ArrayList<SteamChangeReceipt> receipts = new Gee.ArrayList<SteamChangeReceipt> ();
        public SteamRestartRecordResult record (SteamChangeReceipt receipt) {
            receipts.add (receipt);
            return SteamRestartRecordResult.ADDED;
        }
    }

    private class EmptyCompatibilityProcessQuery : Object, CompatibilityProcessQueryBackend {
        public async CompatibilityProcessInspectionResult inspect_processes () {
            return CompatibilityProcessInspectionResult.clear ();
        }
    }

    private class OwnershipChangeQuery : Object, CompatibilityProcessQueryBackend {
        private string path;
        private int calls = 0;
        public OwnershipChangeQuery (string path) { this.path = path; }
        public async CompatibilityProcessInspectionResult inspect_processes () {
            if (++calls == 2) {
                var metadata = Utils.Metadata.load (path);
                metadata.tool_id = "external-owner";
                assert (metadata.save (path));
            }
            return CompatibilityProcessInspectionResult.clear ();
        }
    }

    private class ActiveProcess : Object, CompatibilityProcessQueryBackend {
        private string executable;
        private int calls = 0;
        public ActiveProcess (string executable) { this.executable = executable; }
        public async CompatibilityProcessInspectionResult inspect_processes () {
            if (++calls == 1)
                return CompatibilityProcessInspectionResult.clear ();
            var argv = new Gee.ArrayList<string> ();
            argv.add (executable);
            var records = new Gee.ArrayList<CompatibilityProcessRecord> ();
            records.add (new CompatibilityProcessRecord (12345, executable, argv));
            return CompatibilityProcessInspectionResult.clear (records);
        }
    }

    public void register_tests () {
        Test.add_func ("/tinkergame/release-discovery-failure-preserves-install", () => run (18));
        Test.add_func ("/tinkergame/automatic-release-update", () => run (17));
        Test.add_func ("/tinkergame/release-discovery", test_release_discovery);
        Test.add_func ("/tinkergame/lifecycle-and-legacy-coexistence", () => run (0));
        Test.add_func ("/tinkergame/promotion-failure-restores-registration", () => run (1));
        Test.add_func ("/tinkergame/registration-failure-preserves-install", () => run (2));
        Test.add_func ("/tinkergame/incomplete-archive", () => run (3));
        Test.add_func ("/tinkergame/cancel", () => run (4));
        Test.add_func ("/tinkergame/active-process-guard", () => run (5));
        Test.add_func ("/tinkergame/migration-preserves-original-and-existing-destination", () => run (6));
        Test.add_func ("/tinkergame/migration-collision-and-retry", () => run (7));
        Test.add_func ("/tinkergame/identities-and-dependencies", test_identities);
        Test.add_func ("/tinkergame/unsupported-targets", () => run (8));
        Test.add_func ("/tinkergame/refuse-unowned-installation", () => run (9));
        Test.add_func ("/tinkergame/registration-symlink-cannot-write-outside-staging", () => run (10));
        Test.add_func ("/tinkergame/migration-cancel-and-retry", () => run (11));
        Test.add_func ("/tinkergame/cancel-after-preparation", () => run (12));
        Test.add_func ("/tinkergame/repair-missing-module-at-current-revision", () => run (13));
        Test.add_func ("/tinkergame/recheck-ownership-before-replacement", () => run (14));
        Test.add_func ("/tinkergame/repair-registration-at-current-revision", () => run (15));
        Test.add_func ("/tinkergame/recheck-ownership-before-removal", () => run (16));
    }

    private void run (int scenario) {
        var loop = new MainLoop ();
        scenario_async.begin (scenario, (obj, res) => { scenario_async.end (res); loop.quit (); });
        loop.run ();
    }

    private async void scenario_async (int scenario) {
        string root;
        try { root = DirUtils.make_tmp ("protonplus-tg-XXXXXX"); }
        catch (Error e) { assert_not_reached (); }
        var previous_cache = Globals.CACHE_PATH;
        Globals.CACHE_PATH = Path.build_filename (root, "cache");
        assert (Utils.Filesystem.create_directory (Globals.CACHE_PATH));
        var archive = Path.build_filename (root, "fixture.zip");
        try {
            FileUtils.set_data (archive, Base64.decode (Utils.Filesystem.get_file_content (
                "fixtures/archives/tinkergame.zip.base64").strip ()));
        } catch (Error e) { assert_not_reached (); }
        var tools = Path.build_filename (root, "tools");
        assert (Utils.Filesystem.create_directory (tools));
        var launcher = new RecordingLauncher (tools);
        var group = new Group ("Proton", "", "", launcher, "proton");
        group.tools = new Gee.LinkedList<Tool> ();
        var source = new FixtureSource ();
        var tool = new Models.Tools.TinkerGame (group, source);
        var legacy = new Models.Tools.SteamTinkerLaunch (group);
        group.tools.add (tool);
        group.tools.add (legacy);
        var legacy_path = Path.build_filename (tools, "SteamTinkerLaunch");
        assert (Utils.Filesystem.create_directory (legacy_path));
        assert (Utils.Filesystem.modify_file (Path.build_filename (legacy_path, "untouched"), "legacy"));
        var workflow = new FixtureWorkflow ();
        var service = InstallationService.instance;
        service.configure_tinker_game_workflow (workflow);
        service.configure_compatibility_process_guard (new CompatibilityProcessGuard (new EmptyCompatibilityProcessQuery ()));
        var recorder = new Recorder ();
        service.configure_steam_change_recorder (recorder);
        var job = new FixtureJob (tool, archive);
        source.latest_release = job.release;
        assert (Utils.Filesystem.modify_file (Path.build_filename (tools, "untouched"), "outside"));
        if (scenario == 3 || scenario == 4 || scenario == 8 || scenario == 9 || scenario == 10 || scenario == 12) {
            workflow.incomplete = scenario == 3;
            workflow.unsafe_manifest = scenario == 10;
            workflow.cancel_after_preparation = scenario == 12;
            if (scenario == 9) {
                assert (Utils.Filesystem.create_directory (job.install_location));
                assert (Utils.Filesystem.modify_file (Path.build_filename (job.install_location, "external"), "external"));
            }
            job.cancel_after_download = scenario == 4;
            if (scenario == 8)
                launcher.installation_type = Launcher.InstallationTypes.FLATPAK;
            var result = yield job.install ();
            assert (result == (scenario == 3 || scenario == 10 ? ReturnCode.INVALID_DATA : scenario == 4 || scenario == 12
                ? ReturnCode.EXTRACTION_FAILED : scenario == 9 ? ReturnCode.INVALID_CONFIGURATION : ReturnCode.UNSUPPORTED_OPERATION));
            if (scenario == 9) {
                assert ((yield job.remove ()) == ReturnCode.INVALID_CONFIGURATION);
                assert (Utils.Filesystem.get_file_content (Path.build_filename (job.install_location, "external")) == "external");
            } else
                assert (!FileUtils.test (job.install_location, FileTest.EXISTS));
            assert (recorder.receipts.size == 0);
        } else {
            assert ((yield job.install ()) == ReturnCode.RUNNER_INSTALLED);
            assert (FileUtils.test (Path.build_filename (job.install_location, "tinkergame"), FileTest.IS_EXECUTABLE));
            assert (Utils.Filesystem.get_file_content (Path.build_filename (job.install_location, "compatibilitytool.vdf")).contains ("Proton-tg"));
            group.refresh_installed_state ();
            assert (tool.is_installed () && legacy.is_installed ());
            assert (job.get_usage_identifier () == "Proton-tg");
            assert (recorder.receipts.size == 1);
            if (scenario == 6 || scenario == 7 || scenario == 11) {
                yield migration_scenario (job, root, scenario == 7, scenario == 11);
            } else if (scenario == 18) {
                source.fail = true;
                assert ((yield job.update ()) == ReturnCode.REQUEST_FAILED);
                assert (Utils.Metadata.load (job.install_location).release_id == "fixture-1");
                assert (job.release.upstream_release_id == "fixture-1");
                assert (recorder.receipts.size == 1);
            } else if (scenario == 17) {
                source.latest_release = new Release ("TinkerGame alpha.15", "", "",
                    new Models.Assets.Asset ("fixture.zip", "https://fixtures.invalid/alpha15.zip"),
                    "", 0, "v0.1.0-alpha.15", "v0.1.0-alpha.15", Release.Kind.TINKER_GAME);
                assert ((yield job.update ()) == ReturnCode.RUNNER_UPDATED);
                assert (Utils.Metadata.load (job.install_location).release_id == "v0.1.0-alpha.15");
                assert (job.release.title == "TinkerGame alpha.15");
                assert ((yield job.update ()) == ReturnCode.NOTHING_TO_UPDATE);
            } else if (scenario == 16) {
                service.configure_compatibility_process_guard (new CompatibilityProcessGuard (
                    new OwnershipChangeQuery (job.install_location)));
                assert ((yield job.remove ()) == ReturnCode.INVALID_CONFIGURATION);
                assert (Utils.Metadata.load (job.install_location).tool_id == "external-owner");
                assert (recorder.receipts.size == 1);
            } else if (scenario == 13 || scenario == 15) {
                var module = scenario == 15 ? Path.build_filename (job.install_location, "toolmanifest.vdf")
                    : Path.build_filename (job.install_location, "lib", "core", "common.sh");
                assert (FileUtils.remove (module) == 0);
                assert ((yield job.update ()) == ReturnCode.RUNNER_UPDATED);
                assert (FileUtils.test (module, FileTest.IS_REGULAR));
                assert (Utils.Metadata.load (job.install_location).release_id == "fixture-1");
            } else {
                workflow.revoke_ownership = scenario == 14;
                var replacement = new FixtureJob (tool, archive, "fixture-2");
                source.latest_release = replacement.release;
                replacement.fail_promotion = scenario == 1;
                workflow.registration_failure = scenario == 2;
                if (scenario == 5)
                    service.configure_compatibility_process_guard (new CompatibilityProcessGuard (
                        new ActiveProcess (Path.build_filename (job.install_location, "tinkergame"))));
                var result = yield replacement.update ();
                if (scenario == 0) {
                    assert (result == ReturnCode.RUNNER_UPDATED);
                    assert (Utils.Metadata.load (job.install_location).release_id == "fixture-2");
                    assert ((yield replacement.update ()) == ReturnCode.NOTHING_TO_UPDATE);
                    assert ((yield replacement.remove ()) == ReturnCode.RUNNER_REMOVED);
                    assert (!FileUtils.test (job.install_location, FileTest.EXISTS));
                    assert (recorder.receipts.size == 3);
                } else {
                    assert (result == (scenario == 5 ? ReturnCode.RUNNERS_IN_USE : scenario == 14 ? ReturnCode.INVALID_CONFIGURATION : ReturnCode.FILESYSTEM_ERROR));
                    assert (Utils.Metadata.load (job.install_location).release_id == "fixture-1");
                    if (scenario == 14)
                        assert (Utils.Metadata.load (job.install_location).tool_id == "external-owner");
                    assert (Utils.Filesystem.get_file_content (Path.build_filename (job.install_location, "compatibilitytool.vdf")).contains ("Proton-tg"));
                    assert (recorder.receipts.size == 1);
                }
            }
        }
        assert (Utils.Filesystem.get_file_content (Path.build_filename (tools, "untouched")) == "outside");
        assert (Utils.Filesystem.get_file_content (Path.build_filename (legacy_path, "untouched")) == "legacy");
        service.reset_lifecycle_configuration ();
        assert (yield Utils.Filesystem.delete_directory (root));
        Globals.CACHE_PATH = previous_cache;
    }

    private async void migration_scenario (InstallJob job, string root, bool collision, bool cancel) {
        var config = Path.build_filename (root, "config");
        var old = Path.build_filename (config, "steamtinkerlaunch");
        var target = Path.build_filename (config, "tinkergame");
        assert (Utils.Filesystem.create_directory (old));
        var raw = "CUSTOM=\"steamtinkerlaunch run 'quoted value'\"\nPATH='/old/SteamTinkerLaunch'\n";
        assert (Utils.Filesystem.modify_file (Path.build_filename (old, "SteamTinkerLaunch.conf"), raw));
        assert (yield Utils.Filesystem.make_symlink (Path.build_filename (old, "external"), root));
        if (cancel) {
            var cancellable = new Cancellable ();
            cancellable.cancel ();
            var canceled_result = yield TinkerGameMigration.copy_configuration (job, config, cancellable);
            // GTask cancellation reports the default failure enum to a
            // non-throwing Vala async caller; it must never report success.
            assert (canceled_result == ReturnCode.REQUEST_FAILED);
            assert (!FileUtils.test (target, FileTest.EXISTS));
        }
        if (collision) {
            assert (Utils.Filesystem.modify_file (Path.build_filename (old, "TinkerGame.conf"), "collision"));
            assert ((yield TinkerGameMigration.copy_configuration (job, config)) == ReturnCode.FILESYSTEM_ERROR);
            assert (!FileUtils.test (target, FileTest.EXISTS));
            assert (FileUtils.remove (Path.build_filename (old, "TinkerGame.conf")) == 0);
        }
        assert ((yield TinkerGameMigration.copy_configuration (job, config)) == ReturnCode.RUNNER_INSTALLED);
        assert (Utils.Filesystem.get_file_content (Path.build_filename (target, "TinkerGame.conf")) == raw);
        assert (Utils.Filesystem.get_file_content (Path.build_filename (old, "SteamTinkerLaunch.conf")) == raw);
        assert (FileUtils.test (Path.build_filename (target, "external"), FileTest.IS_SYMLINK));
        assert ((yield TinkerGameMigration.copy_configuration (job, config)) == ReturnCode.RUNNER_ALREADY_INSTALLED);
        assert ((yield job.remove ()) == ReturnCode.RUNNER_REMOVED);
        assert (Utils.Filesystem.get_file_content (Path.build_filename (target, "TinkerGame.conf")) == raw);
    }

    private void test_release_discovery () {
        var source = new ProtonPlus.Providers.Sources.TinkerGameReleaseSource ();
        var result = source.parse_response (
            "[{\"draft\":true},{\"tag_name\":\"v0.1.0-alpha.15\",\"prerelease\":true,\"zipball_url\":\"https://fixtures.invalid/alpha15.zip\"},{\"tag_name\":\"v0.1.0-alpha.14\",\"zipball_url\":\"https://fixtures.invalid/alpha14.zip\"}]", 1, 25);
        assert (result.succeeded);
        var page = result.require_page ();
        assert (page.releases.size == 1 && !page.has_more);
        assert (page.releases[0].source_tag == "v0.1.0-alpha.15");
        assert (page.releases[0].kind == Release.Kind.TINKER_GAME);
        assert (page.releases[0].asset.download_url == "https://fixtures.invalid/alpha15.zip");
        assert (!source.parse_response ("{}", 1, 25).succeeded);
        assert (source.parse_response ("[]", 1, 25).require_page ().releases.size == 0);
        assert (source.parse_response ("[{\"draft\":true}]", 1, 1).require_page ().has_more);
    }

    private void test_identities () {
        var launcher = new Launcher ("Test", Launcher.InstallationTypes.SYSTEM, "", { "/fixture" });
        var group = new Group ("Proton", "", "", launcher, "proton");
        var tool = new Models.Tools.TinkerGame (group);
        var legacy = new Models.Tools.SteamTinkerLaunch (group);
        assert (CLI.Handler.matches_runner_id (tool, "tinkergame"));
        assert (!CLI.Handler.matches_runner_id (tool, "steam-tinker-launch"));
        assert (CLI.Handler.matches_runner_id (legacy, "steam-tinker-launch"));
        assert (tool.id != legacy.id);
        assert (Release.kind_from_string ("steam-tinker-launch") == Release.Kind.STEAM_TINKER_LAUNCH);
        assert (Release.kind_from_string ("tinkergame") == Release.Kind.TINKER_GAME);
        assert (TinkerGameWorkflow.yad_version_supported ("15.0 (GTK+ 3.24.0)"));
        assert (!TinkerGameWorkflow.yad_version_supported ("7.1 (GTK+ 3.24.0)"));
        assert (!TinkerGameWorkflow.yad_version_supported ("unknown"));
    }
}
