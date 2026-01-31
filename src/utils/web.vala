namespace ProtonPlus.Utils {
    public class Web {
        public enum GetType {
            OTHER,
            GITHUB,
            GITLAB,
            FORGEJO,
            STEAMTINKERLAUNCH,
        }

        static string get_user_agent () {
            return Config.APP_NAME + "/" + Config.APP_VERSION;
        }

        public static async ReturnCode get_request (string uri, GetType get_type = GetType.OTHER, out string? response) {
            try {
                var session = new Soup.Session ();
                session.set_user_agent (get_user_agent ());

                var message = new Soup.Message ("GET", uri);

                if (Globals.SETTINGS != null) {
                    if (get_type == GetType.GITHUB || get_type == GetType.STEAMTINKERLAUNCH) {
                        var key = Globals.SETTINGS.get_string ("github-api-key");
                        if (key.length > 0)
                            message.request_headers.append ("Authorization", "token %s".printf (key));
                    }

                    if (get_type == GetType.GITLAB) {
                        var key = Globals.SETTINGS.get_string ("gitlab-api-key");
                        if (key.length > 0)
                            message.request_headers.append ("Authorization", "Bearer %s".printf (key));
                    }
                    
                    if (get_type == GetType.STEAMTINKERLAUNCH) {
                        message.request_headers.append ("Accept", "application/vnd.github+json");
                        message.request_headers.append ("X-GitHub-Api-Version", "2022-11-28");
                    }
                }

                Bytes bytes = yield session.send_and_read_async (message, Priority.DEFAULT, null);

                response = (string) bytes.get_data ();

                if (response == null)
                    return ReturnCode.UNKNOWN_ERROR;

                if (response.contains ("Temporary failure in name resolution"))
                    return ReturnCode.CONNECTION_ISSUE;

                switch (get_type) {
                    case GetType.GITHUB:
                        if (response.contains ("https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"))
                            return ReturnCode.API_LIMIT_REACHED;

                        if (response.contains ("Bad credentials"))
                            return ReturnCode.INVALID_ACCESS_TOKEN;

                        break;
                    case GetType.GITLAB:
                        if (response.contains ("401 Unauthorized"))
                            return ReturnCode.INVALID_ACCESS_TOKEN;

                        break;
                    default:
                        break;
                }

                return ReturnCode.VALID_REQUEST;
            } catch (Error e) {
                error (e.message);

                return ReturnCode.UNKNOWN_ERROR;
            }
        }

        public delegate bool cancel_callback ();

        public delegate void progress_callback (bool is_percent, int64 progress_percentage, double speed_kbps, double? remaining_seconds);

        public static async bool Download (string url, string path, cancel_callback? cancel_callback = null, progress_callback? progress_callback = null) {
            try {
                var session = new Soup.Session ();
                session.set_user_agent (get_user_agent ());

                var soup_message = new Soup.Message ("GET", url);

                var input_stream = yield session.send_async (soup_message, Priority.DEFAULT, null);

                if (soup_message.status_code != 200) {
                    error (soup_message.reason_phrase);
                    return false;
                }

                var file = File.new_for_path (path);
                if (file.query_exists ())
                    yield file.delete_async (Priority.DEFAULT, null);

                FileOutputStream output_stream = yield file.create_async (FileCreateFlags.REPLACE_DESTINATION, Priority.DEFAULT, null);

                // Prefer real Content-Length header from the server if it exists.
                // NOTE: Servers typically return "0" when it doesn't know, for
                // live-generated files (such as GitHub's commit-based source
                // archives). However, GitHub's server then caches the generated
                // result for a few minutes to avoid extra work. So the first
                // download of a GitHub source archive will have an unknown "0"
                // length, but any download requests after that it will see the
                // filesize for a few minutes, until GitHub clears their cache.
                int64 server_download_size = soup_message.get_response_headers ().get_content_length ();

                const size_t chunk_size = 4096;
                bool is_percent = server_download_size > 0;
                int64 bytes_downloaded = 0;

                if (progress_callback != null)
                    progress_callback (is_percent, 0, 0, 0); // Set initial progress state.

                var is_canceled = false;

                int64 start_time = get_monotonic_time ();

                while (true) {
                    if (cancel_callback != null && cancel_callback ()) {
                        is_canceled = true;
                        break;
                    }

                    var chunk = yield input_stream.read_bytes_async (chunk_size);

                    if (chunk.get_size () == 0)
                        break;

                    bytes_downloaded += output_stream.write (chunk.get_data ());

                    if (progress_callback != null) {
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
                }

                yield output_stream.close_async ();

                session.abort ();

                if (is_canceled && file.query_exists ())
                    yield file.delete_async (Priority.DEFAULT, null);

                return !is_canceled;
            } catch (Error e) {
                error (e.message);

                return false;
            }
        }
    }
}