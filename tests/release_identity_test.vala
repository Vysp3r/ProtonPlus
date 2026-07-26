namespace AppTests.ReleaseIdentityTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Providers.Sources;

    public void register_tests () {
        Test.add_func ("/release-identity/github-numeric-id-and-tag", test_github_numeric_id_and_tag);
        Test.add_func ("/release-identity/forgejo-numeric-id-and-tag", test_forgejo_numeric_id_and_tag);
        Test.add_func ("/release-identity/gitlab-tag-fallback", test_gitlab_tag_fallback);
        Test.add_func ("/release-identity/github-actions-run-id", test_github_actions_run_id);
        Test.add_func ("/release-identity/cache-round-trip-preserves-latest", test_cache_round_trip_preserves_latest);
        Test.add_func ("/release-identity/legacy-cache-filename-migrates", test_legacy_cache_filename_migrates);
    }

    private string fixture (string provider, string file) {
        return ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename ("fixtures", "providers", provider, file));
    }

    private ProviderDefinition definition (SourceType source_type, string id = "fixture-provider") {
        return new ProviderDefinition (
            Category.PROTON, source_type, id, "Fixture provider", "", "https://example.test/releases", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { new DirectoryNameFormat ("default", "$release_name") },
            null, null, "", false,
            source_type == SourceType.GITHUB_ACTIONS ?
                "https://example.test/artifacts/{id}/fixture-action.zip?signature=example" : ""
        );
    }

    private void test_github_numeric_id_and_tag () {
        var result = new GitHubReleaseSource ().parse_response (
            definition (SourceType.GITHUB), fixture ("github", "release.json"), 1, 25
        );
        assert (result.succeeded);
        var page = result.require_page ();
        assert (page.releases.size == 1);
        assert (page.releases[0].upstream_release_id == "1001");
        assert (page.releases[0].source_tag == "GE-Proton10-1");
    }

    private void test_forgejo_numeric_id_and_tag () {
        var result = new ForgejoReleaseSource ().parse_response (
            definition (SourceType.FORGEJO), fixture ("forgejo", "release.json"), 1, 25
        );
        assert (result.succeeded);
        var page = result.require_page ();
        assert (page.releases.size == 1);
        assert (page.releases[0].upstream_release_id == "4001");
        assert (page.releases[0].source_tag == "GE-Proton8-26");
    }

    private void test_gitlab_tag_fallback () {
        var content = fixture ("gitlab", "release.json")
            .replace ("\"id\": 3001", "\"id\": 0")
            .replace ("ProtonPlus.flatpak", "ProtonPlus.tar.gz");
        var result = new GitLabReleaseSource ().parse_response (definition (SourceType.GITLAB), content, 1, 25);
        assert (result.succeeded);
        var page = result.require_page ();
        assert (page.releases.size == 1);
        assert (page.releases[0].upstream_release_id == "");
        assert (page.releases[0].source_tag == "v0.6.0");
    }

    private void test_github_actions_run_id () {
        var result = new GitHubActionsReleaseSource ().parse_response (
            definition (SourceType.GITHUB_ACTIONS), fixture ("github-actions", "run.json"), 1, 25
        );
        assert (result.succeeded);
        var page = result.require_page ();
        assert (page.releases.size == 1);
        assert (page.releases[0].upstream_release_id == "5001");
        assert (page.releases[0].asset.name == "fixture-action.zip");
    }

    private void save_snapshot (ReleaseCatalogCache cache, ReleaseCatalogSnapshot snapshot) {
        var loop = new MainLoop ();
        cache.save.begin (snapshot, (obj, result) => {
            cache.save.end (result);
            loop.quit ();
        });
        loop.run ();
    }

    private ReleaseCatalogSnapshot? load_snapshot (ReleaseCatalogCache cache) {
        var loop = new MainLoop ();
        ReleaseCatalogSnapshot? snapshot = null;
        cache.load.begin ((obj, result) => {
            snapshot = cache.load.end (result);
            loop.quit ();
        });
        loop.run ();
        return snapshot;
    }

    private void test_cache_round_trip_preserves_latest () {
        string root;
        try {
            root = DirUtils.make_tmp ("protonplus-release-identity-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create test directory: %s", e.message);
            assert_not_reached ();
        }
        var previous_cache_path = Globals.CACHE_PATH;
        Globals.CACHE_PATH = root;
        var launcher = new Launcher ("Fixture", Launcher.InstallationTypes.SYSTEM, "", {}, "fixture");
        var group = new Group ("Fixture", "", "", launcher, "fixture");
        var tool = ProviderCatalog.create_tool (definition (SourceType.GITHUB), group);
        assert (tool != null);
        var releases = new Gee.LinkedList<Release> ();
        releases.add (new Release (
            "v1.2.3", "Fixture release", "2026-07-25T12:34:56Z",
            new ProtonPlus.Models.Assets.Asset ("v1.2.3.tar.gz", "https://example.test/v1.2.3.tar.gz"),
            "https://example.test/releases/v1.2.3", 42, "1001", "v1.2.3"
        ));
        releases.add (new Release (
            "v1.2.2", "Fallback release", "2026-07-24T12:34:56Z",
            new ProtonPlus.Models.Assets.Asset ("v1.2.2.tar.gz", "https://example.test/v1.2.2.tar.gz"),
            "https://example.test/releases/v1.2.2", 0, "", "v1.2.2"
        ));
        var cache = new ReleaseCatalogCache (tool.id, tool.title);
        save_snapshot (cache, new ReleaseCatalogSnapshot (releases, 2, true, "2026-07-25T12:34:56Z"));
        var snapshot = load_snapshot (cache);
        assert (snapshot != null);
        var loaded = (!) snapshot;

        assert (loaded.releases.size == 2);
        assert (loaded.page == 2 && loaded.has_more);
        assert (loaded.releases[0].upstream_release_id == "1001");
        assert (loaded.releases[0].source_tag == "v1.2.3");
        assert (loaded.releases[0].asset.name == "v1.2.3.tar.gz");
        var latest = new ProtonPlus.Services.InstallJob (loaded.releases[0], tool, ProtonPlus.Services.InstallJob.Mode.LATEST);
        assert (latest.selected_asset.download_url == "https://example.test/v1.2.3.tar.gz");

        Globals.CACHE_PATH = previous_cache_path;
        assert (ProtonPlus.Utils.Filesystem.delete_file (Path.build_filename (root, "fixture-system_fixture_fixture-provider.json")));
        assert (DirUtils.remove (root) == 0);
    }

    private void test_legacy_cache_filename_migrates () {
        string root;
        try {
            root = DirUtils.make_tmp ("protonplus-legacy-cache-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create test directory: %s", e.message);
            assert_not_reached ();
        }
        var previous_cache_path = Globals.CACHE_PATH;
        Globals.CACHE_PATH = root;

        var releases = new Gee.LinkedList<Release> ();
        releases.add (new Release (
            "v1", "", "", new ProtonPlus.Models.Assets.Asset ("v1.tar.gz", "https://example.test/v1.tar.gz"),
            "", 0, "1", "v1"
        ));
        var cache = new ReleaseCatalogCache ("fixture/legacy", "Legacy.Title");
        save_snapshot (cache, new ReleaseCatalogSnapshot (releases, 2, true, "2026-07-26T00:00:00Z"));

        var stable_path = Path.build_filename (root, "fixture_legacy.json");
        var legacy_path = Path.build_filename (root, "Legacy_Title.json");
        var json = ProtonPlus.Utils.Filesystem.get_file_content (stable_path);
        assert (json != "");
        ProtonPlus.Utils.Filesystem.delete_file (stable_path);
        ProtonPlus.Utils.Filesystem.create_file (legacy_path, json);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (legacy_path) == json);

        var snapshot = load_snapshot (cache);
        assert (snapshot != null && snapshot.releases.size == 1 && snapshot.page == 2 && snapshot.has_more);
        assert (FileUtils.test (stable_path, FileTest.IS_REGULAR));
        assert (!FileUtils.test (legacy_path, FileTest.EXISTS));

        Globals.CACHE_PATH = previous_cache_path;
        assert (ProtonPlus.Utils.Filesystem.delete_file (stable_path));
        assert (DirUtils.remove (root) == 0);
    }
}
