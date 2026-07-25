namespace ProtonPlus.Utils.Requests {
    public class Response : Object {
        public ReturnCode code { get; set; default = ReturnCode.REQUEST_FAILED; }
        public int status_code { get; set; default = 0; }
        public string? body { get; set; default = null; }
        public string? error_message { get; set; default = null; }

        public bool is_successful {
            get {
                return status_code >= 200 && status_code < 300;
            }
        }
    }

    public class Request : Object {
        private Soup.Message message;
        private Soup.Session session;

        public Request (string uri, string method = "GET", Soup.Session? request_session = null) {
            message = new Soup.Message (method, uri);
            session = request_session ?? Proxy.session;
        }

        public void append_header (string name, string value) {
            message.request_headers.append (name, value);
        }

        public async Response send () {
            var response = new Response ();

            try {
                Bytes bytes = yield session.send_and_read_async (message, Priority.DEFAULT, null);

                response.status_code = (int) message.status_code;
                response.error_message = message.reason_phrase;

                if (!response.is_successful)
                    return response;

                response.body = Parser.data_to_string (bytes.get_data ());
                response.code = ReturnCode.VALID_REQUEST;
                return response;
            } catch (Error e) {
                if (e is Soup.SessionError.PARSING || e.domain == TlsError.quark ()) {
                    response.code = ReturnCode.TLS_HANDSHAKE_ERROR;
                    response.error_message = e.message;
                    return response;
                }

                if (e is IOError.HOST_UNREACHABLE || e is IOError.NETWORK_UNREACHABLE) {
                    response.code = ReturnCode.CONNECTION_ISSUE;
                    response.error_message = e.message;
                    return response;
                }

                if (e is IOError.CONNECTION_REFUSED) {
                    response.code = ReturnCode.CONNECTION_REFUSED;
                    response.error_message = e.message;
                    return response;
                }

                if (e is IOError.HOST_NOT_FOUND) {
                    response.code = ReturnCode.CONNECTION_UNKNOWN;
                    response.error_message = e.message;
                    return response;
                }

                warning (e.message);
                response.error_message = e.message;
                return response;
            }
        }
    }
}
