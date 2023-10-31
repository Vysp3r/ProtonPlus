namespace ProtonPlus.Utils {
    public class Web {
        public delegate bool cancel_callback ();
        public delegate void progress_callback (int progress);

        public static string GET (string url) {
            try {
                var session = new Soup.Session ();
                var message = new Soup.Message ("GET", url);
                session.set_user_agent ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edge/12.246");
                Bytes bytes = session.send_and_read (message);
                return (string) bytes.get_data ();
            } catch (GLib.Error e) {
                message (e.message);
                return "";
            }
        }

        public enum DOWNLOAD_CODES {
            API_ERROR,
            UNEXPECTED_ERROR,
            SUCCESS
        }

        public static DOWNLOAD_CODES Download (string url, string path, cancel_callback cancel_callback, ref int progress) {
            try {
                var client = new Soup.Session ();
                client.set_user_agent ("Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:15.0) Gecko/20100101 Firefox/15.0.1");
    
                var request = new Soup.Message ("GET", url);

                var input_stream = client.send (request);

                if (request.status_code != 200) {
                    message (request.reason_phrase);
                    return DOWNLOAD_CODES.API_ERROR;
                }

                var file = GLib.File.new_for_path (path);
                if (file.query_exists ()) file.delete ();
                FileOutputStream output_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);

                int64 content_length = request.response_headers.get_content_length ();

                const int chunk_size = 1024;
                ulong bytes_downloaded = 0;
                while (bytes_downloaded < content_length) {
                    if (cancel_callback()) {
                        if (file.query_exists ()) file.delete ();
                        break;
                    }

                    ulong bytes_read = output_stream.write (input_stream.read_bytes (chunk_size).get_data ());

                    bytes_downloaded += bytes_read;

                    progress = (int) (((double) bytes_downloaded / content_length) * 100);
                }
                output_stream.close ();

                client.abort ();

                return DOWNLOAD_CODES.SUCCESS;
            } catch (GLib.Error e) {
                message (e.message);
                return DOWNLOAD_CODES.UNEXPECTED_ERROR;
            }
        }

        public static DOWNLOAD_CODES OldDownload (string url, string path) {
            try {
                var session = new Soup.Session ();
                var request = new Soup.Message ("GET", url);
                var response = session.send_and_read (request);

                if (request.status_code != 200) {
                    message (request.reason_phrase);
                    return DOWNLOAD_CODES.API_ERROR;
                }

                var file = GLib.File.new_for_path (path);
                var output_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
                output_stream.write (response.get_data ());

                return DOWNLOAD_CODES.SUCCESS;
            } catch (GLib.Error e) {
                message (e.message);
                return DOWNLOAD_CODES.UNEXPECTED_ERROR;
            }
        }
    }
}