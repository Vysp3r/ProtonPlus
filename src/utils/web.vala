namespace ProtonPlus.Utils {
    public class Web {
        public static string get_user_agent () {
            return Constants.APP_NAME + "/" + Constants.APP_VERSION;
        }

        public static async string ? GET (string url) {
            try {
                var session = new Soup.Session ();
                session.set_user_agent (get_user_agent ());

                var message = new Soup.Message ("GET", url);

                Bytes bytes = yield session.send_and_read_async (message, GLib.Priority.DEFAULT, null);

                return (string) bytes.get_data ();
            } catch (GLib.Error e) {
                message (e.message);
                return null;
            }
        }

        public delegate bool cancel_callback ();

        public delegate void progress_callback (int progress);

        public enum DOWNLOAD_CODES {
            API_ERROR,
            UNEXPECTED_ERROR,
            SUCCESS
        }

        public static async DOWNLOAD_CODES Download (string url, string path, int64 download_size, cancel_callback cancel_callback, progress_callback progress_callback) {
            try {
                var session = new Soup.Session ();
                session.set_user_agent (get_user_agent ());

                var message = new Soup.Message ("GET", url);

                var input_stream = yield session.send_async (message, GLib.Priority.DEFAULT, null);

                if (message.status_code != 200) {
                    GLib.message (message.reason_phrase);
                    return DOWNLOAD_CODES.API_ERROR;
                }

                var file = GLib.File.new_for_path (path);
                if (file.query_exists ()) {
                    yield file.delete_async (GLib.Priority.DEFAULT, null);
                }

                FileOutputStream output_stream = yield file.create_async (FileCreateFlags.REPLACE_DESTINATION, GLib.Priority.DEFAULT, null);

                // Temporary fix for GitLab since they don't give the file size from their API
                if (download_size == -1) {
                    download_size = message.get_response_headers ().get_content_length ();
                }

                const size_t chunk_size = 4096;
                ulong bytes_downloaded = 0;

                while (true) {
                    if (cancel_callback ()) {
                        if (file.query_exists ()) {
                            yield file.delete_async (GLib.Priority.DEFAULT, null);
                        }
                        break;
                    }

                    var chunk = yield input_stream.read_bytes_async (chunk_size);

                    if (chunk.get_size () == 0) {
                        break;
                    }

                    bytes_downloaded += output_stream.write (chunk.get_data ());

                    if (progress_callback != null) {
                        var progress = (int) (((double) bytes_downloaded / download_size) * 100);
                        progress_callback (progress);
                    }
                }

                yield output_stream.close_async ();

                session.abort ();

                return DOWNLOAD_CODES.SUCCESS;
            } catch (GLib.Error e) {
                message (e.message);
                return DOWNLOAD_CODES.UNEXPECTED_ERROR;
            }
        }
    }
}