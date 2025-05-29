namespace ProtonPlus.Models.Runners {
    public abstract class GitLab : Basic {
        internal bool use_name_instead_of_tag_name { get; set; }
        internal string[] request_asset_exclude { get; set; }

        public override async List<Release> load () {
            var temp_releases = new List<Release> ();

            var json = yield Utils.Web.GET (endpoint + "?per_page=25&page=" + page ++.to_string (), false);

            if (json == null)
                return temp_releases;

            var root_node = Utils.Parser.get_node_from_json (json);

            if (root_node == null || root_node.get_node_type () != Json.NodeType.ARRAY)
                return temp_releases;

            var root_array = root_node.get_array ();
            if (root_array == null)
                return temp_releases;

            for (var i = 0; i < root_array.get_length (); i++) {
                var object = root_array.get_object_element (i);

                string title = use_name_instead_of_tag_name ? object.get_string_member ("name") : object.get_string_member ("tag_name");
                string description = object.get_string_member ("description").strip ();;
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

                var page_url_object = object.get_object_member ("_links");
                if (page_url_object == null)
                    continue;

                string page_url = page_url_object.get_string_member ("self");

                var assets_object = object.get_object_member ("assets");
                if (assets_object == null)
                    continue;

                var link_array = assets_object.get_array_member ("links");
                if (link_array == null)
                    continue;

                if (link_array.get_length () - 1 >= asset_position) {
                    var link_object = link_array.get_object_element (asset_position);

                    var download_url = link_object.get_string_member ("direct_asset_url").replace ("?ref_type=heads", "");

                    var release = new Releases.Basic.gitlab (this, title, description, release_date, download_url, page_url);

                    releases.append (release);
                    temp_releases.append (release);
                }
            }

            return temp_releases;
        }
    }
}