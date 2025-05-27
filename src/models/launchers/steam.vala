namespace ProtonPlus.Models.Launchers {
    public class Steam : Launcher {
        public List<Game> games;
        public List<RunnerDropDownItem> compat_tools;
        public static bool IS_SHORTCUT_INSTALLED = false;
        private Utils.VDF.Shortcuts shortcuts_file;
        private int shortcut_status = 0;

        public Steam (Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "/.local/share/Steam",
                                             "/.steam/root",
                                             "/.steam/steam",
                                             "/.steam/debian-installation" };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "/.var/app/com.valvesoftware.Steam/data/Steam" };
                break;
            case Launcher.InstallationTypes.SNAP:
                directories = new string[] { "/snap/steam/common/.steam/root" };
                break;
            }

            base ("Steam", installation_type, Config.RESOURCE_BASE + "/steam.png", directories);

            if (installed) {
                groups = get_groups ();
                install.connect ((release) => true);
                uninstall.connect ((release) => true);           
            }
        }

        Group[] get_groups () {
            var groups = new Group[1];

            groups[0] = new Group (_("Runners"), "", "/compatibilitytools.d", this);
            groups[0].runners = get_runners (groups[0]);

            return groups;
        }

        public static List<Runner> get_runners (Group group) {
            var runners = new List<Runner> ();

            runners.append (new Runners.Proton_GE (group));
            runners.append (new Runners.Proton_CachyOS (group));
            runners.append (new Runners.Proton_EM (group));
            runners.append (new Runners.Proton_Sarek (group));
            runners.append (new Runners.Proton_Sarek_Async (group));
            runners.append (new Runners.Proton_GE_RSTP (group));
            runners.append (new Runners.Proton_Tkg (group));
            runners.append (new Runners.Northstar_Proton (group));
            runners.append (new Runners.Luxtorpeda (group));
            runners.append (new Runners.Boxtron (group));
            runners.append (new Runners.Roberta (group));
            runners.append (new Runners.SteamTinkerLaunch (group));

            return runners;
        }

        public bool check_shortcut() {
            //TODO Make this check if the shortcut is installed or not
            return false;
        }

        public bool install_shortcut() {
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

                return true;
            } catch (Error e) {
                message(e.message);
                return false;
            }
        }

        public bool uninstall_shortcut() {
            try {
                shortcuts_file.remove_shortcut_by_name("ProtonPlus");
                shortcuts_file.save();
                return true;
            } catch (Error e) {
                message(e.message);
                return true;
            }
        }

        public class RunnerDropDownItem : Object {
            public string display_title { get; set; }
            public string title { get; set; }
        
            public RunnerDropDownItem(string display_title, bool format) {
                this.display_title = display_title;
                this.title = format ? display_title.down().split(".", 2)[0].replace(" ", "_") : display_title;
            }
        }

        public async bool load_library_data() {
            games = new List<Game> ();

            compat_tools = new List<RunnerDropDownItem> ();

            var awacy_games = yield get_awacy_games();

            var compat_tool_mapping_table = yield get_compat_tool_mapping_table();

            var libraryfolder_content = Utils.Filesystem.get_file_content("%s/steamapps/libraryfolders.vdf".printf(directory));
            var current_libraryfolder_content = "";
            var current_libraryfolder_id = 0;
            var current_libraryfolder_path = "";
            var current_apps = "";
            var current_appid = "";
            var current_steamapps_path = "";
            var current_manifest_path = "";
            var current_manifest_content = "";
            var current_name = "";
            var current_installdir = "";
            var start_text = "";
            var end_text = "";
            var start_pos = 0;
            var end_pos = 0;
            var current_position = 0;

            while (true) {
                start_text = "%i\"\n\t{".printf(current_libraryfolder_id++);
                end_text = "}";
                start_pos = libraryfolder_content.index_of(start_text, 0) + start_text.length;

                if (start_pos - start_text.length == -1)
                    break;

                end_pos = libraryfolder_content.index_of(end_text, start_pos);
                current_libraryfolder_content = libraryfolder_content.substring(start_pos, end_pos - start_pos);
                current_position = end_pos;

                if (current_libraryfolder_content.contains("apps")) {
                    end_pos = libraryfolder_content.index_of(end_text, current_position + 1);
                    current_libraryfolder_content = libraryfolder_content.substring(start_pos, end_pos - start_pos);
                    // message("current_libraryfolder_id: %i, start: %i, end: %i, current_libraryfolder_content: %s", current_libraryfolder_id, start_pos, end_pos, current_libraryfolder_content);

                    start_text = "path\"\t\t\"";
                    end_text = "\"";
                    start_pos = current_libraryfolder_content.index_of(start_text, 0) + start_text.length;
                    end_pos = current_libraryfolder_content.index_of(end_text, start_pos);
                    current_libraryfolder_path = current_libraryfolder_content.substring(start_pos, end_pos - start_pos);
                    current_position = end_pos;
                    // message("start: %i, end: %i, current_libraryfolder_path: %s", start_pos, end_pos, current_libraryfolder_path);

                    start_text = "apps\"\n\t\t{\n";
                    end_text = "}";
                    start_pos = current_libraryfolder_content.index_of(start_text, current_position) + start_text.length;
                    end_pos = current_libraryfolder_content.index_of(end_text, start_pos + start_text.length);
                    current_apps = current_libraryfolder_content.substring(start_pos, end_pos - start_pos);
                    current_position = 0;
                    // message("start: %i, end: %i, apps: %s", start_pos, end_pos, current_apps);

                    while (true) {
                        start_text = "\t\t\t\"";
                        end_text = "\"";
                        start_pos = current_apps.index_of(start_text, current_position) + start_text.length;

                        if (start_pos - start_text.length == -1)
                            break;

                        end_pos = current_apps.index_of(end_text, start_pos + start_text.length);
                        current_appid = current_apps.substring(start_pos, end_pos - start_pos);
                        current_position = end_pos;
                        // message("start: %i, end: %i, id: %s", start_pos, end_pos, current_appid);

                        bool valid_appid = true;
                        string[] excluded_appids = { "2230260", "1826330", "1161040", "1070560", "1391110", "1628350", "228980" };
                        foreach (var excluded_appid in excluded_appids) {
                            if (current_appid == excluded_appid) {
                                valid_appid = false;
                                break;
                            }
                        }
                        if (!valid_appid)
                            continue;

                        current_steamapps_path = "%s/steamapps".printf(current_libraryfolder_path);
                        if (!FileUtils.test(current_steamapps_path, FileTest.IS_DIR))
                            continue;

                        current_manifest_path = "%s/appmanifest_%s.acf".printf(current_steamapps_path, current_appid);
                        if (!FileUtils.test(current_manifest_path, FileTest.IS_REGULAR))
                            continue;
                        current_manifest_content = Utils.Filesystem.get_file_content(current_manifest_path);
                        // message("current_manifest_path: %s", current_manifest_path);

                        start_text = "name\"\t\t\"";
                        end_text = "\"";
                        start_pos = current_manifest_content.index_of(start_text, 0) + start_text.length;
                        end_pos = current_manifest_content.index_of(end_text, start_pos);
                        current_name = Markup.escape_text(current_manifest_content.substring(start_pos, end_pos - start_pos));
                        // message("start: %i, end: %i, current_name: %s %s", start_pos, end_pos, current_name);

                        if (/Proton \d+.\d+/.match(current_name) || current_appid == "2180100" || current_appid == "1493710") {
                            compat_tools.append(new RunnerDropDownItem(current_name, true));
                            continue;
                        }

                        start_text = "installdir\"\t\t\"";
                        end_text = "\"";
                        start_pos = current_manifest_content.index_of(start_text, 0) + start_text.length;
                        end_pos = current_manifest_content.index_of(end_text, start_pos);
                        current_installdir = current_manifest_content.substring(start_pos, end_pos - start_pos);
                        // message("start: %i, end: %i, current_installdir: %s", start_pos, end_pos, current_installdir);

                        if (!FileUtils.test("%s/common/%s".printf(current_steamapps_path, current_installdir), FileTest.IS_DIR))
                            continue;

                        var game = new Game(int.parse(current_appid), current_name, current_installdir, current_libraryfolder_id, current_libraryfolder_path);

                        foreach (var awacy_game in awacy_games) {
                            if (awacy_game.appid == game.appid) {
                                game.awacy_name = awacy_game.name;
                                game.awacy_status = awacy_game.status;
                            }
                        }

                        var compat_tool = compat_tool_mapping_table.get(game.appid);
                        if (compat_tool == null)
                            compat_tool = compat_tool_mapping_table.get(0);
                        game.compat_tool = compat_tool;
                        // message("compat_tool: %s".printf(compat_tool));

                        games.append(game);
                    }
                } else {
                    continue;
                }
            }

            try {
                foreach (var group in groups) {
                    File directory = File.new_for_path("%s%s".printf(directory, group.directory));
                    FileEnumerator? enumerator = directory.enumerate_children("standard::*", FileQueryInfoFlags.NONE, null);

                    if (enumerator != null) {
                        FileInfo? file_info;
                        while ((file_info = enumerator.next_file()) != null) {
                            if (file_info.get_file_type() != FileType.DIRECTORY)
                                continue;

                            if (file_info.get_name() != "LegacyRuntime")
                                compat_tools.append(new RunnerDropDownItem(file_info.get_name(), false));
                        }
                    }
                }
            } catch (Error e) {
                message(e.message);
            }
            
            return true;
        }

        async List<Models.AwacyGame?> get_awacy_games() {
            var games = new List<Models.AwacyGame?> ();

            var json = yield Utils.Web.GET("https://raw.githubusercontent.com/AreWeAntiCheatYet/AreWeAntiCheatYet/refs/heads/master/games.json", false);

            if (json == null)
                return games;

            var root_node = Utils.Parser.get_node_from_json(json);

            if (root_node == null)
                return games;

            if (root_node.get_node_type() != Json.NodeType.ARRAY)
                return games;

            var root_array = root_node.get_array();
            if (root_array == null)
                return games;

            for (var i = 0; i < root_array.get_length(); i++) {
                var object = root_array.get_object_element(i);

                var storeids_object = object.get_object_member("storeIds");
                if (storeids_object == null)
                    continue;

                if (!storeids_object.has_member("steam"))
                    continue;

                int appid = 0;
                if (!int.try_parse(storeids_object.get_string_member("steam"), out appid))
                    continue;

                if (!object.has_member("slug"))
                    continue;

                var name = object.get_string_member("slug");

                if (!object.has_member("status"))
                    continue;

                var status = object.get_string_member("status");

                // message("appid: %i, slug: %s, status: %s".printf(appid, name, status));

                var game = Models.AwacyGame();
                game.appid = appid;
                game.name = name;
                game.status = status;

                games.append(game);
            }

            return games;
        }

        async HashTable<int, string> get_compat_tool_mapping_table() {
            var compat_tool_mapping_table = new HashTable<int, string> (null, null);

            var config_content = Utils.Filesystem.get_file_content("%s/config/config.vdf".printf(directory));
            var compat_tool_mapping_content = "";
            var compat_tool_mapping_item = "";
            var compat_tool_mapping_item_appid = 0;
            var compat_tool_mapping_item_name = "";
            var start_text = "";
            var end_text = "";
            var start_pos = 0;
            var end_pos = 0;
            var current_position = 0;

            start_text = "CompatToolMapping\"\n\t\t\t\t";
            end_text = "\n\t\t\t\t}";
            start_pos = config_content.index_of(start_text, 0) + start_text.length;
            end_pos = config_content.index_of(end_text, start_pos);
            compat_tool_mapping_content = config_content.substring(start_pos, end_pos - start_pos);
            // message("start: %i, end: %i, compat_tool_mapping_content: %s", start_pos, end_pos, compat_tool_mapping_content);

            while (true) {
                start_text = "\"";
                end_text = "}";
                start_pos = compat_tool_mapping_content.index_of(start_text, current_position);

                if (start_pos == -1)
                    break;

                end_pos = compat_tool_mapping_content.index_of(end_text, start_pos) + 1;
                compat_tool_mapping_item = compat_tool_mapping_content.substring(start_pos, end_pos - start_pos);
                current_position = end_pos;
                // message("start: %i, end: %i, compat_tool_mapping_item: %s", start_pos, end_pos, compat_tool_mapping_item);

                start_text = "\"";
                end_text = "\"";
                start_pos = compat_tool_mapping_item.index_of(start_text, 0) + start_text.length;
                end_pos = compat_tool_mapping_item.index_of(end_text, start_pos);
                var compat_tool_mapping_item_appid_valid = int.try_parse(compat_tool_mapping_item.substring(start_pos, end_pos - start_pos), out compat_tool_mapping_item_appid);
                if (!compat_tool_mapping_item_appid_valid)
                    continue;
                // message("start: %i, end: %i, compat_tool_mapping_item_appid: %i", start_pos, end_pos, compat_tool_mapping_item_appid);

                start_text = "name\"\t\t\"";
                end_text = "\"";
                start_pos = compat_tool_mapping_item.index_of(start_text, 0) + start_text.length;
                end_pos = compat_tool_mapping_item.index_of(end_text, start_pos);
                compat_tool_mapping_item_name = compat_tool_mapping_item.substring(start_pos, end_pos - start_pos);
                // message("start: %i, end: %i, compat_tool_mapping_item_name: %s", start_pos, end_pos, compat_tool_mapping_item_name);

                compat_tool_mapping_table.set(compat_tool_mapping_item_appid, compat_tool_mapping_item_name);
            }

            return compat_tool_mapping_table;
        }
    }
}