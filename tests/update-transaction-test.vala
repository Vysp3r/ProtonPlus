namespace AppTests.UpdateTransactionTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Launchers;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Models.Tools;
    using ProtonPlus.Providers.Sources;
    using ProtonPlus.Services;

    private class FailingReleaseSource : Object, ReleaseSource {
        public async ReleasePageResult fetch_page (ProviderDefinition definition, int requested_page, int limit) {
            return ReleasePageResult.failure (ReturnCode.REQUEST_FAILED);
        }
    }

    private class StaticReleaseSource : Object, ReleaseSource {
        private Release release;
        public int requests { get; private set; default = 0; }

        public StaticReleaseSource (Release release) {
            this.release = release;
        }

        public async ReleasePageResult fetch_page (ProviderDefinition definition, int requested_page, int limit) {
            requests++;
            var releases = new Gee.LinkedList<Release> ();
            releases.add (release);
            return ReleasePageResult.success (new ReleasePage (releases, requested_page + 1, false));
        }
    }

    private class FixtureCoordinator : Object, ProtonPlus.Services.InstallationOperationCoordinator {
        public int install_calls { get; private set; default = 0; }
        public string selected_url { get; private set; default = ""; }
        public string selected_variant_id { get; private set; default = ""; }

        public async ReturnCode install_for_update (ProtonPlus.Services.InstallJob job) {
            install_calls++;
            selected_url = job.selected_asset.download_url;
            selected_variant_id = job.selected_variant_id ?? "";
            return ReturnCode.FILESYSTEM_ERROR;
        }
    }

    private class FixtureSteamLauncher : Launcher {
        private SteamRestartTarget target;

        public FixtureSteamLauncher (string root) {
            base ("Steam fixture", InstallationTypes.SYSTEM, "", { root }, "steam",
                null, root, "steam", "steam-system");
            target = SteamRestartTarget.for_native (root, "Steam", "steam.desktop");
        }

        public override SteamRestartTarget? get_steam_restart_target () {
            return target;
        }
    }

    private class RecordingSteamChange : Object, SteamChangeRecorder {
        public Gee.List<SteamChangeReceipt> receipts = new Gee.ArrayList<SteamChangeReceipt> ();

        public SteamRestartRecordResult record (SteamChangeReceipt receipt) {
            receipts.add (receipt);
            return SteamRestartRecordResult.ADDED;
        }
    }

    private class EmptyCompatibilityProcessQuery : Object, CompatibilityProcessQueryBackend {
        public Gee.List<CompatibilityProcessRecord> query_processes () {
            return new Gee.ArrayList<CompatibilityProcessRecord> ();
        }
    }

    public void register_tests () {
        Test.add_func ("/update-transaction/migrates-settings-prefix-and-cleans-backup", test_migrates_settings_prefix_and_cleans_backup);
        Test.add_func ("/update-transaction/migrates-settings-symlink", test_migrates_settings_symlink);
        Test.add_func ("/update-transaction/migration-failure-rolls-back-runner", test_migration_failure_rolls_back_runner);
        Test.add_func ("/update-transaction/github-actions-request-failure-is-propagated", test_github_actions_request_failure_is_propagated);
        Test.add_func ("/update-transaction/latest-identity-controls-update-detection", test_latest_identity_controls_update_detection);
        Test.add_func ("/update-transaction/latest-restores-installed-variant", test_latest_restores_installed_variant);
        Test.add_func ("/update-transaction/latest-incompatible-restored-variant-is-skipped", test_latest_incompatible_restored_variant_is_skipped);
        Test.add_func ("/update-transaction/latest-legacy-variant-falls-back-to-compatible-release", test_latest_legacy_variant_falls_back_to_compatible_release);
        Test.add_func ("/update-transaction/latest-legacy-variant-without-compatible-release-is-untouched", test_latest_legacy_variant_without_compatible_release_is_untouched);
        Test.add_func ("/update-transaction/stable-variant-id-survives-release-display-name-change", test_stable_variant_id_survives_release_display_name_change);
        Test.add_func ("/update-transaction/bulk-updates-skip-incompatible-targets", test_bulk_updates_skip_incompatible_targets);
        Test.add_func ("/update-transaction/background-update-records-steam-receipt", test_background_update_records_steam_receipt);
    }

    private string create_temp_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-update-transaction-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create test directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private ReturnCode finalize_replacement (string runner_directory, string backup_directory, bool migrate_default_prefix) {
        var loop = new MainLoop ();
        ReturnCode result = ReturnCode.FILESYSTEM_ERROR;
        var workflow = new ProtonPlus.Services.StandardArchiveWorkflow ();

        workflow.finalize_replaced_runner.begin (
            runner_directory,
            backup_directory,
            migrate_default_prefix,
            (obj, res) => {
                result = workflow.finalize_replaced_runner.end (res);
                loop.quit ();
            }
        );
        loop.run ();
        return result;
    }

    private ProviderTool failing_runner (
        string root,
        SourceType source_type,
        ArchiveInstallRequirement archive_install_requirement = ArchiveInstallRequirement.STANDARD
    ) {
        var launcher = new Launcher ("Fixture", Launcher.InstallationTypes.SYSTEM, "", { root });
        var group = new Group ("Fixture", "", "", launcher);
        var definition = new ProviderDefinition (
            Category.PROTON, source_type, "fixture-%s".printf (ProviderDefinition.source_id_for (source_type)),
            "Fixture Runner", "", "https://example.test/releases", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") }, null, null, "", false,
            source_type == SourceType.GITHUB_ACTIONS ? "https://example.test/artifacts/{id}/fixture.zip" : "",
            archive_install_requirement
        );
        return new ProviderTool.with_catalog (
            definition, new FailingReleaseSource (), group, InstallLayout.template ("default", "$release_name")
        );
    }

    private ProviderTool static_runner (string root, Release release) {
        var launcher = new Launcher ("Fixture", Launcher.InstallationTypes.SYSTEM, "", { root });
        var group = new Group ("Fixture", "", "", launcher);
        var definition = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, "fixture-static", "Fixture Runner", "",
            "https://example.test/releases", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") }
        );
        if (release.variants.size == 0) {
            release.variants.add (new ProtonPlus.Models.Variant (
                "default", "Default", "", true, release.asset.download_url
            ));
        }
        return new ProviderTool.with_catalog (
            definition, new StaticReleaseSource (release), group,
            InstallLayout.template ("default", "$release_name")
        );
    }

    private ReturnCode update_specific_runner (ProviderTool runner) {
        return update_specific_runner_with_coordinator (runner, new FixtureCoordinator ());
    }

    private ReturnCode update_specific_runner_with_coordinator (
        ProviderTool runner,
        FixtureCoordinator coordinator,
        string? installation_location = null
    ) {
        var loop = new MainLoop ();
        ReturnCode result = ReturnCode.FILESYSTEM_ERROR;
        var workflow = new ProtonPlus.Services.StandardArchiveWorkflow ();
        workflow.update_specific_runner.begin (runner, coordinator, installation_location, (obj, response) => {
            result = workflow.update_specific_runner.end (response);
            loop.quit ();
        });
        loop.run ();
        return result;
    }

    private bool delete_directory (string path) {
        var loop = new MainLoop ();
        bool deleted = false;

        ProtonPlus.Utils.Filesystem.delete_directory.begin (path, (obj, result) => {
            deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (result);
            loop.quit ();
        });
        loop.run ();
        return deleted;
    }

    private void create_file (string path, string content) {
        ProtonPlus.Utils.Filesystem.create_file (path, content);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (path) == content);
    }

    private void cache_archive (string cache, string url) {
        var archive_dir = Path.build_filename (cache, "archives");
        assert (ProtonPlus.Utils.Filesystem.create_directory (archive_dir));
        var archive = Path.build_filename (archive_dir,
            "%s.zip".printf (Checksum.compute_for_string (ChecksumType.SHA256, url)));
        try {
            FileUtils.set_data (archive, Base64.decode (ProtonPlus.Utils.Filesystem.get_file_content (
                Path.build_filename ("fixtures", "archives", "runner.zip.base64")
            ).strip ()));
        } catch (FileError e) {
            critical ("Could not seed cached archive: %s", e.message);
            assert_not_reached ();
        }
    }

    private void seed_latest_installation (ProviderTool runner, string tag) {
        var directory = Path.build_filename (runner.group.launcher.directory, "compatibilitytools.d",
            "%s Latest".printf (runner.title));
        assert (ProtonPlus.Utils.Filesystem.create_directory (directory));
        var metadata = new ProtonPlus.Utils.Metadata ();
        metadata.tag = tag;
        metadata.provider_id = runner.provider_id;
        metadata.tool_id = runner.id;
        metadata.launcher_id = runner.group.launcher.tool_target_id;
        assert (metadata.save (directory));
    }

    private void test_migrates_settings_prefix_and_cleans_backup () {
        var root = create_temp_directory ();
        var runner_directory = Path.build_filename (root, "runner");
        var backup_directory = Path.build_filename (root, "backup");
        var runner_prefix = Path.build_filename (runner_directory, "files", "share", "default_pfx");
        var backup_prefix = Path.build_filename (backup_directory, "files", "share", "default_pfx");
        assert (ProtonPlus.Utils.Filesystem.create_directory (runner_prefix));
        assert (ProtonPlus.Utils.Filesystem.create_directory (backup_prefix));
        create_file (Path.build_filename (runner_directory, "marker.txt"), "new runner\n");
        create_file (Path.build_filename (runner_prefix, "prefix.txt"), "new prefix\n");
        create_file (Path.build_filename (backup_directory, "marker.txt"), "old runner\n");
        create_file (Path.build_filename (backup_directory, "user_settings.py"), "old settings\n");
        create_file (Path.build_filename (backup_prefix, "prefix.txt"), "old prefix\n");

        assert (finalize_replacement (runner_directory, backup_directory, true) == ReturnCode.RUNNER_UPDATED);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (runner_directory, "marker.txt")) == "new runner\n");
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (runner_directory, "user_settings.py")) == "old settings\n");
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (runner_prefix, "prefix.txt")) == "old prefix\n");
        assert (!FileUtils.test (backup_directory, FileTest.EXISTS));
        assert (!FileUtils.test ("%s.failed".printf (backup_directory), FileTest.EXISTS));
        assert (delete_directory (root));
    }

    private void test_migrates_settings_symlink () {
        var root = create_temp_directory ();
        var runner_directory = Path.build_filename (root, "runner");
        var backup_directory = Path.build_filename (root, "backup");
        var settings_target = Path.build_filename (root, "shared-settings.py");
        assert (ProtonPlus.Utils.Filesystem.create_directory (runner_directory));
        assert (ProtonPlus.Utils.Filesystem.create_directory (backup_directory));
        create_file (settings_target, "shared settings\n");

        var backup_settings = Path.build_filename (backup_directory, "user_settings.py");
        assert (Posix.symlink (settings_target, backup_settings) == 0);

        assert (finalize_replacement (runner_directory, backup_directory, false) == ReturnCode.RUNNER_UPDATED);
        var runner_settings = Path.build_filename (runner_directory, "user_settings.py");
        assert (FileUtils.test (runner_settings, FileTest.IS_SYMLINK));
        assert (ProtonPlus.Utils.Filesystem.get_file_content (runner_settings) == "shared settings\n");
        assert (!FileUtils.test (backup_directory, FileTest.EXISTS));
        assert (delete_directory (root));
    }

    private void test_migration_failure_rolls_back_runner () {
        var root = create_temp_directory ();
        var runner_directory = Path.build_filename (root, "runner");
        var backup_directory = Path.build_filename (root, "backup");
        var settings_target = Path.build_filename (root, "shared-settings.py");
        assert (ProtonPlus.Utils.Filesystem.create_directory (runner_directory));
        assert (ProtonPlus.Utils.Filesystem.create_directory (backup_directory));
        create_file (Path.build_filename (runner_directory, "marker.txt"), "new runner\n");
        create_file (Path.build_filename (runner_directory, "user_settings.py"), "new settings\n");
        create_file (Path.build_filename (backup_directory, "marker.txt"), "old runner\n");
        create_file (settings_target, "old settings\n");

        var backup_settings = Path.build_filename (backup_directory, "user_settings.py");
        assert (Posix.symlink (settings_target, backup_settings) == 0);

        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*File exists*");
        assert (finalize_replacement (runner_directory, backup_directory, false) == ReturnCode.FILESYSTEM_ERROR);
        Test.assert_expected_messages ();
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (runner_directory, "marker.txt")) == "old runner\n");
        assert (FileUtils.test (Path.build_filename (runner_directory, "user_settings.py"), FileTest.IS_SYMLINK));
        assert (!FileUtils.test (backup_directory, FileTest.EXISTS));
        assert (!FileUtils.test ("%s.failed".printf (backup_directory), FileTest.EXISTS));
        assert (delete_directory (root));
    }

    private void test_github_actions_request_failure_is_propagated () {
        var actions_root = create_temp_directory ();
        var actions_runner = failing_runner (
            actions_root, SourceType.GITHUB_ACTIONS, ArchiveInstallRequirement.NESTED_ARCHIVE
        );
        var actions_directory = Path.build_filename (actions_root, "Fixture Runner Latest");
        assert (ProtonPlus.Utils.Filesystem.create_directory (actions_directory));
        var actions_metadata = new ProtonPlus.Utils.Metadata ();
        actions_metadata.tag = "installed-actions";
        assert (actions_metadata.save (actions_directory));
        assert (update_specific_runner (actions_runner) == ReturnCode.REQUEST_FAILED);

        var regular_root = create_temp_directory ();
        var regular_runner = failing_runner (regular_root, SourceType.GITHUB);
        var regular_directory = Path.build_filename (regular_root, "Fixture Runner Latest");
        assert (ProtonPlus.Utils.Filesystem.create_directory (regular_directory));
        var regular_metadata = new ProtonPlus.Utils.Metadata ();
        regular_metadata.tag = "installed-regular";
        assert (regular_metadata.save (regular_directory));
        assert (update_specific_runner (regular_runner) == ReturnCode.NOTHING_TO_UPDATE);

        var standard_actions_root = create_temp_directory ();
        var standard_actions_runner = failing_runner (standard_actions_root, SourceType.GITHUB_ACTIONS);
        var standard_actions_directory = Path.build_filename (standard_actions_root, "Fixture Runner Latest");
        assert (ProtonPlus.Utils.Filesystem.create_directory (standard_actions_directory));
        var standard_actions_metadata = new ProtonPlus.Utils.Metadata ();
        standard_actions_metadata.tag = "installed-standard-actions";
        assert (standard_actions_metadata.save (standard_actions_directory));
        assert (update_specific_runner (standard_actions_runner) == ReturnCode.NOTHING_TO_UPDATE);

        var nested_regular_root = create_temp_directory ();
        var nested_regular_runner = failing_runner (
            nested_regular_root, SourceType.GITHUB, ArchiveInstallRequirement.NESTED_ARCHIVE
        );
        var nested_regular_directory = Path.build_filename (nested_regular_root, "Fixture Runner Latest");
        assert (ProtonPlus.Utils.Filesystem.create_directory (nested_regular_directory));
        var nested_regular_metadata = new ProtonPlus.Utils.Metadata ();
        nested_regular_metadata.tag = "installed-nested-regular";
        assert (nested_regular_metadata.save (nested_regular_directory));
        assert (update_specific_runner (nested_regular_runner) == ReturnCode.REQUEST_FAILED);

        assert (delete_directory (actions_root));
        assert (delete_directory (regular_root));
        assert (delete_directory (standard_actions_root));
        assert (delete_directory (nested_regular_root));
    }

    private void test_latest_identity_controls_update_detection () {
        var current_root = create_temp_directory ();
        var current_release = new Release (
            "v2", "", "", new Models.Assets.Asset ("runner.zip", "https://example.test/v2.zip"),
            "", 0, "release-v2", "v2"
        );
        var current_runner = static_runner (current_root, current_release);
        var current_directory = Path.build_filename (current_root, "Fixture Runner Latest");
        assert (ProtonPlus.Utils.Filesystem.create_directory (current_directory));
        var current_metadata = new ProtonPlus.Utils.Metadata ();
        current_metadata.tag = "v2";
        current_metadata.release_id = "release-v2";
        assert (current_metadata.save (current_directory));
        var current_coordinator = new FixtureCoordinator ();

        assert (update_specific_runner_with_coordinator (current_runner, current_coordinator) == ReturnCode.NOTHING_TO_UPDATE);
        assert (current_coordinator.install_calls == 0);

        var stale_root = create_temp_directory ();
        var stale_runner = static_runner (stale_root, current_release);
        var stale_directory = Path.build_filename (stale_root, "Fixture Runner Latest");
        assert (ProtonPlus.Utils.Filesystem.create_directory (stale_directory));
        var stale_metadata = new ProtonPlus.Utils.Metadata ();
        stale_metadata.tag = "v1";
        stale_metadata.release_id = "release-v1";
        assert (stale_metadata.save (stale_directory));
        var stale_coordinator = new FixtureCoordinator ();

        assert (update_specific_runner_with_coordinator (stale_runner, stale_coordinator) == ReturnCode.FILESYSTEM_ERROR);
        assert (stale_coordinator.install_calls == 1);

        assert (delete_directory (current_root));
        assert (delete_directory (stale_root));
    }

    private void test_latest_restores_installed_variant () {
        var root = create_temp_directory ();
        var release = new Release (
            "v2", "", "", new Models.Assets.Asset ("runner.zip", "https://example.test/default.zip"),
            "", 0, "release-v2", "v2"
        );
        release.variants.add (new ProtonPlus.Models.Variant (
            "default", "Default", "runner", true, "https://example.test/default.zip"
        ));
        release.variants.add (new ProtonPlus.Models.Variant (
            "alternate", "Alternate", "runner-alternate", false, "https://example.test/alternate.zip"
        ));
        var runner = static_runner (root, release);
        var directory = Path.build_filename (root, "Fixture Runner Latest-Alternate");
        assert (ProtonPlus.Utils.Filesystem.create_directory (directory));
        var metadata = new ProtonPlus.Utils.Metadata ();
        metadata.tag = "v1";
        metadata.release_id = "release-v1";
        metadata.variant_id = "alternate";
        assert (metadata.save (directory));

        var coordinator = new FixtureCoordinator ();

        assert (update_specific_runner_with_coordinator (runner, coordinator, directory) == ReturnCode.FILESYSTEM_ERROR);
        assert (coordinator.install_calls == 1);
        assert (coordinator.selected_url == "https://example.test/alternate.zip");
        assert (coordinator.selected_variant_id == "alternate");

        assert (delete_directory (root));
    }

    private void test_latest_incompatible_restored_variant_is_skipped () {
        var root = create_temp_directory ();
        var release = new Release (
            "v2", "", "", new Models.Assets.Asset ("runner.zip", "https://example.test/v3.zip"),
            "", 0, "release-v2", "v2"
        );
        release.variants.add (new ProtonPlus.Models.Variant (
            "v3", "Optimized", "", true, "https://example.test/v3.zip",
            VariantCompatibility.for_x86_64_level (X86_64Level.V3)
        ));
        var runner = static_runner (root, release);
        var directory = Path.build_filename (root, "Fixture Runner Latest-Optimized");
        assert (ProtonPlus.Utils.Filesystem.create_directory (directory));
        var metadata = new ProtonPlus.Utils.Metadata ();
        metadata.tag = "v1";
        metadata.variant_id = "v3";
        assert (metadata.save (directory));

        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        var coordinator = new FixtureCoordinator ();
        assert (update_specific_runner_with_coordinator (runner, coordinator, directory) == ReturnCode.INCOMPATIBLE_VARIANT);
        assert (coordinator.install_calls == 0);
        assert (FileUtils.test (directory, FileTest.IS_DIR));
        Globals.CPU_CAPABILITIES = previous_capabilities;
        assert (delete_directory (root));
    }

    private void test_latest_legacy_variant_falls_back_to_compatible_release () {
        var root = create_temp_directory ();
        var release = new Release (
            "v2", "", "", new Models.Assets.Asset ("runner.zip", "https://example.test/v3.zip"),
            "", 0, "release-v2", "v2"
        );
        release.variants.add (new ProtonPlus.Models.Variant (
            "v3", "Optimized", "", true, "https://example.test/v3.zip",
            VariantCompatibility.for_x86_64_level (X86_64Level.V3)
        ));
        release.variants.add (new ProtonPlus.Models.Variant (
            "base", "Baseline", "", false, "https://example.test/base.zip",
            VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)
        ));
        var runner = static_runner (root, release);
        var directory = Path.build_filename (root, "Fixture Runner Latest");
        assert (ProtonPlus.Utils.Filesystem.create_directory (directory));
        var metadata = new ProtonPlus.Utils.Metadata ();
        metadata.tag = "v1";
        assert (metadata.save (directory));

        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        var coordinator = new FixtureCoordinator ();
        assert (update_specific_runner_with_coordinator (runner, coordinator, directory) == ReturnCode.FILESYSTEM_ERROR);
        assert (coordinator.install_calls == 1);
        assert (coordinator.selected_variant_id == "base");
        assert (coordinator.selected_url == "https://example.test/base.zip");
        Globals.CPU_CAPABILITIES = previous_capabilities;
        assert (delete_directory (root));
    }

    private void test_latest_legacy_variant_without_compatible_release_is_untouched () {
        var root = create_temp_directory ();
        var release = new Release (
            "v2", "", "", new Models.Assets.Asset ("runner.zip", "https://example.test/v3.zip"),
            "", 0, "release-v2", "v2"
        );
        release.variants.add (new ProtonPlus.Models.Variant (
            "v3", "Optimized", "", true, "https://example.test/v3.zip",
            VariantCompatibility.for_x86_64_level (X86_64Level.V3)
        ));
        var runner = static_runner (root, release);
        var directory = Path.build_filename (root, "Fixture Runner Latest");
        assert (ProtonPlus.Utils.Filesystem.create_directory (directory));
        ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (directory, "old-marker"), "old\n");
        var metadata = new ProtonPlus.Utils.Metadata ();
        metadata.tag = "v1";
        assert (metadata.save (directory));

        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        var coordinator = new FixtureCoordinator ();
        assert (update_specific_runner_with_coordinator (runner, coordinator, directory) == ReturnCode.INCOMPATIBLE_VARIANT);
        assert (coordinator.install_calls == 0);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (directory, "old-marker")) == "old\n");
        Globals.CPU_CAPABILITIES = previous_capabilities;
        assert (delete_directory (root));
    }

    private void test_stable_variant_id_survives_release_display_name_change () {
        var root = create_temp_directory ();
        var old_release = new Release (
            "v1", "", "", new Models.Assets.Asset ("runner.zip", "https://example.test/old.zip"),
            "", 0, "release-v1", "v1"
        );
        old_release.variants.add (new ProtonPlus.Models.Variant (
            "baseline", "Original name", "", true, "https://example.test/old.zip"
        ));
        var runner = static_runner (root, old_release);
        var job = new ProtonPlus.Services.InstallJob (old_release, runner, ProtonPlus.Services.InstallJob.Mode.LATEST);
        job.set_selected_variant ("Original name", old_release.asset, "baseline");

        var updated_release = new Release (
            "v2", "", "", new Models.Assets.Asset ("runner.zip", "https://example.test/new.zip"),
            "", 0, "release-v2", "v2"
        );
        updated_release.variants.add (new ProtonPlus.Models.Variant (
            "baseline", "Renamed build", "", true, "https://example.test/new.zip"
        ));
        updated_release.variants.add (new ProtonPlus.Models.Variant (
            "alternate", "Original name", "", false, "https://example.test/alternate.zip"
        ));
        job.set_release_for_update (updated_release);

        assert (job.selected_variant_id == "baseline");
        assert (job.selected_variant_name == "Renamed build");
        assert (job.selected_asset.download_url == "https://example.test/new.zip");
        assert (delete_directory (root));
    }

    private void test_bulk_updates_skip_incompatible_targets () {
        var root = create_temp_directory ();
        var cache = Path.build_filename (root, "cache");
        var tools = Path.build_filename (root, "tools");
        var previous_cache_path = Globals.CACHE_PATH;
        Globals.CACHE_PATH = cache;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache));
        assert (ProtonPlus.Utils.Filesystem.create_directory (tools));

        var launcher = new Launcher ("Fixture", Launcher.InstallationTypes.SYSTEM, "", { tools }, "fixture");
        var group = new Group ("Fixture", "", "", launcher, "fixture");
        group.tools = new Gee.LinkedList<Models.Tool> ();
        launcher.groups = { group };

        var compatible_url = "https://fixtures.invalid/compatible-runner.zip";
        var compatible_release = new Release (
            "v2", "", "", new Models.Assets.Asset ("runner.zip", compatible_url), "", 0, "compatible-v2", "v2"
        );
        compatible_release.variants.add (new ProtonPlus.Models.Variant (
            "base", "Baseline", "", true, compatible_url,
            VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)
        ));
        var incompatible_release = new Release (
            "v2", "", "", new Models.Assets.Asset ("runner.zip", "https://fixtures.invalid/incompatible-runner.zip"), "", 0, "incompatible-v2", "v2"
        );
        incompatible_release.variants.add (new ProtonPlus.Models.Variant (
            "v3", "Optimized", "", true, "https://fixtures.invalid/incompatible-runner.zip",
            VariantCompatibility.for_x86_64_level (X86_64Level.V3)
        ));

        var compatible_definition = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, "compatible-fixture", "Compatible Runner", "",
            "https://example.test/releases", 1,
            { new VariantDefinition ("base", "Baseline", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") }
        );
        var incompatible_definition = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, "incompatible-fixture", "Incompatible Runner", "",
            "https://example.test/releases", 1,
            { new VariantDefinition ("v3", "Optimized", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") }
        );
        var compatible_source = new StaticReleaseSource (compatible_release);
        var incompatible_source = new StaticReleaseSource (incompatible_release);
        var compatible_runner = new ProviderTool.with_catalog (
            compatible_definition, compatible_source, group, InstallLayout.template ("default", "$release_name")
        );
        var incompatible_runner = new ProviderTool.with_catalog (
            incompatible_definition, incompatible_source, group, InstallLayout.template ("default", "$release_name")
        );
        group.tools.add (incompatible_runner);
        group.tools.add (compatible_runner);

        var compatible_directory = Path.build_filename (tools, "Compatible Runner Latest");
        var incompatible_directory = Path.build_filename (tools, "Incompatible Runner Latest");
        assert (ProtonPlus.Utils.Filesystem.create_directory (compatible_directory));
        assert (ProtonPlus.Utils.Filesystem.create_directory (incompatible_directory));
        ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (incompatible_directory, "old-marker"), "old\n");
        var compatible_metadata = new ProtonPlus.Utils.Metadata ();
        compatible_metadata.tag = "v1";
        compatible_metadata.provider_id = compatible_runner.provider_id;
        compatible_metadata.tool_id = compatible_runner.id;
        compatible_metadata.launcher_id = launcher.tool_target_id;
        assert (compatible_metadata.save (compatible_directory));
        var incompatible_metadata = new ProtonPlus.Utils.Metadata ();
        incompatible_metadata.tag = "v1";
        incompatible_metadata.variant_id = "v3";
        incompatible_metadata.provider_id = incompatible_runner.provider_id;
        incompatible_metadata.tool_id = incompatible_runner.id;
        incompatible_metadata.launcher_id = launcher.tool_target_id;
        assert (incompatible_metadata.save (incompatible_directory));

        var archive_cache = Path.build_filename (
            cache, "archives", "%s.zip".printf (Checksum.compute_for_string (ChecksumType.SHA256, compatible_url))
        );
        assert (ProtonPlus.Utils.Filesystem.create_directory (Path.get_dirname (archive_cache)));
        try {
            FileUtils.set_data (archive_cache, Base64.decode (ProtonPlus.Utils.Filesystem.get_file_content (
                Path.build_filename ("fixtures", "archives", "runner.zip.base64")
            ).strip ()));
        } catch (FileError e) {
            critical ("Could not seed cached archive: %s", e.message);
            assert_not_reached ();
        }

        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        var launchers = new List<Launcher> ();
        launchers.append (launcher);
        var loop = new MainLoop ();
        ReturnCode result = ReturnCode.FILESYSTEM_ERROR;
        ProtonPlus.Services.InstallationService.instance.check_for_updates.begin (launchers, (obj, response) => {
            result = ProtonPlus.Services.InstallationService.instance.check_for_updates.end (response);
            loop.quit ();
        });
        loop.run ();

        assert (result == ReturnCode.RUNNERS_UPDATED);
        assert (incompatible_source.requests == 1);
        assert (compatible_source.requests == 1);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (incompatible_directory, "old-marker")) == "old\n");
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (compatible_directory, "marker.txt")) == "new runner\n");
        Globals.CPU_CAPABILITIES = previous_capabilities;
        Globals.CACHE_PATH = previous_cache_path;
        assert (delete_directory (root));
    }

    private void test_background_update_records_steam_receipt () {
        var root = create_temp_directory ();
        var cache = Path.build_filename (root, "cache");
        var steam_root = Path.build_filename (root, "host-data", "Steam");
        var previous_cache = Globals.CACHE_PATH;
        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CACHE_PATH = cache;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        InstallationService.reset_lifecycle_configuration_for_tests ();
        InstallationService.instance.configure_compatibility_process_guard (
            new CompatibilityProcessGuard (new EmptyCompatibilityProcessQuery ())
        );

        try {
            assert (ProtonPlus.Utils.Filesystem.create_directory (cache));
            assert (ProtonPlus.Utils.Filesystem.create_directory (Path.build_filename (
                steam_root, "compatibilitytools.d"
            )));
            var steam = new FixtureSteamLauncher (steam_root);
            var faugus = new FaugusLauncher (
                Launcher.InstallationTypes.SYSTEM,
                root,
                Path.build_filename (root, "host-data"),
                Path.build_filename (root, "config"),
                Path.build_filename (root, "data"),
                Path.build_filename (root, "state")
            );
            assert (faugus.directory == steam_root);
            assert (steam.get_steam_restart_target ().id == faugus.get_steam_restart_target ().id);

            var steam_group = new Group ("Proton", "", "/compatibilitytools.d", steam, "proton");
            steam_group.tools = new Gee.LinkedList<Models.Tool> ();
            steam.groups = { steam_group };
            var faugus_group = new Group ("Proton", "", "/compatibilitytools.d", faugus, "proton");
            faugus_group.tools = new Gee.LinkedList<Models.Tool> ();
            faugus.groups = { faugus_group };

            var update_url = "https://fixtures.invalid/background-update.zip";
            var update_release = new Release (
                "v2", "", "", new Models.Assets.Asset ("runner.zip", update_url), "", 0,
                "background-v2", "v2"
            );
            update_release.variants.add (new Models.Variant ("base", "Baseline", "", true, update_url,
                VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)));
            var update_definition = new ProviderDefinition (
                Category.PROTON, SourceType.GITHUB, "background-provider", "Background Runner", "",
                "https://fixtures.invalid/releases", 1,
                { new VariantDefinition ("base", "Baseline", "$release_name", true,
                    VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)) },
                { InstallLayout.template ("default", "$release_name") }
            );
            var update_source = new StaticReleaseSource (update_release);
            var update_runner = new ProviderTool.with_catalog (
                update_definition, update_source, steam_group,
                InstallLayout.template ("default", "$release_name")
            );
            steam_group.tools.add (update_runner);
            var duplicate_source = new StaticReleaseSource (update_release);
            var faugus_duplicate = new ProviderTool.with_catalog (
                update_definition, duplicate_source, faugus_group,
                InstallLayout.template ("default", "$release_name")
            );
            faugus_group.tools.add (faugus_duplicate);
            assert (update_runner.id == faugus_duplicate.id);
            seed_latest_installation (update_runner, "v1");
            cache_archive (cache, update_url);

            var current_url = "https://fixtures.invalid/background-current.zip";
            var current_release = new Release (
                "v2", "", "", new Models.Assets.Asset ("runner.zip", current_url), "", 0,
                "background-current-v2", "v2"
            );
            current_release.variants.add (new Models.Variant ("base", "Baseline", "", true, current_url));
            var current_definition = new ProviderDefinition (
                Category.PROTON, SourceType.GITHUB, "background-current", "Current Runner", "",
                "https://fixtures.invalid/releases", 1,
                { new VariantDefinition ("base", "Baseline", "$release_name", true) },
                { InstallLayout.template ("default", "$release_name") }
            );
            var current_source = new StaticReleaseSource (current_release);
            var current_runner = new ProviderTool.with_catalog (
                current_definition, current_source, steam_group,
                InstallLayout.template ("default", "$release_name")
            );
            steam_group.tools.add (current_runner);
            seed_latest_installation (current_runner, "v2");

            var incompatible_url = "https://fixtures.invalid/background-incompatible.zip";
            var incompatible_release = new Release (
                "v2", "", "", new Models.Assets.Asset ("runner.zip", incompatible_url), "", 0,
                "background-incompatible-v2", "v2"
            );
            incompatible_release.variants.add (new Models.Variant ("v3", "Optimized", "", true,
                incompatible_url, VariantCompatibility.for_x86_64_level (X86_64Level.V3)));
            var incompatible_definition = new ProviderDefinition (
                Category.PROTON, SourceType.GITHUB, "background-incompatible", "Incompatible Runner", "",
                "https://fixtures.invalid/releases", 1,
                { new VariantDefinition ("v3", "Optimized", "$release_name", true,
                    VariantCompatibility.for_x86_64_level (X86_64Level.V3)) },
                { InstallLayout.template ("default", "$release_name") }
            );
            var incompatible_source = new StaticReleaseSource (incompatible_release);
            var incompatible_runner = new ProviderTool.with_catalog (
                incompatible_definition, incompatible_source, steam_group,
                InstallLayout.template ("default", "$release_name")
            );
            steam_group.tools.add (incompatible_runner);
            seed_latest_installation (incompatible_runner, "v1");

            var recorder = new RecordingSteamChange ();
            InstallationService.instance.configure_steam_change_recorder (recorder);
            var launchers = new List<Launcher> ();
            launchers.append (steam);
            launchers.append (faugus);
            var loop = new MainLoop ();
            ReturnCode result = ReturnCode.FILESYSTEM_ERROR;
            InstallationService.instance.check_for_updates.begin (launchers, (obj, response) => {
                result = InstallationService.instance.check_for_updates.end (response);
                loop.quit ();
            });
            loop.run ();

            assert (result == ReturnCode.RUNNERS_UPDATED);
            assert (recorder.receipts.size == 1);
            var receipt = recorder.receipts.get (0);
            assert (receipt.kind == SteamChangeKind.COMPATIBILITY_TOOL_UPDATED_OR_REPLACED);
            assert (receipt.target.id == steam.get_steam_restart_target ().id);
            var expected_path = Path.build_filename (steam_root, "compatibilitytools.d", "Background Runner Latest");
            assert (receipt.resource_key == Filename.canonicalize (expected_path, null));
            assert (duplicate_source.requests == 0);
            assert (current_source.requests == 1);
            assert (incompatible_source.requests == 1);

            InstallationService.instance.check_for_updates.begin (launchers, (obj, response) => {
                result = InstallationService.instance.check_for_updates.end (response);
                loop.quit ();
            });
            loop.run ();
            assert (result == ReturnCode.NOTHING_TO_UPDATE);
            assert (recorder.receipts.size == 1);
        } finally {
            InstallationService.reset_lifecycle_configuration_for_tests ();
            Globals.CPU_CAPABILITIES = previous_capabilities;
            Globals.CACHE_PATH = previous_cache;
            assert (delete_directory (root));
        }
    }
}
