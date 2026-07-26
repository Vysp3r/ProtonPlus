namespace AppTests.ReleaseIdentityTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Providers.Sources;
    using ProtonPlus.Models.Launchers.Runners;

    private class FixtureRunner : Base {
        private IReleases fixture_releases;

        public FixtureRunner (SourceType source_type, IReleases fixture_releases) {
            base (source_type, "fixture-provider", "Fixture provider", "", "https://example.test/releases");
            this.fixture_releases = fixture_releases;
            add_directory_name_format ("fixture", "$release_name");

            if (source_type == SourceType.GITHUB_ACTION)
                url_template = "https://example.test/artifacts/{id}/fixture-action.zip?signature=example";
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            code = ReturnCode.RELEASES_LOADED;
            return fixture_releases;
        }
    }

    public void register_tests () {
        Test.add_func ("/release-identity/github-numeric-id-and-tag", test_github_numeric_id_and_tag);
        Test.add_func ("/release-identity/forgejo-numeric-id-and-tag", test_forgejo_numeric_id_and_tag);
        Test.add_func ("/release-identity/gitlab-tag-fallback", test_gitlab_tag_fallback);
        Test.add_func ("/release-identity/github-actions-run-id", test_github_actions_run_id);
        Test.add_func ("/release-identity/query-bearing-asset-name", test_query_bearing_asset_name);
        Test.add_func ("/release-identity/cache-round-trip-preserves-latest", test_cache_round_trip_preserves_latest);
    }

    private string create_temp_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-release-identity-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create test directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private Json.Array get_releases_array (string provider) {
        var fixture_path = Path.build_filename ("fixtures", "providers", provider, "release.json");
        var node = ProtonPlus.Utils.Parser.get_node_from_json (
            ProtonPlus.Utils.Filesystem.get_file_content (fixture_path)
        );
        assert (node != null);
        assert (node.get_node_type () == Json.NodeType.ARRAY);
        return node.get_array ();
    }

    private Json.Array get_workflow_runs () {
        var fixture_path = Path.build_filename ("fixtures", "providers", "github-actions", "run.json");
        var node = ProtonPlus.Utils.Parser.get_node_from_json (
            ProtonPlus.Utils.Filesystem.get_file_content (fixture_path)
        );
        assert (node != null);
        assert (node.get_node_type () == Json.NodeType.OBJECT);
        return node.get_object ().get_array_member ("workflow_runs");
    }

    private Tools.Basic create_tool (SourceType source_type, IReleases source_releases, string directory) {
        var launcher = new Launcher ("Fixture launcher", Launcher.InstallationTypes.SYSTEM, "", {}, "fixture");
        launcher.directory = directory;
        var group = new Group ("Fixture group", "", "", launcher, "fixture");
        var runner = new FixtureRunner (source_type, source_releases);
        var tool = runner.create_tool (group);
        assert (tool != null);
        return tool;
    }

    private Gee.LinkedList<Release> load_more (Tools.Basic tool, out ReturnCode code) {
        var loop = new MainLoop ();
        var releases = new Gee.LinkedList<Release> ();
        ReturnCode result_code = ReturnCode.REQUEST_FAILED;

        tool.load_more.begin ((obj, res) => {
            releases = tool.load_more.end (res, out result_code);
            loop.quit ();
        });
        loop.run ();

        code = result_code;
        return releases;
    }

    private void save_releases (Tool tool) {
        var loop = new MainLoop ();
        ProtonPlus.Utils.CacheManager.save_releases.begin (tool, (obj, res) => {
            ProtonPlus.Utils.CacheManager.save_releases.end (res);
            loop.quit ();
        });
        loop.run ();
    }

    private void load_releases (Tool tool) {
        var loop = new MainLoop ();
        ProtonPlus.Utils.CacheManager.load_releases.begin (tool, (obj, res) => {
            ProtonPlus.Utils.CacheManager.load_releases.end (res);
            loop.quit ();
        });
        loop.run ();
    }

    private void delete_directory (string directory) {
        var loop = new MainLoop ();
        bool deleted = false;
        ProtonPlus.Utils.Filesystem.delete_directory.begin (directory, (obj, res) => {
            deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (res);
            loop.quit ();
        });
        loop.run ();
        assert (deleted);
    }

    private void test_github_numeric_id_and_tag () {
        var root = create_temp_directory ();
        var source_releases = new ProtonPlus.Providers.Sources.GitHub.Releases.from_json (
            get_releases_array ("github")
        );
        var tool = create_tool (SourceType.GITHUB, source_releases, root);
        ReturnCode code;
        var releases = load_more (tool, out code);

        assert (code == ReturnCode.RELEASES_LOADED);
        assert (releases.size == 1);
        assert (releases[0].upstream_release_id == "1001");
        assert (releases[0].source_tag == "GE-Proton10-1");
        assert (releases[0].asset.name == "GE-Proton10-1.tar.gz");
        assert (releases[0].asset.download_url == "https://github.com/example/project/releases/download/GE-Proton10-1/GE-Proton10-1.tar.gz");
        delete_directory (root);
    }

    private void test_forgejo_numeric_id_and_tag () {
        var root = create_temp_directory ();
        var source_releases = new ProtonPlus.Providers.Sources.Forgejo.Releases.from_json (
            get_releases_array ("forgejo")
        );
        var tool = create_tool (SourceType.FORGEJO, source_releases, root);
        ReturnCode code;
        var releases = load_more (tool, out code);

        assert (code == ReturnCode.RELEASES_LOADED);
        assert (releases.size == 1);
        assert (releases[0].upstream_release_id == "4001");
        assert (releases[0].source_tag == "GE-Proton8-26");
        assert (releases[0].asset.name == "Wine-GE-Proton8-26.tar.xz");
        assert (releases[0].asset.download_url == "https://codeberg.org/example/project/releases/download/GE-Proton8-26/Wine-GE-Proton8-26.tar.xz");
        delete_directory (root);
    }

    private void test_gitlab_tag_fallback () {
        var root = create_temp_directory ();
        var source_releases = new ProtonPlus.Providers.Sources.GitLab.Releases.from_json (
            get_releases_array ("gitlab")
        );
        var source_release = source_releases.list.get (0) as ProtonPlus.Providers.Sources.GitLab.Release;
        assert (source_release != null);
        source_release.id = 0;
        var source_asset = source_release.assets.get (0);
        source_asset.name = "ProtonPlus.tar.gz";
        source_asset.download_url = "https://example.test/ProtonPlus.tar.gz";

        var tool = create_tool (SourceType.GITLAB, source_releases, root);
        ReturnCode code;
        var releases = load_more (tool, out code);

        assert (code == ReturnCode.RELEASES_LOADED);
        assert (releases.size == 1);
        assert (releases[0].upstream_release_id == "");
        assert (releases[0].source_tag == "v0.6.0");
        assert (releases[0].asset.name == "ProtonPlus.tar.gz");
        assert (releases[0].asset.download_url == "https://example.test/ProtonPlus.tar.gz");
        delete_directory (root);
    }

    private void test_github_actions_run_id () {
        var root = create_temp_directory ();
        var source_releases = new ProtonPlus.Providers.Sources.GitHubActions.Releases.from_json (
            get_workflow_runs ()
        );
        var tool = create_tool (SourceType.GITHUB_ACTION, source_releases, root);
        ReturnCode code;
        var releases = load_more (tool, out code);

        assert (code == ReturnCode.RELEASES_LOADED);
        assert (releases.size == 1);
        assert (releases[0].upstream_release_id == "5001");
        assert (releases[0].source_tag == "");
        assert (releases[0].asset.name == "fixture-action.zip");
        assert (releases[0].asset.download_url == "https://example.test/artifacts/5001/fixture-action.zip?signature=example");
        delete_directory (root);
    }

    private void test_query_bearing_asset_name () {
        var asset = ProtonPlus.Models.Assets.Asset.from_download_url (
            "https://example.test/downloads/runner.tar.zst?signature=example&expires=1"
        );

        assert (asset.name == "runner.tar.zst");
        assert (asset.download_url == "https://example.test/downloads/runner.tar.zst?signature=example&expires=1");
        assert (asset.is_archive ());
    }

    private void test_cache_round_trip_preserves_latest () {
        var root = create_temp_directory ();
        var previous_cache_path = Globals.CACHE_PATH;
        Globals.CACHE_PATH = root;

        var source_releases = new ProtonPlus.Providers.Sources.GitHub.Releases.from_json (
            get_releases_array ("github")
        );
        var tool = create_tool (SourceType.GITHUB, source_releases, root);
        tool.releases.add (new Release.github (
            tool,
            "v1.2.3",
            "Fixture release",
            "2026-07-25T12:34:56Z",
            42,
            new ProtonPlus.Models.Assets.Asset ("v1.2.3.tar.gz", "https://example.test/v1.2.3.tar.gz"),
            "https://example.test/releases/v1.2.3",
            "1001",
            "v1.2.3"
        ));
        tool.releases.add (new Release.gitlab (
            tool,
            "v1.2.2",
            "Fallback release",
            "2026-07-24T12:34:56Z",
            new ProtonPlus.Models.Assets.Asset ("v1.2.2.tar.gz", "https://example.test/v1.2.2.tar.gz"),
            "https://example.test/releases/v1.2.2",
            "",
            "v1.2.2"
        ));

        save_releases (tool);
        var cache_file = Path.build_filename (root, "fixture-system_fixture_fixture-provider.json");
        var legacy_cache_file = Path.build_filename (root, "Fixture_provider.json");
        assert (FileUtils.test (cache_file, FileTest.IS_REGULAR));

        var cache_content = ProtonPlus.Utils.Filesystem.get_file_content (cache_file);
        assert (ProtonPlus.Utils.Filesystem.modify_file (legacy_cache_file, cache_content));
        save_releases (tool);
        assert (!FileUtils.test (legacy_cache_file, FileTest.EXISTS));

        cache_content = ProtonPlus.Utils.Filesystem.get_file_content (cache_file);
        assert (ProtonPlus.Utils.Filesystem.modify_file (legacy_cache_file, cache_content));
        assert (FileUtils.remove (cache_file) == 0);

        tool.releases.clear ();
        load_releases (tool);

        assert (FileUtils.test (cache_file, FileTest.IS_REGULAR));
        assert (!FileUtils.test (legacy_cache_file, FileTest.EXISTS));
        assert (tool.releases.size == 3);
        var latest = tool.releases[0] as Releases.Latest;
        assert (latest != null);
        assert (latest.upstream_release_id == "1001");
        assert (latest.source_tag == "v1.2.3");
        assert (tool.releases[1].upstream_release_id == "1001");
        assert (tool.releases[1].source_tag == "v1.2.3");
        assert (tool.releases[1].asset.name == "v1.2.3.tar.gz");
        assert (tool.releases[1].asset.download_url == "https://example.test/v1.2.3.tar.gz");
        assert (tool.releases[2].upstream_release_id == "");
        assert (tool.releases[2].source_tag == "v1.2.2");
        assert (tool.releases[2].asset.name == "v1.2.2.tar.gz");
        assert (tool.releases[2].asset.download_url == "https://example.test/v1.2.2.tar.gz");
        assert (latest.asset.name == "v1.2.3.tar.gz");
        assert (latest.asset.download_url == "https://example.test/v1.2.3.tar.gz");

        tool.releases[1].variants.add (new ProtonPlus.Models.Variant (
            "alternate",
            "v1.2.3-alternate.zip",
            false,
            tool,
            "https://example.test/v1.2.3-alternate.zip?signature=example"
        ));
        tool.releases[1].set_selected_variant (
            "alternate",
            ProtonPlus.Models.Assets.Asset.from_download_url (
                "https://example.test/v1.2.3-alternate.zip?signature=example"
            )
        );
        assert (tool.releases[1].asset.name == "v1.2.3-alternate.zip");
        assert (tool.releases[1].asset.download_url == "https://example.test/v1.2.3-alternate.zip?signature=example");

        var obsolete_cache_release = new Json.Object ();
        obsolete_cache_release.set_string_member ("kind", "generic");
        obsolete_cache_release.set_string_member ("title", "v0.5.0");
        obsolete_cache_release.set_string_member ("description", "Obsolete cache entry");
        obsolete_cache_release.set_string_member ("release_date", "2026-07-23T12:34:56Z");
        obsolete_cache_release.set_string_member ("download_url", "https://example.test/v0.5.0.tar.gz");
        obsolete_cache_release.set_string_member ("page_url", "https://example.test/releases/v0.5.0");
        obsolete_cache_release.set_string_member ("source_tag", "v0.5.0");
        assert (Release.from_json (tool, obsolete_cache_release) == null);

        var incomplete_asset_release = new Json.Object ();
        incomplete_asset_release.set_string_member ("kind", "generic");
        incomplete_asset_release.set_string_member ("title", "v0.5.0");
        incomplete_asset_release.set_string_member ("source_tag", "v0.5.0");
        incomplete_asset_release.set_object_member ("asset", new ProtonPlus.Models.Assets.Asset ("", "https://example.test/v0.5.0.tar.gz").to_json ());
        assert (Release.from_json (tool, incomplete_asset_release) == null);

        Globals.CACHE_PATH = previous_cache_path;
        delete_directory (root);
    }
}
