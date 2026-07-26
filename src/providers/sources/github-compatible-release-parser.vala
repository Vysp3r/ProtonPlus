namespace ProtonPlus.Providers.Sources {
    using Gee;

    internal enum GitHubCompatiblePrimaryAssetPolicy {
        FIRST_ARCHIVE,
        DEFAULT_VARIANT_ASSET,
    }

    internal class GitHubCompatibleReleaseParser : Object {
        public static Models.Tools.ReleasePageResult parse (
            Models.Providers.ProviderDefinition definition,
            string response_body,
            int requested_page,
            int limit,
            GitHubCompatiblePrimaryAssetPolicy primary_asset_policy
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
                var first_asset = assets.first ();
                if (first_asset == null)
                    continue;

                var variants = CatalogReleaseBuilder.create_variants (
                    definition, tag_name, tag_name, assets, first_asset.download_url
                );
                Models.Assets.Asset? primary_asset = null;
                switch (primary_asset_policy) {
                case GitHubCompatiblePrimaryAssetPolicy.FIRST_ARCHIVE:
                    primary_asset = first_asset;
                    break;
                case GitHubCompatiblePrimaryAssetPolicy.DEFAULT_VARIANT_ASSET:
                    primary_asset = CatalogReleaseBuilder.select_default_asset (assets, variants);
                    break;
                default:
                    assert_not_reached ();
                }
                if (primary_asset == null)
                    continue;

                var release = new Models.Release (
                    tag_name,
                    object.get_string_member_with_default ("body", "").strip (),
                    ReleaseSourceSupport.get_iso8601_date (object, "created_at"),
                    primary_asset,
                    object.get_string_member_with_default ("html_url", ""),
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

        private static LinkedList<Models.Assets.Asset> parse_assets (Json.Object release) {
            var assets = new LinkedList<Models.Assets.Asset> ();
            var array = release.get_array_member ("assets");
            if (array == null)
                return assets;

            for (var index = 0; index < array.get_length (); index++) {
                var object = array.get_object_element (index);
                if (object == null)
                    continue;
                var asset = new Models.Assets.Asset (
                    object.get_string_member_with_default ("name", ""),
                    object.get_string_member_with_default ("browser_download_url", ""),
                    object.has_member ("size") ? object.get_int_member ("size") : 0
                );
                if (asset.is_archive ())
                    assets.add (asset);
            }
            return assets;
        }
    }
}
