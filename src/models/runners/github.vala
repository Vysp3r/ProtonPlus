namespace ProtonPlus.Models.Runners {
    public class GitHub : Basic {
        internal bool use_name_instead_of_tag_name { get; set; }
        internal string[] request_asset_filter { get; set; }
        internal string[] request_asset_exclude { get; set; }

        public GitHub () {
            get_type = Utils.Web.GetType.GITHUB;
        }

        public override async ReturnCode load (out List<Models.Release> releases) {
            releases = new List<Release> ();

            string? response;

            var code = yield Utils.Web.get_request ("%s?per_page=25&page=%i".printf (endpoint, page), get_type, out response);

            if (code != ReturnCode.VALID_REQUEST)
                return code;

            page++;

            var root_node = Utils.Parser.get_node_from_json (response);

            if (root_node == null)
                return ReturnCode.UNKNOWN_ERROR;

            if (root_node.get_node_type () != Json.NodeType.ARRAY)
                return ReturnCode.UNKNOWN_ERROR;

            var root_array = root_node.get_array ();
            if (root_array == null)
                return ReturnCode.UNKNOWN_ERROR;

            for (var i = 0; i < root_array.get_length (); i++) {
                var object = root_array.get_object_element (i);

                var asset_array = object.get_array_member ("assets");
                if (asset_array == null)
                    continue;

                string title = use_name_instead_of_tag_name ? object.get_string_member ("name") : object.get_string_member ("tag_name");
                string description = object.get_string_member ("body").strip ();
                string page_url = object.get_string_member ("html_url");
                string release_date = object.get_string_member ("created_at");

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
                } else if (request_asset_exclude != null) {
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

                var real_asset_position = asset_position;

                if (asset_position_time_condition != null) {
                    var asset_position_time_condition_split = asset_position_time_condition.split ("|");

                    if (asset_position_time_condition_split.length == 2) {
                        var condition_time = new DateTime.from_iso8601 (asset_position_time_condition_split[0], null);

                        var release_time = new DateTime.from_iso8601 (release_date, null);

                        var result = release_time.compare (condition_time);
                        if (result <= 0) {
                            int number = 0;
                            var parsed = int.try_parse (asset_position_time_condition_split[1], out number);
                            if (!parsed)
                                continue;

                            real_asset_position = number;
                        }
                    }
                }

                if (asset_position_hwcaps_condition) {
                    for (int y = 0; y < asset_array.get_length (); y++) {
                        var asset_object = asset_array.get_object_element (y);

                        if (asset_object.get_string_member ("name").contains ("%s.tar.xz".printf (Globals.HWCAPS.nth_data (0)))) {
                            real_asset_position = y;

                            break;
                        }
                    }
                }

                if (asset_array.get_length () - 1 >= real_asset_position) {
                    var asset_object = asset_array.get_object_element (real_asset_position);

                    string download_url = asset_object.get_string_member ("browser_download_url");
                    int64 download_size = asset_object.get_int_member ("size");

                    var release = new Releases.Basic.github (this, title, description, release_date, download_size, download_url, page_url);

                    releases.append (release);
                    this.releases.append (release);
                }
            }

            has_more = root_array.get_length () == 25;
            
            return ReturnCode.RELEASES_LOADED;
        }
    }
}
