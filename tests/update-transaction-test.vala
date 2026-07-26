namespace AppTests.UpdateTransactionTest {
    using GLib;
    using ProtonPlus;

    public void register_tests () {
        Test.add_func ("/update-transaction/migrates-settings-prefix-and-cleans-backup", test_migrates_settings_prefix_and_cleans_backup);
        Test.add_func ("/update-transaction/migrates-settings-symlink", test_migrates_settings_symlink);
        Test.add_func ("/update-transaction/migration-failure-rolls-back-runner", test_migration_failure_rolls_back_runner);
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

        ProtonPlus.Models.Tool.finalize_replaced_runner.begin (
            runner_directory,
            backup_directory,
            migrate_default_prefix,
            (obj, res) => {
                result = ProtonPlus.Models.Tool.finalize_replaced_runner.end (res);
                loop.quit ();
            }
        );
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
}
