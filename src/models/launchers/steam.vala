namespace ProtonPlus.Models.Launchers {
    public class Steam : Launcher {
        public List<SteamProfile> profiles;
        public SteamProfile profile { get; set; }
 		public string default_compatibility_tool { get; set; }
        public bool enable_default_compatibility_tool { get; set; }

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

            base ("Steam", installation_type, Globals.RESOURCE_BASE + "/steam.png", directories);

            has_library_support = true;

            if (installed) {
                groups = get_groups ();
                install.connect ((release) => true);
                uninstall.connect ((release) => true);

                profiles = SteamProfile.get_profiles(this);
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
            runners.append (new Runners.Proton_Kron4ek (group));
            runners.append (new Runners.Northstar_Proton (group));
            runners.append (new Runners.Luxtorpeda (group));
            runners.append (new Runners.Boxtron (group));
            runners.append (new Runners.Roberta (group));
            runners.append (new Runners.SteamTinkerLaunch (group));

            return runners;
        }

        public int get_compatibility_tool_usage_count (string compatibility_tool_name) {
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

            var compatibility_tool_hashtable = yield get_compatibility_tool_hashtable();

 			var default_compatibility_tool = compatibility_tool_hashtable.get(0);
            enable_default_compatibility_tool = default_compatibility_tool != null;
 			if (enable_default_compatibility_tool)
 				this.default_compatibility_tool = default_compatibility_tool;

            var launch_options_hashtable = yield get_launch_options_hashtable();

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

                        var id = 0;
                        var id_valid = int.try_parse(current_appid, out id);
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

                        var launch_options = launch_options_hashtable.get(game.appid);
                        if (launch_options == null)
                            launch_options = "";
                        game.launch_options = launch_options;
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

        async HashTable<int, string> get_compatibility_tool_hashtable() {
            var compatibility_tool_hashtable = new HashTable<int, string> (null, null);

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

                compatibility_tool_hashtable.set(compat_tool_mapping_item_appid, compat_tool_mapping_item_name);
            }

            return compatibility_tool_hashtable;
        }

        async HashTable<int, string> get_launch_options_hashtable() {
            var launch_options_hashtable = new HashTable<int, string> (null, null);

            var content = Utils.Filesystem.get_file_content(profile.localconfig_path);
            var start_text = "";
            var end_text = "";
            var start_pos = 0;
            var end_pos = 0;
            var apps = "";
            var app = "";
            var id_text = "";
            var id_valid = false;
            var id = 0;
            var launch_options = "";

            start_text = "apps\"\n\t\t\t\t{";
            start_pos = content.index_of(start_text, 0) + start_text.length;

            if (start_pos == -1)
                return launch_options_hashtable;

            end_text = "\n\t\t\t\t}";
            end_pos = content.index_of(end_text, start_pos);

            if (end_pos == -1)
                return launch_options_hashtable;

            apps = content.substring(start_pos, end_pos - start_pos);
            // message("start: %i, end: %i, apps: %s", start_pos, end_pos, apps);

            var position = 0;
            while (true) {
                start_text = "\"";
                start_pos = apps.index_of(start_text, position);

                if (start_pos == -1)
                    break;

                end_text = "\n\t\t\t\t\t}";
                position = end_pos = apps.index_of(end_text, start_pos + start_text.length) + end_text.length;

                if (end_pos == -1)
                    break;

                app = apps.substring(start_pos, end_pos - start_pos);
                // message("start: %i, end: %i, app: %s", start_pos, end_pos, app);

                if (app.contains("LaunchOptions")) {
                    start_text = "\"";
                    start_pos = app.index_of(start_text, 0) + start_text.length;

                    if (start_pos == -1)
                        break;

                    end_text = "\"";
                    end_pos = app.index_of(end_text, start_pos);

                    if (end_pos == -1)
                        break;
                        
                    id_text = app.substring(start_pos, end_pos - start_pos);
                    // message("start: %i, end: %i, id: %s", start_pos, end_pos, id_text);

                    id_valid = int.try_parse(id_text, out id);
                    if(!id_valid)
                        break;

                    start_text = "LaunchOptions\"\t\t\"";
                    start_pos = app.index_of(start_text, 0) + start_text.length;

                    if (start_pos == -1)
                        break;

                    end_text = "\"";
                    end_pos = app.index_of(end_text, start_pos);

                    if (end_pos == -1)
                        break;
                        
                    launch_options = app.substring(start_pos, end_pos - start_pos);
                    // message("start: %i, end: %i, launch_options: %s", start_pos, end_pos, launch_options);

                    launch_options_hashtable.set(id, launch_options);
                }
            }

            return launch_options_hashtable;
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

			start_text = "CompatToolMapping\"\n\t\t\t\t{\n";
			end_text = "\n\t\t\t\t}";
			start_pos = config_content.index_of (start_text, 0) + start_text.length;
			end_pos = config_content.index_of (end_text, start_pos);
			compat_tool_mapping_content = config_content.substring (start_pos, end_pos - start_pos);
			// message("start: %i, end: %i, compat_tool_mapping_content: %s", start_pos, end_pos, compat_tool_mapping_content);

			if (compat_tool_mapping_content.contains (default_id.to_string ())) {
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

				Utils.Filesystem.modify_file (config_path, config_content);

				this.default_compatibility_tool = compatibility_tool;

				return true;
			}

			return false;
		}
    }
}
