namespace AppTests.InstallerTransactionTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Launchers.Runners.Proton;

    private class FixtureRelease : Release {
        private string fixture_path;
        private bool cancel_download;
        private bool fail_promotion;

        public FixtureRelease (
            ProtonPlus.Models.Tools.Basic runner,
            string install_location,
            string fixture_path,
            bool cancel_download = false,
            bool fail_promotion = false
        ) {
            base.simple (runner, "Fixture Runner", install_location);
            this.fixture_path = fixture_path;
            this.cancel_download = cancel_download;
            this.fail_promotion = fail_promotion;
            asset = new ProtonPlus.Models.Internal.Assets.Asset (
                "runner.zip", "https://fixtures.invalid/runner.zip"
            );
        }

        protected override async bool download_archive (string url, string path, out string? error_message) {
            if (cancel_download) {
                ProtonPlus.Utils.Filesystem.create_file (path, "partial download");
                canceled = true;
                error_message = "Download canceled";
                return false;
            }

            var copied = yield ProtonPlus.Utils.Filesystem.copy_file (fixture_path, path);
            error_message = copied ? null : "Could not copy fixture";
            return copied;
        }

        protected override async bool promote_staged_installation (string staged_install_path) {
            if (fail_promotion)
                return false;

            return yield base.promote_staged_installation (staged_install_path);
        }
    }

    private class BlockingFixtureRelease : FixtureRelease {
        private bool downloads_released = false;
        public signal void download_started ();

        public BlockingFixtureRelease (ProtonPlus.Models.Tools.Basic runner, string install_location, string fixture_path) {
            base (runner, install_location, fixture_path);
        }

        public void release_download () {
            downloads_released = true;
        }

        protected override async bool download_archive (string url, string path, out string? error_message) {
            download_started ();
            while (!downloads_released)
                yield wait_for_download_release ();

            return yield base.download_archive (url, path, out error_message);
        }

        private async void wait_for_download_release () {
            Timeout.add (10, () => {
                wait_for_download_release.callback ();
                return Source.REMOVE;
            });
            yield;
        }
    }

    private class FixtureGitHubActionRelease : ProtonPlus.Models.Releases.GitHubAction {
        public FixtureGitHubActionRelease (ProtonPlus.Models.Tools.Basic runner) {
            base (
                runner,
                "Fixture action",
                "2026-07-25T12:34:56Z",
                ProtonPlus.Models.Internal.Assets.Asset.from_download_url (
                    "https://fixtures.invalid/artifact.zip?signature=example"
                ),
                "",
                ""
            );
        }

        public async string? extract_nested_archive_for_test (string source_path, string extract_path) {
            return yield _after_extraction (source_path, extract_path);
        }
    }

    public void register_tests () {
        Test.add_func ("/installer-transaction/stages-promotes-cleans-and-writes-metadata", test_stages_promotes_cleans_and_writes_metadata);
        Test.add_func ("/installer-transaction/failed-extraction-cleans-private-workspace", test_failed_extraction_cleans_private_workspace);
        Test.add_func ("/installer-transaction/canceled-download-cleans-private-workspace", test_canceled_download_cleans_private_workspace);
        Test.add_func ("/installer-transaction/failed-promotion-restores-previous-installation", test_failed_promotion_restores_previous_installation);
        Test.add_func ("/installer-transaction/cache-clear-waits-for-active-install", test_cache_clear_waits_for_active_install);
        Test.add_func ("/installer-transaction/github-action-extracts-nested-archive", test_github_action_extracts_nested_archive);
    }

    private string create_temp_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-installer-transaction-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create test directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private string materialize_archive_fixture (string root, string name) {
        var encoded = ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename ("fixtures", "archives", "%s.zip.base64".printf (name))
        ).strip ();
        assert (encoded != "");

        var fixture_path = Path.build_filename (root, "%s.zip".printf (name));
        try {
            FileUtils.set_data (fixture_path, Base64.decode (encoded));
        } catch (FileError e) {
            critical ("Could not write archive fixture: %s", e.message);
            assert_not_reached ();
        }

        return fixture_path;
    }

    private ProtonPlus.Models.Tools.Basic create_runner (string tools_root) {
        assert (ProtonPlus.Utils.Filesystem.create_directory (tools_root));
        var launcher = new Launcher ("Test", Launcher.InstallationTypes.SYSTEM, "", { tools_root });
        var group = new Group ("Test", "", "", launcher);
        var runner = new ProtonGE ().create_tool (group);
        assert (runner != null);
        return (!) runner;
    }

    private ReturnCode install (Release release, bool replacement = false) {
        var loop = new MainLoop ();
        ReturnCode result = ReturnCode.FILESYSTEM_ERROR;

        if (replacement) {
            release.install_replacement.begin ((obj, res) => {
                result = release.install_replacement.end (res);
                loop.quit ();
            });
        } else {
            release.install.begin ((obj, res) => {
                result = release.install.end (res);
                loop.quit ();
            });
        }

        loop.run ();
        return result;
    }

    private string? extract_nested_archive (FixtureGitHubActionRelease release, string source_path, string extract_path) {
        var loop = new MainLoop ();
        string? result = null;

        release.extract_nested_archive_for_test.begin (source_path, extract_path, (obj, res) => {
            result = release.extract_nested_archive_for_test.end (res);
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

    private bool has_entry_with_prefix (string directory, string prefix) {
        try {
            var entries = Dir.open (directory);
            string? name;
            while ((name = entries.read_name ()) != null) {
                if (name.has_prefix (prefix))
                    return true;
            }
        } catch (FileError e) {
            critical ("Could not inspect temporary directory: %s", e.message);
            assert_not_reached ();
        }

        return false;
    }

    private void assert_directory_empty (string directory) {
        try {
            var entries = Dir.open (directory);
            assert (entries.read_name () == null);
        } catch (FileError e) {
            critical ("Could not inspect temporary directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private void test_stages_promotes_cleans_and_writes_metadata () {
        var root = create_temp_directory ();
        var cache_root = Path.build_filename (root, "cache");
        var tools_root = Path.build_filename (root, "tools");
        var install_location = Path.build_filename (tools_root, "Fixture Runner");
        Globals.CACHE_PATH = cache_root;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache_root));

        var fixture_path = materialize_archive_fixture (root, "runner");
        var release = new FixtureRelease (create_runner (tools_root), install_location, fixture_path);
        release.upstream_release_id = "fixture-release-id";
        release.source_tag = "fixture-tag";
        release.variants.add (new ProtonPlus.Models.Variant (
            "default", "", true, release.runner as ProtonPlus.Models.Tools.Basic, null, "x86-64"
        ));

        assert (install (release) == ReturnCode.RUNNER_INSTALLED);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (install_location, "marker.txt")) == "new runner\n");

        var metadata = ProtonPlus.Utils.Metadata.load (install_location);
        assert (metadata.runner_title == "Proton-GE");
        assert (metadata.runner_endpoint == "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases");
        assert (metadata.provider_id == release.runner.provider_id);
        assert (metadata.tool_id == release.runner.id);
        assert (metadata.launcher_id == release.runner.group.launcher.instance_id);
        assert (metadata.variant_id == "x86-64");
        assert (metadata.release_id == "fixture-release-id");
        assert (metadata.tag == "fixture-tag");
        assert_no_entries_with_prefix (cache_root, ".protonplus-install-");
        assert_no_entries_with_prefix (tools_root, ".protonplus-stage-");
        assert (delete_directory (root));
    }

    private void test_failed_extraction_cleans_private_workspace () {
        var root = create_temp_directory ();
        var cache_root = Path.build_filename (root, "cache");
        var tools_root = Path.build_filename (root, "tools");
        var install_location = Path.build_filename (tools_root, "Fixture Runner");
        Globals.CACHE_PATH = cache_root;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache_root));

        var fixture_path = Path.build_filename ("fixtures", "archives", "invalid.zip");
        var release = new FixtureRelease (create_runner (tools_root), install_location, fixture_path);

        assert (install (release) == ReturnCode.EXTRACTION_FAILED);
        assert (!FileUtils.test (install_location, FileTest.EXISTS));
        assert_no_entries_with_prefix (cache_root, ".protonplus-install-");
        assert_no_entries_with_prefix (tools_root, ".protonplus-stage-");
        assert (delete_directory (root));
    }

    private void test_canceled_download_cleans_private_workspace () {
        var root = create_temp_directory ();
        var cache_root = Path.build_filename (root, "cache");
        var tools_root = Path.build_filename (root, "tools");
        var install_location = Path.build_filename (tools_root, "Fixture Runner");
        Globals.CACHE_PATH = cache_root;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache_root));

        var fixture_path = materialize_archive_fixture (root, "runner");
        var release = new FixtureRelease (create_runner (tools_root), install_location, fixture_path, true);

        assert (install (release) == ReturnCode.DOWNLOAD_FAILED);
        assert (release.canceled);
        assert (!FileUtils.test (install_location, FileTest.EXISTS));
        assert_no_entries_with_prefix (cache_root, ".protonplus-install-");
        assert_directory_empty (Path.build_filename (cache_root, "archives"));
        assert (delete_directory (root));
    }

    private void test_failed_promotion_restores_previous_installation () {
        var root = create_temp_directory ();
        var cache_root = Path.build_filename (root, "cache");
        var tools_root = Path.build_filename (root, "tools");
        var install_location = Path.build_filename (tools_root, "Fixture Runner");
        Globals.CACHE_PATH = cache_root;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache_root));
        assert (ProtonPlus.Utils.Filesystem.create_directory (install_location));
        ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (install_location, "marker.txt"), "previous runner\n");

        var fixture_path = materialize_archive_fixture (root, "runner");
        var release = new FixtureRelease (create_runner (tools_root), install_location, fixture_path, false, true);

        assert (install (release, true) == ReturnCode.FILESYSTEM_ERROR);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (install_location, "marker.txt")) == "previous runner\n");
        assert_no_entries_with_prefix (tools_root, ".protonplus-previous-");
        assert_no_entries_with_prefix (tools_root, ".protonplus-stage-");
        assert_no_entries_with_prefix (cache_root, ".protonplus-install-");
        assert (delete_directory (root));
    }

    private void test_cache_clear_waits_for_active_install () {
        var root = create_temp_directory ();
        var cache_root = Path.build_filename (root, "cache");
        var tools_root = Path.build_filename (root, "tools");
        var install_location = Path.build_filename (tools_root, "Fixture Runner");
        Globals.CACHE_PATH = cache_root;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache_root));

        var fixture_path = materialize_archive_fixture (root, "runner");
        var release = new BlockingFixtureRelease (create_runner (tools_root), install_location, fixture_path);
        var download_started_loop = new MainLoop ();
        var completion_loop = new MainLoop ();
        var install_finished = false;
        var clear_finished = false;
        ReturnCode install_code = ReturnCode.FILESYSTEM_ERROR;
        bool clear_succeeded = false;

        release.download_started.connect (() => {
            download_started_loop.quit ();
        });
        release.install.begin ((obj, res) => {
            install_code = release.install.end (res);
            install_finished = true;
            if (clear_finished)
                completion_loop.quit ();
        });
        download_started_loop.run ();
        assert (has_entry_with_prefix (cache_root, ".protonplus-install-"));

        ProtonPlus.Utils.CacheManager.clear_cache.begin ((obj, res) => {
            clear_succeeded = ProtonPlus.Utils.CacheManager.clear_cache.end (res);
            clear_finished = true;
            if (install_finished)
                completion_loop.quit ();
        });

        var wait_loop = new MainLoop ();
        Timeout.add (50, () => {
            wait_loop.quit ();
            return Source.REMOVE;
        });
        wait_loop.run ();
        assert (!clear_finished);
        assert (has_entry_with_prefix (cache_root, ".protonplus-install-"));

        release.release_download ();
        var timed_out = false;
        var timeout_id = Timeout.add_seconds (5, () => {
            timed_out = true;
            completion_loop.quit ();
            return Source.REMOVE;
        });
        completion_loop.run ();
        if (!timed_out)
            Source.remove (timeout_id);

        assert (!timed_out);
        assert (install_code == ReturnCode.RUNNER_INSTALLED);
        assert (clear_succeeded);
        assert_no_entries_with_prefix (cache_root, ".protonplus-install-");
        assert (!FileUtils.test (Path.build_filename (cache_root, "archives"), FileTest.EXISTS));
        assert (delete_directory (root));
    }

    private void test_github_action_extracts_nested_archive () {
        var root = create_temp_directory ();
        var tools_root = Path.build_filename (root, "tools");
        var fixture_path = materialize_archive_fixture (root, "runner");
        var release = new FixtureGitHubActionRelease (create_runner (tools_root));

        assert (release.asset.name == "artifact.zip");
        assert (release.asset.download_url == "https://fixtures.invalid/artifact.zip?signature=example");

        var source_path = extract_nested_archive (release, fixture_path, root);
        assert (source_path != null);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename (source_path, "marker.txt")
        ) == "new runner\n");
        assert (delete_directory (root));
    }
}
