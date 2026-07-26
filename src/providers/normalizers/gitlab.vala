namespace ProtonPlus.Providers.Normalizers {
    using ProtonPlus.Models;
    using ProtonPlus.Models.Tools;
    public class GitLab : Basic {
        internal bool use_name_instead_of_tag_name { get; set; }
        internal string[] request_asset_exclude { get; set; }

        public GitLab () {
            get_request_type = Utils.Web.GetRequestType.GITLAB;
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
                var source_release = source_release_item as ProtonPlus.Providers.Sources.GitLab.Release;
                if (source_release == null)
                    continue;

                string title = use_name_instead_of_tag_name ? source_release.name : source_release.tag_name;

                if (this.is_asset_exclude (title, request_asset_exclude)) {
                    continue;
                }

                var release_assets = new Gee.LinkedList<ProtonPlus.Models.Assets.IAsset> ();
                foreach (var source_asset in source_release.assets) {
                    var asset = new ProtonPlus.Models.Assets.Asset (source_asset.name, source_asset.download_url);
                    if (asset.is_archive ()) {
                        release_assets.add (asset);
                    }
                }

                if (release_assets.size == 0)
                    continue;

                var first_asset = release_assets.get (0);
                if (first_asset == null)
                    continue;

                var release_variants = create_release_variants (title, source_release.tag_name, release_assets, first_asset.download_url);
                var primary_download_url = get_default_variant_download_url (release_variants, first_asset.download_url);
                if (primary_download_url == null || primary_download_url == "")
                    continue;

                ProtonPlus.Models.Assets.Asset? primary_asset = null;
                foreach (var release_asset in release_assets) {
                    if (release_asset.download_url == primary_download_url) {
                        primary_asset = release_asset as ProtonPlus.Models.Assets.Asset;
                        break;
                    }
                }
                if (primary_asset == null)
                    continue;

                var release = new Release.gitlab (
                    this,
                    title,
                    source_release.description,
                    source_release.created_at.format_iso8601 (),
                    primary_asset,
                    source_release.page_url,
                    source_release.id > 0 ? source_release.id.to_string () : "",
                    source_release.tag_name
                );
                foreach (var variant in release_variants) {
                    release.variants.add (variant);
                }

                _releases.add (release);
            }

            return new ReleasePage (
                _releases,
                requested_page + 1,
                source_releases.list.size == RELEASE_PAGE_SIZE
            );
        }
    }
}
