namespace ProtonPlus.Providers.Sources {
    using Gee;

    public class GitHubActionsReleaseSource : Object, ReleaseSource {
        public async Models.Tools.ReleasePage? fetch_page (
            Models.Providers.ProviderDefinition definition,
            int requested_page,
            int limit,
            out ReturnCode code
        ) {
            var releases = new LinkedList<Models.Release> ();
            var current_page = requested_page;
            var reached_end = false;

            while (releases.size == 0 && !reached_end) {
                var response = yield request_page (definition.endpoint, current_page, limit);
                if (response.code != ReturnCode.VALID_REQUEST) {
                    code = response.code;
                    return null;
                }

                var page = parse_response (definition, response.body, current_page, limit, out code);
                if (page == null)
                    return null;

                releases.add_all (page.releases);
                reached_end = !page.has_more;
                current_page = page.next_page;
            }

            code = ReturnCode.RELEASES_LOADED;
            return new Models.Tools.ReleasePage (releases, current_page, !reached_end);
        }

        public Models.Tools.ReleasePage? parse_response (
            Models.Providers.ProviderDefinition definition,
            string response_body,
            int requested_page,
            int limit,
            out ReturnCode code
        ) {
            Json.Node? root_node;
            try {
                root_node = Json.from_string (response_body);
            } catch (Error e) {
                code = ReturnCode.INVALID_DATA;
                return null;
            }
            if (root_node == null || root_node.get_node_type () != Json.NodeType.OBJECT) {
                code = ReturnCode.INVALID_DATA;
                return null;
            }

            var root = root_node.get_object ();
            var runs = root != null ? root.get_array_member ("workflow_runs") : null;
            if (runs == null) {
                code = ReturnCode.INVALID_DATA;
                return null;
            }

            var releases = new LinkedList<Models.Release> ();
            for (var index = 0; index < runs.get_length (); index++) {
                var run = runs.get_object_element (index);
                if (run == null || run.get_string_member_with_default ("status", "") != "completed" ||
                    run.get_string_member_with_default ("conclusion", "") != "success")
                    continue;

                var id = run.has_member ("id") ? run.get_int_member ("id") : 0;
                var download_url = definition.url_template.replace ("{id}", id.to_string ());
                var release = new Models.Release (
                    run.has_member ("run_number") ? run.get_int_member ("run_number").to_string () : "",
                    "",
                    get_date (run, "created_at"),
                    Models.Assets.Asset.from_download_url (download_url),
                    run.get_string_member_with_default ("html_url", ""),
                    0,
                    id > 0 ? id.to_string () : "",
                    "",
                    Models.Release.Kind.GITHUB_ACTION,
                    run.get_string_member_with_default ("artifacts_url", "")
                );
                releases.add (release);
            }

            code = ReturnCode.RELEASES_LOADED;
            return new Models.Tools.ReleasePage (releases, requested_page + 1, runs.get_length () == limit);
        }

        // Kept protected so the source's cross-page filtering can be tested
        // without a network request; production still owns HTTP here.
        protected virtual async Utils.Web.Response request_page (string endpoint, int page, int limit) {
            return yield Utils.Web.get_request (
                "%s?per_page=%i&page=%i".printf (endpoint, limit, page),
                Utils.Web.GetRequestType.GITHUB
            );
        }

        private static string get_date (Json.Object object, string member) {
            var parsed = new DateTime.from_iso8601 (object.get_string_member_with_default (member, ""), null);
            return (parsed ?? new DateTime.now_utc ()).format_iso8601 ();
        }
    }
}
