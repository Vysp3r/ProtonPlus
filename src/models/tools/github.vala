namespace ProtonPlus.Models.Tools {
    public class GitHub : Basic {
        internal bool use_name_instead_of_tag_name { get; set; }
        internal string[] request_asset_filter { get; set; }
        internal string[] request_asset_exclude { get; set; }

        private Gee.LinkedList<Internal.Assets.IAsset> get_release_assets (Internal.Requests.Github.Release source_release) {
            var assets = new Gee.LinkedList<Internal.Assets.IAsset> ();

            foreach (var source_asset in source_release.assets) {
                var asset = new Internal.Assets.Github (source_asset.name, source_asset.download_url, (int) source_asset.size);
                if (asset.is_archive ()) {
                    assets.add (asset);
                }
            }

            return assets;
        }

        public GitHub () {
            get_request_type = Utils.Web.GetRequestType.GITHUB;
        }

        public override async Gee.LinkedList<Release> load_more (out ReturnCode code) {
            var _releases = new Gee.LinkedList<Release> ();

            if (source_runner == null) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            var source_releases = yield source_runner.request_releases (page, 25, out code);

            if (code != ReturnCode.RELEASES_LOADED || source_releases == null)
                return _releases;

            page++;

            foreach (var source_release_item in source_releases.list) {
                var source_release = source_release_item as Internal.Requests.Github.Release;
                if (source_release == null)
                    continue;

                string title = use_name_instead_of_tag_name ? source_release.name : source_release.tag_name;

                if (request_asset_filter != null) {
                    var excluded = false;
                    foreach (var filter in request_asset_filter) {
                        if (!title.contains (filter)) {
                            excluded = true;
                            break;
                        }
                    }

                    if (excluded)
                        continue;
                } else if (this.is_asset_exclude (title, request_asset_exclude)) {
                    continue;
                }

                var release_assets = get_release_assets (source_release);
                if (release_assets.size == 0)
                    continue;

                var asset_object = release_assets.first () as Internal.Assets.Github;

                if (asset_object != null) {
                    string description = source_release.description;
                    string page_url = source_release.page_url;
                    string release_date = source_release.created_at.format_iso8601 ();

                    var release = new Release.github (this, title, description, release_date, asset_object.download_size, asset_object.download_url, page_url);

                    foreach (var variant in create_release_variants (title, source_release.tag_name, release_assets, release.download_url)) {
                        release.variants.add (variant);
                    }

                    _releases.add (release);
                }
            }

            has_more = source_releases.list.size == 25;

            return _releases;
        }

        public void filter_variant (Variant variant, Json.Array assets) {
        }
    }
}
