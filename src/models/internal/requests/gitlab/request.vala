namespace ProtonPlus.Models.Internal.Requests.Gitlab {

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
            var _releases = new Gitlab.Releases ();
            string? response = null;

            code = yield send (
                "%s?per_page=%i&page=%i".printf (endpoint, limit, page),
                out response);

            if (code != ReturnCode.VALID_REQUEST)
                return _releases;

            var root_node = Utils.Parser.get_node_from_json (response);
            if (root_node == null) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            if (root_node.get_node_type () != Json.NodeType.ARRAY) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            var root_array = root_node.get_array ();
            if (root_array == null) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            if (root_array.get_length () == 0) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            code = ReturnCode.RELEASES_LOADED;
            return new Gitlab.Releases.from_json (root_array);
        }

        public async IReleases load_more (IRunner runner) {
            this.page++;
            return yield request (runner, this.page, this.limit);
        }

        public static async ReturnCode send (string uri, out string? response) {
            response = null;
            try {
                var message = new Soup.Message ("GET", uri);

                if (Globals.SETTINGS != null) {
                    var key = Globals.SETTINGS.get_string ("gitlab-api-key");
                    if (key.length > 0)
                        message.request_headers.append ("Authorization", "Bearer %s".printf (key));
                }

                Bytes bytes = yield ProtonPlus.Utils.Web.get_session ().send_and_read_async (message, Priority.DEFAULT, null);

                unowned uint8[] data = bytes.get_data ();
                response = (string) (data);

                if (response == null)
                    return ReturnCode.UNKNOWN_ERROR;

                if (message.status_code == 403 || message.status_code == 429)
                    return ReturnCode.API_LIMIT_REACHED;
                if (response.contains ("401 Unauthorized"))
                    return ReturnCode.INVALID_ACCESS_TOKEN;

                return ReturnCode.VALID_REQUEST;
            } catch (Error e) {
                if (e is Soup.SessionError.PARSING ||
                    e.message.contains ("TLS handshake") ||
                    e.message.contains ("TLS connection")) {
                    return ReturnCode.TLS_HANDSHAKE_ERROR;
                }

                if (e.message.contains ("Temporary failure in name resolution"))
                    return ReturnCode.CONNECTION_ISSUE;

                if (e.message.contains ("Connection refused"))
                    return ReturnCode.CONNECTION_REFUSED;

                if (e.message.contains ("Name or service not known"))
                    return ReturnCode.CONNECTION_UNKNOWN;

                warning (e.message);
                return ReturnCode.UNKNOWN_ERROR;
            }
        }
    }
}
