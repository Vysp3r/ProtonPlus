namespace ProtonPlus.Models.Tools {
    public class Forgejo : Basic {
        public Forgejo () {
            get_request_type = Utils.Web.GetRequestType.FORGEJO;
        }

        private Gee.LinkedList<Internal.Assets.IAsset> get_release_assets (Internal.Requests.Forgejo.Release source_release) {
            var assets = new Gee.LinkedList<Internal.Assets.IAsset> ();

            foreach (var source_asset in source_release.assets) {
                var asset = new Internal.Assets.Github (source_asset.name, source_asset.download_url, (int) source_asset.size);
                if (asset.is_archive ()) {
                    assets.add (asset);
                }
            }

            return assets;
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
                var source_release = source_release_item as Internal.Requests.Forgejo.Release;
                if (source_release == null)
                    continue;

                string title = source_release.tag_name;
                var release_assets = get_release_assets (source_release);

                if (release_assets.size == 0)
                    continue;

                var first_asset = release_assets.get (0) as Internal.Assets.Github;
                if (first_asset == null)
                    continue;

                var release_variants = create_release_variants (title, source_release.tag_name, release_assets, first_asset.download_url);
                var primary_download_url = get_default_variant_download_url (release_variants, first_asset.download_url);
                if (primary_download_url == null || primary_download_url == "")
                    continue;

                Internal.Assets.Github? primary_asset = first_asset;
                foreach (var release_asset in release_assets) {
                    var github_asset = release_asset as Internal.Assets.Github;
                    if (github_asset == null)
                        continue;

                    if (github_asset.download_url == primary_download_url) {
                        primary_asset = github_asset;
                        break;
                    }
                }

                var release = new Release.github (this, title, source_release.description, source_release.created_at.format_iso8601 (), primary_asset.download_size, primary_download_url, source_release.page_url);
                foreach (var variant in release_variants) {
                    release.variants.add (variant);
                }

                _releases.add (release);
            }

            has_more = source_releases.list.size == 25;

            return _releases;
        }
    }
}
