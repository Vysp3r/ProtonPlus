namespace ProtonPlus.Models.Runners {
    public class GitHubAction : Basic {
        internal string url_template { get; set; }

        public override async List<Models.Release> load () {
            var temp_releases = new List<Models.Release> ();

            fetch_code = Runner.FetchCodes.GOOD;

            var json = yield Utils.Web.GET (endpoint + "?per_page=25&page=" + page.to_string (), true);

            var api_limit_reached = json.contains ("https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting");
            var connection_issue = json.contains ("Temporary failure in name resolution");
            if (json == null || api_limit_reached  || connection_issue) {
                fetch_code = connection_issue ? Runner.FetchCodes.CONNECTION_ISSUE : api_limit_reached ? Runner.FetchCodes.API_LIMIT_REACHED : Runner.FetchCodes.UNKNOWN_ERROR;

                return temp_releases;
            }

            page++;

            var root_node = Utils.Parser.get_node_from_json (json);

            var root_object = root_node.get_object ();

            if (!root_object.has_member ("workflow_runs") || root_object.get_member ("workflow_runs").get_node_type () != Json.NodeType.ARRAY)
                return temp_releases;

            var runs_array = root_object.get_array_member ("workflow_runs");
            if (runs_array == null)
                return temp_releases;

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
                    temp_releases.append (release);
                }
            }

            has_more = runs_array.get_length () == 25;

            return temp_releases;
        }
    }
}