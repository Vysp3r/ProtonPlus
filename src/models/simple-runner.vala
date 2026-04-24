namespace ProtonPlus.Models {
    public class SimpleRunner : Object {
        public string display_title { get; set; }
        public string internal_title { get; set; }
        public string path { get; set; }

        public SimpleRunner (string display_title, string internal_title) {
            this.display_title = display_title;
            this.internal_title = internal_title;
        }

        public SimpleRunner.with_path (string display_title, string internal_title, string path) {
            this.display_title = display_title;
            this.internal_title = internal_title;
            this.path = path;
        }

        public SimpleRunner.from_path (string path) {
            this.path = path;

            var content = Utils.Filesystem.get_file_content ("%s/compatibilitytool.vdf".printf (path));
            var start_text = "";
            var end_text = "";
            var start_pos = 0;
            var end_pos = 0;

            start_text = "display_name\" \"";
            start_pos = content.index_of (start_text, 0) + start_text.length;
            if (start_pos == -1) {
                warning ("Error parsing the file");
                return;
            }

            end_text = "\"";
            end_pos = content.index_of (end_text, start_pos);
            if (end_pos == -1) {
                warning ("Error parsing the file");
                return;
            }

            display_title = content.substring (start_pos, end_pos - start_pos);

            start_text = "compat_tools\"";
            start_pos = content.index_of (start_text, 0) + start_text.length;
            if (start_pos == -1) {
                warning ("Error parsing the file");
                return;
            }

            start_text = "\"";
            start_pos = content.index_of (start_text, start_pos) + start_text.length;
            if (start_pos == -1) {
                warning ("Error parsing the file");
                return;
            }

            end_text = "\" // Internal name of this tool";
            end_pos = content.index_of (end_text, start_pos);
            if (end_pos == -1) {
                warning ("Error parsing the file");
                return;
            }

            internal_title = content.substring (start_pos, end_pos - start_pos);
        }
    }
}
