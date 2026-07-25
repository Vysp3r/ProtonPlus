namespace ProtonPlus.Models.Releases {
    public class Latest : Release {
        public string source_release_title { get; set; }

        public Latest (
            Tools.Basic runner,
            string title,
            string description,
            string release_date,
            string download_url,
            string page_url,
            string source_release_title = ""
        ) {
            shared (runner, title, release_date, download_url, page_url);

            this.description = description;
            this.source_release_title = source_release_title;
        }

        public override Json.Object to_json () {
            var obj = base.to_json ();
            obj.set_string_member ("kind", "latest");
            obj.set_string_member ("source_release_title", source_release_title);
            return obj;
        }

        protected override async string? _after_extraction (string source_path, string extract_path) {
            var basic_runner = runner as Tools.Basic;
            var source_runner = basic_runner != null ? basic_runner.source_runner as Models.Launchers.Runners.Base : null;

            if (source_runner != null && source_runner.source_type == Models.Launchers.Runners.SourceType.GITHUB_ACTION)
                return yield extract_nested_archive (source_path, extract_path);

            return source_path;
        }

        protected override async bool _after_staging_install (string staged_install_path) {
            var compatibilitytoolvdf_path = "%s/compatibilitytool.vdf".printf (staged_install_path);
            if (!FileUtils.test (compatibilitytoolvdf_path, FileTest.IS_REGULAR)) {
                persist_source_release_title (staged_install_path);
                return true;
            }

            var compatibilitytoolvdf_content = Utils.Filesystem.get_file_content (compatibilitytoolvdf_path);
            if (compatibilitytoolvdf_content == "") {
                error_message = _ ("Failed to read compatibilitytool.vdf");
                return false;
            }

            var start_text = "";
            var end_text = "";
            var start_pos = 0;
            var end_pos = 0;

            start_text = "compat_tools\"\n  {\n    \"";
            start_pos = compatibilitytoolvdf_content.index_of (start_text, 0);
            if (start_pos == -1)
                return false;
            start_pos += start_text.length;

            end_text = "\" // Internal name of this tool";
            end_pos = compatibilitytoolvdf_content.index_of (end_text, start_pos);
            if (end_pos == -1)
                return false;

            var internal_title = compatibilitytoolvdf_content.substring (start_pos, end_pos - start_pos);

            start_pos = compatibilitytoolvdf_content.index_of (start_text, 0);
            if (start_pos == -1)
                return false;

            end_pos = compatibilitytoolvdf_content.index_of (end_text, start_pos + start_text.length);
            if (end_pos == -1)
                return false;
            end_pos += end_text.length;

            var internal_title_line = compatibilitytoolvdf_content.substring (start_pos, end_pos - start_pos);

            var internal_title_line_modified = internal_title_line.replace (internal_title, title);

            compatibilitytoolvdf_content = compatibilitytoolvdf_content.replace (internal_title_line, internal_title_line_modified);

            start_text = "display_name\" \"";
            start_pos = compatibilitytoolvdf_content.index_of (start_text, 0);
            if (start_pos == -1)
                return false;
            start_pos += start_text.length;

            end_text = "\"";
            end_pos = compatibilitytoolvdf_content.index_of (end_text, start_pos);
            if (end_pos == -1)
                return false;

            var display_title = compatibilitytoolvdf_content.substring (start_pos, end_pos - start_pos);

            start_pos = compatibilitytoolvdf_content.index_of (start_text, 0);
            if (start_pos == -1)
                return false;

            end_pos = compatibilitytoolvdf_content.index_of (end_text, start_pos + start_text.length);
            if (end_pos == -1)
                return false;
            end_pos += end_text.length;

            var display_title_line = compatibilitytoolvdf_content.substring (start_pos, end_pos - start_pos);

            var display_title_line_modified = display_title_line.replace (display_title, title);

            compatibilitytoolvdf_content = compatibilitytoolvdf_content.replace (display_title_line, display_title_line_modified);

            var modified = Utils.Filesystem.modify_file (compatibilitytoolvdf_path, compatibilitytoolvdf_content);
            if (!modified)
                return false;

            persist_source_release_title (staged_install_path);

            return true;
        }

        private void persist_source_release_title (string path) {
            if (source_release_title == "")
                return;

            var metadata = Utils.Metadata.load (path);
            metadata.tag = source_release_title;
            metadata.save (path);
        }

        protected override async ReturnCode _start_update () {
            return yield Models.Tool.update_specific_runner (runner as Models.Tools.Basic);
        }
    }
}
