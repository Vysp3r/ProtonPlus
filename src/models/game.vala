namespace ProtonPlus.Models {
    public struct AwacyGame {
        int appid;
        string name;
        string status;
    }

    public class Game : Object {
        public int appid { get; set; }
        public string name { get; set; }
        public string installdir { get; set; }
        public int library_folder_id { get; set; }
        public string library_folder_path { get; set; }
        public string awacy_name { get; set; }
        public string awacy_status { get; set; }
        public string compat_tool { get; set; }

        public Game(int appid, string name, string installdir, int library_folder_id, string library_folder_path) {
            this.appid = appid;
            this.name = name;
            this.installdir = installdir;
            this.library_folder_id = library_folder_id;
            this.library_folder_path = library_folder_path;
        }

        public static async List<Game> get_installed_games() {
            var games = new List<Game> ();

            var awacy_games = yield get_awacy_games();

            var compat_tool_mapping_table = yield get_compat_tool_mapping_table();

            var libraryfolder_content = Utils.Filesystem.get_file_content("/home/vysp3r/.steam/steam/steamapps/libraryfolders.vdf");
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
                        string[] excluded_appids = { "2230260", "1826330", "1161040", "1070560", "1391110", "1628350", "2180100", "228980" };
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
                        // message("start: %i, end: %i, current_name: %s", start_pos, end_pos, current_name);

                        if (/Proton \d+.\d+/.match(current_name))
                            continue;

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
                        game.compat_tool = compat_tool.replace("-", " ");
                        // message("compat_tool: %s".printf(compat_tool));

                        games.append(game);
                    }
                } else {
                    continue;
                }
            }

            return games;
        }

        static async List<AwacyGame?> get_awacy_games() {
            var games = new List<AwacyGame?> ();

            var json = yield Utils.Web.GET("https://raw.githubusercontent.com/AreWeAntiCheatYet/AreWeAntiCheatYet/refs/heads/master/games.json", false);

            if (json == null || json.contains("https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"))
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

                var game = AwacyGame();
                game.appid = appid;
                game.name = name;
                game.status = status;

                games.append(game);
            }

            return games;
        }

        static async HashTable<int, string> get_compat_tool_mapping_table() {
            var compat_tool_mapping_table = new HashTable<int, string> (null, null);

            var config_content = Utils.Filesystem.get_file_content("/home/vysp3r/.steam/steam/config/config.vdf");
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