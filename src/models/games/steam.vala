namespace ProtonPlus.Models.Games {
	public class Steam : Game {
		public uint appid { get; set; }
		public int library_folder_id { get; set; }
		public string library_folder_path { get; set; }
		public string awacy_name { get; set; }
		public string awacy_status { get; set; }
		public string launch_options { get; set; }
		public bool is_non_steam { get; set; }

		public Steam(uint appid, string name, string game_folder_name, int library_folder_id, string library_folder_path, Launchers.Steam launcher) {
			base(name, "%s/steamapps/common/%s".printf(library_folder_path, game_folder_name), "%s/steamapps/compatdata/%u".printf(library_folder_path, appid), appid, launcher);

			this.appid = appid;
			this.library_folder_id = library_folder_id;
			this.library_folder_path = library_folder_path;
			this.launcher = launcher;
		}

		public Steam.non_steam (uint appid, string name, string launch_options, string compatibility_tool, Launchers.Steam launcher) {
			base (name, "", "%s/steamapps/compatdata/%u".printf(launcher.directory, appid), appid, launcher);
			
			this.appid = appid;
			this.launch_options = launch_options;
			this.compatibility_tool = compatibility_tool;
			this.is_non_steam = true;
		}

		public override bool change_compatibility_tool(string compatibility_tool) {
			var config_path = "%s/config/config.vdf".printf(launcher.directory);
			var config_content = Utils.Filesystem.get_file_content(config_path);
			StringBuilder compat_tool_mapping_string_builder;
			var compat_tool_mapping_content = "";
			var compat_tool_mapping_item = "";
			uint compat_tool_mapping_item_appid = 0;
			var compat_tool_mapping_item_name = "";
			var start_text = "";
			var end_text = "";
			var start_pos = 0;
			var end_pos = 0;
			var current_position = 0;

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
			start_pos = config_content.index_of(start_text, 0);
			end_pos = config_content.index_of(end_text, start_pos) + end_text.length;
			compat_tool_mapping_content = config_content.substring(start_pos, end_pos - start_pos);
			// message("start: %i, end: %i, compat_tool_mapping_content: %s", start_pos, end_pos, compat_tool_mapping_content);

			compat_tool_mapping_string_builder = new StringBuilder(compat_tool_mapping_content);

			if (compat_tool_mapping_content.contains(appid.to_string())) {
				start_text = "\n\t\t\t\t\t\"%u\"".printf(appid);
				start_pos = compat_tool_mapping_content.index_of(start_text, current_position);
				if (start_pos == -1)
					return false;

				end_text = "}";
				end_pos = compat_tool_mapping_content.index_of(end_text, start_pos + start_text.length) + end_text.length;
				if (end_pos == -1)
					return false;

				compat_tool_mapping_item = compat_tool_mapping_content.substring(start_pos, end_pos - start_pos);

				current_position = end_pos;
				// message("start: %i, end: %i, compat_tool_mapping_item: %s", start_pos, end_pos, compat_tool_mapping_item);

				start_text = "\"";
				start_pos = compat_tool_mapping_item.index_of(start_text, 0) + start_text.length;
				if (start_pos == -1)
					return false;

				end_text = "\"";
				end_pos = compat_tool_mapping_item.index_of(end_text, start_pos);
				if (end_pos == -1)
					return false;

				var compat_tool_mapping_item_appid_valid = uint.try_parse(compat_tool_mapping_item.substring(start_pos, end_pos - start_pos), out compat_tool_mapping_item_appid);
				if (!compat_tool_mapping_item_appid_valid)
					return false;
				// message("start: %i, end: %i, compat_tool_mapping_item_appid: %i", start_pos, end_pos, compat_tool_mapping_item_appid);

				if (compat_tool_mapping_item_appid != appid)
					return false;

				if (compatibility_tool == _("Undefined")) {
					config_content = config_content.replace(compat_tool_mapping_item, "");
				} else {
					start_text = "name\"\t\t\"";
					start_pos = compat_tool_mapping_item.index_of(start_text, 0) + start_text.length;
					if (start_pos == -1)
						return false;

					end_text = "\"";
					end_pos = compat_tool_mapping_item.index_of(end_text, start_pos);
					if (end_pos == -1)
						return false;

					compat_tool_mapping_item_name = compat_tool_mapping_item.substring(start_pos, end_pos - start_pos);
					// message("start: %i, end: %i, compat_tool_mapping_item_name: %s", start_pos, end_pos, compat_tool_mapping_item_name);

					var compat_tool_mapping_item_modified = compat_tool_mapping_item.replace(compat_tool_mapping_item_name, compatibility_tool);

					config_content = config_content.replace(compat_tool_mapping_item, compat_tool_mapping_item_modified);
				}
			} else {
				if (compatibility_tool == _("Undefined"))
					return true;

				var line1 = "\n\t\t\t\t\t\"%u\"\n".printf(appid);
				var line2 = "\t\t\t\t\t{\n";
				var line3 = "\t\t\t\t\t\t\"name\"\t\t\"%s\"\n".printf(compatibility_tool);
				var line4 = "\t\t\t\t\t\t\"config\"\t\t\"%s\"\n".printf("");
				var line5 = "\t\t\t\t\t\t\"priority\"\t\t\"%i\"\n".printf(250);
				var line6 = "\t\t\t\t\t}";
				var new_item = line1 + line2 + line3 + line4 + line5 + line6;

				compat_tool_mapping_string_builder.insert(compat_tool_mapping_content.length - "\n\t\t\t\t}".length, new_item);

				config_content = config_content.replace(compat_tool_mapping_content, compat_tool_mapping_string_builder.str);
			}

			Utils.Filesystem.modify_file(config_path, config_content);

			this.compatibility_tool = compatibility_tool;

			return true;
		}

		public bool change_launch_options(string launch_options, string localconfig_path) {
			var escaped_launch_options = launch_options.replace("\"", "\\\"");

			if (is_non_steam) {
				var steam_launcher = launcher as Launchers.Steam;

				var shortcut = steam_launcher.profile.shortcuts.get_shortcut_by_name(name);
				shortcut.LaunchOptions = escaped_launch_options;

				steam_launcher.profile.shortcuts.replace_shortcut_by_name(name, shortcut);

				try {
					steam_launcher.profile.shortcuts.save();
				} catch (Error error) {
					message (error.message);

					return false;
				}
				
				this.launch_options = launch_options;

				return true;
			}

			var config_content = Utils.Filesystem.get_file_content(localconfig_path);
			var start_text = "";
			var end_text = "";
			var start_pos = 0;
			var end_pos = 0;
			var app = "";
			var app_launch_options = "";
			var app_modified = "";

			start_text = "%u\"\n\t\t\t\t\t{".printf(appid);
			start_pos = config_content.index_of(start_text, 0) + start_text.length - 1;
			if (start_pos == -1)
				return false;

			end_text = "\n\t\t\t\t\t}";
			end_pos = config_content.index_of(end_text, start_pos) + end_text.length;
			if (end_pos == -1)
				return false;

			app = config_content.substring(start_pos, end_pos - start_pos);
			message("start: %i, end: %i, app: %s", start_pos, end_pos, app);

			if (escaped_launch_options.length == 0) {
				if (app.contains("LaunchOptions")) {
					start_text = "\n\t\t\t\t\t\t\"LaunchOptions\"\t\t\"";
					start_pos = app.index_of(start_text, 0);
					if (start_pos == -1)
						return false;

					end_text = "\"\n";
					end_pos = app.index_of(end_text, start_pos + start_text.length);
					if (end_pos == -1)
						return false;

					end_pos = end_pos + end_text.length - 1;

					app_launch_options = app.substring(start_pos, end_pos - start_pos);
					// message("start: %i, end: %i, app_launch_options: %s", start_pos, end_pos, app_launch_options);

					app_modified = app.replace(app_launch_options, "");
				}
			} else {
				if (app.contains("LaunchOptions")) {
					start_text = "LaunchOptions\"\t\t\"";
					start_pos = app.index_of(start_text, 0) + start_text.length;

					if (start_pos == -1)
						return false;

					end_text = "\"\n";
					end_pos = app.index_of(end_text, start_pos);

					if (end_pos == -1)
						return false;

					app_launch_options = app.substring(start_pos, end_pos - start_pos);
					// message("start: %i, end: %i, app_launch_options: %s", start_pos, end_pos, app_launch_options);

					if (app_launch_options.length > 0) {
						message(app_launch_options + " | " + escaped_launch_options);
						app_modified = app.replace(app_launch_options, escaped_launch_options);
					} else {
						var before = app.substring(0, start_pos);
						var after = app.substring(start_pos, app.length - before.length);
						app_modified = "%s%s%s".printf(before, escaped_launch_options, after);
					}
				} else {
					app_launch_options = "\n\t\t\t\t\t\t\"LaunchOptions\"\t\t\"%s\"".printf(escaped_launch_options);

					end_pos = app.last_index_of("\n\t\t\t\t\t}");
					if (end_pos == -1)
						return false;

					app_modified =
						app.substring(0, end_pos) +
						app_launch_options + 
						app.substring(end_pos);
				}
			}

			config_content = config_content.replace(app, app_modified);

			Utils.Filesystem.modify_file(localconfig_path, config_content);

			this.launch_options = launch_options;

			return true;
		}

		public class AwacyGame {
			public int appid { get; set; }
			public string name { get; set; }
			public string status { get; set; }

			public AwacyGame(int appid, string name, string status) {
				this.appid = appid;
				this.name = name;
				this.status = status;
			}

			public static async List<Models.Games.Steam.AwacyGame?> get_awacy_games() {
				var games = new List<Models.Games.Steam.AwacyGame?> ();

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

					var game = new AwacyGame(appid, name, status);

					games.append(game);
				}

				return games;
			}
		}
	}
}
