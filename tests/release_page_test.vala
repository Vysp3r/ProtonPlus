namespace AppTests.ReleasePageTest {
    using GLib;
    using Gee;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Internal.Requests;
    using ProtonPlus.Models.Launchers.Runners;

    private class PagedFixtureRunner : Base {
        private IReleases fallback_page;
        private HashMap<int, IReleases> pages = new HashMap<int, IReleases> ();
        public ArrayList<int> requested_pages { get; private set; default = new ArrayList<int> (); }

        public PagedFixtureRunner (SourceType source_type, IReleases fallback_page) {
            base (source_type, "fixture-provider", "Fixture runner", "", "https://example.test/releases");
            this.fallback_page = fallback_page;
            add_directory_name_format ("default", "$release_name");
        }

        public void set_page (int page, IReleases releases) {
            pages.set (page, releases);
        }

        public void add_filter (string filter) {
            if (request_asset_filter == null)
                request_asset_filter = new ArrayList<string> ();
            request_asset_filter.add (filter);
        }

        public void add_release_variant (string id, string name, string format, bool is_default) {
            add_variant (id, name, format, is_default);
        }

        public void set_action_url_template (string template) {
            url_template = template;
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            requested_pages.add (page);
            code = ReturnCode.RELEASES_LOADED;

            var releases = pages.get (page);
            return releases != null ? releases : fallback_page;
        }
    }

    public void register_tests () {
        Test.add_func ("/release-pages/github-browse-snapshot", test_github_browse_snapshot);
        Test.add_func ("/release-pages/latest-eligible-is-stateless", test_latest_eligible_is_stateless);
        Test.add_func ("/release-pages/latest-eligible-reaches-end", test_latest_eligible_reaches_end);
        Test.add_func ("/release-pages/provider-fixture-contract", test_provider_fixture_contract);
        Test.add_func ("/release-pages/github-actions-scanning", test_github_actions_scanning);
    }

    private Json.Array get_release_array (string provider) {
        var content = ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename ("fixtures", "providers", provider, "release.json")
        );
        var root = ProtonPlus.Utils.Parser.get_node_from_json (content);
        assert (root != null);
        assert (root.get_node_type () == Json.NodeType.ARRAY);
        return root.get_array ();
    }

    private Json.Array get_action_array () {
        var content = ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename ("fixtures", "providers", "github-actions", "run.json")
        );
        var root = ProtonPlus.Utils.Parser.get_node_from_json (content);
        assert (root != null);
        assert (root.get_node_type () == Json.NodeType.OBJECT);
        return root.get_object ().get_array_member ("workflow_runs");
    }

    private Internal.Requests.Github.Release github_release (string tag, int64 id, bool alternate_asset = false) {
        var releases = new Internal.Requests.Github.Releases.from_json (get_release_array ("github"));
        var release = releases.list.get (0) as Internal.Requests.Github.Release;
        assert (release != null);

        release.id = id;
        release.name = tag;
        release.tag_name = tag;
        release.assets.clear ();

        var primary = new Internal.Requests.Github.Asset ();
        primary.name = "%s.tar.gz".printf (tag);
        primary.download_url = "https://example.test/%s.tar.gz".printf (tag);
        primary.size = 42;
        release.assets.add (primary);

        if (alternate_asset) {
            var alternate = new Internal.Requests.Github.Asset ();
            alternate.name = "%s-alt.tar.gz".printf (tag);
            alternate.download_url = "https://example.test/%s-alt.tar.gz".printf (tag);
            alternate.size = 84;
            release.assets.add (alternate);
        }

        return release;
    }

    private Internal.Requests.GithubAction.Release action_release (int64 id, bool successful) {
        var releases = new Internal.Requests.GithubAction.Releases.from_json (get_action_array ());
        var release = releases.list.get (0) as Internal.Requests.GithubAction.Release;
        assert (release != null);

        release.id = id;
        release.title = "Workflow run %s".printf (id.to_string ());
        release.status = "completed";
        release.conclusion = successful ? "success" : "failure";
        return release;
    }

    private Internal.Requests.Github.Releases github_releases (LinkedList<IRelease> releases) {
        return new Internal.Requests.Github.Releases (releases);
    }

    private Internal.Requests.GithubAction.Releases action_releases (LinkedList<IRelease> releases) {
        return new Internal.Requests.GithubAction.Releases (releases);
    }

    private Tools.Basic create_tool (PagedFixtureRunner runner) {
        var launcher = new Launcher (
            "Fixture launcher", Launcher.InstallationTypes.SYSTEM, "", { "/tmp" }, "fixture"
        );
        var group = new Group ("Fixture group", "", "", launcher, "fixture");
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

    private Tools.ReleasePage? fetch_release_page (Tools.Basic tool, int requested_page, out ReturnCode code) {
        var loop = new MainLoop ();
        Tools.ReleasePage? release_page = null;
        ReturnCode result_code = ReturnCode.REQUEST_FAILED;

        tool.fetch_release_page.begin (requested_page, (obj, res) => {
            release_page = tool.fetch_release_page.end (res, out result_code);
            loop.quit ();
        });
        loop.run ();

        code = result_code;
        return release_page;
    }

    private Release? fetch_latest_eligible_release (Tools.Basic tool, out ReturnCode code) {
        var loop = new MainLoop ();
        Release? release = null;
        ReturnCode result_code = ReturnCode.REQUEST_FAILED;

        tool.fetch_latest_eligible_release.begin ((obj, res) => {
            release = tool.fetch_latest_eligible_release.end (res, out result_code);
            loop.quit ();
        });
        loop.run ();

        code = result_code;
        return release;
    }

    private PagedFixtureRunner create_filtered_github_runner () {
        var empty_page = new LinkedList<IRelease> ();
        var runner = new PagedFixtureRunner (SourceType.GITHUB, github_releases (empty_page));
        runner.add_filter ("eligible");
        runner.add_release_variant ("default", "default", "$tag_name.tar.gz", true);
        runner.add_release_variant ("alternate", "alternate", "$tag_name-alt.tar.gz", false);

        var filtered_items = new LinkedList<IRelease> ();
        for (var index = 0; index < Tools.Basic.RELEASE_PAGE_SIZE; index++) {
            filtered_items.add (github_release ("filtered-%d".printf (index), index + 1));
        }
        runner.set_page (1, github_releases (filtered_items));

        var eligible_items = new LinkedList<IRelease> ();
        eligible_items.add (github_release ("eligible-2", 102, true));
        eligible_items.add (github_release ("eligible-1", 101, true));
        runner.set_page (2, github_releases (eligible_items));
        return runner;
    }

    private void assert_requested_pages (ArrayList<int> requested_pages, int[] expected_pages) {
        assert (requested_pages.size == expected_pages.length);
        for (var index = 0; index < expected_pages.length; index++)
            assert (requested_pages.get (index) == expected_pages[index]);
    }

    private void test_github_browse_snapshot () {
        var runner = create_filtered_github_runner ();
        var tool = create_tool (runner);

        ReturnCode code;
        var normalized_page = fetch_release_page (tool, 1, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (normalized_page != null);
        assert (normalized_page.releases.size == 0);
        assert (normalized_page.next_page == 2);
        assert (normalized_page.has_more);
        assert (tool.page == 1);
        assert (!tool.has_more);

        var first_browse_page = load_more (tool, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (first_browse_page.size == 0);
        assert (tool.page == 2);
        assert (tool.has_more);

        var second_browse_page = load_more (tool, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (second_browse_page.size == 2);
        assert (second_browse_page.get (0).title == "eligible-2");
        assert (second_browse_page.get (1).title == "eligible-1");
        assert (second_browse_page.get (0).variants.size == 2);
        assert (second_browse_page.get (0).variants.get (0).download_url ==
                "https://example.test/eligible-2.tar.gz");
        assert (second_browse_page.get (0).variants.get (1).download_url ==
                "https://example.test/eligible-2-alt.tar.gz");
        assert (tool.page == 3);
        assert (!tool.has_more);
        assert_requested_pages (runner.requested_pages, { 1, 1, 2 });
    }

    private void test_latest_eligible_is_stateless () {
        var runner = create_filtered_github_runner ();
        var tool = create_tool (runner);

        ReturnCode code;
        var latest = fetch_latest_eligible_release (tool, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (latest != null);
        assert (latest.title == "eligible-2");
        assert (tool.page == 1);
        assert (!tool.has_more);
        assert_requested_pages (runner.requested_pages, { 1, 2 });
    }

    private void test_latest_eligible_reaches_end () {
        var runner = create_filtered_github_runner ();
        runner.set_page (2, github_releases (new LinkedList<IRelease> ()));
        var tool = create_tool (runner);

        ReturnCode code;
        var latest = fetch_latest_eligible_release (tool, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (latest == null);
        assert (tool.page == 1);
        assert (!tool.has_more);
        assert_requested_pages (runner.requested_pages, { 1, 2 });
    }

    private void test_provider_fixture_contract () {
        var github_items = new LinkedList<IRelease> ();
        github_items.add (github_release ("GE-Proton10-1", 1001));
        var github_runner = new PagedFixtureRunner (SourceType.GITHUB, github_releases (new LinkedList<IRelease> ()));
        github_runner.set_page (1, github_releases (github_items));
        github_runner.add_release_variant ("default", "default", "$tag_name.tar.gz", true);
        assert_fixture_page (create_tool (github_runner), "GE-Proton10-1", "1001", "GE-Proton10-1.tar.gz");

        var gitlab_items = new LinkedList<Internal.Requests.Gitlab.Release> ();
        var gitlab_source = new Internal.Requests.Gitlab.Releases.from_json (get_release_array ("gitlab"));
        gitlab_items.add (gitlab_source.list.get (0) as Internal.Requests.Gitlab.Release);
        var gitlab_runner = new PagedFixtureRunner (
            SourceType.GITLAB, new Internal.Requests.Gitlab.Releases (new LinkedList<Internal.Requests.Gitlab.Release> ())
        );
        gitlab_runner.set_page (1, new Internal.Requests.Gitlab.Releases (gitlab_items));
        gitlab_runner.add_release_variant ("default", "default", "$release_name", true);
        assert_empty_fixture_page (create_tool (gitlab_runner));

        var forgejo_items = new LinkedList<IRelease> ();
        var forgejo_source = new Internal.Requests.Forgejo.Releases.from_json (get_release_array ("forgejo"));
        forgejo_items.add (forgejo_source.list.get (0));
        var forgejo_runner = new PagedFixtureRunner (
            SourceType.FORGEJO, new Internal.Requests.Forgejo.Releases (new LinkedList<IRelease> ())
        );
        forgejo_runner.set_page (1, new Internal.Requests.Forgejo.Releases (forgejo_items));
        forgejo_runner.add_release_variant ("default", "default", "$tag_name", true);
        assert_fixture_page (create_tool (forgejo_runner), "GE-Proton8-26", "4001", "Wine-GE-Proton8-26.tar.xz");
    }

    private void assert_fixture_page (Tools.Basic tool, string expected_title, string expected_id, string expected_asset) {
        ReturnCode code;
        var release_page = fetch_release_page (tool, 1, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (release_page != null);
        assert (release_page.releases.size == 1);
        assert (release_page.releases.get (0).title == expected_title);
        assert (release_page.releases.get (0).upstream_release_id == expected_id);
        assert (release_page.releases.get (0).asset.name == expected_asset);
        assert (release_page.next_page == 2);
        assert (!release_page.has_more);
        assert (tool.page == 1);

        var browsed_releases = load_more (tool, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (browsed_releases.size == 1);
        assert (tool.page == 2);
        assert (!tool.has_more);
    }

    private void assert_empty_fixture_page (Tools.Basic tool) {
        ReturnCode code;
        var release_page = fetch_release_page (tool, 1, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (release_page != null);
        assert (release_page.releases.size == 0);
        assert (release_page.next_page == 2);
        assert (!release_page.has_more);
        assert (tool.page == 1);

        var browsed_releases = load_more (tool, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (browsed_releases.size == 0);
        assert (tool.page == 2);
        assert (!tool.has_more);
    }

    private void test_github_actions_scanning () {
        var empty_page = new LinkedList<IRelease> ();
        var runner = new PagedFixtureRunner (SourceType.GITHUB_ACTION, action_releases (empty_page));
        runner.set_action_url_template ("https://example.test/artifacts/{id}/fixture-action.zip");

        var unsuccessful_runs = new LinkedList<IRelease> ();
        for (var index = 0; index < Tools.Basic.RELEASE_PAGE_SIZE; index++)
            unsuccessful_runs.add (action_release (index + 1, false));
        runner.set_page (1, action_releases (unsuccessful_runs));

        var successful_runs = new LinkedList<IRelease> ();
        successful_runs.add (action_release (5001, true));
        runner.set_page (2, action_releases (successful_runs));

        var tool = create_tool (runner);
        ReturnCode code;
        var releases = load_more (tool, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (releases.size == 1);
        assert (releases.get (0).title == "Workflow run 5001");
        assert (releases.get (0).asset.download_url ==
                "https://example.test/artifacts/5001/fixture-action.zip");
        assert (tool.page == 3);
        assert (!tool.has_more);
        assert_requested_pages (runner.requested_pages, { 1, 2 });
    }
}
