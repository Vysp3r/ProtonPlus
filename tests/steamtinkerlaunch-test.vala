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

    public void register_tests () { Test.add_func ("/steamtinkerlaunch/replacement-link-failure-rolls-back", test_replacement_link_failure_rolls_back); }
    private string temporary_directory () { try { return DirUtils.make_tmp ("protonplus-steamtinkerlaunch-test-XXXXXX"); } catch (FileError e) { critical ("Could not create test directory: %s", e.message); assert_not_reached (); } }
    private string fixture_archive (string root) {
        var encoded = ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename ("fixtures", "archives", "steamtinkerlaunch.zip.base64")).strip (); var path = Path.build_filename (root, "steamtinkerlaunch.zip");
        try { FileUtils.set_data (path, Base64.decode (encoded)); } catch (FileError e) { critical ("Could not write archive fixture: %s", e.message); assert_not_reached (); } return path;
    }
    private Tool tool (string root) { assert (ProtonPlus.Utils.Filesystem.create_directory (root)); var launcher = new Launcher ("Test", Launcher.InstallationTypes.SYSTEM, "", { root }); return new Models.Tools.SteamTinkerLaunch (new Group ("Test", "", "", launcher)); }
    private ReturnCode install_replacement (FixtureJob job) { var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR; job.install_replacement.begin ((obj, res) => { code = job.install_replacement.end (res); loop.quit (); }); loop.run (); return code; }
    private bool delete_directory (string path) { var loop = new MainLoop (); var deleted = false; ProtonPlus.Utils.Filesystem.delete_directory.begin (path, (obj, result) => { deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (result); loop.quit (); }); loop.run (); return deleted; }
    private void no_entries (string directory, string prefix) { try { var entries = Dir.open (directory); string? name; while ((name = entries.read_name ()) != null) assert (!name.has_prefix (prefix)); } catch (FileError e) { critical ("Could not inspect temporary directory: %s", e.message); assert_not_reached (); } }
    private void test_replacement_link_failure_rolls_back () {
        var root = temporary_directory (); var cache = Path.build_filename (root, "cache"); var tools = Path.build_filename (root, "tools"); var base_location = Path.build_filename (root, ".local", "share", "steamtinkerlaunch"); var link_parent = Path.build_filename (root, ".local", "bin"); var link = Path.build_filename (link_parent, "steamtinkerlaunch");
        Globals.CACHE_PATH = cache; assert (ProtonPlus.Utils.Filesystem.create_directory (cache)); assert (ProtonPlus.Utils.Filesystem.create_directory (base_location)); assert (ProtonPlus.Utils.Filesystem.create_directory (link_parent)); ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (base_location, "marker.txt"), "previous stl\n"); ProtonPlus.Utils.Filesystem.create_file (link, "blocked link\n");
        var job = new FixtureJob (tool (tools), root, fixture_archive (root));
        assert (install_replacement (job) == ReturnCode.FILESYSTEM_ERROR); assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (base_location, "marker.txt")) == "previous stl\n"); assert (FileUtils.test (link, FileTest.IS_REGULAR)); no_entries (Path.get_dirname (base_location), ".protonplus-stl-stage-"); no_entries (cache, ".protonplus-stl-"); assert (delete_directory (root));
    }
}
