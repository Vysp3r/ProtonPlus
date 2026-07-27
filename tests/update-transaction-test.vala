namespace AppTests.UpdateTransactionTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Models.Tools;
    using ProtonPlus.Providers.Sources;

    private class FailingReleaseSource : Object, ReleaseSource {
        public async ReleasePageResult fetch_page (ProviderDefinition definition, int requested_page, int limit) {
            return ReleasePageResult.failure (ReturnCode.REQUEST_FAILED);
        }
    }

    private class StaticReleaseSource : Object, ReleaseSource {
        private Release release;

        public StaticReleaseSource (Release release) {
            this.release = release;
        }

        public async ReleasePageResult fetch_page (ProviderDefinition definition, int requested_page, int limit) {
            var releases = new Gee.LinkedList<Release> ();
            releases.add (release);
            return ReleasePageResult.success (new ReleasePage (releases, requested_page + 1, false));
        }
    }

    private class FixtureCoordinator : Object, ProtonPlus.Services.InstallationOperationCoordinator {
        public int install_calls { get; private set; default = 0; }
        public string selected_url { get; private set; default = ""; }

        public async ReturnCode install_for_update (ProtonPlus.Services.InstallJob job) {
            install_calls++;
            selected_url = job.selected_asset.download_url;
            return ReturnCode.FILESYSTEM_ERROR;
        }
    }

    public void register_tests () {
        Test.add_func ("/update-transaction/migrates-settings-prefix-and-cleans-backup", test_migrates_settings_prefix_and_cleans_backup);
        Test.add_func ("/update-transaction/migrates-settings-symlink", test_migrates_settings_symlink);
        Test.add_func ("/update-transaction/migration-failure-rolls-back-runner", test_migration_failure_rolls_back_runner);
        Test.add_func ("/update-transaction/github-actions-request-failure-is-propagated", test_github_actions_request_failure_is_propagated);
        Test.add_func ("/update-transaction/latest-identity-controls-update-detection", test_latest_identity_controls_update_detection);
        Test.add_func ("/update-transaction/latest-restores-installed-variant", test_latest_restores_installed_variant);
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

        assert (delete_directory (root));
    }
}
