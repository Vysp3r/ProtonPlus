namespace ProtonPlus.Utils.VDF {
    // Owns the narrowly scoped compatibilitytool.vdf parsing used for local
    // launcher discovery.  Keep this parsing behavior aligned with the
    // historical Simple.from_path implementation.
    public class CompatibilityToolLoader : Object {
        public static Models.CompatibilityTool from_path (string path) {
            var fallback_title = Path.get_basename (path);
            var tool = new Models.CompatibilityTool (fallback_title, fallback_title, path);
            /* A tool-owned Proton launcher is an explicit runtime fact.  This
             * avoids guessing from custom display titles while letting locally
             * installed Proton variants use common Proton capabilities. */
            if (FileUtils.test (Path.build_filename (path, "proton"), FileTest.IS_REGULAR))
                tool.runtime_kind = Models.CompatibilityToolRuntimeKind.PROTON;
            var compatibilitytoolvdf_path = "%s/compatibilitytool.vdf".printf (path);
            if (!FileUtils.test (compatibilitytoolvdf_path, FileTest.IS_REGULAR))
                return tool;

            var content = Filesystem.get_file_content (compatibilitytoolvdf_path);
            if (content == "")
                return tool;

            var start_text = "display_name\" \"";
            var start_pos = content.index_of (start_text, 0);
            if (start_pos != -1) {
                start_pos += start_text.length;
                var end_pos = content.index_of ("\"", start_pos);
                if (end_pos != -1)
                    tool.display_title = content.substring (start_pos, end_pos - start_pos);
            }

            start_text = "compat_tools\"";
            start_pos = content.index_of (start_text, 0);
            if (start_pos != -1) {
                start_pos += start_text.length;
                start_pos = content.index_of ("\"", start_pos);
                if (start_pos != -1) {
                    start_pos += "\"".length;
                    var end_pos = content.index_of ("\" // Internal name of this tool", start_pos);
                    if (end_pos != -1)
                        tool.internal_title = content.substring (start_pos, end_pos - start_pos);
                }
            }

            return tool;
        }
    }
}
