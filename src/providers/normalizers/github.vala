namespace ProtonPlus.Providers.Normalizers {
    using ProtonPlus.Models;
    using ProtonPlus.Models.Tools;
    public class GitHub : Basic {
        internal bool use_name_instead_of_tag_name { get; set; }
        internal string[] request_asset_filter { get; set; }
        internal string[] request_asset_exclude { get; set; }

        private Gee.LinkedList<ProtonPlus.Models.Assets.IAsset> get_release_assets (ProtonPlus.Providers.Sources.GitHub.Release source_release) {
            var assets = new Gee.LinkedList<ProtonPlus.Models.Assets.IAsset> ();

            foreach (var source_asset in source_release.assets) {
                var asset = new ProtonPlus.Models.Assets.GitHub (source_asset.name, source_asset.download_url, (int) source_asset.size);
                if (asset.is_archive ()) {
                    assets.add (asset);
                }
            }

            return assets;
        }

        public GitHub () {
            get_request_type = Utils.Web.GetRequestType.GITHUB;
        }

        public override async ReleasePage? fetch_release_page (int requested_page, out ReturnCode code) {
            var _releases = new Gee.LinkedList<Release> ();

            if (source_runner == null) {
                code = ReturnCode.INVALID_CONFIGURATION;
                return null;
            }

            var source_releases = yield source_runner.request_releases (requested_page, RELEASE_PAGE_SIZE, out code);

            if (code != ReturnCode.RELEASES_LOADED || source_releases == null)
                return null;

            foreach (var source_release_item in source_releases.list) {
                var source_release = source_release_item as ProtonPlus.Providers.Sources.GitHub.Release;
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

                var asset_object = release_assets.first () as ProtonPlus.Models.Assets.GitHub;

                if (asset_object != null) {
                    string description = source_release.description;
                    string page_url = source_release.page_url;
                    string release_date = source_release.created_at.format_iso8601 ();

                    var release = new Release.github (
                        this,
                        title,
                        description,
                        release_date,
                        asset_object.download_size,
                        asset_object,
                        page_url,
                        source_release.id > 0 ? source_release.id.to_string () : "",
                        source_release.tag_name
                    );

                    foreach (var variant in create_release_variants (title, source_release.tag_name, release_assets, release.asset.download_url)) {
                        release.variants.add (variant);
                    }

                    _releases.add (release);
                }
            }

            return new ReleasePage (
                _releases,
                requested_page + 1,
                source_releases.list.size == RELEASE_PAGE_SIZE
            );
        }
    }
}
