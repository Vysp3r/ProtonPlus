namespace ProtonPlus.Utils {
    public class Web {
        const int PROXY_MODE_SYSTEM = 0;
        const int PROXY_MODE_MANUAL = 1;


        public enum GetRequestType {
            OTHER,
            GITHUB,
            GITLAB,
            FORGEJO,
            STEAMTINKERLAUNCH,
        }

        static Soup.Session? _session = null;
        static int applied_proxy_mode = -1;
        static string? applied_proxy_url = null;

        static Soup.Session current_session {
            get {
                if (_session == null) {
                    _session = new Soup.Session ();
                    _session.user_agent = Config.APP_NAME + "/" + Config.APP_VERSION;
                }
                update_proxy_settings ();
                return _session;
            }
        }

        public static Soup.Session get_session () {
            return current_session;
        }

        public static void update_proxy_settings () {
            if (_session == null)
                return;

            var proxy_mode = PROXY_MODE_SYSTEM;
            var proxy_url = "";

            if (Globals.SETTINGS != null) {
                proxy_mode = Globals.SETTINGS.get_enum ("proxy-mode");
                proxy_url = Globals.SETTINGS.get_string ("proxy-url").strip ();
            }

            if (applied_proxy_mode == proxy_mode && applied_proxy_url == proxy_url)
                return;

            if (proxy_mode == PROXY_MODE_MANUAL) {
                if (is_valid_proxy_url (proxy_url)) {
                    _session.set_proxy_resolver (new SimpleProxyResolver (proxy_url, null));
                } else {
                    if (proxy_url.length > 0)
                        warning ("Invalid proxy URL. Falling back to the system proxy.");
                    _session.set_proxy_resolver (ProxyResolver.get_default ());
                }
            } else {
                _session.set_proxy_resolver (ProxyResolver.get_default ());
            }

            applied_proxy_mode = proxy_mode;
            applied_proxy_url = proxy_url;
        }

        static bool is_valid_proxy_url (string proxy_url) {
            var supported_schemes = new string[] { "http://", "https://", "socks://", "socks4://", "socks5://" };

            if (proxy_url.length == 0)
                return false;

            foreach (var scheme in supported_schemes) {
                if (proxy_url.has_prefix (scheme) && proxy_url.length > scheme.length)
                    return true;
            }

            return false;
        }

        public static async Requests.Response get_request (string uri, GetRequestType get_request_type = GetRequestType.OTHER) {
            var request = new Requests.Request (uri, "GET", current_session);

            if (Globals.SETTINGS != null) {
                if (get_request_type == GetRequestType.GITHUB || get_request_type == GetRequestType.STEAMTINKERLAUNCH) {
                    var key = Globals.SETTINGS.get_string ("github-api-key");
                    if (key.length > 0)
                        request.append_header ("Authorization", "token %s".printf (key));
                }

                if (get_request_type == GetRequestType.GITLAB) {
                    var key = Globals.SETTINGS.get_string ("gitlab-api-key");
                    if (key.length > 0)
                        request.append_header ("Authorization", "Bearer %s".printf (key));
                }

                if (get_request_type == GetRequestType.STEAMTINKERLAUNCH) {
                    request.append_header ("Accept", "application/vnd.github+json");
                    request.append_header ("X-GitHub-Api-Version", "2022-11-28");
                }
            }

            var response = yield request.send ();

            if (response.is_successful)
                return response;

            if (response.status_code == 403 || response.status_code == 429) {
                response.code = ReturnCode.API_LIMIT_REACHED;
            } else if (response.status_code == 401 &&
                       (get_request_type == GetRequestType.GITHUB ||
                        get_request_type == GetRequestType.GITLAB ||
                        get_request_type == GetRequestType.FORGEJO ||
                        get_request_type == GetRequestType.STEAMTINKERLAUNCH)) {
                response.code = ReturnCode.INVALID_ACCESS_TOKEN;
            }

            return response;
        }

        public delegate void progress_callback (bool is_percent, int64 progress_percentage, double speed_kbps, double? remaining_seconds);

        private static void report_download_progress (
            progress_callback progress_callback,
            bool is_percent,
            int64 bytes_downloaded,
            int64 server_download_size,
            int64 start_time
        ) {
            int64 elapsed_us = get_monotonic_time () - start_time;
            double elapsed_s = elapsed_us / 1000000.0;

            double speed_kbps = elapsed_s > 0 ? (bytes_downloaded / 1024.0) / elapsed_s : 0.0;
            double speed_bps = elapsed_s > 0 ? bytes_downloaded / elapsed_s : 0.0;

            double? remaining_seconds = null;
            if (is_percent && speed_bps > 0.0) {
                int64 bytes_left = server_download_size - bytes_downloaded;
                remaining_seconds = bytes_left / speed_bps;
            }

            // Use "bytes downloaded" when total size is unknown.
            int64 progress = !is_percent ? bytes_downloaded : (int64) (((double) bytes_downloaded / server_download_size) * 100);
            progress_callback (is_percent, progress, speed_kbps, remaining_seconds);
        }

        private static async void cleanup_partial_download (File file, FileOutputStream? output_stream) {
            if (output_stream != null) {
                try {
                    yield output_stream.close_async (Priority.DEFAULT, null);
                } catch (Error e) {
                    warning ("Could not close partial download: %s".printf (e.message));
                }
            }

            try {
                if (file.query_exists ())
                    yield file.delete_async (Priority.DEFAULT, null);
            } catch (Error e) {
                warning ("Could not remove partial download: %s".printf (e.message));
            }
        }

        public static async bool download (
            string url,
            string path,
            Cancellable? cancellable = null,
            progress_callback? progress_callback = null,
            out string? error_message = null
        ) {
            error_message = null;
            var file = File.new_for_path (path);
            FileOutputStream? output_stream = null;
            bool has_partial_file = false;

            try {
                var soup_message = new Soup.Message ("GET", url);

                var input_stream = yield current_session.send_async (soup_message, Priority.DEFAULT, cancellable);

                if (soup_message.status_code != 200) {
                    warning (soup_message.reason_phrase);
                    error_message = soup_message.reason_phrase;
                    return false;
                }

                output_stream = yield file.create_async (FileCreateFlags.REPLACE_DESTINATION, Priority.DEFAULT, null);
                has_partial_file = true;

                // Prefer real Content-Length header from the server if it exists.
                // NOTE: Servers typically return "0" when it doesn't know, for
                // live-generated files (such as GitHub's commit-based source
                // archives). However, GitHub's server then caches the generated
                // result for a few minutes to avoid extra work. So the first
                // download of a GitHub source archive will have an unknown "0"
                // length, but any download requests after that it will see the
                // filesize for a few minutes, until GitHub clears their cache.
                int64 server_download_size = soup_message.get_response_headers ().get_content_length ();

                const size_t chunk_size = 64 * 1024;
                const int64 progress_report_interval_us = 100 * 1000;
                bool is_percent = server_download_size > 0;
                int64 bytes_downloaded = 0;

                if (progress_callback != null)
                    progress_callback (is_percent, 0, 0, 0); // Set initial progress state.

                var is_canceled = false;

                int64 start_time = get_monotonic_time ();
                int64 last_progress_report_time = start_time;

                while (true) {
                    if (cancellable != null && cancellable.is_cancelled ()) {
                        is_canceled = true;
                        break;
                    }

                    var chunk = yield input_stream.read_bytes_async (chunk_size, Priority.DEFAULT, cancellable);

                    if (chunk.get_size () == 0)
                        break;

                    size_t bytes_written;
                    yield output_stream.write_all_async (chunk.get_data (), Priority.DEFAULT, cancellable, out bytes_written);

                    bytes_downloaded += bytes_written;

                    int64 now = get_monotonic_time ();
                    if (progress_callback != null && now - last_progress_report_time >= progress_report_interval_us) {
                        report_download_progress (progress_callback, is_percent, bytes_downloaded, server_download_size, start_time);
                        last_progress_report_time = now;
                    }
                }

                if (!is_canceled && progress_callback != null)
                    report_download_progress (progress_callback, is_percent, bytes_downloaded, server_download_size, start_time);

                yield output_stream.close_async ();
                output_stream = null;

                if (is_canceled) {
                    yield cleanup_partial_download (file, output_stream);
                    return false;
                }

                has_partial_file = false;
                return true;
            } catch (Error e) {
                if (has_partial_file)
                    yield cleanup_partial_download (file, output_stream);

                if (cancellable != null && cancellable.is_cancelled ())
                    return false;

                warning (e.message);
                error_message = e.message;

                return false;
            }
        }
    }
}
