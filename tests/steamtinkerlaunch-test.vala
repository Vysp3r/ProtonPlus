namespace AppTests.SteamTinkerLaunchTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;

    private class FixtureSteamTinkerLaunch : ProtonPlus.Models.Releases.SteamTinkerLaunch {
        private string fixture_path;

        public FixtureSteamTinkerLaunch (Tool runner, string home_location, string fixture_path) {
            base (runner, home_location, false);
            this.fixture_path = fixture_path;
        }

        protected override string get_download_url () {
            return "https://fixtures.invalid/steamtinkerlaunch.zip";
        }

        protected override async bool download_archive (string url, string path, out string? error_message) {
            var copied = yield ProtonPlus.Utils.Filesystem.copy_file (fixture_path, path);
            error_message = copied ? null : "Could not copy fixture";
            return copied;
        }
    }

    public void register_tests () {
        Test.add_func ("/steamtinkerlaunch/replacement-link-failure-rolls-back", test_replacement_link_failure_rolls_back);
    }

    private string create_temp_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-steamtinkerlaunch-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create test directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private string materialize_archive_fixture (string root) {
        var encoded = ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename ("fixtures", "archives", "steamtinkerlaunch.zip.base64")
        ).strip ();
        assert (encoded != "");

        var fixture_path = Path.build_filename (root, "steamtinkerlaunch.zip");
        try {
            FileUtils.set_data (fixture_path, Base64.decode (encoded));
        } catch (FileError e) {
            critical ("Could not write archive fixture: %s", e.message);
            assert_not_reached ();
        }
        return fixture_path;
    }

    private Tool create_runner (string tools_root) {
        assert (ProtonPlus.Utils.Filesystem.create_directory (tools_root));
        var launcher = new Launcher ("Test", Launcher.InstallationTypes.SYSTEM, "", { tools_root });
        var group = new Group ("Test", "", "", launcher);
        return new ProtonPlus.Models.Tools.SteamTinkerLaunch (group);
    }

    private ReturnCode install_replacement (Release release) {
        var loop = new MainLoop ();
        ReturnCode result = ReturnCode.FILESYSTEM_ERROR;
        release.install_replacement.begin ((obj, res) => {
            result = release.install_replacement.end (res);
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

    private void assert_no_entries_with_prefix (string directory, string prefix) {
        try {
            var entries = Dir.open (directory);
            string? name;
            while ((name = entries.read_name ()) != null)
                assert (!name.has_prefix (prefix));
        } catch (FileError e) {
            critical ("Could not inspect temporary directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private void test_replacement_link_failure_rolls_back () {
        var root = create_temp_directory ();
        var cache_root = Path.build_filename (root, "cache");
        var tools_root = Path.build_filename (root, "tools");
        var install_parent = Path.build_filename (root, ".local", "share");
        var base_location = Path.build_filename (install_parent, "steamtinkerlaunch");
        var link_parent = Path.build_filename (root, ".local", "bin");
        var link_location = Path.build_filename (link_parent, "steamtinkerlaunch");
        Globals.CACHE_PATH = cache_root;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache_root));
        assert (ProtonPlus.Utils.Filesystem.create_directory (base_location));
        assert (ProtonPlus.Utils.Filesystem.create_directory (link_parent));
        ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (base_location, "marker.txt"), "previous stl\n");
        ProtonPlus.Utils.Filesystem.create_file (link_location, "blocked link\n");

        var fixture_path = materialize_archive_fixture (root);
        var release = new FixtureSteamTinkerLaunch (create_runner (tools_root), root, fixture_path);

        assert (release.asset.name == "steamtinkerlaunch.zip");
        assert (release.asset.download_url == "https://fixtures.invalid/steamtinkerlaunch.zip");

        assert (install_replacement (release) == ReturnCode.FILESYSTEM_ERROR);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (base_location, "marker.txt")) == "previous stl\n");
        assert (FileUtils.test (link_location, FileTest.IS_REGULAR));
        assert (ProtonPlus.Utils.Filesystem.get_file_content (link_location) == "blocked link\n");
        assert_no_entries_with_prefix (install_parent, ".protonplus-stl-stage-");
        assert_no_entries_with_prefix (install_parent, ".protonplus-stl-previous-");
        assert_no_entries_with_prefix (cache_root, ".protonplus-stl-");
        assert (delete_directory (root));
    }
}
