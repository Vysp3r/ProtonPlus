namespace ProtonPlus.Models.Launchers {
    public class Steam : Launcher {
        public List<SteamProfile> profiles;
        public SteamProfile profile { get; set; }
 		public string default_compatibility_tool { get; set; }
        public HashTable<uint, string> compatibility_tool_hashtable;

        public Steam (Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "/.local/share/Steam",
                                             "/.steam/steam",
                                             "/.steam/root",
                                             "/.steam/debian-installation" };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "/.var/app/com.valvesoftware.Steam/data/Steam" };
                break;
            case Launcher.InstallationTypes.SNAP:
                directories = new string[] { "/snap/steam/common/.steam/root" };
                break;
            }

            base ("Steam", installation_type, "%s/steam.svg".printf (Globals.RESOURCE_BASE), directories);

            has_library_support = true;
        }

        public async void switch_profile (SteamProfile profile) {
            if (this.profile != null) {
                foreach (var non_steam_game in this.profile.non_steam_games) {
                    games.remove (non_steam_game);
                }
            }
            
            this.profile = profile;

            foreach(var game in (List<Games.Steam>) games) {
                var launch_options = profile.launch_options_hashtable.get(game.appid);
                game.launch_options = launch_options;
            }

            foreach (var non_steam_game in profile.non_steam_games) {
                games.append (non_steam_game);
            }
        }

        public override int get_compatibility_tool_usage_count (string compatibility_tool_name) {
            int count = 0;

            foreach (var game in games) {
                if (game.compatibility_tool == compatibility_tool_name)
                    count++;
            }

            return count;
        }

        public override async bool load_game_library() {
            games = new List<Game> ();

            compatibility_tools = new List<SimpleRunner> ();

            var awacy_games = yield Models.Games.Steam.AwacyGame.get_awacy_games();

            var compatibility_tool_hashtable_loaded = yield load_compatibility_tool_hashtable();
            if (!compatibility_tool_hashtable_loaded)
                return false;

            var default_compatibility_tool = compatibility_tool_hashtable.get(0);
            if (default_compatibility_tool != null)
                this.default_compatibility_tool = default_compatibility_tool;

            var libraryfolder_content = Utils.Filesystem.get_file_content("%s/steamapps/libraryfolders.vdf".printf(directory));

            if (libraryfolder_content.length > 0) {
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
                        end_pos = current_libraryfolder_content.index_of(end_text, start_pos);
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

                            uint id = 0;
                            var id_valid = uint.try_parse(current_appid, out id);
                            if (!id_valid)
                                continue;

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
                            current_name = current_manifest_content.substring(start_pos, end_pos - start_pos);
                            // message("start: %i, end: %i, current_name: %s", start_pos, end_pos, current_name);

                            if (/Proton \d+.\d+/.match(current_name) || current_appid == "2180100" || current_appid == "1493710") {
                                compatibility_tools.append(new SimpleRunner(current_name, current_name.down ().split (".", 2)[0].replace (" ", "_")));
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

                            var game = new Games.Steam(id, current_name, current_installdir, current_libraryfolder_id, current_libraryfolder_path, this);

                            foreach (var awacy_game in awacy_games) {
                                if (awacy_game.appid == game.appid) {
                                    game.awacy_name = awacy_game.name;
                                    game.awacy_status = awacy_game.status;
                                }
                            }

                            var compatibility_tool = compatibility_tool_hashtable.get(game.appid);
                            if (compatibility_tool == null)
                                compatibility_tool = "Undefined";
                            game.compatibility_tool = compatibility_tool;
                            // message("compatibility_tool: %s".printf(compatibility_tool));

                            games.append(game);
                        }
                    } else {
                        continue;
                    }
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

							if (file_info.get_name().contains ("wine-proton-exp")) {

							} else if (file_info.get_name() != "LegacyRuntime") {
								var file_path = "%s/%s".printf (directory.get_path (), file_info.get_name ());
								try {
									var simple_runner = new SimpleRunner.from_path(file_path);
                                	compatibility_tools.append(simple_runner);
								} catch (Error e) {
									message (e.message);
								}
							}
                        }
                    }
                }
            } catch (Error e) {
                message(e.message);
            }
            
            return true;
        }

        async bool load_compatibility_tool_hashtable() {
            compatibility_tool_hashtable = new HashTable<uint, string> (null, null);

            var config_content = Utils.Filesystem.get_file_content("%s/config/config.vdf".printf(directory));
            var compat_tool_mapping_content = "";
            var compat_tool_mapping_item = "";
            uint compat_tool_mapping_item_appid = 0;
            var compat_tool_mapping_item_name = "";
            var start_text = "";
            var end_text = "";
            var start_pos = 0;
            var end_pos = 0;
            var current_position = 0;

            start_text = "CompatToolMapping\"\n\t\t\t\t";

            if (!config_content.contains (start_text)) {
                compatibility_tool_hashtable.set (0, "proton_experimental");

                return true;
            }

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
                var compat_tool_mapping_item_appid_valid = uint.try_parse(compat_tool_mapping_item.substring(start_pos, end_pos - start_pos), out compat_tool_mapping_item_appid);
                if (!compat_tool_mapping_item_appid_valid)
                    continue;
                // message("start: %i, end: %i, compat_tool_mapping_item_appid: %i", start_pos, end_pos, compat_tool_mapping_item_appid);

                start_text = "name\"\t\t\"";
                end_text = "\"";
                start_pos = compat_tool_mapping_item.index_of(start_text, 0) + start_text.length;
                end_pos = compat_tool_mapping_item.index_of(end_text, start_pos);
                compat_tool_mapping_item_name = compat_tool_mapping_item.substring(start_pos, end_pos - start_pos);
                // message("start: %i, end: %i, compat_tool_mapping_item_name: %s", start_pos, end_pos, compat_tool_mapping_item_name);

                compatibility_tool_hashtable.set(compat_tool_mapping_item_appid, compat_tool_mapping_item_name);
            }

            return true;
        }

        public bool change_default_compatibility_tool (string compatibility_tool) {
			var default_id = 0;
			var config_path = "%s/config/config.vdf".printf (directory);
			var config_content = Utils.Filesystem.get_file_content (config_path);
			var compat_tool_mapping_content = "";
			var compat_tool_mapping_item = "";
			var compat_tool_mapping_item_appid = 0;
			var compat_tool_mapping_item_name = "";
			var start_text = "";
			var end_text = "";
			var start_pos = 0;
			var end_pos = 0;

			start_text = "\"CompatToolMapping\"\n\t\t\t\t{";
			end_text = "\n\t\t\t\t}";
			if (config_content.index_of(start_text, 0) == -1) {
				var start_steam_text = "\"Steam\"\n\t\t\t{";
				var start_steam_pos = config_content.index_of(start_steam_text, 0);
				var insert_pos = start_steam_pos + start_steam_text.length;
				config_content =
					config_content.substring(0, insert_pos) +
					"\n\t\t\t\t\"CompatToolMapping\"\n\t\t\t\t{\n\t\t\t\t}" +
					config_content.substring(insert_pos);
			}
			start_pos = config_content.index_of (start_text, 0) + start_text.length;
			end_pos = config_content.index_of (end_text, start_pos);
			compat_tool_mapping_content = config_content.substring (start_pos, end_pos - start_pos);
			// message("start: %i, end: %i, compat_tool_mapping_content: %s", start_pos, end_pos, compat_tool_mapping_content);

			if (compat_tool_mapping_content.contains ("\"%i\"".printf(default_id))) {
				start_text = "\t\t\t\t\t\"%i\"".printf (default_id);
				start_pos = compat_tool_mapping_content.index_of (start_text, 0);
				if (start_pos == -1)
					return false;

				end_text = "}";
				end_pos = compat_tool_mapping_content.index_of (end_text, start_pos + start_text.length) + end_text.length;
				if (end_pos == -1)
					return false;

				compat_tool_mapping_item = compat_tool_mapping_content.substring (start_pos, end_pos - start_pos);
				// message("start: %i, end: %i, compat_tool_mapping_item: %s", start_pos, end_pos, compat_tool_mapping_item);

				start_text = "\"";
				start_pos = compat_tool_mapping_item.index_of (start_text, 0) + start_text.length;
				if (start_pos == -1)
					return false;

				end_text = "\"";
				end_pos = compat_tool_mapping_item.index_of (end_text, start_pos);
				if (end_pos == -1)
					return false;

				var compat_tool_mapping_item_appid_valid = int.try_parse (compat_tool_mapping_item.substring (start_pos, end_pos - start_pos), out compat_tool_mapping_item_appid);
				if (!compat_tool_mapping_item_appid_valid)
					return false;
				// message("start: %i, end: %i, compat_tool_mapping_item_appid: %i", start_pos, end_pos, compat_tool_mapping_item_appid);

				if (compat_tool_mapping_item_appid != 0)
					return false;

				start_text = "name\"\t\t\"";
				start_pos = compat_tool_mapping_item.index_of (start_text, 0) + start_text.length;
				if (start_pos == -1)
					return false;

				end_text = "\"";
				end_pos = compat_tool_mapping_item.index_of (end_text, start_pos);
				if (end_pos == -1)
					return false;

				compat_tool_mapping_item_name = compat_tool_mapping_item.substring (start_pos, end_pos - start_pos);
				// message("start: %i, end: %i, compat_tool_mapping_item_name: %s", start_pos, end_pos, compat_tool_mapping_item_name);

				var compat_tool_mapping_item_modified = compat_tool_mapping_item.replace (compat_tool_mapping_item_name, compatibility_tool);

				config_content = config_content.replace (compat_tool_mapping_item, compat_tool_mapping_item_modified);
			} else {
				config_content =
					config_content.substring(0, start_pos) +
					"\n\t\t\t\t\t\"%i\"\n\t\t\t\t\t{\n".printf(default_id) +
                    "\t\t\t\t\t\t\"name\"\t\t\"%s\"\n".printf(compatibility_tool) +
                    "\t\t\t\t\t\t\"config\"\t\t\"\"\n" +
                    "\t\t\t\t\t\t\"priority\"\t\t\"75\"\n" +
                    "\t\t\t\t\t}" +
					config_content.substring(start_pos);
            }

            Utils.Filesystem.modify_file (config_path, config_content);

            this.default_compatibility_tool = compatibility_tool;

            return true;
		}
    }
}
