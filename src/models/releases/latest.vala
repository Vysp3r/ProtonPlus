namespace ProtonPlus.Models.Releases {
    public class Latest : Release {
        public string source_release_title { get; set; }

        public Latest (
            Tools.Basic runner,
            string title,
            string description,
            string release_date,
            Internal.Assets.Asset asset,
            string page_url,
            string source_release_title = "",
            string upstream_release_id = "",
            string source_tag = ""
        ) {
            this.upstream_release_id = upstream_release_id;
            this.source_tag = source_tag;
            shared (runner, title, release_date, asset, page_url);

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
                return true;
            }

            var compatibilitytoolvdf_content = Utils.Filesystem.get_file_content (compatibilitytoolvdf_path);
            if (compatibilitytoolvdf_content == "") {
                error_message = _ ("Failed to read compatibilitytool.vdf");
                return false;
            }

            var document = Utils.VDF.VdfParser.parse_document (compatibilitytoolvdf_content);
            if (document == null)
                return false;

            var compat_tools = document.root.get_child ("compat_tools");
            if (compat_tools == null || compat_tools.children.size != 1)
                return false;

            var tool = compat_tools.children.get (0);
            if (tool.key == "" || tool.key_start < 0 || tool.key_end < tool.key_start)
                return false;

            compatibilitytoolvdf_content = document.replace_key (tool, title);

            document = Utils.VDF.VdfParser.parse_document (compatibilitytoolvdf_content);
            if (document == null)
                return false;

            compat_tools = document.root.get_child ("compat_tools");
            if (compat_tools == null || compat_tools.children.size != 1)
                return false;

            tool = compat_tools.children.get (0);
            var display_name = tool.get_child ("display_name");
            if (display_name == null || display_name.value == null ||
                display_name.value_start < 0 || display_name.value_end < display_name.value_start)
                return false;

            compatibilitytoolvdf_content = document.replace_value (display_name, title);

            var modified = Utils.Filesystem.modify_file (compatibilitytoolvdf_path, compatibilitytoolvdf_content);
            if (!modified)
                return false;

            return true;
        }

        protected override string get_legacy_metadata_tag () {
            return source_release_title != "" ? source_release_title : base.get_legacy_metadata_tag ();
        }

        protected override async ReturnCode _start_update () {
            return yield Models.Tool.update_specific_runner (runner as Models.Tools.Basic);
        }
    }
}
