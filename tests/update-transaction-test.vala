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

    private class FixtureCoordinator : Object, ProtonPlus.Services.InstallationOperationCoordinator {
        public async ReturnCode install_for_update (ProtonPlus.Services.InstallJob job) {
            return ReturnCode.FILESYSTEM_ERROR;
        }
    }

    public void register_tests () {
        Test.add_func ("/update-transaction/migrates-settings-prefix-and-cleans-backup", test_migrates_settings_prefix_and_cleans_backup);
        Test.add_func ("/update-transaction/migrates-settings-symlink", test_migrates_settings_symlink);
        Test.add_func ("/update-transaction/migration-failure-rolls-back-runner", test_migration_failure_rolls_back_runner);
        Test.add_func ("/update-transaction/github-actions-request-failure-is-propagated", test_github_actions_request_failure_is_propagated);
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

    private ReturnCode update_specific_runner (ProviderTool runner) {
        var loop = new MainLoop ();
        ReturnCode result = ReturnCode.FILESYSTEM_ERROR;
        var workflow = new ProtonPlus.Services.StandardArchiveWorkflow ();
        workflow.update_specific_runner.begin (runner, new FixtureCoordinator (), (obj, response) => {
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
}
