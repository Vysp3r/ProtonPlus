namespace ProtonPlus.Utils {
    public class Metadata : Object {
        private const string FILENAME = ".protonplus";

        public string runner_endpoint { get; set; default = ""; }
        public string runner_title { get; set; default = ""; }
        public string tag { get; set; default = ""; }
        public string provider_id { get; set; default = ""; }
        public string tool_id { get; set; default = ""; }
        public string launcher_id { get; set; default = ""; }
        public string variant_id { get; set; default = ""; }
        public string release_id { get; set; default = ""; }

        public static Metadata load (string directory_path) {
            var metadata = new Metadata ();
            var metadata_path = Path.build_filename (directory_path, FILENAME);

            if (FileUtils.test (metadata_path, FileTest.IS_REGULAR)) {
                var root_node = Parser.get_node_from_json (Filesystem.get_file_content (metadata_path));
                if (root_node != null && root_node.get_node_type () == Json.NodeType.OBJECT) {
                    var root_object = root_node.get_object ();
                    metadata.runner_endpoint = root_object.get_string_member_with_default ("runner_endpoint", "");
                    metadata.runner_title = root_object.get_string_member_with_default ("runner_title", "");
                    metadata.tag = root_object.get_string_member_with_default ("tag", "");
                    metadata.provider_id = root_object.get_string_member_with_default ("provider_id", "");
                    metadata.tool_id = root_object.get_string_member_with_default ("tool_id", "");
                    metadata.launcher_id = root_object.get_string_member_with_default ("launcher_id", "");
                    metadata.variant_id = root_object.get_string_member_with_default ("variant_id", "");
                    metadata.release_id = root_object.get_string_member_with_default ("release_id", "");
                    return metadata;
                }
            }

            return metadata;
        }

        public bool save (string directory_path) {
            var root_object = new Json.Object ();
            root_object.set_string_member ("runner_endpoint", runner_endpoint);
            root_object.set_string_member ("runner_title", runner_title);
            root_object.set_string_member ("tag", tag);
            root_object.set_string_member ("provider_id", provider_id);
            root_object.set_string_member ("tool_id", tool_id);
            root_object.set_string_member ("launcher_id", launcher_id);
            root_object.set_string_member ("variant_id", variant_id);
            root_object.set_string_member ("release_id", release_id);

            var root_node = new Json.Node (Json.NodeType.OBJECT);
            root_node.set_object (root_object);
            var generator = new Json.Generator ();
            generator.set_root (root_node);

            var metadata_path = Path.build_filename (directory_path, FILENAME);
            if (!Filesystem.modify_file (metadata_path, generator.to_data (null)))
                return false;

            return true;
        }
    }
}
