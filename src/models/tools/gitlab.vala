namespace ProtonPlus.Models.Tools {
    public class GitLab : Basic {
        internal bool use_name_instead_of_tag_name { get; set; }
        internal string[] request_asset_exclude { get; set; }

        public GitLab () {
            get_request_type = Utils.Web.GetRequestType.GITLAB;
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
                var source_release = source_release_item as Internal.Requests.Gitlab.Release;
                if (source_release == null)
                    continue;

                string title = use_name_instead_of_tag_name ? source_release.name : source_release.tag_name;

                if (this.is_asset_exclude (title, request_asset_exclude)) {
                    continue;
                }

                var release_assets = new Gee.LinkedList<Internal.Assets.IAsset> ();
                foreach (var source_asset in source_release.assets) {
                    release_assets.add (new Internal.Assets.Asset (source_asset.name, source_asset.download_url));
                }

                if (release_assets.size - 1 >= asset_position) {
                    var asset = release_assets.get (asset_position);
                    if (asset == null)
                        continue;

                    var release = new Release.gitlab (
                        this,
                        title,
                        source_release.description,
                        source_release.created_at.format_iso8601 (),
                        asset.download_url,
                        source_release.page_url
                    );
                    foreach (var variant in create_release_variants (title, source_release.tag_name, release_assets, asset.download_url)) {
                        release.variants.add (variant);
                    }

                    _releases.add (release);
                }
            }

            has_more = source_releases.list.size == 25;

            return _releases;
        }
    }
}
