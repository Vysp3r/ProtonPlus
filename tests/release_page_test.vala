namespace AppTests.ReleasePageTest {
    using GLib;
    using Gee;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Models.Tools;
    using ProtonPlus.Providers.Sources;

    private string? fixture_cache_path = null;

    private class FixtureReleaseSource : Object, ReleaseSource {
        private HashMap<int, ReleasePage> pages = new HashMap<int, ReleasePage> ();
        public ArrayList<int> requested_pages { get; private set; default = new ArrayList<int> (); }
        public ReturnCode response_code { get; set; default = ReturnCode.RELEASES_LOADED; }

        public void set_page (int page, ReleasePage release_page) {
            pages.set (page, release_page);
        }

        public async ReleasePageResult fetch_page (
            ProviderDefinition definition,
            int requested_page,
            int limit
        ) {
            requested_pages.add (requested_page);
            if (response_code != ReturnCode.RELEASES_LOADED)
                return ReleasePageResult.failure (response_code);
            var page = pages.get (requested_page);
            return ReleasePageResult.success (page ?? new ReleasePage (
                new LinkedList<Release> (), requested_page + 1, false
            ));
        }
    }

    private class FixtureGitHubActionsSource : GitHubActionsReleaseSource {
        private HashMap<int, string> responses = new HashMap<int, string> ();
        private HashMap<int, ReturnCode> response_codes = new HashMap<int, ReturnCode> ();
        public ArrayList<int> requested_pages { get; private set; default = new ArrayList<int> (); }

        public void set_response (int page, string body) {
            responses.set (page, body);
        }

        public void set_response_code (int page, ReturnCode code) {
            response_codes.set (page, code);
        }

        protected override async Utils.Web.Response request_page (string endpoint, int page, int limit) {
            requested_pages.add (page);
            var response = new Utils.Web.Response ();
            response.code = response_codes.has_key (page)
                ? response_codes.get (page) : ReturnCode.VALID_REQUEST;
            response.status_code = 200;
            response.body = responses.get (page) ?? "{\"workflow_runs\":[]}";
            return response;
        }
    }

    public void register_tests () {
        Test.add_func ("/release-catalog/pagination-and-persistence", test_pagination_and_persistence);
        Test.add_func ("/release-catalog/latest-discovery-is-stateless", test_latest_discovery_is_stateless);
        Test.add_func ("/release-catalog/github-actions-scans-filtered-pages", test_github_actions_scanning);
        Test.add_func ("/release-catalog/github-actions-later-page-failure", test_github_actions_later_page_failure);
        Test.add_func ("/release-catalog/github-actions-proton-tkg-cache-reuse", test_github_actions_proton_tkg_cache_reuse);
        Test.add_func ("/release-catalog/in-memory-state-skips-cache-and-network", test_in_memory_state_skips_network);
        Test.add_func ("/release-catalog/valid-cache-skips-network", test_valid_cache_skips_network);
        Test.add_func ("/release-catalog/missing-and-malformed-cache-fetches", test_missing_and_malformed_cache_fetches);
        Test.add_func ("/release-catalog/stale-variants-refresh", test_stale_variants_refresh);
        Test.add_func ("/release-catalog/stale-compatibility-refreshes", test_stale_compatibility_refreshes);
        Test.add_func ("/release-catalog/forced-refresh-is-atomic", test_forced_refresh_is_atomic);
        Test.add_func ("/release-catalog/load-more-failure-preserves-state", test_load_more_failure_preserves_state);
        Test.add_func ("/release-catalog/latest-empty-and-failure-are-distinct", test_latest_empty_and_failure_are_distinct);
        Test.add_func ("/release-catalog/static-and-instance-state", test_static_and_instance_state);
    }

    private string cache_path () {
        if (fixture_cache_path == null) {
            try {
                fixture_cache_path = DirUtils.make_tmp ("protonplus-release-catalog-test-XXXXXX");
            } catch (FileError e) {
                critical ("Could not create cache fixture directory: %s", e.message);
                assert_not_reached ();
            }
        }
        Globals.CACHE_PATH = (!) fixture_cache_path;
        return (!) fixture_cache_path;
    }

    private ProviderDefinition definition (
        SourceType source_type = SourceType.GITHUB,
        bool two_variants = false,
        VariantCompatibility? compatibility = null
    ) {
        VariantDefinition[] variants = {
            new VariantDefinition ("standard", "default", "$release_name", true, compatibility)
        };
        if (two_variants) {
            variants = {
                new VariantDefinition ("standard", "default", "$release_name", true),
                new VariantDefinition ("alt", "alternate", "$release_name.zip", false)
            };
        }
        return new ProviderDefinition (
            Category.PROTON, source_type, "fixture-provider", "Fixture provider", "",
            "https://example.test/releases", "https://example.test/source", 1, variants,
            { InstallLayout.template ("default", "$release_name") },
            null, null, "", false,
            source_type == SourceType.GITHUB_ACTIONS ? "https://example.test/artifacts/{id}/fixture-action.zip" : ""
        );
    }

    private ReleaseCatalog catalog (string id, ProviderDefinition value, ReleaseSource source) {
        cache_path ();
        return new ReleaseCatalog (id, "Fixture provider", value, source);
    }

    private Release release (string title, string id) {
        return new Release (
            title, "", "2026-07-26T00:00:00Z",
            new ProtonPlus.Models.Assets.Asset ("%s.tar.gz".printf (title), "https://example.test/%s.tar.gz".printf (title)),
            "", 0, id, title
        );
    }

    private Release cached_release (string title, string id, bool default_url = true, bool duplicate_urls = false) {
        var value = release (title, id);
        value.variants.add (new ProtonPlus.Models.Variant ("standard", "default", "$release_name", true,
            default_url ? "https://example.test/%s.tar.gz".printf (title) : ""));
        if (duplicate_urls)
            value.variants.add (new ProtonPlus.Models.Variant ("alt", "alternate", "$release_name.zip", false,
                "https://example.test/%s.tar.gz".printf (title)));
        return value;
    }

    private ReleaseCatalogResult load (ReleaseCatalog catalog, bool force) {
        var loop = new MainLoop ();
        ReleaseCatalogResult? result = null;
        catalog.load.begin (force, (obj, response) => {
            result = catalog.load.end (response);
            loop.quit ();
        });
        loop.run ();
        assert (result != null);
        return (!) result;
    }

    private ReleaseCatalogResult load_more (ReleaseCatalog catalog) {
        var loop = new MainLoop ();
        ReleaseCatalogResult? result = null;
        catalog.load_more.begin ((obj, response) => {
            result = catalog.load_more.end (response);
            loop.quit ();
        });
        loop.run ();
        assert (result != null);
        return (!) result;
    }

    private ReleaseLookupResult latest (ReleaseCatalog catalog) {
        var loop = new MainLoop ();
        ReleaseLookupResult? result = null;
        catalog.fetch_latest_eligible_release.begin ((obj, response) => {
            result = catalog.fetch_latest_eligible_release.end (response);
            loop.quit ();
        });
        loop.run ();
        assert (result != null);
        return (!) result;
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

    private void test_pagination_and_persistence () {
        var source = new FixtureReleaseSource ();
        var first = new LinkedList<Release> ();
        first.add (release ("v2", "2"));
        source.set_page (1, new ReleasePage (first, 2, true));
        var second = new LinkedList<Release> ();
        second.add (release ("v1", "1"));
        source.set_page (2, new ReleasePage (second, 3, false));
        var value = catalog ("pagination-tool", definition (), source);

        var first_result = load (value, false);
        assert (first_result.succeeded);
        assert (first_result.releases.size == 1 && value.releases.size == 1);
        assert (value.page == 2 && value.has_more);
        var second_result = load_more (value);
        assert (second_result.succeeded);
        assert (second_result.releases.size == 1 && value.releases.size == 2);
        assert (value.releases[1].title == "v1");
        assert (value.page == 3 && !value.has_more);
        assert (source.requested_pages.size == 2 && source.requested_pages[0] == 1 && source.requested_pages[1] == 2);

        var snapshot = load_snapshot (new ReleaseCatalogCache ("pagination-tool", "Fixture provider"));
        assert (snapshot != null && snapshot.releases.size == 2 && snapshot.page == 3 && !snapshot.has_more);
    }

    private void test_latest_discovery_is_stateless () {
        var source = new FixtureReleaseSource ();
        source.set_page (1, new ReleasePage (new LinkedList<Release> (), 2, true));
        var second = new LinkedList<Release> ();
        second.add (release ("v1", "1"));
        source.set_page (2, new ReleasePage (second, 3, false));
        var value = catalog ("latest-tool", definition (), source);

        var found = latest (value);
        assert (found.succeeded && found.has_release);
        assert (found.require_release ().title == "v1");
        assert (value.releases.size == 0 && value.page == 1 && !value.has_more && value.last_updated == "");
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
        source.set_response (1, workflow_runs (ReleaseCatalog.RELEASE_PAGE_SIZE, false));
        source.set_response (2, workflow_runs (1, true));
        var value = catalog ("actions-tool", definition (SourceType.GITHUB_ACTIONS), source);

        var result = load (value, false);
        assert (result.succeeded && result.releases.size == 1);
        assert (result.releases[0].kind == Release.Kind.GITHUB_ACTION && result.releases[0].upstream_release_id == "5000");
        assert (value.page == 3 && !value.has_more);

        var update = latest (value);
        assert (update.succeeded && update.has_release && update.require_release ().upstream_release_id == "5000");
        assert (source.requested_pages.size == 4);
        assert (source.requested_pages[0] == 1 && source.requested_pages[1] == 2);
        assert (source.requested_pages[2] == 1 && source.requested_pages[3] == 2);
    }

    private void test_github_actions_later_page_failure () {
        var source = new FixtureGitHubActionsSource ();
        source.set_response (1, workflow_runs (ReleaseCatalog.RELEASE_PAGE_SIZE, false));
        source.set_response_code (2, ReturnCode.REQUEST_FAILED);
        var value = catalog ("actions-failure-tool", definition (SourceType.GITHUB_ACTIONS), source);

        var result = load (value, false);
        assert (!result.succeeded && result.code == ReturnCode.REQUEST_FAILED);
        assert (result.releases.size == 0 && value.releases.size == 0 && value.page == 1 && !value.has_more);
        assert (source.requested_pages.size == 2 && source.requested_pages[0] == 1 && source.requested_pages[1] == 2);
    }

    private void test_github_actions_proton_tkg_cache_reuse () {
        var definition = new ProviderRegistry ().get_by_id ("proton-tkg");
        assert (definition != null);

        var source = new FixtureGitHubActionsSource ();
        source.set_response (1, workflow_runs (1, true));
        var initial_catalog = catalog ("proton-tkg-cache-reuse", (!) definition, source);
        var initial = load (initial_catalog, false);
        assert (initial.succeeded && initial.releases.size == 1);
        assert (initial.releases[0].variants.size == 1);
        assert (initial.releases[0].variants[0].is_default);
        assert (initial.releases[0].variants[0].download_url != null);
        assert (initial.releases[0].variants[0].download_url != "");
        assert (source.requested_pages.size == 1);

        var cached_source = new FixtureGitHubActionsSource ();
        cached_source.set_response_code (1, ReturnCode.REQUEST_FAILED);
        var cached_catalog = catalog ("proton-tkg-cache-reuse", (!) definition, cached_source);
        var cached = load (cached_catalog, false);
        assert (cached.succeeded && cached.releases.size == 1);
        assert (cached.releases[0].variants.size == 1);
        assert (cached_source.requested_pages.size == 0);
    }

    private void test_in_memory_state_skips_network () {
        cache_path ();
        var source = new FixtureReleaseSource ();
        var value = catalog ("memory-tool", definition (), source);
        var cached = new LinkedList<Release> ();
        cached.add (cached_release ("cached", "cache"));
        save_snapshot (new ReleaseCatalogCache ("memory-tool", "Fixture provider"),
            new ReleaseCatalogSnapshot (cached, 2, false, "cached"));
        var existing = new LinkedList<Release> ();
        existing.add (release ("v1", "1"));
        foreach (var release in existing)
            value.releases.add (release);

        var result = load (value, false);
        assert (result.releases.size == 1 && result.succeeded);
        assert (value.releases[0].title == "v1" && source.requested_pages.size == 0);
    }

    private void test_valid_cache_skips_network () {
        cache_path ();
        var cache = new ReleaseCatalogCache ("cached-tool", "Fixture provider");
        var cached = new LinkedList<Release> ();
        cached.add (cached_release ("v1", "1"));
        save_snapshot (cache, new ReleaseCatalogSnapshot (cached, 4, true, "2026-07-26T00:00:00Z"));

        var source = new FixtureReleaseSource ();
        var value = catalog ("cached-tool", definition (), source);
        var result = load (value, false);
        assert (result.releases.size == 1 && result.succeeded);
        assert (value.page == 4 && value.has_more && source.requested_pages.size == 0);
    }

    private void test_missing_and_malformed_cache_fetches () {
        var missing_source = new FixtureReleaseSource ();
        var missing_releases = new LinkedList<Release> ();
        missing_releases.add (release ("v1", "1"));
        missing_source.set_page (1, new ReleasePage (missing_releases, 2, false));
        var missing_result = load (catalog ("missing-tool", definition (), missing_source), false);
        assert (missing_result.releases.size == 1);
        assert (missing_result.succeeded && missing_source.requested_pages.size == 1);

        var malformed_path = Path.build_filename (cache_path (), "malformed-tool.json");
        ProtonPlus.Utils.Filesystem.create_file (malformed_path, "not json");
        assert (ProtonPlus.Utils.Filesystem.get_file_content (malformed_path) == "not json");
        var malformed_source = new FixtureReleaseSource ();
        var malformed_releases = new LinkedList<Release> ();
        malformed_releases.add (release ("v2", "2"));
        malformed_source.set_page (1, new ReleasePage (malformed_releases, 2, false));
        var malformed_result = load (catalog ("malformed-tool", definition (), malformed_source), false);
        assert (malformed_result.releases.size == 1);
        assert (malformed_result.succeeded && malformed_source.requested_pages.size == 1);
    }

    private void test_stale_variants_refresh () {
        cache_path ();
        var mismatched = new LinkedList<Release> ();
        mismatched.add (cached_release ("old", "1", true, true));
        save_snapshot (new ReleaseCatalogCache ("variant-count-tool", "Fixture provider"),
            new ReleaseCatalogSnapshot (mismatched, 2, false, "old"));
        var mismatch_source = new FixtureReleaseSource ();
        var mismatch_fresh = new LinkedList<Release> ();
        mismatch_fresh.add (release ("fresh", "2"));
        mismatch_source.set_page (1, new ReleasePage (mismatch_fresh, 2, false));
        var mismatch_result = load (catalog ("variant-count-tool", definition (), mismatch_source), false);
        assert (mismatch_result.releases[0].title == "fresh");
        assert (mismatch_result.succeeded && mismatch_source.requested_pages.size == 1);

        var no_url = new LinkedList<Release> ();
        no_url.add (cached_release ("old", "1", false));
        save_snapshot (new ReleaseCatalogCache ("missing-url-tool", "Fixture provider"),
            new ReleaseCatalogSnapshot (no_url, 2, false, "old"));
        var no_url_source = new FixtureReleaseSource ();
        var fresh = new LinkedList<Release> ();
        fresh.add (release ("fresh", "2"));
        no_url_source.set_page (1, new ReleasePage (fresh, 2, false));
        var no_url_result = load (catalog ("missing-url-tool", definition (), no_url_source), false);
        assert (no_url_result.releases[0].title == "fresh");
        assert (no_url_result.succeeded && no_url_source.requested_pages.size == 1);

        var wrong_primary = new LinkedList<Release> ();
        var wrong_primary_release = new Release (
            "old", "", "2026-07-26T00:00:00Z",
            new ProtonPlus.Models.Assets.Asset (
                "old-first.tar.gz", "https://example.test/old-first.tar.gz"
            ),
            "", 0, "1", "old"
        );
        wrong_primary_release.variants.add (new ProtonPlus.Models.Variant (
            "standard", "default", "$release_name", true,
            "https://example.test/old-default.tar.gz"
        ));
        wrong_primary.add (wrong_primary_release);
        save_snapshot (new ReleaseCatalogCache ("wrong-primary-tool", "Fixture provider"),
            new ReleaseCatalogSnapshot (wrong_primary, 2, false, "old"));
        var wrong_primary_source = new FixtureReleaseSource ();
        wrong_primary_source.set_page (1, new ReleasePage (fresh, 2, false));
        var wrong_primary_result = load (
            catalog ("wrong-primary-tool", definition (), wrong_primary_source), false
        );
        assert (wrong_primary_result.releases[0].title == "fresh");
        assert (wrong_primary_result.succeeded && wrong_primary_source.requested_pages.size == 1);

        var duplicate = new LinkedList<Release> ();
        duplicate.add (cached_release ("old", "1", true, true));
        save_snapshot (new ReleaseCatalogCache ("duplicate-url-tool", "Fixture provider"),
            new ReleaseCatalogSnapshot (duplicate, 2, false, "old"));
        var duplicate_source = new FixtureReleaseSource ();
        duplicate_source.set_page (1, new ReleasePage (fresh, 2, false));
        var duplicate_result = load (catalog ("duplicate-url-tool", definition (SourceType.GITHUB, true), duplicate_source), false);
        assert (duplicate_result.releases[0].title == "fresh");
        assert (duplicate_result.succeeded && duplicate_source.requested_pages.size == 1);
    }

    private void test_stale_compatibility_refreshes () {
        cache_path ();
        var stale_path = Path.build_filename (cache_path (), "stale-compatibility-tool.json");
        assert (ProtonPlus.Utils.Filesystem.modify_file (stale_path,
            "{\"last_updated\":\"old\",\"page\":2,\"has_more\":false,\"releases\":[{\"kind\":\"generic\",\"title\":\"old\",\"asset\":{\"name\":\"old.tar.gz\",\"download_url\":\"https://example.test/old.tar.gz\"},\"upstream_release_id\":\"1\",\"variants\":[{\"id\":\"standard\",\"name\":\"default\",\"format\":\"$release_name\",\"default\":true,\"download_url\":\"https://example.test/old.tar.gz\"}]}]}"
        ));

        var source = new FixtureReleaseSource ();
        var fresh = new LinkedList<Release> ();
        fresh.add (release ("fresh", "2"));
        source.set_page (1, new ReleasePage (fresh, 2, false));
        var result = load (catalog (
            "stale-compatibility-tool",
            definition (SourceType.GITHUB, false, VariantCompatibility.for_x86_64_level (X86_64Level.V3)),
            source
        ), false);
        assert (result.succeeded && result.releases[0].title == "fresh");
        assert (source.requested_pages.size == 1);
    }

    private void test_forced_refresh_is_atomic () {
        var source = new FixtureReleaseSource ();
        var old = new LinkedList<Release> ();
        old.add (release ("old", "1"));
        source.set_page (1, new ReleasePage (old, 2, true));
        var value = catalog ("refresh-tool", definition (), source);
        load (value, false);
        var fresh = new LinkedList<Release> ();
        fresh.add (release ("fresh", "2"));
        source.set_page (1, new ReleasePage (fresh, 2, false));
        var refresh_result = load (value, true);
        assert (refresh_result.releases[0].title == "fresh");
        assert (refresh_result.succeeded && source.requested_pages[source.requested_pages.size - 1] == 1);

        source.response_code = ReturnCode.REQUEST_FAILED;
        var failed_refresh = load (value, true);
        assert (failed_refresh.releases[0].title == "fresh");
        assert (failed_refresh.code == ReturnCode.REQUEST_FAILED && value.releases.size == 1 && value.releases[0].title == "fresh");

        var failed_source = new FixtureReleaseSource ();
        failed_source.response_code = ReturnCode.REQUEST_FAILED;
        var failed = catalog ("failed-initial-tool", definition (), failed_source);
        var failed_initial = load (failed, false);
        assert (failed_initial.code == ReturnCode.REQUEST_FAILED && failed.releases.size == 0 && failed.last_updated == "");
    }

    private void test_load_more_failure_preserves_state () {
        var source = new FixtureReleaseSource ();
        var first = new LinkedList<Release> ();
        first.add (release ("v2", "2"));
        source.set_page (1, new ReleasePage (first, 2, true));
        var value = catalog ("load-more-failure-tool", definition (), source);
        assert (load (value, false).succeeded);

        source.response_code = ReturnCode.REQUEST_FAILED;
        var result = load_more (value);
        assert (!result.succeeded && result.code == ReturnCode.REQUEST_FAILED);
        assert (result.releases.size == 1 && result.releases[0].title == "v2");
        assert (value.releases.size == 1 && value.releases[0].title == "v2");
        assert (value.page == 2 && value.has_more && !value.loading);
    }

    private void test_latest_empty_and_failure_are_distinct () {
        var empty_source = new FixtureReleaseSource ();
        empty_source.set_page (1, new ReleasePage (new LinkedList<Release> (), 2, false));
        var empty_catalog = catalog ("latest-empty-tool", definition (), empty_source);
        var empty_result = latest (empty_catalog);
        assert (empty_result.succeeded && !empty_result.has_release && empty_result.code == ReturnCode.RELEASES_LOADED);
        assert (empty_catalog.releases.size == 0 && empty_catalog.page == 1 && !empty_catalog.has_more);

        var failed_source = new FixtureReleaseSource ();
        failed_source.response_code = ReturnCode.REQUEST_FAILED;
        var failed_catalog = catalog ("latest-failure-tool", definition (), failed_source);
        var failed_result = latest (failed_catalog);
        assert (!failed_result.succeeded && !failed_result.has_release && failed_result.code == ReturnCode.REQUEST_FAILED);
        assert (failed_catalog.releases.size == 0 && failed_catalog.page == 1 && !failed_catalog.has_more);
    }

    private void test_static_and_instance_state () {
        var static_catalog = new ReleaseCatalog.with_static_release (release ("Static", "static"));
        var static_result = load (static_catalog, false);
        assert (static_result.releases.size == 1 && static_result.succeeded);
        assert (!static_catalog.has_more);

        var source = new FixtureReleaseSource ();
        var first = catalog ("first-instance", definition (), source);
        var second = catalog ("second-instance", definition (), source);
        var values = new LinkedList<Release> ();
        values.add (release ("first", "1"));
        foreach (var release in values)
            first.releases.add (release);
        assert (first.releases.size == 1 && second.releases.size == 0);
    }
}
