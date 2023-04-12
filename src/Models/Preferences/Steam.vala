namespace Models.Preferences {
    public class Steam : Object {
        private Utils.VDF.Shortcuts shortcuts_file;
        private int shortcut_status = 0;

        private string getShortcutLocation() throws Error {
            string[] locations = {
                "/.local/share/Steam",
                "/.steam/root",
                "/.steam/steam",
                "/.steam/debian-installation",
                "/.var/app/com.valvesoftware.Steam/data/Steam",
                "/snap/steam/common/.steam/root"
            };
            try {
                foreach (var location in locations) {
                    string path = GLib.Environment.get_home_dir() + location + "/userdata";
                    stdout.printf("trying %s\n", path);
                    if (FileUtils.test(path, FileTest.IS_DIR)) {
                        Dir directory = Dir.open(path);
                        string? dir;
                        while ((dir = directory.read_name()) != null) {
                            stdout.printf("trying %s\n", path + "/" + dir);
                            if (dir != "." && dir != "..") {
                                File file = File.new_for_path(path + "/" + dir);
                                if (file.query_file_type(FileQueryInfoFlags.NONE) == FileType.DIRECTORY) {
                                    stdout.printf("trying %s\n", path + "/" + dir + "/config/shortcuts.vdf");
                                    if (FileUtils.test(path + "/" + dir + "/config/shortcuts.vdf", FileTest.IS_REGULAR)) {
                                        stdout.printf("found %s\n", path + "/" + dir + "/config/shortcuts.vdf");
                                        path += "/" + dir + "/config/shortcuts.vdf";
                                        return path;
                                    } else {
                                        path += "/" + dir + "/config/shortcuts.vdf";
                                        Utils.VDF.Shortcuts.create_new_shortcuts_file_at(path);
                                        return path;
                                    }
                                }
                            }
                        }
                        break;
                    }
                }
            } catch (Error e) {
                throw e;
            }

            throw new GLib.Error(GLib.Quark.from_string("vala-vdf"), 0, "Shortcut file not found");
        }

        public Steam() throws Error {
            try {
                var path = getShortcutLocation();
                shortcuts_file = new Utils.VDF.Shortcuts(path);
            } catch (Error e) {
                throw e;
            }
        }

        public bool isShortcutInstalled() {
            var pp_shortcut = shortcuts_file.get_shortcut_by_name("ProtonPlus");

            if (pp_shortcut.AppName == null) {
                shortcut_status = 1;
                return false;
            }
            shortcut_status = 2;
            return true;
        }

        private void uninstall() throws Error {
            try {
                shortcuts_file.remove_shortcut_by_name("ProtonPlus");
                shortcuts_file.save();
            } catch (Error e) {
                throw e;
            }
        }

        private void install() throws Error {
            Utils.VDF.Shortcut pp_shortcut = {};

            try {
                pp_shortcut.AppID = 0;
                pp_shortcut.AllowDesktopConfig = true;
                pp_shortcut.AllowOverlay = true;
                pp_shortcut.AppName = "ProtonPlus";
                pp_shortcut.Devkit = 0;
                pp_shortcut.DevkitGameID = "\0";
                pp_shortcut.DevkitOverrideAppID = 0;
                pp_shortcut.Exe = "\"/usr/bin/flatpak\"";
                pp_shortcut.FlatpakAppID = "";
                pp_shortcut.IsHidden = false;
                pp_shortcut.LastPlayTime = 0;
                pp_shortcut.LaunchOptions = "\"run\" \"--branch=stable\" \"--arch=x86_64\" \"--command=com.vysp3r.ProtonPlus\" \"com.vysp3r.ProtonPlus\"";
                pp_shortcut.OpenVR = 0;
                pp_shortcut.ShortcutPath = "/var/lib/flatpak/exports/share/applications/com.vysp3r.ProtonPlus.desktop";
                pp_shortcut.StartDir = "\"/usr/bin/\"";
                pp_shortcut.Icon = "\0";

                shortcuts_file.append_shortcut(pp_shortcut);
                shortcuts_file.save();
            } catch (Error e) {
                throw e;
            }
        }

        public void toggleState() throws Error {
            try {
                switch (shortcut_status) {
                case 0:
                    throw new GLib.Error(GLib.Quark.from_string("vala-vdf"), 0, _("Shortcut file not found"));
                case 1:
                    install();
                    shortcut_status = 2;
                    break;
                case 2:
                    uninstall();
                    shortcut_status = 1;
                    break;
                }
            } catch (Error e) {
                throw e;
            }
        }
    }
}
