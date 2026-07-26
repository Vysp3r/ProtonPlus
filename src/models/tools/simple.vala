namespace ProtonPlus.Models.Tools {
    public class Simple : Tool {
        // Simple tools represent external compatibility entries.  Their
        // display and internal titles are intentionally not stable tool IDs.
        public string display_title { get; set; }
        public string internal_title { get; set; }
        public string path { get; set; }

        public Simple (string display_title, string internal_title) {
            this.title = display_title;
            this.display_title = display_title;
            this.internal_title = internal_title;
        }

        public Simple.with_path (string display_title, string internal_title, string path) {
            this.title = display_title;
            this.display_title = display_title;
            this.internal_title = internal_title;
            this.path = path;
        }

        public Simple.from_path (string path) {
            this.path = path;

            var fallback_title = Path.get_basename (path);
            title = fallback_title;
            display_title = fallback_title;
            internal_title = fallback_title;

            var compatibilitytoolvdf_path = "%s/compatibilitytool.vdf".printf (path);
            if (!FileUtils.test (compatibilitytoolvdf_path, FileTest.IS_REGULAR)) {
                return;
            }

            var content = Utils.Filesystem.get_file_content (compatibilitytoolvdf_path);
            if (content == "") {
                return;
            }

            var start_text = "";
            var end_text = "";
            var start_pos = 0;
            var end_pos = 0;

            start_text = "display_name\" \"";
            start_pos = content.index_of (start_text, 0);
            if (start_pos != -1) {
                start_pos += start_text.length;
                end_text = "\"";
                end_pos = content.index_of (end_text, start_pos);
                if (end_pos != -1) {
                    title = content.substring (start_pos, end_pos - start_pos);
                    display_title = title;
                }
            }

            start_text = "compat_tools\"";
            start_pos = content.index_of (start_text, 0);
            if (start_pos != -1) {
                start_pos += start_text.length;

                start_text = "\"";
                start_pos = content.index_of (start_text, start_pos);
                if (start_pos != -1) {
                    start_pos += start_text.length;
                    end_text = "\" // Internal name of this tool";
                    end_pos = content.index_of (end_text, start_pos);
                    if (end_pos != -1) {
                        internal_title = content.substring (start_pos, end_pos - start_pos);
                    }
                }
            }
        }
    }
}
