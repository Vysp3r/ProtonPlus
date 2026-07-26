namespace AppTests.ProviderSourceTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/providers/github/release", test_github_release);
        Test.add_func ("/providers/github/missing-fields", test_github_missing_fields);
        Test.add_func ("/providers/gitlab/release", test_gitlab_release);
        Test.add_func ("/providers/gitlab/missing-fields", test_gitlab_missing_fields);
        Test.add_func ("/providers/forgejo/release", test_forgejo_release);
        Test.add_func ("/providers/forgejo/missing-fields", test_forgejo_missing_fields);
        Test.add_func ("/providers/github-actions/run", test_github_actions_run);
        Test.add_func ("/providers/github-actions/missing-fields", test_github_actions_missing_fields);
        Test.add_func ("/providers/malformed-responses", test_malformed_responses);
        Test.add_func ("/providers/invalid-json", test_invalid_json_responses);
    }

    private string get_fixture_content (string provider, string fixture) {
        var path = Path.build_filename ("fixtures", "providers", provider, fixture);
        var content = ProtonPlus.Utils.Filesystem.get_file_content (path);
        assert (content != "");
        return content;
    }

    private Json.Node? get_fixture_node (string provider, string fixture) {
        try {
            return Json.from_string (get_fixture_content (provider, fixture));
        } catch (Error e) {
            return null;
        }
    }

    private Json.Array? get_releases_array (string provider, string fixture) {
        var node = get_fixture_node (provider, fixture);
        if (node == null || node.get_node_type () != Json.NodeType.ARRAY)
            return null;

        return node.get_array ();
    }

    private Json.Array? get_workflow_runs (string fixture) {
        var node = get_fixture_node ("github-actions", fixture);
        if (node == null || node.get_node_type () != Json.NodeType.OBJECT)
            return null;

        var object = node.get_object ();
        if (object == null || !object.has_member ("workflow_runs"))
            return null;

        var workflow_runs = object.get_member ("workflow_runs");
        if (workflow_runs == null || workflow_runs.get_node_type () != Json.NodeType.ARRAY)
            return null;

        return object.get_array_member ("workflow_runs");
    }

    private void test_github_release () {
        var releases = new ProtonPlus.Providers.Sources.GitHub.Releases.from_json (
            get_releases_array ("github", "release.json")
        );
        assert (releases.size == 1);

        var release = (ProtonPlus.Providers.Sources.GitHub.Release) releases.list.get (0);
        assert (release.id == 1001);
        assert (release.name == "GE-Proton10-1");
        assert (release.tag_name == "GE-Proton10-1");
        assert (release.description == "Release notes");
        assert (release.page_url == "https://github.com/example/project/releases/tag/GE-Proton10-1");
        assert (release.draft);
        assert (release.prereleas);
        assert (release.assets.size == 1);

        var asset = release.assets.get (0);
        assert (asset.id == 2001);
        assert (asset.name == "GE-Proton10-1.tar.gz");
        assert (asset.content_type == "application/gzip");
        assert (asset.size == 42);
        assert (asset.digest == "sha256:github");
        assert (asset.download_url == "https://github.com/example/project/releases/download/GE-Proton10-1/GE-Proton10-1.tar.gz");
    }

    private void test_github_missing_fields () {
        var releases = new ProtonPlus.Providers.Sources.GitHub.Releases.from_json (
            get_releases_array ("github", "missing-fields.json")
        );
        assert (releases.size == 1);

        var release = (ProtonPlus.Providers.Sources.GitHub.Release) releases.list.get (0);
        assert (release.id == 0);
        assert (release.name == "");
        assert (release.tag_name == "");
        assert (release.description == "");
        assert (release.page_url == "");
        assert (!release.draft);
        assert (!release.prereleas);
        assert (release.assets.size == 0);
    }

    private void test_gitlab_release () {
        var releases = new ProtonPlus.Providers.Sources.GitLab.Releases.from_json (
            get_releases_array ("gitlab", "release.json")
        );
        assert (releases.size == 1);

        var release = (ProtonPlus.Providers.Sources.GitLab.Release) releases.list.get (0);
        assert (release.id == 3001);
        assert (release.name == "ProtonPlus 0.6.0");
        assert (release.tag_name == "v0.6.0");
        assert (release.description == "GitLab release notes");
        assert (release.page_url == "https://gitlab.com/example/project/-/releases/v0.6.0");
        assert (release.assets.size == 1);

        var asset = release.assets.get (0);
        assert (asset.id == 3002);
        assert (asset.name == "ProtonPlus.flatpak");
        assert (asset.content_type == "application/octet-stream");
        assert (asset.size == 84);
        assert (asset.digest == "sha256:gitlab");
        assert (asset.download_url == "https://gitlab.com/example/project/-/releases/v0.6.0/downloads/ProtonPlus.flatpak");
    }

    private void test_gitlab_missing_fields () {
        var releases = new ProtonPlus.Providers.Sources.GitLab.Releases.from_json (
            get_releases_array ("gitlab", "missing-fields.json")
        );
        assert (releases.size == 1);

        var release = (ProtonPlus.Providers.Sources.GitLab.Release) releases.list.get (0);
        assert (release.id == 0);
        assert (release.name == "");
        assert (release.tag_name == "");
        assert (release.description == "");
        assert (release.page_url == "");
        assert (!release.draft);
        assert (!release.prereleas);
        assert (release.assets.size == 0);
    }

    private void test_forgejo_release () {
        var releases = new ProtonPlus.Providers.Sources.Forgejo.Releases.from_json (
            get_releases_array ("forgejo", "release.json")
        );
        assert (releases.size == 1);

        var release = (ProtonPlus.Providers.Sources.Forgejo.Release) releases.list.get (0);
        assert (release.id == 4001);
        assert (release.name == "Wine-GE-Proton8-26");
        assert (release.tag_name == "GE-Proton8-26");
        assert (release.description == "Forgejo release notes");
        assert (release.page_url == "https://codeberg.org/example/project/releases/tag/GE-Proton8-26");
        assert (release.assets.size == 1);

        var asset = release.assets.get (0);
        assert (asset.id == 4002);
        assert (asset.name == "Wine-GE-Proton8-26.tar.xz");
        assert (asset.content_type == "application/x-xz");
        assert (asset.size == 126);
        assert (asset.digest == "sha256:forgejo");
        assert (asset.download_url == "https://codeberg.org/example/project/releases/download/GE-Proton8-26/Wine-GE-Proton8-26.tar.xz");
    }

    private void test_forgejo_missing_fields () {
        var releases = new ProtonPlus.Providers.Sources.Forgejo.Releases.from_json (
            get_releases_array ("forgejo", "missing-fields.json")
        );
        assert (releases.size == 1);

        var release = (ProtonPlus.Providers.Sources.Forgejo.Release) releases.list.get (0);
        assert (release.id == 0);
        assert (release.name == "");
        assert (release.tag_name == "");
        assert (release.description == "");
        assert (release.page_url == "");
        assert (!release.draft);
        assert (!release.prereleas);
        assert (release.assets.size == 0);
    }

    private void test_github_actions_run () {
        var releases = new ProtonPlus.Providers.Sources.GitHubActions.Releases.from_json (
            get_workflow_runs ("run.json")
        );
        assert (releases.size == 1);

        var release = (ProtonPlus.Providers.Sources.GitHubActions.Release) releases.list.get (0);
        assert (release.id == 5001);
        assert (release.title == "73");
        assert (release.name == "73");
        assert (release.page_url == "https://github.com/example/project/actions/runs/5001");
        assert (release.artifacts_url == "https://api.github.com/repos/example/project/actions/runs/5001/artifacts");
        assert (release.status == "completed");
        assert (release.conclusion == "success");
    }

    private void test_github_actions_missing_fields () {
        var releases = new ProtonPlus.Providers.Sources.GitHubActions.Releases.from_json (
            get_workflow_runs ("missing-fields.json")
        );
        assert (releases.size == 1);

        var release = (ProtonPlus.Providers.Sources.GitHubActions.Release) releases.list.get (0);
        assert (release.id == 0);
        assert (release.title == "");
        assert (release.name == "");
        assert (release.page_url == "");
        assert (release.artifacts_url == "");
        assert (release.status == "");
        assert (release.conclusion == "");
    }

    private void test_malformed_responses () {
        assert (get_releases_array ("github", "malformed.json") == null);
        assert (get_releases_array ("gitlab", "malformed.json") == null);
        assert (get_releases_array ("forgejo", "malformed.json") == null);
        assert (get_workflow_runs ("malformed.json") == null);
    }

    private void test_invalid_json_responses () {
        assert (get_fixture_node ("github", "invalid.json") == null);
        assert (get_fixture_node ("gitlab", "invalid.json") == null);
        assert (get_fixture_node ("forgejo", "invalid.json") == null);
        assert (get_fixture_node ("github-actions", "invalid.json") == null);
    }
}
