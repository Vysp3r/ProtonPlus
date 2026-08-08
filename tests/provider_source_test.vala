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
        Test.add_func ("/providers/github-actions/definition-filters", test_github_actions_definition_filters);
        Test.add_func ("/providers/github/definition-filters", test_github_definition_filters);
        Test.add_func ("/providers/github/incomplete-assets", test_github_incomplete_assets);
        Test.add_func ("/providers/forgejo/incomplete-assets", test_forgejo_incomplete_assets);
        Test.add_func ("/providers/gitlab/incomplete-assets", test_gitlab_incomplete_assets);
        Test.add_func ("/providers/github-compatible/default-variant-assets", test_github_compatible_default_variant_assets);
        Test.add_func ("/providers/github-compatible/stable-release-policy", test_github_compatible_stable_release_policy);
        Test.add_func ("/providers/github-compatible/validation-and-skipped-releases", test_github_compatible_validation_and_skipped_releases);
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
            "https://example.test/source",
            1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") },
            null,
            null,
            "",
            false,
            template
        );
    }

    private ProviderDefinition policy_definition (SourceType source_type) {
        return new ProviderDefinition (
            Category.PROTON,
            source_type,
            "fixture-%s-policy".printf (ProviderDefinition.source_id_for (source_type)),
            "Fixture provider",
            "",
            "https://example.test/releases",
            "https://example.test/source",
            1,
            {
                new VariantDefinition ("default", "default", "$release_name-default", true),
                new VariantDefinition ("first", "first", "$release_name-first", false)
            },
            { InstallLayout.template ("default", "$release_name") }
        );
    }

    private void test_github_release_page () {
        var result = new GitHubReleaseSource ().parse_response (
            definition (SourceType.GITHUB), fixture ("github", "release.json"), 1, 25
        );
        assert (result.succeeded);
        assert (result.code == ReturnCode.RELEASES_LOADED);
        assert (result.page != null);
        var page = result.require_page ();
        assert (page.releases.size == 1);
        var release = page.releases[0];
        assert (release.upstream_release_id == "1001");
        assert (release.source_tag == "GE-Proton10-1");
        assert (release.asset.name == "GE-Proton10-1.tar.gz");
        assert (release.asset.download_url == "https://github.com/example/project/releases/download/GE-Proton10-1/GE-Proton10-1.tar.gz");
        assert (release.asset.download_size == 42);
        assert (release.download_size == 42);
        assert (page.next_page == 2);
        assert (!page.has_more);
    }

    private void test_gitlab_release_page () {
        var content = fixture ("gitlab", "release.json").replace ("ProtonPlus.flatpak", "ProtonPlus.tar.gz");
        var result = new GitLabReleaseSource ().parse_response (
            definition (SourceType.GITLAB), content, 3, 25
        );
        assert (result.succeeded);
        var page = result.require_page ();
        assert (page.releases.size == 1);
        var release = page.releases[0];
        assert (release.upstream_release_id == "3001");
        assert (release.source_tag == "v0.6.0");
        assert (release.asset.name == "ProtonPlus.tar.gz");
        assert (release.asset.download_url == "https://gitlab.com/example/project/-/releases/v0.6.0/downloads/ProtonPlus.tar.gz");
        assert (release.asset.download_size == 0);
        assert (release.page_url == "https://gitlab.com/example/project/-/releases/v0.6.0");
        assert (page.next_page == 4);
    }

    private void test_forgejo_release_page () {
        var result = new ForgejoReleaseSource ().parse_response (
            definition (SourceType.FORGEJO), fixture ("forgejo", "release.json"), 1, 25
        );
        assert (result.succeeded);
        var page = result.require_page ();
        assert (page.releases.size == 1);
        var release = page.releases[0];
        assert (release.upstream_release_id == "4001");
        assert (release.source_tag == "GE-Proton8-26");
        assert (release.asset.name == "Wine-GE-Proton8-26.tar.xz");
        assert (release.asset.download_url == "https://codeberg.org/example/project/releases/download/GE-Proton8-26/Wine-GE-Proton8-26.tar.xz");
        assert (release.asset.download_size == 126);
        assert (release.download_size == 126);
    }

    private void test_github_actions_release_page () {
        var definition = new ProviderRegistry ().get_by_id ("proton-tkg");
        assert (definition != null);
        var result = new GitHubActionsReleaseSource ().parse_response (
            (!) definition, fixture ("github-actions", "run.json"), 1, 25
        );
        assert (result.succeeded);
        var page = result.require_page ();
        assert (page.releases.size == 1);
        var release = page.releases[0];
        assert (release.kind == ProtonPlus.Models.Release.Kind.GITHUB_ACTION);
        assert (release.upstream_release_id == "5001");
        assert (release.asset.name == "proton-tkg-build.zip");
        assert (release.asset.download_url == "https://nightly.link/Frogging-Family/wine-tkg-git/actions/runs/5001/proton-tkg-build.zip");
        assert (release.asset.download_size == 0);
        assert (release.artifacts_url == "https://api.github.com/repos/example/project/actions/runs/5001/artifacts");
        assert (release.variants.size == 1);
        assert (release.variants[0].id == "standard");
        assert (release.variants[0].name == "default");
        assert (release.variants[0].is_default);
        assert (release.variants[0].download_url == release.asset.download_url);
    }

    private void test_github_actions_definition_filters () {
        var filtered = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB_ACTIONS, "filtered-actions", "Fixture provider", "",
            "https://example.test/releases", "https://example.test/source", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") },
            { "73" }, null, "", false,
            "https://example.test/artifacts/{id}/fixture-action.zip?signature=example"
        );
        var filtered_result = new GitHubActionsReleaseSource ().parse_response (
            filtered, fixture ("github-actions", "run.json"), 1, 25
        );
        assert (filtered_result.succeeded && filtered_result.require_page ().releases.size == 1);

        var excluded = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB_ACTIONS, "excluded-actions", "Fixture provider", "",
            "https://example.test/releases", "https://example.test/source", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") },
            null, { "73" }, "", false,
            "https://example.test/artifacts/{id}/fixture-action.zip?signature=example"
        );
        var excluded_result = new GitHubActionsReleaseSource ().parse_response (
            excluded, fixture ("github-actions", "run.json"), 1, 25
        );
        assert (excluded_result.succeeded && excluded_result.require_page ().releases.size == 0);
    }

    private void test_github_definition_filters () {
        var filtered = new ProviderDefinition (
            Category.WINE, SourceType.GITHUB, "filtered", "Filtered", "", "https://example.test/releases",
            "https://example.test/source", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") },
            { "proton" }
        );
        var filtered_result = new GitHubReleaseSource ().parse_response (filtered, fixture ("github", "release.json"), 1, 25);
        assert (filtered_result.succeeded && filtered_result.require_page ().releases.size == 0);

        var excluded = new ProviderDefinition (
            Category.WINE, SourceType.GITHUB, "excluded", "Excluded", "", "https://example.test/releases",
            "https://example.test/source", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") },
            null, { "GE-Proton" }
        );
        var excluded_result = new GitHubReleaseSource ().parse_response (excluded, fixture ("github", "release.json"), 1, 25);
        assert (excluded_result.succeeded && excluded_result.require_page ().releases.size == 0);
    }

    private void test_github_incomplete_assets () {
        var result = new GitHubReleaseSource ().parse_response (
            policy_definition (SourceType.GITHUB), fixture ("github", "incomplete-assets.json"), 1, 25
        );
        assert (result.succeeded);
        var page = result.require_page ();
        assert (page.releases.size == 1);
        var release = page.releases[0];
        assert (release.source_tag == "v-mixed");
        assert (release.asset.name == "v-mixed-default.tar.gz");
        assert (release.asset.download_url == "https://example.test/github/v-mixed-default.tar.gz");
        assert (release.asset.download_url != "");
        assert (release.variants[0].is_default);
        assert (release.variants[0].download_url == "https://example.test/github/v-mixed-default.tar.gz");
        assert (release.variants[0].download_url != "");

        var fallback_result = new GitHubReleaseSource ().parse_response (
            definition (SourceType.GITHUB), fixture ("github", "incomplete-assets.json"), 1, 25
        );
        assert (fallback_result.succeeded);
        var fallback = fallback_result.require_page ().releases[0];
        assert (fallback.asset.download_url == "https://example.test/github/v-mixed-first.tar.gz");
        assert (fallback.variants[0].download_url == fallback.asset.download_url);
    }

    private void test_forgejo_incomplete_assets () {
        var result = new ForgejoReleaseSource ().parse_response (
            policy_definition (SourceType.FORGEJO), fixture ("forgejo", "incomplete-assets.json"), 1, 25
        );
        assert (result.succeeded);
        var page = result.require_page ();
        assert (page.releases.size == 1);
        var release = page.releases[0];
        assert (release.source_tag == "v-mixed");
        assert (release.asset.name == "v-mixed-default.tar.gz");
        assert (release.asset.download_url == "https://example.test/forgejo/v-mixed-default.tar.gz");
        assert (release.asset.download_url != "");
        assert (release.variants[0].is_default);
        assert (release.variants[0].download_url == release.asset.download_url);
        assert (release.variants[0].download_url != "");

        var fallback_result = new ForgejoReleaseSource ().parse_response (
            definition (SourceType.FORGEJO), fixture ("forgejo", "incomplete-assets.json"), 1, 25
        );
        assert (fallback_result.succeeded);
        var fallback = fallback_result.require_page ().releases[0];
        assert (fallback.asset.download_url == "https://example.test/forgejo/v-mixed-first.tar.gz");
        assert (fallback.variants[0].download_url == fallback.asset.download_url);
    }

    private void test_gitlab_incomplete_assets () {
        var result = new GitLabReleaseSource ().parse_response (
            policy_definition (SourceType.GITLAB), fixture ("gitlab", "incomplete-assets.json"), 1, 25
        );
        assert (result.succeeded);
        var page = result.require_page ();
        assert (page.releases.size == 1);
        var release = page.releases[0];
        assert (release.source_tag == "v-mixed");
        assert (release.asset.name == "v-mixed-default.tar.gz");
        assert (release.asset.download_url == "https://example.test/gitlab/v-mixed-default.tar.gz");
        assert (release.asset.download_url != "");
        assert (release.variants[0].is_default);
        assert (release.variants[0].download_url == release.asset.download_url);
        assert (release.variants[0].download_url != "");

        var fallback_result = new GitLabReleaseSource ().parse_response (
            definition (SourceType.GITLAB), fixture ("gitlab", "incomplete-assets.json"), 1, 25
        );
        assert (fallback_result.succeeded);
        var fallback = fallback_result.require_page ().releases[0];
        assert (fallback.asset.download_url == "https://example.test/gitlab/v-mixed-first.tar.gz");
        assert (fallback.variants[0].download_url == fallback.asset.download_url);
    }

    private void test_github_compatible_default_variant_assets () {
        var response = "[{\"id\":42,\"tag_name\":\"v1\",\"body\":\"notes\",\"html_url\":\"https://example.test/v1\",\"created_at\":\"2026-07-25T12:34:56Z\",\"assets\":[{\"name\":\"v1-first.tar.gz\",\"browser_download_url\":\"https://example.test/v1-first.tar.gz\",\"size\":10},{\"name\":\"v1-default.tar.gz\",\"browser_download_url\":\"https://example.test/v1-default.tar.gz\",\"size\":20}]}]";
        var github_result = new GitHubReleaseSource ().parse_response (
            policy_definition (SourceType.GITHUB), response, 1, 25
        );
        var forgejo_result = new ForgejoReleaseSource ().parse_response (
            policy_definition (SourceType.FORGEJO), response, 1, 25
        );

        assert (github_result.succeeded && forgejo_result.succeeded);
        var github = github_result.require_page ().releases[0];
        var forgejo = forgejo_result.require_page ().releases[0];
        assert (github.upstream_release_id == "42" && github.source_tag == "v1");
        assert (github.asset.name == "v1-default.tar.gz" && github.download_size == 20);
        assert (forgejo.asset.name == "v1-default.tar.gz" && forgejo.download_size == 20);
        assert (github.variants[0].download_url == "https://example.test/v1-default.tar.gz");
        assert (forgejo.variants[0].download_url == "https://example.test/v1-default.tar.gz");
    }

    private void test_github_compatible_stable_release_policy () {
        var response = fixture ("github", "release-policy.json");
        var github_result = new GitHubReleaseSource ().parse_response (
            definition (SourceType.GITHUB), response, 1, 25
        );
        var forgejo_result = new ForgejoReleaseSource ().parse_response (
            definition (SourceType.FORGEJO), response, 1, 25
        );

        assert (github_result.succeeded && forgejo_result.succeeded);
        var github = github_result.require_page ();
        var forgejo = forgejo_result.require_page ();
        assert (github.releases.size == 1 && forgejo.releases.size == 1);
        assert (github.releases[0].source_tag == "GE-Proton10-1");
        assert (forgejo.releases[0].source_tag == "GE-Proton10-1");
    }

    private void test_github_compatible_validation_and_skipped_releases () {
        var invalid = new GitHubReleaseSource ().parse_response (
            definition (SourceType.GITHUB), fixture ("github", "invalid.json"), 1, 25
        );
        assert (!invalid.succeeded && invalid.code == ReturnCode.INVALID_DATA && invalid.page == null);

        var wrong_root = new ForgejoReleaseSource ().parse_response (
            definition (SourceType.FORGEJO), "{}", 1, 25
        );
        assert (!wrong_root.succeeded && wrong_root.code == ReturnCode.INVALID_DATA && wrong_root.page == null);

        var gitlab_missing_assets = new GitLabReleaseSource ().parse_response (
            definition (SourceType.GITLAB), fixture ("gitlab", "missing-fields.json"), 1, 25
        );
        assert (gitlab_missing_assets.succeeded && gitlab_missing_assets.require_page ().releases.size == 0);

        var skipped = new GitHubReleaseSource ().parse_response (
            definition (SourceType.GITHUB),
            "[{\"tag_name\":\"v1\",\"assets\":[]},{\"tag_name\":\"v2\",\"assets\":[{\"name\":\"notes.txt\",\"browser_download_url\":\"https://example.test/notes.txt\",\"size\":1}]}]",
            7,
            2
        );
        assert (skipped.succeeded);
        var page = skipped.require_page ();
        assert (page.releases.size == 0 && page.next_page == 8 && page.has_more);
    }

    private void test_invalid_response_codes () {
        var github = new GitHubReleaseSource ().parse_response (definition (SourceType.GITHUB), "{}", 1, 25);
        assert (!github.succeeded && github.code == ReturnCode.INVALID_DATA && github.page == null);
        var gitlab = new GitLabReleaseSource ().parse_response (definition (SourceType.GITLAB), "not json", 1, 25);
        assert (!gitlab.succeeded && gitlab.code == ReturnCode.INVALID_DATA && gitlab.page == null);
        var forgejo = new ForgejoReleaseSource ().parse_response (definition (SourceType.FORGEJO), "{}", 1, 25);
        assert (!forgejo.succeeded && forgejo.code == ReturnCode.INVALID_DATA && forgejo.page == null);
        var actions = new GitHubActionsReleaseSource ().parse_response (definition (SourceType.GITHUB_ACTIONS), "[]", 1, 25);
        assert (!actions.succeeded && actions.code == ReturnCode.INVALID_DATA && actions.page == null);
    }

    private void test_empty_pages () {
        var github_result = new GitHubReleaseSource ().parse_response (definition (SourceType.GITHUB), "[]", 8, 25);
        assert (github_result.succeeded);
        var github = github_result.require_page ();
        assert (github.releases.size == 0);
        assert (github.next_page == 9);
        assert (!github.has_more);

        var forgejo_result = new ForgejoReleaseSource ().parse_response (definition (SourceType.FORGEJO), "[]", 8, 25);
        assert (forgejo_result.succeeded);
        var forgejo = forgejo_result.require_page ();
        assert (forgejo.releases.size == 0);
        assert (forgejo.next_page == 9);
        assert (!forgejo.has_more);

        var actions_result = new GitHubActionsReleaseSource ().parse_response (
            definition (SourceType.GITHUB_ACTIONS), "{\"workflow_runs\":[]}", 8, 25
        );
        assert (actions_result.succeeded);
        var actions = actions_result.require_page ();
        assert (actions.releases.size == 0);
        assert (actions.next_page == 9);
        assert (!actions.has_more);
    }
}
