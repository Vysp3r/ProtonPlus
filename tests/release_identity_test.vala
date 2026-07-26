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
        ReturnCode code;
        var page = new GitHubReleaseSource ().parse_response (
            definition (SourceType.GITHUB), fixture ("github", "release.json"), 1, 25, out code
        );
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (page != null && page.releases.size == 1);
        assert (page.releases[0].upstream_release_id == "1001");
        assert (page.releases[0].source_tag == "GE-Proton10-1");
    }

    private void test_forgejo_numeric_id_and_tag () {
        ReturnCode code;
        var page = new ForgejoReleaseSource ().parse_response (
            definition (SourceType.FORGEJO), fixture ("forgejo", "release.json"), 1, 25, out code
        );
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (page != null && page.releases.size == 1);
        assert (page.releases[0].upstream_release_id == "4001");
        assert (page.releases[0].source_tag == "GE-Proton8-26");
    }

    private void test_gitlab_tag_fallback () {
        var content = fixture ("gitlab", "release.json")
            .replace ("\"id\": 3001", "\"id\": 0")
            .replace ("ProtonPlus.flatpak", "ProtonPlus.tar.gz");
        ReturnCode code;
        var page = new GitLabReleaseSource ().parse_response (definition (SourceType.GITLAB), content, 1, 25, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (page != null && page.releases.size == 1);
        assert (page.releases[0].upstream_release_id == "");
        assert (page.releases[0].source_tag == "v0.6.0");
    }

    private void test_github_actions_run_id () {
        ReturnCode code;
        var page = new GitHubActionsReleaseSource ().parse_response (
            definition (SourceType.GITHUB_ACTIONS), fixture ("github-actions", "run.json"), 1, 25, out code
        );
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (page != null && page.releases.size == 1);
        assert (page.releases[0].upstream_release_id == "5001");
        assert (page.releases[0].asset.name == "fixture-action.zip");
    }

    private void save_releases (Tool tool) {
        var loop = new MainLoop ();
        ProtonPlus.Utils.CacheManager.save_releases.begin (tool, (obj, result) => {
            ProtonPlus.Utils.CacheManager.save_releases.end (result);
            loop.quit ();
        });
        loop.run ();
    }

    private void load_releases (Tool tool) {
        var loop = new MainLoop ();
        ProtonPlus.Utils.CacheManager.load_releases.begin (tool, (obj, result) => {
            ProtonPlus.Utils.CacheManager.load_releases.end (result);
            loop.quit ();
        });
        loop.run ();
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
        tool.releases.add (new Release (
            "v1.2.3", "Fixture release", "2026-07-25T12:34:56Z",
            new ProtonPlus.Models.Assets.Asset ("v1.2.3.tar.gz", "https://example.test/v1.2.3.tar.gz"),
            "https://example.test/releases/v1.2.3", 42, "1001", "v1.2.3"
        ));
        tool.releases.add (new Release (
            "v1.2.2", "Fallback release", "2026-07-24T12:34:56Z",
            new ProtonPlus.Models.Assets.Asset ("v1.2.2.tar.gz", "https://example.test/v1.2.2.tar.gz"),
            "https://example.test/releases/v1.2.2", 0, "", "v1.2.2"
        ));
        save_releases (tool);
        tool.releases.clear ();
        load_releases (tool);

        assert (tool.releases.size == 2);
        assert (tool.releases[0].upstream_release_id == "1001");
        assert (tool.releases[0].source_tag == "v1.2.3");
        assert (tool.releases[0].asset.name == "v1.2.3.tar.gz");
        var latest = new ProtonPlus.Services.InstallJob (tool.releases[0], tool, ProtonPlus.Services.InstallJob.Mode.LATEST);
        assert (latest.selected_asset.download_url == "https://example.test/v1.2.3.tar.gz");

        Globals.CACHE_PATH = previous_cache_path;
        assert (ProtonPlus.Utils.Filesystem.delete_file (Path.build_filename (root, "fixture-system_fixture_fixture-provider.json")));
        assert (DirUtils.remove (root) == 0);
    }
}
