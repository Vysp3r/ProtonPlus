namespace AppTests.MigrationV0_6_6Test {
    using GLib;
    using ProtonPlus.Services.Migrations.Versions;

    public void register_tests () {
        Test.add_func ("/migrations/v0.6.6/removes-legacy-flatpak-systemd-units", test_removes_legacy_flatpak_systemd_units);
        Test.add_func ("/migrations/v0.6.6/removes-empty-legacy-flatpak-systemd-directories", test_removes_empty_legacy_flatpak_systemd_directories);
        Test.add_func ("/migrations/v0.6.6/native-install-does-not-remove-units", test_native_install_does_not_remove_units);
    }

    private string temporary_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-migration-v0.6.6-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create temporary directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private void create_file (string path) {
        try {
            var parent = File.new_for_path (Path.get_dirname (path));
            if (!parent.query_exists ())
                parent.make_directory_with_parents ();
            FileUtils.set_contents (path, "fixture\n");
        } catch (Error e) {
            critical ("Could not create fixture: %s", e.message);
            assert_not_reached ();
        }
    }

    private void remove_fixture (string root) {
        var systemd_dir = Path.build_filename (root, "systemd", "user");
        foreach (var name in new string[] {
            "protonplus.service",
            "protonplus.timer",
            "other.service"
        }) {
            var path = Path.build_filename (systemd_dir, name);
            if (FileUtils.test (path, FileTest.EXISTS))
                assert (FileUtils.remove (path) == 0);
        }

        if (FileUtils.test (systemd_dir, FileTest.IS_DIR))
            assert (DirUtils.remove (systemd_dir) == 0);
        var systemd_parent = Path.build_filename (root, "systemd");
        if (FileUtils.test (systemd_parent, FileTest.IS_DIR))
            assert (DirUtils.remove (systemd_parent) == 0);
        assert (DirUtils.remove (root) == 0);
    }

    private void test_removes_legacy_flatpak_systemd_units () {
        var root = temporary_directory ();
        var systemd_dir = Path.build_filename (root, "systemd", "user");
        var service_path = Path.build_filename (systemd_dir, "protonplus.service");
        var timer_path = Path.build_filename (systemd_dir, "protonplus.timer");
        var unrelated_path = Path.build_filename (systemd_dir, "other.service");

        create_file (service_path);
        create_file (timer_path);
        create_file (unrelated_path);

        v0_6_6.cleanup_legacy_flatpak_systemd_units (true, root);

        assert (!FileUtils.test (service_path, FileTest.EXISTS));
        assert (!FileUtils.test (timer_path, FileTest.EXISTS));
        assert (FileUtils.test (unrelated_path, FileTest.EXISTS));
        assert (FileUtils.test (systemd_dir, FileTest.IS_DIR));
        remove_fixture (root);
    }

    private void test_removes_empty_legacy_flatpak_systemd_directories () {
        var root = temporary_directory ();
        var systemd_parent = Path.build_filename (root, "systemd");
        var systemd_dir = Path.build_filename (systemd_parent, "user");
        var service_path = Path.build_filename (systemd_dir, "protonplus.service");
        var timer_path = Path.build_filename (systemd_dir, "protonplus.timer");

        create_file (service_path);
        create_file (timer_path);

        v0_6_6.cleanup_legacy_flatpak_systemd_units (true, root);

        assert (!FileUtils.test (service_path, FileTest.EXISTS));
        assert (!FileUtils.test (timer_path, FileTest.EXISTS));
        assert (!FileUtils.test (systemd_dir, FileTest.IS_DIR));
        assert (!FileUtils.test (systemd_parent, FileTest.IS_DIR));
        assert (DirUtils.remove (root) == 0);
    }

    private void test_native_install_does_not_remove_units () {
        var root = temporary_directory ();
        var systemd_dir = Path.build_filename (root, "systemd", "user");
        var service_path = Path.build_filename (systemd_dir, "protonplus.service");
        var timer_path = Path.build_filename (systemd_dir, "protonplus.timer");

        create_file (service_path);
        create_file (timer_path);

        v0_6_6.cleanup_legacy_flatpak_systemd_units (false, root);

        assert (FileUtils.test (service_path, FileTest.EXISTS));
        assert (FileUtils.test (timer_path, FileTest.EXISTS));
        remove_fixture (root);
    }
}
