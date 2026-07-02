namespace ProtonPlus.Models.Internal.Requests.GithubAction {

    using ProtonPlus.Models.Launchers.Runners;
    using ProtonPlus.Models.Internal.Requests;

    public class Request : Object, IRequest {
        public int page { get; set; default = 1; }
        public int limit { get; set; default = 25; }

        public async IReleases? request (IRunner runner, int page = 1, int limit = 25) {
            ReturnCode code;
            return yield request_endpoint (runner.endpoint, page, limit, out code);
        }

        public async IReleases? request_endpoint (string endpoint, int page = 1, int limit = 25, out ReturnCode code) {
            var _releases = new GithubAction.Releases ();
            string? response = null;

            code = yield ProtonPlus.Models.Internal.Requests.Github.Request.send (
                "%s?per_page=%i&page=%i".printf (endpoint, limit, page),
                out response
            );

            if (code != ReturnCode.VALID_REQUEST)
                return _releases;

            var root_node = Utils.Parser.get_node_from_json (response);
            if (root_node == null) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            var root_object = root_node.get_object ();
            if (root_object == null || !root_object.has_member ("workflow_runs")) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            var workflow_runs = root_object.get_member ("workflow_runs");
            if (workflow_runs == null || workflow_runs.get_node_type () != Json.NodeType.ARRAY) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            var root_array = root_object.get_array_member ("workflow_runs");
            if (root_array == null || root_array.get_length () == 0) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            code = ReturnCode.RELEASES_LOADED;
            return new GithubAction.Releases.from_json (root_array);
        }

        public async IReleases load_more (IRunner runner) {
            this.page++;
            return yield request (runner, this.page, this.limit);
        }
    }
}
