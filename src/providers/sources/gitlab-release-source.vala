namespace ProtonPlus.Providers.Sources {
    using Gee;

    public class GitLabReleaseSource : Object, ReleaseSource {
        public async Models.Tools.ReleasePageResult fetch_page (
            Models.Providers.ProviderDefinition definition,
            int requested_page,
            int limit
        ) {
            var response = yield Utils.Web.get_request (
                "%s?per_page=%i&page=%i".printf (definition.endpoint, limit, requested_page),
                Utils.Web.GetRequestType.GITLAB
            );
            if (response.code != ReturnCode.VALID_REQUEST)
                return Models.Tools.ReleasePageResult.failure (response.code);

            return parse_response (definition, response.body, requested_page, limit);
        }

        public Models.Tools.ReleasePageResult parse_response (
            Models.Providers.ProviderDefinition definition,
            string response_body,
            int requested_page,
            int limit
        ) {
            var root_array = ReleaseSourceSupport.parse_array (response_body);
            if (root_array == null)
                return Models.Tools.ReleasePageResult.failure (ReturnCode.INVALID_DATA);

            var releases = new LinkedList<Models.Release> ();
            for (var index = 0; index < root_array.get_length (); index++) {
                var object = root_array.get_object_element (index);
                if (object == null)
                    continue;

                var tag_name = object.get_string_member_with_default ("tag_name", "");
                if (!CatalogReleaseBuilder.is_eligible (definition, tag_name))
                    continue;

                var assets = parse_assets (object);
                if (assets.size == 0)
                    continue;

                var variants = CatalogReleaseBuilder.create_variants (
                    definition, tag_name, tag_name, assets
                );
                var primary_asset = CatalogReleaseBuilder.select_default_asset (assets, variants);
                if (primary_asset == null)
                    continue;

                var links = object.get_object_member ("_links");
                var release = new Models.Release (
                    tag_name,
                    object.get_string_member_with_default ("description", "").strip (),
                    ReleaseSourceSupport.get_iso8601_date (object, "created_at"),
                    primary_asset,
                    links != null ? links.get_string_member_with_default ("self", "") : "",
                    primary_asset.download_size,
                    object.has_member ("id") && object.get_int_member ("id") > 0 ? object.get_int_member ("id").to_string () : "",
                    tag_name
                );
                ReleaseSourceSupport.add_variants (release, variants);
                releases.add (release);
            }

            return Models.Tools.ReleasePageResult.success (
                new Models.Tools.ReleasePage (releases, requested_page + 1, root_array.get_length () == limit)
            );
        }

        private LinkedList<Models.Assets.Asset> parse_assets (Json.Object release) {
            var assets = new LinkedList<Models.Assets.Asset> ();
            var container = release.get_object_member ("assets");
            var array = container != null ? container.get_array_member ("links") : null;
            if (array == null)
                return assets;

            for (var index = 0; index < array.get_length (); index++) {
                var object = array.get_object_element (index);
                if (object == null)
                    continue;
                var name = object.get_string_member_with_default ("name", "");
                var download_url = object.get_string_member_with_default (
                    "direct_asset_url", ""
                ).replace ("?ref_type=heads", "");
                if (name == "" || download_url == "" || !Models.Assets.Asset.is_archive_name (name))
                    continue;

                assets.add (new Models.Assets.Asset (
                    name,
                    download_url,
                    object.has_member ("size") ? object.get_int_member ("size") : 0,
                    object.get_string_member_with_default ("digest", "")
                ));
            }
            return assets;
        }
    }
}
