namespace ProtonPlus.Models {
    // Owns the complete remote browse state for exactly one Tool instance.
    // Provider adapters remain stateless: they normalize a requested page and
    // this class applies the result to the catalog and its persisted snapshot.
    public class ReleaseCatalog : Object {
        public const int RELEASE_PAGE_SIZE = 25;
        public const int64 CACHE_TTL = TimeSpan.HOUR;

        private Providers.ProviderDefinition? definition;
        private ProtonPlus.Providers.Sources.ReleaseSource? release_source;
        private ReleaseCatalogCache? cache;
        private Release? static_release;
        private string? _last_version = null;

        public Gee.LinkedList<Release> releases { get; private set; default = new Gee.LinkedList<Release> (); }
        public int page { get; private set; default = 1; }
        public bool has_more { get; private set; default = false; }
        public string last_updated { get; private set; default = ""; }
        public bool loading { get; private set; default = false; }

        public signal void releases_changed ();

        public ReleaseCatalog (
            string tool_id,
            string tool_title,
            Providers.ProviderDefinition definition,
            ProtonPlus.Providers.Sources.ReleaseSource release_source
        ) {
            this.definition = definition;
            this.release_source = release_source;
            this.cache = new ReleaseCatalogCache (tool_id, tool_title);
        }

        public ReleaseCatalog.with_static_release (Release release) {
            this.static_release = release;
        }

        public string? last_version {
            owned get {
                if (_last_version != null && _last_version.length > 0)
                    return _last_version;
                if (releases.size == 0)
                    return "";

                Release? last_release = releases.get (0);
                if (last_release == null || last_release.title == null || last_release.title == "")
                    return "";

                string title = last_release.title;
                try {
                    var regex = new GLib.Regex ("(\\d+[\\d\\.\\-]+?)(?:-[sS][lL][rR]|-[hH][dD][rR])?$", GLib.RegexCompileFlags.OPTIMIZE);
                    GLib.MatchInfo match;
                    if (regex.match (title, 0, out match)) {
                        string version = match.fetch (1);
                        if (version.has_suffix ("-"))
                            version = version.substring (0, version.length - 1);
                        _last_version = version;
                        return version;
                    }
                } catch (GLib.RegexError e) {
                    warning ("Could not parse the release version: %s", e.message);
                }
                return title;
            }
        }

        public async ReleaseCatalogResult load (bool force_refresh) {
            if (static_release != null) {
                if (releases.size == 0)
                    replace_releases (single_release (static_release));
                return ReleaseCatalogResult.success (releases);
            }

            if (releases.size > 0 && !force_refresh && cache_is_fresh (last_updated))
                return ReleaseCatalogResult.success (releases);

            loading = true;
            if (!force_refresh && releases.size == 0 && cache != null) {
                var snapshot = yield cache.load ();
                if (snapshot != null && snapshot.releases.size > 0 && cached_releases_match_definition (snapshot.releases)) {
                    apply_snapshot (snapshot);
                    if (cache_is_fresh (snapshot.last_updated)) {
                        loading = false;
                        return ReleaseCatalogResult.success (releases);
                    }
                }
            }

            var page_result = yield fetch_page (1);
            if (!page_result.succeeded) {
                loading = false;
                return ReleaseCatalogResult.failure (page_result.code, releases);
            }
            var release_page = page_result.require_page ();

            // Preserve the established empty-page behaviour: browsing state
            // advances, but an existing collection is not replaced by empty
            // source output.
            page = release_page.next_page;
            has_more = release_page.has_more;
            if (release_page.releases.size == 0) {
                loading = false;
                return ReleaseCatalogResult.success (releases);
            }

            replace_releases (release_page.releases);
            last_updated = new DateTime.now_local ().format_iso8601 ();
            yield save_snapshot ();
            loading = false;
            return ReleaseCatalogResult.success (releases);
        }

        public async ReleaseCatalogResult refresh () {
            return yield load (true);
        }

        public async ReleaseCatalogResult load_more () {
            if (static_release != null) {
                return ReleaseCatalogResult.success (new Gee.LinkedList<Release> ());
            }

            loading = true;
            var page_result = yield fetch_page (page);
            if (!page_result.succeeded) {
                loading = false;
                return ReleaseCatalogResult.failure (page_result.code, releases);
            }
            var release_page = page_result.require_page ();

            foreach (var release in release_page.releases)
                releases.add (release);
            page = release_page.next_page;
            has_more = release_page.has_more;
            _last_version = null;
            releases_changed ();
            yield save_snapshot ();
            loading = false;
            return ReleaseCatalogResult.success (release_page.releases);
        }

