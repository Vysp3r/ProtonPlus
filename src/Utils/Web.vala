namespace Utils {
    public class Web {
        public static string GET (string url) {
            try {
                var session = new Soup.Session ();
                var message = new Soup.Message ("GET", url);
                session.set_user_agent ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edge/12.246");
                Bytes bytes = session.send_and_read (message);
                return (string) bytes.get_data ();
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
                return "";
            }
        }

        public static void Download (string url, string path, ref double state, ref bool cancelled, ref bool requestError, ref bool downloadError, ref string errorMessage) {
            var client = new Soup.Session ();
            client.set_user_agent ("Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:15.0) Gecko/20100101 Firefox/15.0.1");

            var request = new Soup.Message ("GET", url);

            try {
                var input_stream = client.send (request);

                if (request.status_code != 200) {
                    requestError = true;
                    errorMessage = request.reason_phrase + "\n"; // TODO
                    return;
                }

                var file = GLib.File.new_for_path (path);
                if (file.query_exists ()) file.delete ();
                FileOutputStream output_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);

                int64 content_length = request.response_headers.get_content_length ();

                const int chunk_size = 1024;
                ulong bytes_downloaded = 0;
                while (bytes_downloaded < content_length) {
                    if (cancelled) {
                        if (file.query_exists ()) file.delete ();
                        break;
                    }

                    ulong bytes_read = output_stream.write (input_stream.read_bytes (chunk_size).get_data ());

                    bytes_downloaded += bytes_read;
                    state = (double) bytes_downloaded / content_length;
                }

                output_stream.close ();
            } catch (GLib.Error e) {
                downloadError = true;
                errorMessage = e.message + "\n"; // TODO
            }

            client.abort ();
        }

        public static void OldDownload (string url, string path, ref bool requestError, ref bool downloadError, ref string errorMessage) {
            try {
                var session = new Soup.Session ();
                var request = new Soup.Message ("GET", url);
                var response = session.send_and_read (request);

                if (request.status_code == 200) {
                    var file = GLib.File.new_for_path (path);
                    var output_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
                    output_stream.write (response.get_data ());
                } else {
                    requestError = true;
                    errorMessage = "Error: " + request.status_code.to_string () + "\n"; // TODO
                }
            } catch (GLib.Error e) {
                downloadError = true;
                errorMessage = e.message + "\n"; // TODO
            }
        }
    }
}
