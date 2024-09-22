namespace ProtonPlus.Utils {
    public class Web {
        public static string get_user_agent () {
            return Constants.APP_NAME + "/" + Constants.APP_VERSION;
        }

        public static async string ? GET (string url, bool stl = false) {
            try {
                var session = new Soup.Session ();
                session.set_user_agent (get_user_agent ());

                var message = new Soup.Message ("GET", url);

                Bytes bytes = yield session.send_and_read_async (message, Priority.DEFAULT, null);

                return (string) bytes.get_data ();
            } catch (Error e) {
                message (e.message);
                return null;
            }
        }

        public delegate bool cancel_callback ();

        public delegate void progress_callback (bool is_percent, int64 progress);

        public static async bool Download (string url, string path, cancel_callback cancel_callback, progress_callback progress_callback) {
            try {
                var session = new Soup.Session ();
                session.set_user_agent (get_user_agent ());

                var soup_message = new Soup.Message ("GET", url);

                var input_stream = yield session.send_async (soup_message, Priority.DEFAULT, null);

                if (soup_message.status_code != 200) {
                    message (soup_message.reason_phrase);
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
                    progress_callback (is_percent, 0); // Set initial progress state.

                var is_canceled = false;

                while (true) {
                    if (cancel_callback ()) {
                        is_canceled = true;
                        break;
                    }

                    var chunk = yield input_stream.read_bytes_async (chunk_size);

                    if (chunk.get_size () == 0)
                        break;

                    bytes_downloaded += output_stream.write (chunk.get_data ());

                    if (progress_callback != null) {
                        // Use "bytes downloaded" when total size is unknown.
                        int64 progress = !is_percent ? bytes_downloaded : (int64) (((double) bytes_downloaded / server_download_size) * 100);
                        progress_callback (is_percent, progress);
                    }
                }

                yield output_stream.close_async ();

                session.abort ();

                if (is_canceled && file.query_exists ())
                    yield file.delete_async (Priority.DEFAULT, null);

                return !is_canceled;
            } catch (Error e) {
                message (e.message);
                return false;
            }
        }
    }
}