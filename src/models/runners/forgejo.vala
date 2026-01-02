namespace ProtonPlus.Models.Runners {
    public class Forgejo : Basic {
        public Forgejo () {
            get_type = Utils.Web.GetType.FORGEJO;
        }

        public override async ReturnCode load (out List<Models.Release> releases) {
            releases = new List<Release> ();

            string? response;

            var code = yield Utils.Web.get_request ("%s?limit=25&page=%i".printf (endpoint, page), get_type, out response);

            if (code != ReturnCode.VALID_REQUEST)
                return code;
                
            page++;

            var root_node = Utils.Parser.get_node_from_json (response);

            if (root_node == null || root_node.get_node_type () != Json.NodeType.ARRAY)
                return ReturnCode.UNKNOWN_ERROR;

            var root_array = root_node.get_array ();
            if (root_array == null)
                return ReturnCode.UNKNOWN_ERROR;

            for (var i = 0; i < root_array.get_length (); i++) {
                var object = root_array.get_object_element (i);

                string title = object.get_string_member ("tag_name");
                string description = object.get_string_member ("body").strip ();;
                string release_date = object.get_string_member ("created_at");

                string page_url = object.get_string_member ("html_url");

                var assets_array = object.get_array_member ("assets");
                if (assets_array == null)
                    continue;

                if (assets_array.get_length () - 1 >= asset_position) {
                    var link_object = assets_array.get_object_element (asset_position);

                    var download_url = link_object.get_string_member ("browser_download_url");
                    var download_size = link_object.get_int_member ("size");

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