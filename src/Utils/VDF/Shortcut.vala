namespace VDF {
    public struct Shortcut {
        uint32 AppID;
        bool AllowDesktopConfig;
        bool AllowOverlay;
        string AppName;
        uint32 Devkit;
        string DevkitGameID;
        uint32 DevkitOverrideAppID;
        string Exe;
        string FlatpakAppID;
        bool IsHidden;
        uint32 LastPlayTime;
        string LaunchOptions;
        uint32 OpenVR;
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
                        shortcut.AppID = (uint32) entry.value.get("appid").get_int32();
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
                    }
                }
            }
        }

        private void write_shortcut_on_node(VDF.Node node, VDF.Shortcut shortcut) {
            node.set("appid", new GLib.Variant.uint32(shortcut.AppID));
            node.set("AllowDesktopConfig", new GLib.Variant.uint32(shortcut.AllowDesktopConfig ? 1 : 0));
            node.set("AllowOverlay", new GLib.Variant.uint32(shortcut.AllowOverlay ? 1 : 0));
            node.set("AppName", new GLib.Variant.string(shortcut.AppName));
            node.set("Devkit", new GLib.Variant.uint32(shortcut.Devkit));
            node.set("DevkitGameID", new GLib.Variant.string(shortcut.DevkitGameID));
            node.set("DevkitOverrideAppID", new GLib.Variant.uint32(shortcut.DevkitOverrideAppID));
            node.set("Exe", new GLib.Variant.string(shortcut.Exe));
            node.set("FlatpakAppID", new GLib.Variant.string(shortcut.FlatpakAppID));
            node.set("IsHidden", new GLib.Variant.uint32(shortcut.IsHidden ? 1 : 0));
            node.set("LastPlayTime", new GLib.Variant.uint32(shortcut.LastPlayTime));
            node.set("LaunchOptions", new GLib.Variant.string(shortcut.LaunchOptions));
            node.set("OpenVR", new GLib.Variant.uint32(shortcut.OpenVR));
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
    }
}