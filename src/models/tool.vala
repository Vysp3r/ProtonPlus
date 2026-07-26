namespace ProtonPlus.Models {
    public abstract class Tool : Object {
        // This is a serialized runtime identity.  Its components remain
        // available through group and provider_id.
        public string id { get; internal set; default = ""; }
        public string provider_id { get; internal set; default = ""; }
        public string source_id { get; internal set; default = ""; }
        public string title { get; set; }
        public string description { get; set; }
        public Group group { get; set; }
        public bool has_more { get; set; }
        public bool legacy { get; set; }
        public string last_updated { get; set; }
        public int page { get; set; default = 1; }
        public int sort_priority { get; set; default = 1000; }
        private string? _last_version = null;

        public Gee.LinkedList<Release> releases { get; set; default = new Gee.LinkedList<Release> (); }
        public Gee.LinkedList<Variant> variants { get; set; default = new Gee.LinkedList<Variant> (); }

        construct {
            // Be explicit: some construction paths may not honor property defaults reliably.
            if (releases == null)
                releases = new Gee.LinkedList<Release> ();
            if (variants == null)
                variants = new Gee.LinkedList<Variant> ();
        }

        internal void set_identity (string provider_id, string source_id) {
            this.provider_id = provider_id;
            this.source_id = source_id;
            this.id = "%s/%s/%s".printf (group.launcher.instance_id, group.id, provider_id);
        }

        public virtual bool is_installed () {
            return false;
        }

        public virtual bool is_used () {
            return false;
        }

        public string? last_version {
            owned get {
                if (_last_version != null && _last_version.length > 0)
                    return _last_version;

                if (this.releases == null || this.releases.size == 0) {
                    return "";
                }

                Release? lastRelease = null;
                if (this.releases.size > 1) {
                    lastRelease = this.releases.get (1);
                } else {
                    lastRelease = this.releases.get (0);
                }

                if (lastRelease == null) {
                    return "";
                }

                string title = lastRelease.title;

                if (title == null || title == "") {
                    return "";
                }

                try {
                    var regex = new GLib.Regex ("(\\d+[\\d\\.\\-]+?)(?:-[sS][lL][rR]|-[hH][dD][rR])?$", GLib.RegexCompileFlags.OPTIMIZE);
                    GLib.MatchInfo match;

                    if (regex.match (title, 0, out match)) {
                        string version = match.fetch (1);

                        if (version.has_suffix ("-")) {
                            version = version.substring (0, version.length - 1);
                        }
                        this._last_version = version;
                        return version;
                    }
                } catch (GLib.RegexError e) {
                    warning ("Could not parse the release version: %s", e.message);
                }

                return title;
            }
            set {
                _last_version = value;
            }
        }

        public async Gee.LinkedList<Release> get_releases_async (bool force_fetch, out ReturnCode code) {
            if (releases == null)
                releases = new Gee.LinkedList<Release> ();

            if (releases.size > 0 && !force_fetch) {
                code = ReturnCode.RELEASES_LOADED;
            } else {
                if (!force_fetch) {
                    yield Utils.CacheManager.load_releases (this);

                    if (releases.size > 0) {
                        var needs_variant_refresh = false;
                        var basic_tool = this as Models.Tools.Basic;

                        if (basic_tool != null && variants != null && variants.size > 0) {
                            foreach (var cached_release in releases) {
                                if (cached_release.variants == null || cached_release.variants.size != variants.size) {
                                    needs_variant_refresh = true;
                                    break;
                                }

                                // A runner can change the filename pattern of a
                                // single default variant.  Keep its cached URL
                                // only when that pattern still matches.
                                for (var i = 0; i < variants.size; i++) {
                                    var configured_variant = variants.get (i);
                                    var cached_variant = cached_release.variants.get (i);

                                    if (cached_variant.name != configured_variant.name ||
                                        cached_variant.format != configured_variant.format ||
                                        cached_variant.is_default != configured_variant.is_default) {
                                        needs_variant_refresh = true;
                                        break;
                                    }
                                }

                                if (needs_variant_refresh)
                                    break;

                                var default_variant_has_url = true;
                                foreach (var cached_variant in cached_release.variants) {
                                    if (cached_variant.is_default) {
                                        default_variant_has_url = cached_variant.download_url != null && cached_variant.download_url != "";
                                        break;
                                    }
                                }

                                if (!default_variant_has_url) {
                                    needs_variant_refresh = true;
                                    break;
                                }

                                for (var i = 0; i < cached_release.variants.size - 1; i++) {
                                    var left_variant = cached_release.variants.get (i);
                                    if (left_variant.download_url == null || left_variant.download_url == "")
                                        continue;

                                    for (var j = i + 1; j < cached_release.variants.size; j++) {
                                        var right_variant = cached_release.variants.get (j);
                                        if (right_variant.download_url == null || right_variant.download_url == "")
                                            continue;

                                        if (left_variant.format != right_variant.format && left_variant.download_url == right_variant.download_url) {
                                            needs_variant_refresh = true;
                                            break;
                                        }
                                    }

                                    if (needs_variant_refresh)
                                        break;
                                }

                                if (needs_variant_refresh)
                                    break;
                            }
                        }

                        if (!needs_variant_refresh) {
                            code = ReturnCode.RELEASES_LOADED;
                            return releases;
                        }

                        // Cached releases without per-release variants are stale for variant filtering.
                        page = 1;
                    }
                } else {
                    page = 1;
                }

                var new_releases = yield load_more (out code);

                if (code != ReturnCode.RELEASES_LOADED || new_releases.size == 0)
                    return releases;

                releases.clear ();
                _last_version = null;
                foreach (var release in new_releases) {
                    releases.add (release);
                }

                last_updated = new DateTime.now_local ().format_iso8601 ();
                yield Utils.CacheManager.save_releases (this);
            }

            return releases;
        }

        // Stateful browsing entrypoint.  Basic tools implement this by
        // applying their provider-neutral ReleasePage result to page and
        // has_more; non-provider tools keep their specialized behavior.
        public abstract async Gee.LinkedList<Release> load_more (out ReturnCode code);

    }
}
