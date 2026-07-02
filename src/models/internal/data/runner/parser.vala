using GLib;
using Json;
using Gee;

namespace ProtonPlus.Models.Internal.Data.Runner {

    public class Parser : GLib.Object {

        public static Root ? parse_runners_json (string json_data) {
            var parser = new Json.Parser ();

            try {
                parser.load_from_data (json_data, -1);

                var root_node = parser.get_root ();
                if (root_node == null || root_node.get_node_type () != Json.NodeType.OBJECT) {
                    return null;
                }

                var root_obj = root_node.get_object ();
                var root = new Root ();

                if (!parse_version (root_obj, root)) {
                    return null;
                }

                parse_compat_layers (root_obj, root);

                parse_launchers (root_obj, root);

                return root;
            } catch (Error e) {
                stderr.printf ("Chyba při parsování JSONu: %s\n", e.message);
                return null;
            }
        }

        public static bool parse_version (Json.Object root_obj, Root root) {
            if (root_obj.has_member ("version")) {
                var version_node = root_obj.get_member ("version");

                if (version_node.get_node_type () != Json.NodeType.VALUE) {
                    return false;
                }

                var val_type = version_node.get_value_type ();
                if (val_type != typeof (int64) && val_type != typeof (int)) {
                    return false;
                }

                root.version = (int) root_obj.get_int_member ("version");
            }
            return true;
        }

        public static void parse_compat_layers (Json.Object root_obj, Root root) {
            if (!root_obj.has_member ("compat_layers"))return;

            var layers_array = root_obj.get_array_member ("compat_layers");
            foreach (var element_node in layers_array.get_elements ()) {
                if (element_node.get_node_type () != Json.NodeType.OBJECT)continue;

                var group_obj = element_node.get_object ();
                var group = new CompatLayerGroup ();

                if (group_obj.has_member ("title"))group.title = group_obj.get_string_member ("title");
                if (group_obj.has_member ("description"))group.description = group_obj.get_string_member ("description");

                if (group_obj.has_member ("runners")) {
                    parse_runners (group_obj.get_array_member ("runners"), group);
                }

                root.compat_layers.add (group);
            }
        }

        public static void parse_runners (Json.Array runners_array, CompatLayerGroup group) {
            foreach (var runner_node in runners_array.get_elements ()) {
                if (runner_node.get_node_type () != Json.NodeType.OBJECT)continue;

                var runner_obj = runner_node.get_object ();
                var runner = new Runner ();

                if (runner_obj.has_member ("title"))runner.title = runner_obj.get_string_member ("title");
                if (runner_obj.has_member ("description"))runner.description = runner_obj.get_string_member ("description");
                if (runner_obj.has_member ("endpoint"))runner.endpoint = runner_obj.get_string_member ("endpoint");
                if (runner_obj.has_member ("support_latest"))runner.support_latest = runner_obj.get_boolean_member ("support_latest");
                if (runner_obj.has_member ("tag"))runner.tag = runner_obj.get_string_member ("tag");
                if (runner_obj.has_member ("type"))runner.runner_type = runner_obj.get_string_member ("type");

                if (runner_obj.has_member ("directory_name_format"))runner.directory_name_format = runner_obj.get_string_member ("directory_name_format");
                if (runner_obj.has_member ("url_template"))runner.url_template = runner_obj.get_string_member ("url_template");
                if (runner_obj.has_member ("legacy"))runner.legacy = runner_obj.get_boolean_member ("legacy");

                if (runner_obj.has_member ("directory_name_formats")) {
                    parse_directory_formats (runner_obj.get_array_member ("directory_name_formats"), runner);
                }

                if (runner_obj.has_member ("variants")) {
                    parse_variants (runner_obj.get_array_member ("variants"), runner);
                }

                parse_asset_lists (runner_obj, runner);

                group.runners.add (runner);
            }
        }
        public static void parse_variants (Json.Array formats_array, Runner runner) {
            foreach (var format_node in formats_array.get_elements ()) {
                if (format_node.get_node_type () != Json.NodeType.OBJECT)continue;

                var f_obj = format_node.get_object ();
                var format = new RunnerVariant ();
                if (f_obj.has_member ("name"))format.name = f_obj.get_string_member ("name");
                if (f_obj.has_member ("format"))format.format = f_obj.get_string_member ("format");
                if (f_obj.has_member ("default"))format.is_default = f_obj.get_boolean_member_with_default ("default", false);

                runner.variants.add (format);
            }
        }

        public static void parse_directory_formats (Json.Array formats_array, Runner runner) {
            foreach (var format_node in formats_array.get_elements ()) {
                if (format_node.get_node_type () != Json.NodeType.OBJECT)continue;

                var f_obj = format_node.get_object ();
                var format = new DirectoryNameFormat ();
                if (f_obj.has_member ("launcher"))format.launcher = f_obj.get_string_member ("launcher");
                if (f_obj.has_member ("directory_name_format"))format.directory_name_format = f_obj.get_string_member ("directory_name_format");

                runner.directory_name_formats.add (format);
            }
        }

        public static void parse_asset_lists (Json.Object runner_obj, Runner runner) {
            if (runner_obj.has_member ("request_asset_exclude") && !runner_obj.get_member ("request_asset_exclude").is_null ()) {
                runner.request_asset_exclude = new ArrayList<string> ();
                var exclude_array = runner_obj.get_array_member ("request_asset_exclude");
                foreach (var str_node in exclude_array.get_elements ()) {
                    runner.request_asset_exclude.add (str_node.get_string ());
                }
            }

            if (runner_obj.has_member ("request_asset_filter") && !runner_obj.get_member ("request_asset_filter").is_null ()) {
                runner.request_asset_filter = new ArrayList<string> ();
                var filter_array = runner_obj.get_array_member ("request_asset_filter");
                foreach (var str_node in filter_array.get_elements ()) {
                    runner.request_asset_filter.add (str_node.get_string ());
                }
            }
        }

        public static void parse_launchers (Json.Object root_obj, Root root) {
            if (!root_obj.has_member ("launchers"))return;

            var launchers_array = root_obj.get_array_member ("launchers");
            foreach (var element_node in launchers_array.get_elements ()) {
                if (element_node.get_node_type () != Json.NodeType.OBJECT)continue;

                var launcher_obj = element_node.get_object ();
                var launcher = new Launcher ();
                if (launcher_obj.has_member ("title"))launcher.title = launcher_obj.get_string_member ("title");

                if (launcher_obj.has_member ("compat_layers")) {
                    var cl_array = launcher_obj.get_array_member ("compat_layers");
                    foreach (var cl_node in cl_array.get_elements ()) {
                        if (cl_node.get_node_type () != Json.NodeType.OBJECT)continue;

                        var cl_obj = cl_node.get_object ();
                        var cl = new LauncherCompatLayer ();
                        if (cl_obj.has_member ("title"))cl.title = cl_obj.get_string_member ("title");
                        if (cl_obj.has_member ("directory"))cl.directory = cl_obj.get_string_member ("directory");

                        launcher.compat_layers.add (cl);
                    }
                }
                root.launchers.add (launcher);
            }
        }
    }
}
