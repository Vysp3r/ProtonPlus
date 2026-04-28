namespace ProtonPlus.Models.Releases {
    public class Latest : Release {
        public Latest (Tools.Basic runner, string title, string description, string release_date, string download_url, string page_url) {
            shared (runner, title, release_date, download_url, page_url);

            this.description = description;
        }

        protected override async ReturnCode _start_install () {
            var code = yield base._start_install ();
            if (code != ReturnCode.RUNNER_INSTALLED)
            return code;

            var compatibilitytoolvdf_path = "%s/compatibilitytool.vdf".printf (destination_path);

            var compatibilitytoolvdf_content = Utils.Filesystem.get_file_content (compatibilitytoolvdf_path);
            if (compatibilitytoolvdf_content == "") {
                error_message = _ ("Failed to read compatibilitytool.vdf");
                return ReturnCode.UNKNOWN_ERROR;
            }

            var start_text = "";
            var end_text = "";
            var start_pos = 0;
            var end_pos = 0;

            start_text = "compat_tools\"\n  {\n    \"";
            start_pos = compatibilitytoolvdf_content.index_of (start_text, 0) + start_text.length;
            if (start_pos == -1)
            return ReturnCode.UNKNOWN_ERROR;

            end_text = "\" // Internal name of this tool";
            end_pos = compatibilitytoolvdf_content.index_of (end_text, start_pos);
            if (end_pos == -1)
            return ReturnCode.UNKNOWN_ERROR;

            var internal_title = compatibilitytoolvdf_content.substring (start_pos, end_pos - start_pos);

            start_pos = compatibilitytoolvdf_content.index_of (start_text, 0);
            if (start_pos == -1)
            return ReturnCode.UNKNOWN_ERROR;

            end_pos = compatibilitytoolvdf_content.index_of (end_text, start_pos + start_text.length) + end_text.length;
            if (end_pos == -1)
            return ReturnCode.UNKNOWN_ERROR;

            var internal_title_line = compatibilitytoolvdf_content.substring (start_pos, end_pos - start_pos);

            var internal_title_line_modified = internal_title_line.replace (internal_title, title);

            compatibilitytoolvdf_content = compatibilitytoolvdf_content.replace (internal_title_line, internal_title_line_modified);

            start_text = "display_name\" \"";
            start_pos = compatibilitytoolvdf_content.index_of (start_text, 0) + start_text.length;
            if (start_pos == -1)
            return ReturnCode.UNKNOWN_ERROR;

            end_text = "\"";
            end_pos = compatibilitytoolvdf_content.index_of (end_text, start_pos);
            if (end_pos == -1)
            return ReturnCode.UNKNOWN_ERROR;

            var display_title = compatibilitytoolvdf_content.substring (start_pos, end_pos - start_pos);

            start_pos = compatibilitytoolvdf_content.index_of (start_text, 0);
            if (start_pos == -1)
            return ReturnCode.UNKNOWN_ERROR;

            end_pos = compatibilitytoolvdf_content.index_of (end_text, start_pos + start_text.length) + end_text.length;
            if (end_pos == -1)
            return ReturnCode.UNKNOWN_ERROR;

            var display_title_line = compatibilitytoolvdf_content.substring (start_pos, end_pos - start_pos);

            var display_title_line_modified = display_title_line.replace (display_title, title);

            compatibilitytoolvdf_content = compatibilitytoolvdf_content.replace (display_title_line, display_title_line_modified);

            var modified = Utils.Filesystem.modify_file (compatibilitytoolvdf_path, compatibilitytoolvdf_content);
            if (!modified)
            return ReturnCode.UNKNOWN_ERROR;

            return ReturnCode.RUNNER_INSTALLED;
        }

        protected override async ReturnCode _start_update () {
            return yield Models.Tool.update_specific_runner (runner as Models.Tools.Basic);
        }
    }
}
