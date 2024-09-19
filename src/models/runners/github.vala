namespace ProtonPlus.Models.Runners {
    public abstract class GitHub : Basic {
        internal int old_asset_location { get; set; } // TODO Describe this
        internal int old_asset_position { get; set; } // TODO Describe this
        internal bool use_name_instead_of_tag_name { get; set; } // TODO Describe this
        internal string[] request_asset_exclude { get; set; } // TODO Describe this

        public override async List<Models.Release> load () {
            var temp_releases = new List<Models.Release> ();

            var json = yield Utils.Web.GET (endpoint + "?per_page=25&page=" + page ++.to_string (), false);

            if (json == null || json.contains ("https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"))
                return temp_releases;

            var root_node = Utils.Parser.get_node_from_json (json);

            if (root_node == null)
                return temp_releases;

            if (root_node.get_node_type () != Json.NodeType.ARRAY)
                return temp_releases;

            var root_array = root_node.get_array ();
            if (root_array == null)
                return temp_releases;

            for (var i = 0; i < root_array.get_length (); i++) {
                var object = root_array.get_object_element (i);

                var asset_array = object.get_array_member ("assets");
                if (asset_array == null)
                    continue;

                string title = use_name_instead_of_tag_name ? object.get_string_member ("name") : object.get_string_member ("tag_name");
                string description = object.get_string_member ("body");
                string page_url = object.get_string_member ("html_url");
                string release_date = object.get_string_member ("created_at").split ("T")[0];

                if (request_asset_exclude != null) {
                    var excluded = false;

                    foreach (var excluded_asset in request_asset_exclude) {
                        if (title.contains (excluded_asset)) {
                            excluded = true;
                            break;
                        }
                    }

                    if (excluded)
                        continue;
                }

                int pos = releases.length () >= old_asset_location ? old_asset_position : asset_position;

                if (asset_array.get_length () - 1 >= pos) {
                    var asset_object = asset_array.get_object_element (pos);

                    string download_url = asset_object.get_string_member ("browser_download_url");
                    int64 download_size = asset_object.get_int_member ("size");

                    var release = new Releases.Basic.github (this, title, description, release_date, download_size, download_url, page_url);

                    releases.append (release);
                    temp_releases.append (release);
                }
            }

            return temp_releases;
        }
    }
}