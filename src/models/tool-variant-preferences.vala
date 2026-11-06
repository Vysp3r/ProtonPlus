namespace ProtonPlus.Models {
    /// Owns the saved variant-name contract, including legacy display-name keys.
    public class ToolVariantPreferences : Object {
        private const string SETTINGS_KEY = "selected-tool-variants";
        private Settings? settings;

        public ToolVariantPreferences (Settings? settings) {
            this.settings = settings;
        }

        public string load (Tool tool) {
            return settings == null ? "" : read_json (settings.get_string (SETTINGS_KEY), tool);
        }

        public void save (Tool tool, string variant_name) {
            if (settings != null)
                settings.set_string (
                    SETTINGS_KEY, write_json (settings.get_string (SETTINGS_KEY), tool, variant_name)
                );
        }

        public static string read_json (string raw, Tool tool) {
            var values = parse_json (raw);
            var selected = string_member (values, tool.id);
            if (selected != "")
                return selected;

            var legacy_key = "%s::%s::%s".printf (
                tool.group.launcher.title, tool.group.title, tool.title
            );
            return string_member (values, legacy_key);
        }

        public static string write_json (string raw, Tool tool, string variant_name) {
            var values = parse_json (raw);
            // Keep legacy and unrelated entries intact. Only the current tool's
            // canonical key changes when a user chooses another variant.
            values.set_string_member (tool.id, variant_name);

            var node = new Json.Node (Json.NodeType.OBJECT);
            node.set_object (values);
            var generator = new Json.Generator ();
            generator.set_root (node);
            return generator.to_data (null);
        }

        private static Json.Object parse_json (string raw) {
            if (raw != "") {
                try {
                    var node = Json.from_string (raw);
                    if (node.get_node_type () == Json.NodeType.OBJECT)
                        return node.get_object ();
                } catch (Error e) {
                    // A damaged preference should not prevent browsing tools.
                }
            }
            return new Json.Object ();
        }

        private static string string_member (Json.Object values, string key) {
            var node = values.get_member (key);
            if (node == null || node.get_node_type () != Json.NodeType.VALUE ||
                node.get_value_type () != typeof (string))
                return "";
            return node.get_string () ?? "";
        }
    }
}
