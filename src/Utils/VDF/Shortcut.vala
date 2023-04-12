namespace Utils {
    namespace VDF {
        public struct Shortcut {
            int32 AppID;
            bool AllowDesktopConfig;
            bool AllowOverlay;
            string AppName;
            int32 Devkit;
            string DevkitGameID;
            int32 DevkitOverrideAppID;
            string Exe;
            string FlatpakAppID;
            bool IsHidden;
            int32 LastPlayTime;
            string LaunchOptions;
            int32 OpenVR;
            string ShortcutPath;
            string StartDir;
            string Icon;
            VDF.Node shortcut_node;
            VDF.Node shortcut_node_tags;
        }

        public class Shortcuts : VDF.Binary {
            public Shortcuts(string path) {
                base(path);
            }

            public size_t get_shortcuts_count() {
                size_t count = 0;
                foreach (var entry in nodes.entries) {
                    if (entry.key.contains("shortcuts.") && !entry.key.contains(".tags")) {
                        count++;
                    }
                }
                return count;
            }

            public VDF.Shortcut get_shortcut_by_name(string name) {
                VDF.Shortcut shortcut = {};
                foreach (var entry in nodes.entries) {
                    if (entry.key.contains("shortcuts.") && !entry.key.contains(".tags")) {
                        if (entry.value.get("AppName").get_string() == name) {
                            shortcut.AppID = entry.value.get("appid").get_int32();
                            shortcut.AllowDesktopConfig = entry.value.get("AllowDesktopConfig").get_int32() > 0 ? true : false;
                            shortcut.AllowOverlay = entry.value.get("AllowOverlay").get_int32() > 0 ? true : false;
                            shortcut.AppName = entry.value.get("AppName").get_string();
                            shortcut.Devkit = entry.value.get("Devkit").get_int32();
                            shortcut.DevkitGameID = entry.value.get("DevkitGameID").get_string();
                            shortcut.DevkitOverrideAppID = entry.value.get("DevkitOverrideAppID").get_int32();
                            shortcut.Exe = entry.value.get("Exe").get_string();
                            shortcut.FlatpakAppID = entry.value.get("FlatpakAppID").get_string();
                            shortcut.IsHidden = entry.value.get("IsHidden").get_int32() > 0 ? true : false;
                            shortcut.LastPlayTime = entry.value.get("LastPlayTime").get_int32();
                            shortcut.LaunchOptions = entry.value.get("LaunchOptions").get_string();
                            shortcut.OpenVR = entry.value.get("OpenVR").get_int32();
                            shortcut.ShortcutPath = entry.value.get("ShortcutPath").get_string();
                            shortcut.StartDir = entry.value.get("StartDir").get_string();
                            shortcut.Icon = entry.value.get("icon").get_string();
                        }
                    }
                }
                return shortcut;
            }

            public void replace_shortcut_by_name(string name, VDF.Shortcut shortcut) {
                foreach (var entry in nodes.entries) {
                    if (entry.key.contains("shortcuts.") && !entry.key.contains(".tags")) {
                        if (entry.value.get("AppName").get_string() == name) {
                            write_shortcut_on_node(entry.value, shortcut);
                            return;
                        }
                    }
                }
            }

            public int get_shortcut_id_by_name(string name) throws Error {
                foreach (var entry in nodes.entries) {
                    if (entry.key.contains("shortcuts.") && !entry.key.contains(".tags")) {
                        if (entry.value.get("AppName").get_string() == name) {
                            return int.parse(entry.key.split(".")[1]);
                        }
                    }
                }


                throw new GLib.Error(GLib.Quark.from_string("vala-vdf"), 0, @"Could not find the shortcut named $(name).");
            }

            public void remove_shortcut_by_name(string name) throws Error {
                try {
                    Gee.TreeMap<string, unowned VDF.Node> new_nodes = new Gee.TreeMap<string, unowned VDF.Node> ();
                    var node_base_id = get_shortcut_id_by_name(name);
                    var node_base_name = @"shortcuts.$(node_base_id)";

                    foreach (var entry in nodes.entries) {
                        if (!entry.key.contains(node_base_name)) {
                            var curr_key = entry.key;
                            if (entry.key.contains(".")) {
                                var curr_id = int.parse(entry.key.split(".")[1]);
                                var new_id = curr_id - 1;
                                if (curr_id > node_base_id) {
                                    curr_key = curr_key.replace(curr_id.to_string("%d"), new_id.to_string("%d"));
                                }
                            }
                            new_nodes.set(curr_key, entry.value);
                        }
                    }

                    nodes = new_nodes;
                } catch (Error e) {
                    throw e;
                }
            }

            private void write_shortcut_on_node(VDF.Node node, VDF.Shortcut shortcut) {
                node.set("appid", new GLib.Variant.int32(shortcut.AppID));
                node.set("AllowDesktopConfig", new GLib.Variant.int32(shortcut.AllowDesktopConfig ? 1 : 0));
                node.set("AllowOverlay", new GLib.Variant.int32(shortcut.AllowOverlay ? 1 : 0));
                node.set("AppName", new GLib.Variant.string(shortcut.AppName));
                node.set("Devkit", new GLib.Variant.int32(shortcut.Devkit));
                node.set("DevkitGameID", new GLib.Variant.string(shortcut.DevkitGameID));
                node.set("DevkitOverrideAppID", new GLib.Variant.int32(shortcut.DevkitOverrideAppID));
                node.set("Exe", new GLib.Variant.string(shortcut.Exe));
                node.set("FlatpakAppID", new GLib.Variant.string(shortcut.FlatpakAppID));
                node.set("IsHidden", new GLib.Variant.int32(shortcut.IsHidden ? 1 : 0));
                node.set("LastPlayTime", new GLib.Variant.int32(shortcut.LastPlayTime));
                node.set("LaunchOptions", new GLib.Variant.string(shortcut.LaunchOptions));
                node.set("OpenVR", new GLib.Variant.int32(shortcut.OpenVR));
                node.set("ShortcutPath", new GLib.Variant.string(shortcut.ShortcutPath));
                node.set("StartDir", new GLib.Variant.string(shortcut.StartDir));
                node.set("icon", new GLib.Variant.string(shortcut.Icon));
            }

            public void append_shortcut(VDF.Shortcut shortcut) {
                var new_node_id = get_shortcuts_count();
                shortcut.shortcut_node = new VDF.Node(@"shortcuts.$(new_node_id)");
                shortcut.shortcut_node_tags = new VDF.Node(@"shortcuts.$(new_node_id).tags");

                write_shortcut_on_node(shortcut.shortcut_node, shortcut);

                nodes.set(@"shortcuts.$(new_node_id)", shortcut.shortcut_node);
                nodes.set(@"shortcuts.$(new_node_id).tags", shortcut.shortcut_node_tags);
            }

            public static void create_new_shortcuts_file_at(string path) throws Error {
                try {
                    var new_vdf = GLib.File.new_for_path(path);
                    var new_vdf_stream = new_vdf.create(FileCreateFlags.PRIVATE);
                    var data_stream = new DataOutputStream(new_vdf_stream);
                    data_stream.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);
                    data_stream.put_byte('\x00');
                    data_stream.put_string("shortcuts");
                    data_stream.put_byte('\x00');
                    data_stream.put_byte('\x08');
                    data_stream.put_byte('\x08');
                } catch (Error e) {
                    throw e;
                }
            }
        }
    }
}
