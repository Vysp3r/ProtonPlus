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
        private ReturnCode? failure;
        public int requests { get; private set; default = 0; }

        public StaticReleaseSource (Release release, ReturnCode? failure = null) {
            this.release = release;
            this.failure = failure;
        }

        public async ReleasePageResult fetch_page (
            ProviderDefinition definition, int requested_page, int limit
        ) {
            requests++;
            if (failure != null)
                return ReleasePageResult.failure ((!) failure);
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

    // Lutris uses the same physical /runners/wine directory for Proton and
    // Wine, while DXVK and VKD3D live under /runtime/.
    // Keep all paths inside the temporary fixture, never the user's Lutris.
    private class FixtureLutrisLauncher : Launcher {
        public FixtureLutrisLauncher (string root) {
            base ("Lutris", InstallationTypes.SYSTEM, "", { root }, "lutris",
                null, root, "lutris", "lutris-system");
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
        public async CompatibilityProcessInspectionResult inspect_processes () {
            return CompatibilityProcessInspectionResult.clear ();
        }
    }

    private class TargetCompatibilityProcessQuery : Object, CompatibilityProcessQueryBackend {
        private string target;

        public TargetCompatibilityProcessQuery (string target) {
            this.target = target;
        }

        public async CompatibilityProcessInspectionResult inspect_processes () {
            var executable = Path.build_filename (target, "files", "bin", "wine-preloader");
            var argv = new Gee.ArrayList<string> ();
            argv.add (executable);
            argv.add ("/games/game.EXE");
            var records = new Gee.ArrayList<CompatibilityProcessRecord> ();
            records.add (new CompatibilityProcessRecord (5150, executable, argv));
            return CompatibilityProcessInspectionResult.clear (records);
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
        public string[] selections = {};
        private int selection_index = 0;

        public FixtureHandler (Gee.LinkedList<Launcher> launchers,
            FixtureJobBehavior behavior = FixtureJobBehavior.NORMAL,
            ProtonPlus.CLI.CliOutputSink? output_sink = null) {
            base (launchers, output_sink ?? new ProtonPlus.CLI.RecordingCliOutputSink ());
            this.behavior = behavior;
        }

        protected override string? read_selection_input () {
            return selection_index < selections.length ? selections[selection_index++] : null;
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
        Test.add_func ("/cli/rejects-malformed-tool-commands", test_rejects_malformed_tool_commands);
        Test.add_func ("/cli/rejects-malformed-release-selection", test_rejects_malformed_release_selection);
        Test.add_func ("/cli/invalid-arguments-prevent-mutations", test_invalid_arguments_prevent_mutations);
        Test.add_func ("/cli/niche-provider-requires-opt-in", test_niche_provider_requires_opt_in);
        Test.add_func ("/cli/sarek-release-build-selection", test_sarek_release_build_selection);
        Test.add_func ("/cli/list-managed-releases", test_list_managed_releases);
        Test.add_func ("/cli/list-lutris-runners", test_list_lutris_runners);
        Test.add_func ("/cli/list-legacy-and-partial-identities", test_list_legacy_and_partial_identities);
        Test.add_func ("/cli/list-preserves-legacy-receipt", test_list_preserves_legacy_receipt);
        Test.add_func ("/cli/list-invalid-records", test_list_invalid_records);
        Test.add_func ("/cli/search-json", test_search_json);
        Test.add_func ("/cli/outdated-json", test_outdated_json);
        Test.add_func ("/cli/sync-and-cleanup", test_sync_and_cleanup);
        Test.add_func ("/cli/uninstall-inventory-path", test_uninstall_uses_inventory_path);
        Test.add_func ("/cli/bulk-update-restores-backup-only-installation", test_bulk_update_restores_backup_only_installation);
        Test.add_func ("/cli/bulk-update-retains-backup-beside-primary", test_bulk_update_retains_backup_beside_primary);
        Test.add_func ("/cli/steam-lifecycle-receipts", test_steam_lifecycle_receipts);
        Test.add_func ("/cli/uninstall-uses-target-aware-process-policy", test_uninstall_uses_target_aware_process_policy);
    }

    private int run_cli (string[] args, ProtonPlus.CLI.Handler? supplied_handler = null,
        ProtonPlus.CLI.CliOutputSink? output_sink = null) {
        var loop = new MainLoop ();
        var handler = supplied_handler ?? new ProtonPlus.CLI.Handler (null,
            output_sink ?? new ProtonPlus.CLI.RecordingCliOutputSink ());
        var exit_code = -1;

        handler.run.begin (args, (obj, result) => {
            exit_code = handler.run.end (result);
            loop.quit ();
        });
        loop.run ();

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
        Launcher launcher,
        Group group,
        string provider_id,
        string title,
        Release value,
        VariantCompatibility? compatibility = null,
        Category category = Category.PROTON,
        ReturnCode? failure = null
    ) {
        var definition = new ProviderDefinition (new ProviderConfig () {
            category = category,
            source_type = SourceType.GITHUB,
            provider_id = provider_id,
            title = title,
            description = "",
            endpoint = "https://fixtures.invalid/releases",
            repository_url = "https://fixtures.invalid/source",
            sort_priority = 1,
            variants = { new VariantDefinition ("default", "Default", "$release_name", true, compatibility) },
            install_layouts = { InstallLayout.template ("default", "$release_name") }
        });
        var runner = new ProviderTool.with_catalog (
            definition, new StaticReleaseSource (value, failure), group,
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
        seed_latest_state (runner, "%s Latest".printf (runner.title), tag);
    }

    private string seed_latest_state (ProviderTool runner, string directory_name, string tag) {
        var directory = Path.build_filename (
            runner.group.launcher.directory, runner.group.directory, directory_name
        );
        assert (Utils.Filesystem.create_directory (directory));
        var metadata = new Utils.Metadata ();
        metadata.tag = tag;
        metadata.provider_id = runner.provider_id;
        metadata.tool_id = runner.id;
        metadata.launcher_id = runner.group.launcher.tool_target_id;
        assert (metadata.save (directory));
        return directory;
    }

    private string seed_managed_installation (
        ProviderTool runner,
        string directory_name,
        string internal_title,
        string display_title
    ) {
        var directory = Path.build_filename (
            runner.group.launcher.directory, runner.group.directory, directory_name
        );
        assert (Utils.Filesystem.create_directory (directory));

        var metadata = new Utils.Metadata ();
        metadata.provider_id = runner.provider_id;
        metadata.tool_id = runner.id;
        metadata.launcher_id = runner.group.launcher.tool_target_id;
        metadata.release_id = "fixture-%s".printf (directory_name);
        assert (metadata.save (directory));

        try {
            FileUtils.set_contents (
                Path.build_filename (directory, "compatibilitytool.vdf"),
                "\"compat_tools\"\n{\n\t\"%s\"\n\t{\n\t\t\"display_name\" \"%s\"\n\t}\n}\n".printf (
                    internal_title, display_title
                )
            );
        } catch (FileError e) {
            critical ("Could not seed compatibility tool manifest: %s", e.message);
            assert_not_reached ();
        }

        return directory;
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

    private void test_niche_provider_requires_opt_in () {
        var root = temporary_directory ();
        try {
            var launcher = new Launcher ("Fixture", Launcher.InstallationTypes.SYSTEM, "", { root }, "fixture");
            var group = new Group ("Proton", "", "/proton", launcher, "proton");
            var registry = new ProviderRegistry ();
            var runner = ProviderCatalog.create_tool (registry.get_by_id ("proton-anime"), group);
            group.tools = new Gee.LinkedList<Tool> ();
            group.tools.add (runner);
            group.tools.add (ProviderCatalog.create_tool (registry.get_by_id ("proton-ge"), group));
            launcher.groups = { group };

            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var handler = new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.NORMAL, output);
            assert (run_cli ({ "protonplus", "install", launcher.instance_id, runner.provider_id, "latest" }, handler) == 1);
            assert (output.stderr_text.contains ("Enable niche tools in Preferences"));
            assert (handler.last_job == null);
            assert (run_cli ({ "protonplus", "install", launcher.instance_id, "missing" }, handler) == 1);
            assert (output.stdout_text.contains ("Proton-GE"));
            assert (!output.stdout_text.contains ("Proton-Anime"));
        } finally {
            assert (delete_directory (root));
        }
    }

    private void test_sarek_release_build_selection () {
        var root = temporary_directory ();
        var previous_cache = Globals.CACHE_PATH;
        Globals.CACHE_PATH = Path.build_filename (root, "cache");
        try {
            assert (Utils.Filesystem.create_directory (Globals.CACHE_PATH));
            var definition = new ProviderRegistry ().get_by_id ("dxvk-sarek");
            var releases = new GitHubReleaseSource ().parse_response (definition,
                Utils.Filesystem.get_file_content ("fixtures/providers/github/sarek.json"), 1, 25).require_page ().releases;
            var launcher = new Launcher ("Fixture", Launcher.InstallationTypes.SYSTEM, "", { root }, "fixture");
            var group = new Group ("DXVK", "", "/dxvk", launcher, "dxvk");
            var runner = new ProviderTool.with_catalog (definition, new StaticReleaseSource (releases[4]),
                group, definition.get_install_layout ("default"));
            group.tools = new Gee.LinkedList<Tool> ();
            group.tools.add (runner);
            launcher.groups = { group };
            assert (Utils.Filesystem.create_directory (Path.build_filename (root, "dxvk")));
            InstallationService.instance.configure_compatibility_process_guard (
                new CompatibilityProcessGuard (new EmptyCompatibilityProcessQuery ()));
            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var handler = new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.CANCEL_DOWNLOAD, output);
            handler.selections = { "1", "2" };
            assert (run_cli ({ "protonplus", "install", launcher.instance_id, runner.provider_id }, handler) == 1);
            assert (handler.last_job.selected_variant_id == "non-async");
            assert (handler.last_job.selected_asset.download_url == releases[4].variants[1].download_url);
            assert (output.stdout_text.contains ("Standard") && output.stdout_text.contains ("Async"));
            assert (!FileUtils.test (handler.last_job.install_location, FileTest.EXISTS));
        } finally {
            Globals.CACHE_PATH = previous_cache;
            assert (delete_directory (root));
        }
    }

    private void test_exit_codes () {
        var default_handler = new ProtonPlus.CLI.Handler ();
        assert (default_handler.output_sink is ProtonPlus.CLI.TerminalCliOutputSink);

        var usage_output = new ProtonPlus.CLI.RecordingCliOutputSink ();
        assert (run_cli ({ "protonplus" }, null, usage_output) == 1);
        assert (usage_output.stdout_text.contains ("Usage:"));
        assert (usage_output.stderr_text == "");

        var version_output = new ProtonPlus.CLI.RecordingCliOutputSink ();
        assert (run_cli ({ "protonplus", "version" }, null, version_output) == 0);
        assert (version_output.stdout_text.contains ("ProtonPlus %s".printf (Config.APP_VERSION)));
        assert (version_output.stderr_text == "");

        var help_output = new ProtonPlus.CLI.RecordingCliOutputSink ();
        assert (run_cli ({ "protonplus", "help" }, null, help_output) == 0);
        assert (help_output.stdout_text.contains ("Usage:"));
        assert (!help_output.stdout_text.contains ("ProtonPlus %s".printf (Config.APP_VERSION)));
        assert (help_output.stderr_text == "");

        var unknown_output = new ProtonPlus.CLI.RecordingCliOutputSink ();
        assert (run_cli ({ "protonplus", "unknown" }, null, unknown_output) == 1);
        assert (unknown_output.stderr_text.contains ("Unknown command 'unknown'"));
        assert (unknown_output.stdout_text.contains ("Usage:"));
    }

    private void test_invalid_arguments_prevent_mutations () {
        var root = temporary_directory ();
        try {
            ProviderTool runner;
            var launcher = setup_launcher (root, "fixture-runner", "Fixture Runner",
                release ("v2", "v2", "https://fixtures.invalid/runner.zip"), out runner);
            var installed = seed_latest_state (runner, runner.title + " Latest", "v1");
            assert_rejected_mutation (launcher, { "protonplus", "install" });
            assert_rejected_mutation (launcher, { "protonplus", "install", launcher.instance_id, runner.provider_id, "latset" });
            assert_rejected_mutation (launcher, { "protonplus", "uninstall", launcher.instance_id, "all", "--dry-run" });
            assert_rejected_mutation (launcher, { "protonplus", "update", "all", "--dry-run" });
            assert_rejected_mutation (launcher, { "protonplus", "update", launcher.instance_id, runner.provider_id, "extra" });
            assert (CLI.changes_installed_tools ({ "protonplus", "update", "all" }));
            assert (CLI.changes_installed_tools ({ "protonplus", "uninstall", launcher.instance_id, runner.provider_id, "all" }));
            assert (CLI.changes_installed_tools ({ "protonplus", "install", launcher.instance_id, runner.provider_id, "latest" }));
            assert (Utils.Metadata.load (installed).tag == "v1");
        } finally {
            assert (delete_directory (root));
        }
    }

    private void assert_rejected_mutation (Launcher launcher, string[] args) {
        assert (!CLI.changes_installed_tools (args));
        var output = new CLI.RecordingCliOutputSink ();
        var handler = new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.NORMAL, output);
        assert (run_cli (args, handler) == 1);
        assert (output.stderr_text.contains ("Usage:"));
        assert (output.stdout_text == "");
    }

    // Identity assertions ignore padding; alignment is checked separately below.
    private string compact_columns (string text) {
        try {
            return new Regex (" {2,}").replace (text.replace ("\033[1m", "").replace ("\033[0m", ""), -1, 0, "  ");
        } catch (RegexError error) {
            assert_not_reached ();
        }
    }

    private void test_list_managed_releases () {
        var root = temporary_directory ();
        try {
            ProviderTool runner;
            var launcher = setup_launcher (
                root, "ge-proton", "GE-Proton",
                release ("GE-Proton9-27", "GE-Proton9-27",
                    "https://fixtures.invalid/ge-proton.zip"),
                out runner
            );
            var latest_path = seed_latest_state (runner, "GE-Proton Latest", "GE-Proton9-27");

            var versioned_path = seed_managed_installation (
                runner, "GE-Proton9-26", "GE-Proton9-26", "Proton-GE 9-26"
            );
            var metadata = Utils.Metadata.load (versioned_path);
            metadata.tag = "GE-Proton9-26";
            assert (metadata.save (versioned_path));

            // A valid identity remains useful when the release tag is unknown.
            assert (Utils.Filesystem.create_directory (Path.build_filename (
                root, "compatibilitytools.d", "unmanaged-runner"
            )));
            var untagged_path = seed_managed_installation (
                runner, "missing-release-tag", "missing-release-tag", "No release tag"
            );

            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            assert (run_cli ({ "protonplus", "list", launcher.instance_id },
                new FixtureHandler (launcher_list (launcher),
                    FixtureJobBehavior.NORMAL, output)) == 0);

            var listing = compact_columns (output.stdout_text);
            assert (listing.contains (
                "  ge-proton  GE-Proton9-27  GE-Proton Latest\n"
            ));
            assert (!listing.contains ("unmanaged-runner"));
            assert (listing.contains ("  ge-proton  GE-Proton9-26  Proton-GE 9-26\n"));
            assert (listing.contains ("  ge-proton  —  No release tag\n"));
            assert (listing.has_prefix ("Fixture:\n"));
            assert (!listing.contains ("No runners installed"));

            // The same directory becomes unmanaged if its receipt is removed.
            assert (FileUtils.remove (Path.build_filename (latest_path, ".protonplus")) == 0);
            assert (FileUtils.remove (Path.build_filename (versioned_path, ".protonplus")) == 0);
            assert (FileUtils.remove (Path.build_filename (untagged_path, ".protonplus")) == 0);
            var empty_output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            assert (run_cli ({ "protonplus", "list", launcher.instance_id },
                new FixtureHandler (launcher_list (launcher),
                    FixtureJobBehavior.NORMAL, empty_output)) == 0);
            assert (empty_output.stdout_text.contains ("No runners installed"));
            assert (!empty_output.stdout_text.contains ("\nFixture:\n"));
        } finally {
            assert (delete_directory (root));
        }
    }

    private void test_list_lutris_runners () {
        var root = temporary_directory ();
        try {
            // Mirror Lutris's real group layout, including the shared Proton/Wine root.
            assert (Utils.Filesystem.create_directory (Path.build_filename (root, "runners", "wine")));
            assert (Utils.Filesystem.create_directory (Path.build_filename (root, "runtime", "dxvk")));
            assert (Utils.Filesystem.create_directory (Path.build_filename (root, "runtime", "vkd3d")));

            var launcher = new FixtureLutrisLauncher (root);
            assert (launcher.instance_id == "lutris-system");
            var proton = new Group ("Proton", "", "/runners/wine", launcher, "proton");
            var wine = new Group ("Wine", "", "/runners/wine", launcher, "wine");
            var dxvk = new Group ("DXVK", "", "/runtime/dxvk", launcher, "dxvk");
            var vkd3d = new Group ("VKD3D", "", "/runtime/vkd3d", launcher, "vkd3d");
            proton.tools = new Gee.LinkedList<Tool> ();
            wine.tools = new Gee.LinkedList<Tool> ();
            dxvk.tools = new Gee.LinkedList<Tool> ();
            vkd3d.tools = new Gee.LinkedList<Tool> ();
            launcher.groups = { proton, wine, dxvk, vkd3d };

            var ge_proton = add_runner (launcher, proton, "ge-proton", "GE-Proton",
                release ("GE-Proton9-27", "GE-Proton9-27", "https://fixtures.invalid/proton.zip"));
            var wine_ge = add_runner (launcher, wine, "wine-ge", "Wine-GE",
                release ("v8", "v8", "https://fixtures.invalid/wine.zip"), null, Category.WINE);
            var doitsujin = add_runner (launcher, dxvk, "dxvk-doitsujin", "DXVK (doitsujin)",
                release ("v3.1.1", "v3.1.1", "https://fixtures.invalid/dxvk.zip"), null, Category.DXVK);
            var vkd3d_proton = add_runner (launcher, vkd3d, "vkd3d-proton", "VKD3D-Proton",
                release ("v2.14", "v2.14", "https://fixtures.invalid/vkd3d.zip"), null, Category.VKD3D);

            seed_latest_state (ge_proton, "GE-Proton Latest", "GE-Proton9-27");
            seed_latest_state (wine_ge, "Wine-GE Latest", "v8");
            var provider_only = seed_latest_state (wine_ge, "wine-provider-only", "v7");
            var metadata = Utils.Metadata.load (provider_only);
            metadata.tool_id = "";
            metadata.launcher_id = "";
            assert (metadata.save (provider_only));
            var legacy_path = seed_latest_state (wine_ge, "wine-legacy", "v6");
            metadata = new Utils.Metadata ();
            metadata.runner_endpoint = wine_ge.endpoint;
            metadata.runner_title = wine_ge.title;
            metadata.tag = "v6";
            assert (metadata.save (legacy_path));
            seed_latest_state (doitsujin, "dxvk-3.1", "v3.1.0");
            seed_latest_state (doitsujin, "DXVK (doitsujin) Latest", "v3.1.1");
            seed_latest_state (vkd3d_proton, "vkd3d-proton-2.14", "v2.14");

            // Real Lutris contains these bare directories without .protonplus records.
            assert (Utils.Filesystem.create_directory (Path.build_filename (root, "runners", "wine", "unmanaged-wine")));
            assert (Utils.Filesystem.create_directory (Path.build_filename (root, "runtime", "dxvk", "unmanaged-dxvk")));

            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            assert (run_cli ({ "protonplus", "list", "lutris-system" },
                new FixtureHandler (launcher_list (launcher),
                    FixtureJobBehavior.NORMAL, output)) == 0);

            var listing = compact_columns (output.stdout_text);
            var version_column = -1;
            var name_column = -1;
            foreach (var line in output.stdout_text.replace ("\033[1m", "").replace ("\033[0m", "").split ("\n")) {
                if (line.has_prefix ("  Runner ID")) {
                    if (version_column < 0) {
                        version_column = line.index_of ("Version");
                        name_column = line.index_of ("Name");
                    }
                    assert (line.index_of ("Version") == version_column);
                    assert (line.index_of ("Name") == name_column);
                } else if (line.has_prefix ("  ")) {
                    assert (line[version_column] != ' ');
                    assert (line[name_column] != ' ');
                    assert (line[version_column - 1] == ' ');
                    assert (line[name_column - 1] == ' ');
                }
            }
            assert (version_column > 2);
            assert (listing.has_prefix ("Proton:\n"));
            assert (listing.contains ("  ge-proton  GE-Proton9-27  GE-Proton Latest\n"));
            assert (listing.contains ("  wine-ge  v8  Wine-GE Latest\n"));
            assert (listing.contains ("  dxvk-doitsujin  v3.1.0  dxvk-3.1\n"));
            assert (listing.contains ("  dxvk-doitsujin  v3.1.1  DXVK (doitsujin) Latest\n"));
            assert (!listing.contains ("unmanaged-wine"));
            assert (!listing.contains ("unmanaged-dxvk"));
            assert (listing.contains ("\nVKD3D:\n  Runner ID  Version  Name\n  vkd3d-proton  v2.14  vkd3d-proton-2.14\n"));
            assert (listing.split ("  ge-proton  ").length == 2);
            assert (listing.contains ("  wine-ge  v7  wine-provider-only\n"));
            assert (listing.contains ("  wine-ge  v6  wine-legacy\n"));
            assert (listing.split ("  wine-ge  ").length == 4);
            assert (listing.split ("  dxvk-doitsujin  ").length == 3);

            // The two shared directories must not miscategorize or duplicate releases.
            var before_wine = listing.split ("\nWine:\n");
            assert (before_wine.length == 2);
            assert (before_wine[0].has_prefix ("Proton:\n"));
            assert (!before_wine[0].contains ("  wine-ge  "));
            assert (!before_wine[1].contains ("  ge-proton  "));
            var before_dxvk = before_wine[1].split ("\nDXVK:\n");
            assert (before_dxvk.length == 2);
            assert (!before_dxvk[0].contains ("  dxvk-doitsujin  "));
            assert (!before_dxvk[1].contains ("  ge-proton  "));
            assert (!before_dxvk[1].contains ("  wine-ge  "));
        } finally {
            assert (delete_directory (root));
        }
    }

    private void test_list_legacy_and_partial_identities () {
        var root = temporary_directory ();
        InstallationService.reset_lifecycle_configuration_for_tests ();
        try {
            ProviderTool runner;
            var launcher = setup_launcher (root, "fixture-legacy", "Fixture Legacy",
                release ("v3", "v3", "https://fixtures.invalid/legacy.zip"), out runner);
            // A stable installation causes the installed-state projection to
            // stop at its first match. Listing must still resolve every release.
            seed_latest_state (runner, "Fixture Legacy Latest", "v3");
            foreach (var tag in new string[] { "v1", "v2" }) {
                var path = seed_latest_state (runner, "legacy-" + tag, tag);
                var metadata = new Utils.Metadata ();
                metadata.runner_endpoint = runner.endpoint;
                metadata.runner_title = runner.title;
                metadata.tag = tag;
                assert (metadata.save (path));
            }
            var provider_only = seed_latest_state (runner, "provider-only", "v0");
            var metadata = Utils.Metadata.load (provider_only);
            metadata.tool_id = "";
            metadata.launcher_id = "";
            assert (metadata.save (provider_only));
            var tool_only = seed_latest_state (runner, "tool-only", "v0.1");
            metadata = Utils.Metadata.load (tool_only);
            metadata.provider_id = "";
            assert (metadata.save (tool_only));

            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            assert (run_cli ({ "protonplus", "list", launcher.instance_id },
                new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.NORMAL, output)) == 0);
            var listing = compact_columns (output.stdout_text);
            assert (listing.contains ("  fixture-legacy  v1  legacy-v1\n"));
            assert (listing.contains ("  fixture-legacy  v2  legacy-v2\n"));
            assert (listing.contains ("  fixture-legacy  v0  provider-only\n"));
            assert (listing.contains ("  fixture-legacy  v0.1  tool-only\n"));
            assert (listing.split ("  fixture-legacy  ").length == 6);
            assert (ProtonPlus.CLI.Handler.matches_runner_id (runner, "fixture-legacy"));

            // The listed ID reaches the same inventory entries for removal,
            // including legacy releases that have not been migrated to IDs.
            configure_fixture_services (new RecordingSteamChange (), root);
            var uninstall_output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            assert (run_cli ({ "protonplus", "uninstall", launcher.instance_id, "fixture-legacy", "all" },
                new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.NORMAL, uninstall_output)) == 0);
            assert (uninstall_output.stdout_text.split ("Successfully uninstalled").length == 6);
            assert (uninstall_output.stderr_text == "");
            assert (!FileUtils.test (provider_only, FileTest.EXISTS));
            assert (!FileUtils.test (tool_only, FileTest.EXISTS));
        } finally {
            InstallationService.reset_lifecycle_configuration_for_tests ();
            SteamConfigurationService.reset_configuration ();
            assert (delete_directory (root));
        }
    }

    private void test_list_preserves_legacy_receipt () {
        var root = temporary_directory ();
        try {
            ProviderTool runner;
            var launcher = setup_launcher (root, "fixture-legacy", "Fixture Legacy",
                release ("v1", "v1", "https://fixtures.invalid/legacy.zip"), out runner);
            var path = seed_latest_state (runner, "Fixture Legacy Latest", "v1");
            var legacy = new Utils.Metadata ();
            legacy.runner_endpoint = runner.endpoint;
            legacy.runner_title = runner.title;
            legacy.tag = "v1";
            assert (legacy.save (path));
            var receipt = Path.build_filename (path, ".protonplus");
            var original = Utils.Filesystem.get_file_content (receipt);

            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            assert (run_cli ({ "protonplus", "list", launcher.instance_id },
                new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.NORMAL, output)) == 0);
            assert (compact_columns (output.stdout_text).contains ("  fixture-legacy  v1  Fixture Legacy Latest\n"));
            assert (Utils.Filesystem.get_file_content (receipt) == original);
        } finally {
            assert (delete_directory (root));
        }
    }

    private void test_list_invalid_records () {
        var root = temporary_directory ();
        try {
            ProviderTool runner;
            var launcher = setup_launcher (root, "fixture-valid", "Fixture Valid",
                release ("v1", "v1", "https://fixtures.invalid/valid.zip"), out runner);
            // These all passed a tool-ID prefix check, despite conflicting or
            // unknown identities. None may fall back to directory/title matching.
            foreach (var name in new string[] { "foreign-launcher", "conflicting-provider", "unknown-tool" }) {
                var path = seed_latest_state (runner, name, "v1");
                var metadata = Utils.Metadata.load (path);
                if (name == "foreign-launcher")
                    metadata.launcher_id = "other-system";
                else if (name == "conflicting-provider")
                    metadata.provider_id = "other-provider";
                else
                    metadata.tool_id += "-unknown";
                assert (metadata.save (path));
            }
            seed_latest_state (runner, "LegacyRuntime", "v1");
            var invalid = seed_latest_state (runner, "invalid-json", "v1");
            Utils.Filesystem.modify_file (Path.build_filename (invalid, ".protonplus"), "{broken");
            var invalid_type = seed_latest_state (runner, "invalid-field-type", "v1");
            Utils.Filesystem.modify_file (Path.build_filename (invalid_type, ".protonplus"),
                "{\"provider_id\":42,\"runner_title\":\"Fixture Valid\",\"tag\":null}");
            // Endpoint-only receipts can be ambiguous between real providers.
            add_runner (launcher, runner.group, "fixture-other", "Fixture Other",
                release ("v1", "v1", "https://fixtures.invalid/other.zip"));
            var ambiguous = seed_latest_state (runner, "ambiguous-legacy", "v1");
            var legacy = new Utils.Metadata ();
            legacy.runner_endpoint = runner.endpoint;
            assert (legacy.save (ambiguous));
            var linked = Path.build_filename (root, "compatibilitytools.d", "linked-release");
            var external = Path.build_filename (root, "external-release");
            assert (Utils.Filesystem.create_directory (external));
            var external_metadata = new Utils.Metadata ();
            external_metadata.provider_id = runner.provider_id;
            external_metadata.tool_id = runner.id;
            external_metadata.launcher_id = launcher.tool_target_id;
            external_metadata.tag = "v1";
            assert (external_metadata.save (external));
            assert (Posix.symlink (external, linked) == 0);
            var linked_receipt = Path.build_filename (root, "compatibilitytools.d", "linked-receipt");
            assert (Utils.Filesystem.create_directory (linked_receipt));
            assert (Posix.symlink (Path.build_filename (external, ".protonplus"),
                Path.build_filename (linked_receipt, ".protonplus")) == 0);

            Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*unexpected*");
            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            assert (run_cli ({ "protonplus", "list", launcher.instance_id },
                new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.NORMAL, output)) == 0);
            Test.assert_expected_messages ();
            assert (output.stdout_text.contains ("No runners installed"));
            assert (!output.stdout_text.contains ("\nFixture:\n"));
            assert (output.stderr_text == "");
        } finally {
            assert (delete_directory (root));
        }
    }

    private Json.Array read_json_packages (string text) {
        try {
            var parser = new Json.Parser ();
            parser.load_from_data (text, -1);
            var root = parser.get_root ().get_object ();
            assert (root.get_int_member ("schema_version") == 1);
            return root.get_array_member ("packages");
        } catch (Error error) {
            Test.message ("Invalid package JSON: %s", error.message);
            assert_not_reached ();
        }
    }

    private void test_search_json () {
        var root = temporary_directory ();
        try {
            ProviderTool runner;
            var latest = release ("v2", "v2", "https://fixtures.invalid/runner.zip");
            var launcher = setup_launcher (root, "fixture-search", "Fixture Runner", latest, out runner);
            runner.description = "A game-specific build";
            add_runner (launcher, runner.group, "unrelated", "Unrelated", latest);
            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var handler = new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.NORMAL, output);
            assert (run_cli ({ "protonplus", "search", "--json", "RUNNER specific" }, handler) == 0);
            var packages = read_json_packages (output.stdout_text);
            assert (packages.get_length () == 1);
            var package = packages.get_object_element (0);
            assert (package.get_string_member ("id") == launcher.instance_id + "/fixture-search");
            assert (package.get_string_member ("tool_target_id") == launcher.tool_target_id);
            assert (package.get_string_member ("description") == runner.description);
            assert (output.stderr_text == "");
        } finally {
            assert (delete_directory (root));
        }
    }

    private void test_outdated_json () {
        var root = temporary_directory ();
        var previous_cache = Globals.CACHE_PATH;
        Globals.CACHE_PATH = Path.build_filename (root, "cache");
        try {
            ProviderTool runner;
            var latest = release ("Release two", "v2", "https://fixtures.invalid/runner.zip");
            var launcher = setup_launcher (root, "fixture-rolling", "Fixture Rolling", latest, out runner);
            var backup = seed_latest_state (runner, runner.title + " Latest Backup", "v1");
            var receipt = Path.build_filename (backup, ".protonplus");
            var original = Utils.Filesystem.get_file_content (receipt);
            var pinned = add_runner (launcher, runner.group, "fixture-pinned", "Fixture Pinned", latest);
            seed_latest_state (pinned, "pinned-v1", "v1");
            var current = add_runner (launcher, runner.group, "fixture-current", "Fixture Current", latest);
            var current_path = seed_latest_state (current, current.title + " Latest", "");
            Utils.Filesystem.create_file (Path.build_filename (current_path, "version"), "revision v2\n");
            Utils.Filesystem.create_file (Path.build_filename (current_path, "proton"), "CURRENT_PREFIX_VERSION=\"v2\"\n");
            var offline = add_runner (launcher, runner.group, "fixture-offline", "Fixture Offline",
                latest, null, Category.PROTON, ReturnCode.CONNECTION_ISSUE);
            seed_latest_installation (offline, "v1");

            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var handler = new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.NORMAL, output);
            assert (run_cli ({ "protonplus", "outdated", launcher.instance_id, "--json" }, handler) == 1);
            var packages = read_json_packages (output.stdout_text);
            assert (packages.get_length () == 1);
            var package = packages.get_object_element (0);
            assert (package.get_string_member ("runner_id") == runner.provider_id);
            assert (package.get_string_member ("installed_version") == "v1");
            assert (package.get_string_member ("latest_version") == "v2");
            assert (package.get_string_member ("variant_id") == "default");
            assert (output.stderr_text.contains (offline.provider_id));
            assert (Utils.Metadata.load (current_path).tag == "");
            assert (Utils.Filesystem.get_file_content (receipt) == original);
            assert (!FileUtils.test (backup.substring (0, backup.length - " Backup".length), FileTest.EXISTS));
            assert (!FileUtils.test (Globals.CACHE_PATH, FileTest.EXISTS));
        } finally {
            Globals.CACHE_PATH = previous_cache;
            assert (delete_directory (root));
        }
    }

    private void test_sync_and_cleanup () {
        var root = temporary_directory ();
        var previous_cache = Globals.CACHE_PATH;
        Globals.CACHE_PATH = Path.build_filename (root, "cache");
        try {
            ProviderTool runner;
            var latest = release ("Release two", "v2", "https://fixtures.invalid/runner.zip");
            var launcher = setup_launcher (root, "fixture-sync", "Fixture Sync", latest, out runner);
            var installed = seed_latest_state (runner, runner.title + " Latest", "v1");
            var receipt = Path.build_filename (installed, ".protonplus");
            var original = Utils.Filesystem.get_file_content (receipt);
            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var launchers = launcher_list (launcher);
            var second_launcher = new FixtureLutrisLauncher (Path.build_filename (root, "lutris"));
            var second_group = new Group ("Fixture", "", "/runners/wine", second_launcher, "fixture");
            var second_source = new StaticReleaseSource (latest);
            var second_tool = new ProviderTool.with_catalog (runner.definition, second_source, second_group,
                InstallLayout.template ("default", "$release_name"));
            second_group.tools = new Gee.LinkedList<Tool> ();
            second_group.tools.add (second_tool);
            second_launcher.groups = { second_group };
            launchers.add (second_launcher);
            var handler = new FixtureHandler (launchers, FixtureJobBehavior.NORMAL, output);

            assert (run_cli ({ "protonplus", "cleanup" }, handler) == 0);
            assert (!FileUtils.test (Globals.CACHE_PATH, FileTest.EXISTS));
            assert (run_cli ({ "protonplus", "sync", launcher.instance_id }, handler) == 0);
            var snapshot = Path.build_filename (Globals.CACHE_PATH, runner.id.replace ("/", "_") + ".json");
            assert (Utils.Filesystem.get_file_content (snapshot).contains ("Release two"));
            var second_snapshot = Path.build_filename (Globals.CACHE_PATH, second_tool.id.replace ("/", "_") + ".json");
            assert (!FileUtils.test (second_snapshot, FileTest.EXISTS));
            assert (run_cli ({ "protonplus", "sync" }, handler) == 0);
            assert (Utils.Filesystem.get_file_content (second_snapshot).contains ("Release two"));
            assert (second_source.requests == 0);
            assert (Posix.symlink (installed, Path.build_filename (Globals.CACHE_PATH, "linked-fixture")) == 0);
            assert (run_cli ({ "protonplus", "cleanup" }, handler) == 0);
            assert (!FileUtils.test (snapshot, FileTest.EXISTS));
            assert (!FileUtils.test (second_snapshot, FileTest.EXISTS));
            assert (Utils.Filesystem.get_file_content (receipt) == original);
            assert (output.stderr_text == "");
        } finally {
            Globals.CACHE_PATH = previous_cache;
            assert (delete_directory (root));
        }
    }

    private void test_rejects_malformed_tool_commands () {
        var root = temporary_directory ();
        try {
            ProviderTool runner;
            var latest = release ("v1", "v1", "https://fixtures.invalid/runner.zip");
            var launcher = setup_launcher (root, "fixture-command", "Fixture Command", latest, out runner);
            var installed = seed_latest_state (runner, runner.title + " Latest", "v1");
            var launcher_id = launcher.instance_id;
            var provider_id = runner.provider_id;
            string[] commands = {
                "install %s %s newest".printf (launcher_id, provider_id),
                "install %s %s latest extra".printf (launcher_id, provider_id),
                "uninstall %s all %s".printf (launcher_id, provider_id),
                "uninstall %s %s al".printf (launcher_id, provider_id),
                "uninstall %s %s all extra".printf (launcher_id, provider_id),
                "update all %s".printf (provider_id),
                "update %s %s extra".printf (launcher_id, provider_id)
            };
            configure_fixture_services (new RecordingSteamChange (), root);
            foreach (var command in commands) {
                var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
                var handler = new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.CANCEL_DOWNLOAD, output);
                assert (run_cli (("protonplus " + command).split (" "), handler) == 1);
                assert (output.stdout_text == "" && output.stderr_text.contains ("Usage:"));
                assert (handler.last_job == null);
                assert (FileUtils.test (installed, FileTest.IS_DIR));
            }
        } finally {
            InstallationService.reset_lifecycle_configuration_for_tests ();
            SteamConfigurationService.reset_configuration ();
            assert (delete_directory (root));
        }
    }

    private void test_rejects_malformed_release_selection () {
        var root = temporary_directory ();
        try {
            ProviderTool runner;
            var latest = release ("v1", "v1", "https://fixtures.invalid/runner.zip");
            var launcher = setup_launcher (root, "fixture-release", "Fixture Release", latest, out runner);
            var installed = seed_latest_state (runner, runner.title + " Latest", "v1");
            configure_fixture_services (new RecordingSteamChange (), root);
            string[] args = { "protonplus", "uninstall", launcher.instance_id, runner.provider_id };
            foreach (var selection in new string[] { "1wrong", "1 2", "4294967297", "0", "-2147483648" }) {
                var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
                var handler = new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.NORMAL, output);
                handler.selections = { selection };
                assert (run_cli (args, handler) == 1);
                assert (output.stderr_text != "");
                assert (handler.last_job == null);
                assert (FileUtils.test (installed, FileTest.IS_DIR));
            }

            var handler = new FixtureHandler (launcher_list (launcher));
            handler.selections = { " 01 " };
            assert (run_cli (args, handler) == 0);
            assert (!FileUtils.test (installed, FileTest.EXISTS));
        } finally {
            InstallationService.reset_lifecycle_configuration_for_tests ();
            SteamConfigurationService.reset_configuration ();
            assert (delete_directory (root));
        }
    }

    private void test_uninstall_uses_inventory_path () {
        var root = temporary_directory ();
        InstallationService.reset_lifecycle_configuration_for_tests ();
        SteamConfigurationService.reset_configuration ();

        try {
            ProviderTool runner;
            var launcher = setup_launcher (
                root, "ge-proton", "GE-Proton",
                release ("GE-Proton9-27", "GE-Proton9-27", "https://fixtures.invalid/ge-proton.zip"),
                out runner
            );
            var real_layout = seed_managed_installation (
                runner, "GE-Proton9-27", "GE-Proton9-27", "Proton-GE 9-27"
            );
            var hostile_layout = seed_managed_installation (
                runner, "managed-hostile-slot", "hostile-internal",
                "GE-Proton/../outside-target"
            );
            var outside_target = Path.build_filename (
                launcher.directory, "compatibilitytools.d", "outside-target"
            );
            assert (Utils.Filesystem.create_directory (outside_target));

            var recorder = new RecordingSteamChange ();
            configure_fixture_services (recorder, root);
            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var handler = new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.NORMAL, output);

            assert (run_cli ({ "protonplus", "uninstall", launcher.instance_id,
                runner.provider_id, "all" }, handler) == 0);
            assert (!FileUtils.test (real_layout, FileTest.EXISTS));
            assert (!FileUtils.test (hostile_layout, FileTest.EXISTS));
            assert (FileUtils.test (outside_target, FileTest.IS_DIR));
            assert (output.stdout_text.contains ("Successfully uninstalled Proton-GE 9-27"));
            assert (output.stdout_text.contains (
                "Successfully uninstalled GE-Proton/../outside-target"
            ));
            assert (output.stderr_text == "");
            assert (recorder.receipts.size == 2);
        } finally {
            InstallationService.reset_lifecycle_configuration_for_tests ();
            SteamConfigurationService.reset_configuration ();
            assert (delete_directory (root));
        }
    }

    private void test_uninstall_uses_target_aware_process_policy () {
        var root = temporary_directory ();
        InstallationService.reset_lifecycle_configuration_for_tests ();
        SteamConfigurationService.reset_configuration ();

        try {
            ProviderTool runner;
            var launcher = setup_launcher (
                root, "fixture-guarded", "Fixture Guarded",
                release ("v1", "v1", "https://fixtures.invalid/guarded.zip"),
                out runner
            );
            var installation = seed_managed_installation (
                runner, "Fixture Guarded Latest", "Fixture-Guarded", "Fixture Guarded Latest"
            );
            InstallationService.instance.configure_compatibility_process_guard (
                new CompatibilityProcessGuard (new TargetCompatibilityProcessQuery (installation))
            );
            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var handler = new FixtureHandler (
                launcher_list (launcher), FixtureJobBehavior.NORMAL, output
            );

            assert (run_cli ({ "protonplus", "uninstall", launcher.instance_id,
                runner.provider_id, "all" }, handler) == 1);
            assert (FileUtils.test (installation, FileTest.IS_DIR));
            assert (output.stderr_text.contains (get_return_code_message (ReturnCode.RUNNERS_IN_USE)));
        } finally {
            InstallationService.reset_lifecycle_configuration_for_tests ();
            SteamConfigurationService.reset_configuration ();
            assert (delete_directory (root));
        }
    }

    private void test_bulk_update_restores_backup_only_installation () {
        var root = temporary_directory ();
        InstallationService.reset_lifecycle_configuration_for_tests ();

        try {
            ProviderTool runner;
            var launcher = setup_launcher (
                root, "fixture-backup-only", "Fixture Backup Only",
                release ("v2", "v2", "https://fixtures.invalid/backup-only.zip"), out runner
            );
            var backup = seed_latest_state (
                runner, "%s Latest Backup".printf (runner.title), "v2"
            );
            Utils.Filesystem.create_file (
                Path.build_filename (backup, "recovery-marker"), "backup-only"
            );
            var primary = Path.build_filename (
                launcher.directory, "compatibilitytools.d", "%s Latest".printf (runner.title)
            );

            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var handler = new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.NORMAL, output);
            assert (run_cli ({ "protonplus", "update", "all" }, handler) == 0);
            assert (FileUtils.test (primary, FileTest.IS_DIR));
            assert (!FileUtils.test (backup, FileTest.EXISTS));
            assert (Utils.Filesystem.get_file_content (
                Path.build_filename (primary, "recovery-marker")
            ) == "backup-only");
            assert (output.stdout_text.contains ("Already up to date: Fixture Backup Only"));
            assert (output.stderr_text == "");
        } finally {
            InstallationService.reset_lifecycle_configuration_for_tests ();
            assert (delete_directory (root));
        }
    }

    private void test_bulk_update_retains_backup_beside_primary () {
        var root = temporary_directory ();
        InstallationService.reset_lifecycle_configuration_for_tests ();

        try {
            ProviderTool runner;
            var launcher = setup_launcher (
                root, "fixture-primary-backup", "Fixture Primary Backup",
                release ("v2", "v2", "https://fixtures.invalid/primary-backup.zip"), out runner
            );
            var primary = seed_latest_state (
                runner, "%s Latest".printf (runner.title), "v2"
            );
            var backup = seed_latest_state (
                runner, "%s Latest Backup".printf (runner.title), "v1"
            );
            Utils.Filesystem.create_file (
                Path.build_filename (backup, "recovery-marker"), "primary-plus-backup"
            );

            var output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var handler = new FixtureHandler (launcher_list (launcher), FixtureJobBehavior.NORMAL, output);
            assert (run_cli ({ "protonplus", "update", "all" }, handler) == 0);
            assert (FileUtils.test (primary, FileTest.IS_DIR));
            assert (FileUtils.test (backup, FileTest.IS_DIR));
            assert (Utils.Filesystem.get_file_content (
                Path.build_filename (backup, "recovery-marker")
            ) == "primary-plus-backup");
            assert (output.stdout_text.contains ("Already up to date: Fixture Primary Backup"));
            assert (output.stderr_text == "");
        } finally {
            InstallationService.reset_lifecycle_configuration_for_tests ();
            assert (delete_directory (root));
        }
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
            var install_output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var install_handler = new FixtureHandler (launcher_list (install_launcher),
                FixtureJobBehavior.NORMAL, install_output);
            assert (run_cli ({ "protonplus", "install", install_launcher.instance_id,
                install_runner.provider_id, "latest" }, install_handler) == 0);
            assert (install_handler.last_job != null);
            assert (install_output.stdout_text.contains ("Successfully installed Fixture Install Latest"));
            assert (install_output.stderr_text == "");
            assert_single_receipt (install_recorder, SteamChangeKind.COMPATIBILITY_TOOL_INSTALLED,
                install_launcher, ((!) install_handler.last_job).install_location);

            InstallationService.reset_lifecycle_configuration_for_tests ();
            SteamConfigurationService.reset_configuration ();
            var uninstall_recorder = new RecordingSteamChange ();
            configure_fixture_services (uninstall_recorder, root);
            var uninstall_output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var uninstall_handler = new FixtureHandler (launcher_list (install_launcher),
                FixtureJobBehavior.NORMAL, uninstall_output);
            assert (run_cli ({ "protonplus", "uninstall", install_launcher.instance_id,
                install_runner.provider_id, "all" }, uninstall_handler) == 0);
            assert (uninstall_handler.last_job != null);
            assert (uninstall_output.stdout_text.contains ("Successfully uninstalled Fixture Install Latest"));
            assert (uninstall_output.stderr_text == "");
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
            var update_output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var update_handler = new FixtureHandler (launcher_list (update_launcher),
                FixtureJobBehavior.NORMAL, update_output);
            assert (run_cli ({ "protonplus", "update", update_launcher.instance_id,
                update_runner.provider_id }, update_handler) == 0);
            assert (update_output.stdout_text.contains ("Successfully updated Fixture Update"));
            assert (update_output.stderr_text == "");
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
            var failed_output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var failed_handler = new FixtureHandler (launcher_list (failed_launcher),
                FixtureJobBehavior.FAIL_PROMOTION, failed_output);
            assert (run_cli ({ "protonplus", "install", failed_launcher.instance_id,
                failed_runner.provider_id, "latest" }, failed_handler) == 1);
            assert (failed_output.stderr_text.contains ("Error: Installation failed:"));
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
            var persistence_output = new ProtonPlus.CLI.RecordingCliOutputSink ();
            var persistence_handler = new FixtureHandler (launcher_list (persistence_launcher),
                FixtureJobBehavior.NORMAL, persistence_output);
            assert (run_cli ({ "protonplus", "install", persistence_launcher.instance_id,
                persistence_runner.provider_id, "latest" }, persistence_handler) == 0);
            assert (persistence_handler.last_job != null);
            assert (((!) persistence_handler.last_job).steam_restart_warning != null);
            assert (persistence_output.stdout_text.contains ("Warning:"));
            assert (persistence_output.stderr_text == "");
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
