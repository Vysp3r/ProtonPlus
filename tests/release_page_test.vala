namespace AppTests.ReleasePageTest {
    using GLib;
    using Gee;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Models.Tools;
    using ProtonPlus.Providers.Sources;

    private class FixtureReleaseSource : Object, ReleaseSource {
        private HashMap<int, ReleasePage> pages = new HashMap<int, ReleasePage> ();
        public ArrayList<int> requested_pages { get; private set; default = new ArrayList<int> (); }

        public void set_page (int page, ReleasePage release_page) {
            pages.set (page, release_page);
        }

        public async ReleasePage? fetch_page (
            ProviderDefinition definition,
            int requested_page,
            int limit,
            out ReturnCode code
        ) {
            requested_pages.add (requested_page);
            code = ReturnCode.RELEASES_LOADED;
            var page = pages.get (requested_page);
            return page != null ? page : new ReleasePage (new LinkedList<Release> (), requested_page + 1, false);
        }
    }

    private class FixtureGitHubActionsSource : GitHubActionsReleaseSource {
        private HashMap<int, string> responses = new HashMap<int, string> ();
        public ArrayList<int> requested_pages { get; private set; default = new ArrayList<int> (); }

        public void set_response (int page, string body) {
            responses.set (page, body);
        }

        protected override async Utils.Web.Response request_page (string endpoint, int page, int limit) {
            requested_pages.add (page);
            var response = new Utils.Web.Response ();
            response.code = ReturnCode.VALID_REQUEST;
            response.status_code = 200;
            response.body = responses.get (page) ?? "{\"workflow_runs\":[]}";
            return response;
        }
    }

    public void register_tests () {
        Test.add_func ("/release-page/pagination-is-stateful", test_pagination_is_stateful);
        Test.add_func ("/release-page/latest-discovery-is-stateless", test_latest_discovery_is_stateless);
        Test.add_func ("/release-page/github-actions-scans-filtered-pages", test_github_actions_scanning);
    }

    private ProviderDefinition definition (SourceType source_type = SourceType.GITHUB) {
        return new ProviderDefinition (
            Category.PROTON, source_type, "fixture-provider", "Fixture provider", "",
            "https://example.test/releases", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { new DirectoryNameFormat ("default", "$release_name") },
            null, null, "", false,
            source_type == SourceType.GITHUB_ACTIONS ? "https://example.test/artifacts/{id}/fixture-action.zip" : ""
        );
    }

    private Basic tool (ProviderDefinition definition, ReleaseSource source) {
        var launcher = new Launcher ("Fixture", Launcher.InstallationTypes.SYSTEM, "", {}, "fixture");
        var group = new Group ("Fixture", "", "", launcher, "fixture");
        return new Basic.with_catalog (definition, source, group, "$release_name");
    }

    private Release release (string title, string id) {
        return new Release (
            title, "", "2026-07-26T00:00:00Z",
            new ProtonPlus.Models.Assets.Asset ("%s.tar.gz".printf (title), "https://example.test/%s.tar.gz".printf (title)),
            "", 0, id, title
        );
    }

    private LinkedList<Release> load_more (Basic tool, out ReturnCode code) {
        var loop = new MainLoop ();
        var releases = new LinkedList<Release> ();
        ReturnCode result = ReturnCode.REQUEST_FAILED;
        tool.load_more.begin ((obj, response) => {
            releases = tool.load_more.end (response, out result);
            loop.quit ();
        });
        loop.run ();
        code = result;
        return releases;
    }

    private Release? latest (Basic tool, out ReturnCode code) {
        var loop = new MainLoop ();
        Release? value = null;
        ReturnCode result = ReturnCode.REQUEST_FAILED;
        tool.fetch_latest_eligible_release.begin ((obj, response) => {
            value = tool.fetch_latest_eligible_release.end (response, out result);
            loop.quit ();
        });
        loop.run ();
        code = result;
        return value;
    }

    private void test_pagination_is_stateful () {
        var source = new FixtureReleaseSource ();
        var first = new LinkedList<Release> ();
        first.add (release ("v2", "2"));
        source.set_page (1, new ReleasePage (first, 2, true));
        var second = new LinkedList<Release> ();
        second.add (release ("v1", "1"));
        source.set_page (2, new ReleasePage (second, 3, false));
        var catalog_tool = tool (definition (), source);

        ReturnCode code;
        var first_page = load_more (catalog_tool, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (first_page.size == 1 && first_page[0].title == "v2");
        assert (catalog_tool.page == 2 && catalog_tool.has_more);
        var second_page = load_more (catalog_tool, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (second_page.size == 1 && second_page[0].title == "v1");
        assert (catalog_tool.page == 3 && !catalog_tool.has_more);
        assert (source.requested_pages.size == 2 && source.requested_pages[0] == 1 && source.requested_pages[1] == 2);
    }

    private void test_latest_discovery_is_stateless () {
        var source = new FixtureReleaseSource ();
        source.set_page (1, new ReleasePage (new LinkedList<Release> (), 2, true));
        var second = new LinkedList<Release> ();
        second.add (release ("v1", "1"));
        source.set_page (2, new ReleasePage (second, 3, false));
        var catalog_tool = tool (definition (), source);

        ReturnCode code;
        var found = latest (catalog_tool, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (found != null && found.title == "v1");
        assert (catalog_tool.page == 1);
        assert (source.requested_pages.size == 2);
        assert (source.requested_pages[0] == 1 && source.requested_pages[1] == 2);
    }

    private string workflow_runs (int count, bool successful) {
        var builder = new StringBuilder ("{\"workflow_runs\":[");
        for (var index = 0; index < count; index++) {
            if (index > 0)
                builder.append (",");
            var id = 5000 + index;
            builder.append ("{\"id\":%d,\"run_number\":%d,\"html_url\":\"https://example.test/runs/%d\",\"artifacts_url\":\"https://example.test/artifacts/%d\",\"status\":\"completed\",\"conclusion\":\"%s\",\"created_at\":\"2026-07-26T00:00:00Z\"}".printf (
                id, id, id, id, successful ? "success" : "failure"
            ));
        }
        builder.append ("]}");
        return builder.str;
    }

    private void test_github_actions_scanning () {
        var source = new FixtureGitHubActionsSource ();
        source.set_response (1, workflow_runs (Basic.RELEASE_PAGE_SIZE, false));
        source.set_response (2, workflow_runs (1, true));
        var catalog_tool = tool (definition (SourceType.GITHUB_ACTIONS), source);

        ReturnCode code;
        var releases = load_more (catalog_tool, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (releases.size == 1);
        assert (releases[0].kind == Release.Kind.GITHUB_ACTION);
        assert (releases[0].upstream_release_id == "5000");
        assert (catalog_tool.page == 3 && !catalog_tool.has_more);

        var update = latest (catalog_tool, out code);
        assert (code == ReturnCode.RELEASES_LOADED);
        assert (update != null && update.upstream_release_id == "5000");
        assert (source.requested_pages.size == 4);
        assert (source.requested_pages[0] == 1 && source.requested_pages[1] == 2);
        assert (source.requested_pages[2] == 1 && source.requested_pages[3] == 2);
    }
}
