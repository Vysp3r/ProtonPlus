namespace ProtonPlus.Models.Tools {
    public class GitHubAction : Basic {
        internal string url_template { get; set; }

        public GitHubAction () {
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

            var root_object = root_node.get_object ();
            if (!root_object.has_member ("workflow_runs") || root_object.get_member ("workflow_runs").get_node_type () != Json.NodeType.ARRAY) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            var root_array = root_object.get_array_member ("workflow_runs");
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

                string title = object.get_int_member ("run_number").to_string ();
                string page_url = object.get_string_member ("html_url");
                string release_date = object.get_string_member ("created_at");
                string download_url = url_template.replace ("{id}", object.get_int_member ("id").to_string ());
                string artifacts_url = object.get_string_member ("artifacts_url");

                if (object.get_string_member_with_default ("status", "") == "completed" && object.get_string_member_with_default ("conclusion", "") == "success") {
                    var release = new Releases.GitHubAction (this, title, release_date, download_url, page_url, artifacts_url);

                    _releases.add (release);
                }
            }

            has_more = root_array.get_length () == 25;

            code = ReturnCode.RELEASES_LOADED;

            return _releases;
        }
    }
}