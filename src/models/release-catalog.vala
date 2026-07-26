namespace ProtonPlus.Models {
    // Owns the complete remote browse state for exactly one Tool instance.
    // Provider adapters remain stateless: they normalize a requested page and
    // this class applies the result to the catalog and its persisted snapshot.
    public class ReleaseCatalog : Object {
        public const int RELEASE_PAGE_SIZE = 25;

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

                Release? last_release = releases.size > 1 ? releases.get (1) : releases.get (0);
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

        public async Gee.LinkedList<Release> load (bool force_refresh, out ReturnCode code) {
            if (static_release != null) {
                if (releases.size == 0)
                    replace_releases (single_release (static_release));
                code = ReturnCode.RELEASES_LOADED;
                return releases;
            }

            if (releases.size > 0 && !force_refresh) {
                code = ReturnCode.RELEASES_LOADED;
                return releases;
            }

            loading = true;
            if (!force_refresh && cache != null) {
                var snapshot = yield cache.load ();
                if (snapshot != null && snapshot.releases.size > 0 && cached_releases_match_definition (snapshot.releases)) {
                    apply_snapshot (snapshot);
                    loading = false;
                    code = ReturnCode.RELEASES_LOADED;
                    return releases;
                }
            }

            var release_page = yield fetch_page (1, out code);
            if (code != ReturnCode.RELEASES_LOADED || release_page == null) {
                loading = false;
                return releases;
            }

            // Preserve the established empty-page behaviour: browsing state
            // advances, but an existing collection is not replaced by empty
            // source output.
            page = release_page.next_page;
            has_more = release_page.has_more;
            if (release_page.releases.size == 0) {
                loading = false;
                return releases;
            }

            replace_releases (release_page.releases);
            last_updated = new DateTime.now_local ().format_iso8601 ();
            yield save_snapshot ();
            loading = false;
            return releases;
        }

        public async Gee.LinkedList<Release> refresh (out ReturnCode code) {
            return yield load (true, out code);
        }

        public async Gee.LinkedList<Release> load_more (out ReturnCode code) {
            if (static_release != null) {
                code = ReturnCode.RELEASES_LOADED;
                return new Gee.LinkedList<Release> ();
            }

            loading = true;
            var release_page = yield fetch_page (page, out code);
            if (code != ReturnCode.RELEASES_LOADED || release_page == null) {
                loading = false;
                return new Gee.LinkedList<Release> ();
            }

            foreach (var release in release_page.releases)
                releases.add (release);
            page = release_page.next_page;
            has_more = release_page.has_more;
            _last_version = null;
            releases_changed ();
            yield save_snapshot ();
            loading = false;
            return release_page.releases;
        }

        // This discovery path intentionally begins at upstream page one and
        // never publishes a page or alters cached browse state.
        public async Release? fetch_latest_eligible_release (out ReturnCode code) {
            if (static_release != null) {
                code = ReturnCode.RELEASES_LOADED;
                return static_release;
            }

            var requested_page = 1;
            while (true) {
                var release_page = yield fetch_page (requested_page, out code);
                if (code != ReturnCode.RELEASES_LOADED || release_page == null)
                    return null;
                if (release_page.releases.size > 0)
                    return release_page.releases.get (0);
                if (!release_page.has_more)
                    return null;
                requested_page = release_page.next_page;
            }
        }

        private async Tools.ReleasePage? fetch_page (int requested_page, out ReturnCode code) {
            if (definition == null || release_source == null) {
                code = ReturnCode.INVALID_CONFIGURATION;
                return null;
            }
            return yield release_source.fetch_page ((!) definition, requested_page, RELEASE_PAGE_SIZE, out code);
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
                if (cached_release.variants.size != configured_variants.length)
                    return false;

                for (var index = 0; index < configured_variants.length; index++) {
                    var configured_variant = configured_variants[index];
                    var cached_variant = cached_release.variants.get (index);
                    if (cached_variant.name != configured_variant.name ||
                        cached_variant.format != configured_variant.format ||
                        cached_variant.is_default != configured_variant.is_default)
                        return false;
                }

                foreach (var cached_variant in cached_release.variants) {
                    if (cached_variant.is_default &&
                        (cached_variant.download_url == null || cached_variant.download_url == ""))
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
