namespace ProtonPlus.Models.Tools {
    public class GitHub : Basic {
        internal bool use_name_instead_of_tag_name { get; set; }
        internal string[] request_asset_filter { get; set; }
        internal string[] request_asset_exclude { get; set; }

        public GitHub () {
            get_request_type = Utils.Web.GetRequestType.GITHUB;
        }

        public override async Gee.LinkedList<Release> load_more (out ReturnCode code) {
            var _releases = new Gee.LinkedList<Release> ();

            string? response;

            code = yield Utils.Web.get_request ("%s?per_page=25&page=%i".printf (endpoint, page), get_request_type, out response);

            if (code != ReturnCode.VALID_REQUEST)
                return _releases;

            page++;

            var root_node = Utils.Parser.get_node_from_json (response);
            if (root_node == null) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            if (root_node.get_node_type () != Json.NodeType.ARRAY) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            var root_array = root_node.get_array ();
            if (root_array == null) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            if (root_array.get_length () == 0) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            for (var i = 0; i < root_array.get_length (); i++) {
                var object = root_array.get_object_element (i);

                var asset_array = object.get_array_member ("assets");
                if (asset_array == null)
                    continue;

                string title = use_name_instead_of_tag_name ? object.get_string_member ("name") : object.get_string_member ("tag_name");

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

                var assetCollection = Internal.Assets.GithubCollection.from_json (asset_array);
                Internal.Assets.Github asset_object = (Internal.Assets.Github) assetCollection.first ();

                if (asset_object != null) {
                    string description = object.get_string_member ("body").strip ();
                    string page_url = object.get_string_member ("html_url");
                    string release_date = object.get_string_member ("created_at");

                    var release = new Release.github (this, title, description, release_date, asset_object.download_size, asset_object.download_url, page_url);

                    //update_variants (release, asset_array);
                    _releases.add (release);
                }
            }

            has_more = root_array.get_length () == 25;

            code = ReturnCode.RELEASES_LOADED;

            return _releases;
        }

        public void update_variants (Release release, Json.Array? assets) {
            foreach (var variant in this.variants) {
                var v = variant;

                release.variants.add (v);
            }
        }

        public void filter_variant (Variant variant, Json.Array assets) {
        }
    }
}
