namespace ProtonPlus.Utils.VDF {
    // Owns the narrowly scoped compatibilitytool.vdf parsing used for local
    // launcher discovery.  Keep this parsing behavior aligned with the
    // historical Simple.from_path implementation.
    public class CompatibilityToolLoader : Object {
        public static Models.CompatibilityTool? try_from_paths (
            string path,
            string inspection_path,
            bool externally_managed = false
        ) {
            Posix.Stat root_stat;
            if (Posix.lstat (inspection_path, out root_stat) != 0 || !Posix.S_ISDIR (root_stat.st_mode))
                return null;

            var manifest_path = Path.build_filename (inspection_path, "compatibilitytool.vdf");
            Posix.Stat manifest_stat;
            if (Posix.lstat (manifest_path, out manifest_stat) != 0 || !Posix.S_ISREG (manifest_stat.st_mode))
                return null;

            var document = VdfParser.parse_document (Filesystem.get_file_content (manifest_path));
            if (document == null)
                return null;
            var compatibility_tools = find_compat_tools ((!) document);
            if (compatibility_tools == null || compatibility_tools.children.size == 0)
                return null;

            var definition = compatibility_tools.children[0];
            var internal_title = definition.key.strip ();
            if (!valid_internal_title (internal_title))
                return null;

            var display_name = definition.get_child ("display_name");
            var display_title = display_name?.value ?? internal_title;
            if (display_title.strip () == "")
                display_title = internal_title;

            var tool = new Models.CompatibilityTool (
                display_title, internal_title, path,
                Models.CompatibilityToolRuntimeKind.UNKNOWN,
                inspection_path, externally_managed
            );
            Posix.Stat proton_stat;
            if (Posix.lstat (Path.build_filename (inspection_path, "proton"), out proton_stat) == 0
                && Posix.S_ISREG (proton_stat.st_mode))
                tool.runtime_kind = Models.CompatibilityToolRuntimeKind.PROTON;
            return tool;
        }

        private static VdfEntry? find_compat_tools (VdfDocument document) {
            var compatibility_tools = document.root.get_child ("compat_tools");
            if (compatibility_tools != null)
                return compatibility_tools;

            var manifest = document.root.get_child ("compatibilitytools");
            return manifest?.get_child ("compat_tools");
        }

        public static Models.CompatibilityTool from_path (string path) {
            var parsed = try_from_paths (path, path);
            if (parsed != null)
                return (!) parsed;

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

        private static bool valid_internal_title (string value) {
            if (value == "" || value == "." || value == ".."
                || value.contains ("/") || value.contains ("\\"))
                return false;
            for (var index = 0; index < value.length; index++) {
                if (value[index] < 0x20 || value[index] == 0x7f)
                    return false;
            }
            return true;
        }
    }
}
