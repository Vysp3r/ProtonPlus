namespace AppTests.ProviderSourceTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Providers.Sources;

    public void register_tests () {
        Test.add_func ("/providers/github/canonical-release-page", test_github_release_page);
        Test.add_func ("/providers/gitlab/canonical-release-page", test_gitlab_release_page);
        Test.add_func ("/providers/forgejo/canonical-release-page", test_forgejo_release_page);
        Test.add_func ("/providers/github-actions/canonical-release-page", test_github_actions_release_page);
        Test.add_func ("/providers/github/definition-filters", test_github_definition_filters);
        Test.add_func ("/providers/invalid-response-codes", test_invalid_response_codes);
        Test.add_func ("/providers/empty-pages", test_empty_pages);
    }

    private string fixture (string provider, string name) {
        var content = ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename ("fixtures", "providers", provider, name)
        );
        assert (content != "");
        return content;
    }

    private ProviderDefinition definition (SourceType source_type) {
        var template = source_type == SourceType.GITHUB_ACTIONS ?
            "https://example.test/artifacts/{id}/fixture-action.zip?signature=example" : "";
        return new ProviderDefinition (
            Category.PROTON,
            source_type,
            "fixture-%s".printf (ProviderDefinition.source_id_for (source_type)),
            "Fixture provider",
            "",
            "https://example.test/releases",
            1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { new DirectoryNameFormat ("default", "$release_name") },
            null,
            null,
            "",
            false,
            template
        );
    }

    private void test_github_release_page () {
        ReturnCode code;
        var page = new GitHubReleaseSource ().parse_response (
            definition (SourceType.GITHUB), fixture ("github", "release.json"), 1, 25, out code
        );
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (page != null);
        assert (page.releases.size == 1);
        var release = page.releases[0];
        assert (release.upstream_release_id == "1001");
        assert (release.source_tag == "GE-Proton10-1");
        assert (release.asset.name == "GE-Proton10-1.tar.gz");
        assert (release.download_size == 42);
        assert (page.next_page == 2);
        assert (!page.has_more);
    }

    private void test_gitlab_release_page () {
        var content = fixture ("gitlab", "release.json").replace ("ProtonPlus.flatpak", "ProtonPlus.tar.gz");
        ReturnCode code;
        var page = new GitLabReleaseSource ().parse_response (
            definition (SourceType.GITLAB), content, 3, 25, out code
        );
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (page != null);
        assert (page.releases.size == 1);
        var release = page.releases[0];
        assert (release.upstream_release_id == "3001");
        assert (release.source_tag == "v0.6.0");
        assert (release.asset.name == "ProtonPlus.tar.gz");
        assert (release.page_url == "https://gitlab.com/example/project/-/releases/v0.6.0");
        assert (page.next_page == 4);
    }

    private void test_forgejo_release_page () {
        ReturnCode code;
        var page = new ForgejoReleaseSource ().parse_response (
            definition (SourceType.FORGEJO), fixture ("forgejo", "release.json"), 1, 25, out code
        );
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (page != null);
        assert (page.releases.size == 1);
        var release = page.releases[0];
        assert (release.upstream_release_id == "4001");
        assert (release.source_tag == "GE-Proton8-26");
        assert (release.asset.name == "Wine-GE-Proton8-26.tar.xz");
        assert (release.download_size == 126);
    }

    private void test_github_actions_release_page () {
        ReturnCode code;
        var page = new GitHubActionsReleaseSource ().parse_response (
            definition (SourceType.GITHUB_ACTIONS), fixture ("github-actions", "run.json"), 1, 25, out code
        );
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (page != null);
        assert (page.releases.size == 1);
        var release = page.releases[0];
        assert (release.kind == ProtonPlus.Models.Release.Kind.GITHUB_ACTION);
        assert (release.upstream_release_id == "5001");
        assert (release.asset.name == "fixture-action.zip");
        assert (release.artifacts_url == "https://api.github.com/repos/example/project/actions/runs/5001/artifacts");
    }

    private void test_github_definition_filters () {
        ReturnCode code;
        var filtered = new ProviderDefinition (
            Category.WINE, SourceType.GITHUB, "filtered", "Filtered", "", "https://example.test/releases", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { new DirectoryNameFormat ("default", "$release_name") },
            { "proton" }
        );
        var page = new GitHubReleaseSource ().parse_response (filtered, fixture ("github", "release.json"), 1, 25, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (page != null && page.releases.size == 0);

        var excluded = new ProviderDefinition (
            Category.WINE, SourceType.GITHUB, "excluded", "Excluded", "", "https://example.test/releases", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { new DirectoryNameFormat ("default", "$release_name") },
            null, { "GE-Proton" }
        );
        page = new GitHubReleaseSource ().parse_response (excluded, fixture ("github", "release.json"), 1, 25, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (page != null && page.releases.size == 0);
    }

    private void test_invalid_response_codes () {
        ReturnCode code;
        assert (new GitHubReleaseSource ().parse_response (definition (SourceType.GITHUB), "{}", 1, 25, out code) == null);
        assert (code == ReturnCode.INVALID_DATA);
        assert (new GitLabReleaseSource ().parse_response (definition (SourceType.GITLAB), "not json", 1, 25, out code) == null);
        assert (code == ReturnCode.INVALID_DATA);
        assert (new ForgejoReleaseSource ().parse_response (definition (SourceType.FORGEJO), "{}", 1, 25, out code) == null);
        assert (code == ReturnCode.INVALID_DATA);
        assert (new GitHubActionsReleaseSource ().parse_response (definition (SourceType.GITHUB_ACTIONS), "[]", 1, 25, out code) == null);
        assert (code == ReturnCode.INVALID_DATA);
    }

    private void test_empty_pages () {
        ReturnCode code;
        var github = new GitHubReleaseSource ().parse_response (definition (SourceType.GITHUB), "[]", 8, 25, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (github != null);
        assert (github.releases.size == 0);
        assert (github.next_page == 9);
        assert (!github.has_more);

        var actions = new GitHubActionsReleaseSource ().parse_response (
            definition (SourceType.GITHUB_ACTIONS), "{\"workflow_runs\":[]}", 8, 25, out code
        );
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (actions != null);
        assert (actions.releases.size == 0);
        assert (actions.next_page == 9);
        assert (!actions.has_more);
    }
}
