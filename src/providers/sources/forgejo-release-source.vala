namespace ProtonPlus.Providers.Sources {
    using Gee;

    public class ForgejoReleaseSource : Object, ReleaseSource {
        public async Models.Tools.ReleasePageResult fetch_page (
            Models.Providers.ProviderDefinition definition,
            int requested_page,
            int limit
        ) {
            var response = yield Utils.Web.get_request (
                "%s?limit=%i&page=%i".printf (definition.endpoint, limit, requested_page),
                Utils.Web.GetRequestType.FORGEJO
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
            Json.Node? root_node;
            try {
                root_node = Json.from_string (response_body);
            } catch (Error e) {
                return Models.Tools.ReleasePageResult.failure (ReturnCode.INVALID_DATA);
            }
            if (root_node == null || root_node.get_node_type () != Json.NodeType.ARRAY) {
                return Models.Tools.ReleasePageResult.failure (ReturnCode.INVALID_DATA);
            }

            var root_array = root_node.get_array ();
            if (root_array == null) {
                return Models.Tools.ReleasePageResult.failure (ReturnCode.INVALID_DATA);
            }

            var releases = new LinkedList<Models.Release> ();
            for (var index = 0; index < root_array.get_length (); index++) {
                var object = root_array.get_object_element (index);
                if (object == null)
                    continue;

                var tag_name = object.get_string_member_with_default ("tag_name", "");
                if (!CatalogReleaseBuilder.is_eligible (definition, tag_name))
                    continue;

                var assets = parse_assets (object);
                var first_asset = assets.first ();
                if (first_asset == null)
                    continue;

                var variants = CatalogReleaseBuilder.create_variants (
                    definition, tag_name, tag_name, assets, first_asset.download_url
                );
                var primary_asset = CatalogReleaseBuilder.select_default_asset (assets, variants);
                if (primary_asset == null)
                    continue;

                var github_asset = primary_asset as Models.Assets.GitHub;
                var release = new Models.Release (
                    tag_name,
                    object.get_string_member_with_default ("body", "").strip (),
                    get_date (object, "created_at"),
                    primary_asset,
                    object.get_string_member_with_default ("html_url", ""),
                    github_asset != null ? github_asset.download_size : 0,
                    object.has_member ("id") && object.get_int_member ("id") > 0 ? object.get_int_member ("id").to_string () : "",
                    tag_name
                );
                add_variants (release, variants);
                releases.add (release);
            }

            return Models.Tools.ReleasePageResult.success (
                new Models.Tools.ReleasePage (releases, requested_page + 1, root_array.get_length () == limit)
            );
        }

        private LinkedList<Models.Assets.Asset> parse_assets (Json.Object release) {
            var assets = new LinkedList<Models.Assets.Asset> ();
            var array = release.get_array_member ("assets");
            if (array == null)
                return assets;

            for (var index = 0; index < array.get_length (); index++) {
                var object = array.get_object_element (index);
                if (object == null)
                    continue;
                var asset = new Models.Assets.GitHub (
                    object.get_string_member_with_default ("name", ""),
                    object.get_string_member_with_default ("browser_download_url", ""),
                    object.has_member ("size") ? (int) object.get_int_member ("size") : 0
                );
                if (asset.is_archive ())
                    assets.add (asset);
            }
            return assets;
        }

        private static string get_date (Json.Object object, string member) {
            var parsed = new DateTime.from_iso8601 (object.get_string_member_with_default (member, ""), null);
            return (parsed ?? new DateTime.now_utc ()).format_iso8601 ();
        }

        private static void add_variants (Models.Release release, LinkedList<Models.Variant> variants) {
            foreach (var variant in variants)
                release.variants.add (variant);
        }
    }
}
