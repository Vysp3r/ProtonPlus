namespace ProtonPlus.Models.Runners {
    public class GitHubAction : Basic {
        internal string url_template { get; set; }

        public GitHubAction () {
            get_type = Utils.Web.GetType.GITHUB;
        }

        public override async ReturnCode load (out List<Models.Release> releases) {
            releases = new List<Models.Release> ();

            string? response;

            var code = yield Utils.Web.get_request ("%s?per_page=25&page=%i".printf (endpoint, page), get_type, out response);

            if (code != ReturnCode.VALID_REQUEST)
                return code;

            page++;

            var root_node = Utils.Parser.get_node_from_json (response);

            var root_object = root_node.get_object ();

            if (!root_object.has_member ("workflow_runs") || root_object.get_member ("workflow_runs").get_node_type () != Json.NodeType.ARRAY)
                return ReturnCode.UNKNOWN_ERROR;

            var runs_array = root_object.get_array_member ("workflow_runs");
            if (runs_array == null)
                return ReturnCode.UNKNOWN_ERROR;

            for (var i = 0; i < runs_array.get_length (); i++) {
                var object = runs_array.get_object_element (i);
                
                string title = object.get_int_member ("run_number").to_string ();
                string page_url = object.get_string_member ("html_url");
                string release_date = object.get_string_member ("created_at").split ("T")[0];
                string download_url = url_template.replace ("{id}", object.get_int_member ("id").to_string ());
                string artifacts_url = object.get_string_member ("artifacts_url");

                if (object.get_string_member_with_default ("status", "") == "completed" && object.get_string_member_with_default ("conclusion", "") == "success") {
                    var release = new Releases.GitHubAction (this, title, release_date, download_url, page_url, artifacts_url);

                    releases.append (release);
                    this.releases.append (release);
                }
            }

            has_more = runs_array.get_length () == 25;

            return ReturnCode.RELEASES_LOADED;
        }
    }
}