        // This discovery path intentionally begins at upstream page one and
        // never publishes a page or alters cached browse state.
        public async ReleaseLookupResult fetch_latest_eligible_release () {
            if (static_release != null)
                return ReleaseLookupResult.found (static_release);

            var requested_page = 1;
            while (true) {
                var page_result = yield fetch_page (requested_page);
                if (!page_result.succeeded)
                    return ReleaseLookupResult.failure (page_result.code);
                var release_page = page_result.require_page ();
                if (release_page.releases.size > 0)
                    return ReleaseLookupResult.found (release_page.releases.get (0));
                if (!release_page.has_more)
                    return ReleaseLookupResult.empty ();
                requested_page = release_page.next_page;
            }
        }

        public static bool cache_timestamp_is_fresh (string last_updated, DateTime now) {
            if (last_updated == "")
                return false;

            var updated = new DateTime.from_iso8601 (last_updated, null);
            if (updated == null)
                return false;

            var age = now.difference (updated);
            return age >= 0 && age < CACHE_TTL;
        }

        private bool cache_is_fresh (string timestamp) {
            return cache_timestamp_is_fresh (timestamp, new DateTime.now_local ());
        }

        private async Tools.ReleasePageResult fetch_page (int requested_page) {
            if (definition == null || release_source == null)
                return Tools.ReleasePageResult.failure (ReturnCode.INVALID_CONFIGURATION);
            return yield release_source.fetch_page ((!) definition, requested_page, RELEASE_PAGE_SIZE);
        }

        private void apply_snapshot (ReleaseCatalogSnapshot snapshot) {
            page = snapshot.page;
            has_more = snapshot.has_more;
            last_updated = snapshot.last_updated;
            replace_releases (snapshot.releases);
        }

        private async void save_snapshot () {
            if (cache == null)
                return;
            yield cache.save (new ReleaseCatalogSnapshot (releases, page, has_more, last_updated));
        }

        private void replace_releases (Gee.Iterable<Release> values) {
            var replacement = new Gee.LinkedList<Release> ();
            foreach (var release in values)
                replacement.add (release);
            releases = replacement;
            _last_version = null;
            releases_changed ();
        }

        private Gee.LinkedList<Release> single_release (Release release) {
            var values = new Gee.LinkedList<Release> ();
            values.add (release);
            return values;
        }

        private bool cached_releases_match_definition (Gee.LinkedList<Release> cached_releases) {
            if (definition == null)
                return false;

            var configured_variants = definition.get_variants ();
            if (configured_variants.length == 0)
                return true;

            foreach (var cached_release in cached_releases) {
                var release_title = cached_release.source_tag != ""
                    ? cached_release.source_tag : cached_release.title;
                if (!ProtonPlus.Providers.Sources.CatalogReleaseBuilder.is_eligible (
                    (!) definition, release_title
                ))
                    return false;

                if (cached_release.variants.size != configured_variants.length)
                    return false;

                for (var index = 0; index < configured_variants.length; index++) {
                    var configured_variant = configured_variants[index];
                    var cached_variant = cached_release.variants.get (index);
                    if (cached_variant.name != configured_variant.name ||
                        cached_variant.format != configured_variant.format ||
                        cached_variant.is_default != configured_variant.is_default ||
                        !cached_variant.compatibility.equals (configured_variant.compatibility))
                        return false;
                }

                foreach (var cached_variant in cached_release.variants) {
                    if (cached_variant.is_default &&
                        (cached_variant.download_url == null || cached_variant.download_url == ""))
                        return false;
                    if (cached_variant.is_default &&
                        cached_release.asset.download_url != cached_variant.download_url)
                        return false;
                    if (cached_variant.is_default && !definition.single_archive_releases &&
                        !ProtonPlus.Providers.Sources.CatalogReleaseBuilder.default_variant_matches_asset (
                            definition,
                            cached_release.title,
                            cached_release.source_tag,
                            cached_release.asset
                        ))
                        return false;
                }

                for (var left_index = 0; left_index < cached_release.variants.size - 1; left_index++) {
                    var left = cached_release.variants.get (left_index);
                    if (left.download_url == null || left.download_url == "")
                        continue;
                    for (var right_index = left_index + 1; right_index < cached_release.variants.size; right_index++) {
                        var right = cached_release.variants.get (right_index);
                        if (right.download_url == null || right.download_url == "")
                            continue;
                        if (left.format != right.format && left.download_url == right.download_url)
                            return false;
                    }
                }
            }
            return true;
        }
    }
}
