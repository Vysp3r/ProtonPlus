namespace ProtonPlus.Providers.Sources {
    using Gee;

    public class GitHubActionsReleaseSource : Object, ReleaseSource {
        public async Models.Tools.ReleasePageResult fetch_page (
            Models.Providers.ProviderDefinition definition,
            int requested_page,
            int limit
        ) {
            var releases = new LinkedList<Models.Release> ();
            var current_page = requested_page;
            var reached_end = false;

            while (releases.size == 0 && !reached_end) {
                var response = yield request_page (definition.endpoint, current_page, limit);
                if (response.code != ReturnCode.VALID_REQUEST)
                    return Models.Tools.ReleasePageResult.failure (response.code);

                var page_result = parse_response (definition, response.body, current_page, limit);
                if (!page_result.succeeded)
                    return page_result;
                var page = page_result.require_page ();

                releases.add_all (page.releases);
                reached_end = !page.has_more;
                current_page = page.next_page;
            }

            return Models.Tools.ReleasePageResult.success (
                new Models.Tools.ReleasePage (releases, current_page, !reached_end)
            );
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
            if (root_node == null || root_node.get_node_type () != Json.NodeType.OBJECT) {
                return Models.Tools.ReleasePageResult.failure (ReturnCode.INVALID_DATA);
            }

            var root = root_node.get_object ();
            var runs = root != null ? root.get_array_member ("workflow_runs") : null;
            if (runs == null) {
                return Models.Tools.ReleasePageResult.failure (ReturnCode.INVALID_DATA);
            }

            var releases = new LinkedList<Models.Release> ();
            for (var index = 0; index < runs.get_length (); index++) {
                var run = runs.get_object_element (index);
                if (run == null || run.get_string_member_with_default ("status", "") != "completed" ||
                    run.get_string_member_with_default ("conclusion", "") != "success")
                    continue;

                var id = run.has_member ("id") ? run.get_int_member ("id") : 0;
                var download_url = definition.url_template.replace ("{id}", id.to_string ());
                var asset = Models.Assets.Asset.from_download_url (download_url);
                var release = new Models.Release (
                    run.has_member ("run_number") ? run.get_int_member ("run_number").to_string () : "",
                    "",
                    ReleaseSourceSupport.get_iso8601_date (run, "created_at"),
                    asset,
                    run.get_string_member_with_default ("html_url", ""),
                    asset.download_size,
                    id > 0 ? id.to_string () : "",
                    "",
                    Models.Release.Kind.GITHUB_ACTION,
                    run.get_string_member_with_default ("artifacts_url", "")
                );
                releases.add (release);
            }

            return Models.Tools.ReleasePageResult.success (
                new Models.Tools.ReleasePage (releases, requested_page + 1, runs.get_length () == limit)
            );
        }

        // Kept protected so the source's cross-page filtering can be tested
        // without a network request; production still owns HTTP here.
        protected virtual async Utils.Web.Response request_page (string endpoint, int page, int limit) {
            return yield Utils.Web.get_request (
                "%s?per_page=%i&page=%i".printf (endpoint, limit, page),
                Utils.Web.GetRequestType.GITHUB
            );
        }
    }
}
