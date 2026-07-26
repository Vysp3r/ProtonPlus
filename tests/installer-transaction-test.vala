namespace AppTests.InstallerTransactionTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;

    private class FixtureJob : ProtonPlus.Services.InstallJob {
        private string fixture_path;
        private bool cancel_download;
        private bool fail_promotion;
        public int download_calls { get; private set; default = 0; }

        public FixtureJob (Models.Tools.Basic runner, string location, string fixture_path, bool cancel_download = false, bool fail_promotion = false) {
            base (new Release (
                "Fixture Runner", "", "", new Models.Assets.Asset ("runner.zip", "https://fixtures.invalid/runner.zip"),
                "", 0, "fixture-release-id", "fixture-tag"
            ), runner, ProtonPlus.Services.InstallJob.Mode.VERSIONED, location);
            this.fixture_path = fixture_path;
            this.cancel_download = cancel_download;
            this.fail_promotion = fail_promotion;
        }

        public override async bool download_archive (string url, string path, out string? error_message) {
            download_calls++;
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

        public override async bool promote_staged_installation (string staged_install_path) {
            if (fail_promotion)
                return false;
            return yield base.promote_staged_installation (staged_install_path);
        }
    }

    public void register_tests () {
        Test.add_func ("/installer-transaction/stages-promotes-cleans-and-writes-metadata", test_stages_promotes_and_writes_metadata);
        Test.add_func ("/installer-transaction/canceled-download-cleans-private-workspace", test_canceled_download_cleans_workspace);
        Test.add_func ("/installer-transaction/failed-promotion-restores-previous-installation", test_failed_promotion_restores_previous_installation);
        Test.add_func ("/installer-transaction/duplicate-is-rejected-before-workflow", test_duplicate_is_rejected_before_workflow);
        Test.add_func ("/installer-transaction/standard-removal-finalizes-common-lifecycle", test_standard_removal_finalizes_common_lifecycle);
        Test.add_func ("/installer-transaction/operation-identity-prevents-duplicates", test_operation_identity_prevents_duplicates);
    }

    private string temporary_directory () {
        try { return DirUtils.make_tmp ("protonplus-installer-transaction-test-XXXXXX"); }
        catch (FileError e) { critical ("Could not create test directory: %s", e.message); assert_not_reached (); }
    }
    private string fixture_archive (string root) {
        var encoded = ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename ("fixtures", "archives", "runner.zip.base64")).strip ();
        var path = Path.build_filename (root, "runner.zip");
        try { FileUtils.set_data (path, Base64.decode (encoded)); }
        catch (FileError e) { critical ("Could not write archive fixture: %s", e.message); assert_not_reached (); }
        return path;
    }
    private Models.Tools.Basic runner (string root) {
        assert (ProtonPlus.Utils.Filesystem.create_directory (root));
        var launcher = new Launcher ("Test", Launcher.InstallationTypes.SYSTEM, "", { root });
        var group = new Group ("Test", "", "", launcher);
        ProviderDefinition? definition = null;
        foreach (var candidate in new ProviderDefinitions ().get (Category.PROTON)) {
            if (candidate.provider_id == "proton-ge") {
                definition = candidate;
                break;
            }
        }
        assert (definition != null);
        var value = ProviderCatalog.create_tool ((!) definition, group);
        assert (value != null);
        return (!) value;
    }
    private ReturnCode install (FixtureJob job, bool replacement = false) {
        var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR;
        if (replacement) job.install_replacement.begin ((obj, res) => { code = job.install_replacement.end (res); loop.quit (); });
        else job.install.begin ((obj, res) => { code = job.install.end (res); loop.quit (); });
        loop.run (); return code;
    }
    private ReturnCode remove (ProtonPlus.Services.InstallJob job) {
        var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR;
        job.remove.begin (false, (obj, res) => { code = job.remove.end (res); loop.quit (); });
        loop.run (); return code;
    }
    private bool delete_directory (string path) {
        var loop = new MainLoop (); var deleted = false;
        ProtonPlus.Utils.Filesystem.delete_directory.begin (path, (obj, res) => { deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (res); loop.quit (); });
        loop.run (); return deleted;
    }
    private void no_entries (string directory, string prefix) {
        try { var entries = Dir.open (directory); string? name; while ((name = entries.read_name ()) != null) assert (!name.has_prefix (prefix)); }
        catch (FileError e) { critical ("Could not inspect temporary directory: %s", e.message); assert_not_reached (); }
    }
    private void prepare (out string root, out string cache, out string tools, out string location) {
        root = temporary_directory (); cache = Path.build_filename (root, "cache"); tools = Path.build_filename (root, "tools"); location = Path.build_filename (tools, "Fixture Runner");
        Globals.CACHE_PATH = cache; assert (ProtonPlus.Utils.Filesystem.create_directory (cache));
    }
    private void test_stages_promotes_and_writes_metadata () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var target = runner (tools); var job = new FixtureJob (target, location, fixture_archive (root));
        assert (install (job) == ReturnCode.RUNNER_INSTALLED);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (location, "marker.txt")) == "new runner\n");
        var metadata = ProtonPlus.Utils.Metadata.load (location);
        assert (metadata.tool_id == target.id); assert (metadata.release_id == "fixture-release-id"); assert (metadata.tag == "fixture-tag");
        assert (job.is_finished && job.install_success);
        assert (ProtonPlus.Utils.DownloadManager.instance.active_downloads.size == 0);
        no_entries (cache, ".protonplus-install-"); no_entries (tools, ".protonplus-stage-"); assert (delete_directory (root));
    }
    private void test_canceled_download_cleans_workspace () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var job = new FixtureJob (runner (tools), location, fixture_archive (root), true);
        assert (install (job) == ReturnCode.DOWNLOAD_FAILED); assert (job.canceled); assert (job.is_finished && !job.install_success); assert (job.state == ProtonPlus.Services.InstallJob.State.NOT_INSTALLED); assert (ProtonPlus.Utils.DownloadManager.instance.active_downloads.size == 0); assert (!FileUtils.test (location, FileTest.EXISTS)); no_entries (cache, ".protonplus-install-"); assert (delete_directory (root));
    }
    private void test_failed_promotion_restores_previous_installation () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        assert (ProtonPlus.Utils.Filesystem.create_directory (location)); ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (location, "marker.txt"), "previous runner\n");
        var job = new FixtureJob (runner (tools), location, fixture_archive (root), false, true);
        assert (install (job, true) == ReturnCode.FILESYSTEM_ERROR); assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (location, "marker.txt")) == "previous runner\n");
        assert (job.is_finished && !job.install_success); assert (ProtonPlus.Utils.DownloadManager.instance.active_downloads.size == 0); no_entries (tools, ".protonplus-previous-"); assert (delete_directory (root));
    }

    private void test_duplicate_is_rejected_before_workflow () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var job = new FixtureJob (runner (tools), location, fixture_archive (root));
        var manager = ProtonPlus.Utils.DownloadManager.instance;
        manager.add_download (job);
        assert (install (job) == ReturnCode.OPERATION_IN_PROGRESS);
        assert (job.download_calls == 0);
        manager.remove_download (job);
        assert (delete_directory (root));
    }

    private void test_standard_removal_finalizes_common_lifecycle () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        assert (ProtonPlus.Utils.Filesystem.create_directory (location));
        var job = new FixtureJob (runner (tools), location, fixture_archive (root));
        assert (remove (job) == ReturnCode.RUNNER_REMOVED);
        assert (!FileUtils.test (location, FileTest.EXISTS));
        assert (job.state == ProtonPlus.Services.InstallJob.State.NOT_INSTALLED);
        assert (job.step == ProtonPlus.Services.InstallJob.Step.NOTHING);
        assert (ProtonPlus.Utils.DownloadManager.instance.active_downloads.size == 0);
        assert (delete_directory (root));
    }

    private void test_operation_identity_prevents_duplicates () {
        var root = temporary_directory ();
        var target = runner (root);
        var release = new Release (
            "Same display title", "", "", new Models.Assets.Asset ("runner.zip", "https://fixtures.invalid/runner.zip"),
            "", 0, "release-one", "release-one"
        );
        release.variants.add (new ProtonPlus.Models.Variant ("default", "Default", "", true));
        release.variants.add (new ProtonPlus.Models.Variant ("alternate", "Alternate", "", false));

        var first = new ProtonPlus.Services.InstallJob (release, target);
        var same_target = new ProtonPlus.Services.InstallJob (release, target);
        var different_release = new ProtonPlus.Services.InstallJob (new Release (
            "Same display title", "", "", new Models.Assets.Asset ("runner.zip", "https://fixtures.invalid/runner.zip"),
            "", 0, "release-two", "release-two"
        ), target);
        different_release.release.variants.add (new ProtonPlus.Models.Variant ("default", "Default", "", true));
        var alternate = new ProtonPlus.Services.InstallJob (release, target);
        alternate.set_selected_variant ("Alternate", new Models.Assets.Asset ("alternate.zip", "https://fixtures.invalid/alternate.zip"));
        var latest_one = new ProtonPlus.Services.InstallJob (release, target, ProtonPlus.Services.InstallJob.Mode.LATEST);
        var latest_two = new ProtonPlus.Services.InstallJob (different_release.release, target, ProtonPlus.Services.InstallJob.Mode.LATEST);
        var steam_tinker_launch = new ProtonPlus.Services.InstallJob (release, target, ProtonPlus.Services.InstallJob.Mode.STEAM_TINKER_LAUNCH, null, root);
        var special_release = new Release (
            "Steam Tinker Launch", "", "", new Models.Assets.Asset ("stl.zip", "https://fixtures.invalid/stl.zip"),
            "", 0, "stl-release", "stl-release", Release.Kind.STEAM_TINKER_LAUNCH
        );
        var automatically_selected_stl = new ProtonPlus.Services.InstallJob (special_release, target, ProtonPlus.Services.InstallJob.Mode.VERSIONED, null, root);

        assert (first.steam_tinker_launch_context == null);
        assert (steam_tinker_launch.steam_tinker_launch_context != null);
        assert (automatically_selected_stl.steam_tinker_launch_context != null);
        assert (first.operation_id == same_target.operation_id);
        assert (first.operation_id != different_release.operation_id);
        assert (first.operation_id != alternate.operation_id);
        assert (latest_one.operation_id == latest_two.operation_id);
        assert (latest_one.operation_id != steam_tinker_launch.operation_id);

        var manager = ProtonPlus.Utils.DownloadManager.instance;
        assert (manager.active_downloads.size == 0);
        manager.add_download (first);
        manager.add_download (same_target);
        assert (manager.active_downloads.size == 1);
        assert (manager.is_downloading (same_target));
        assert (manager.get_active_download (same_target) == first);
        manager.remove_download (first);
        assert (manager.active_downloads.size == 0);

        assert (delete_directory (root));
    }
}
