namespace ProtonPlus.Models {
	public class Launcher : Object {
		public string title;
		public string icon_path;
		public string directory;
		public bool installed;
		public bool has_library_support;
		public List<Game> games;
		public List<SimpleRunner> compatibility_tools;

		public Group[] groups;

		public InstallationTypes installation_type;
		public enum InstallationTypes {
			SYSTEM,
			FLATPAK,
			SNAP
		}

		public Launcher (string title, InstallationTypes installation_type, string icon_path, string[] directories) {
			this.title = title;
			this.installation_type = installation_type;
			this.icon_path = icon_path;
			this.directory = "";

			foreach (var directory in directories) {
				var current_path = Environment.get_home_dir () + directory;
				if (FileUtils.test (current_path, FileTest.IS_DIR)) {
					if (!(this is Launchers.Steam) || (FileUtils.test (current_path + "/steamclient.dll", FileTest.IS_REGULAR) && FileUtils.test (current_path + "/steamclient64.dll", FileTest.IS_REGULAR))) {
						this.directory = current_path;
						break;
					}
				}
			}

			installed = directory.length > 0;
		}

		public string get_installation_type_title () {
			switch (installation_type) {
			case InstallationTypes.SYSTEM:
				return "System";
			case InstallationTypes.FLATPAK:
				return "Flatpak";
			case InstallationTypes.SNAP:
				return "Snap";
			default:
				return "Invalid type";
			}
		}

		public virtual async bool load_game_library () {
			return true;
		}

		public static async List<Launcher>? get_all () {
			var launchers = new List<Launcher> ();

			launchers.append (new Launchers.Steam (InstallationTypes.SYSTEM));
			launchers.append (new Launchers.Steam (InstallationTypes.FLATPAK));
			launchers.append (new Launchers.Steam (InstallationTypes.SNAP));

			launchers.append (new Launchers.Lutris (InstallationTypes.SYSTEM));
			launchers.append (new Launchers.Lutris (InstallationTypes.FLATPAK));

			launchers.append (new Launchers.Bottles (InstallationTypes.SYSTEM));
			launchers.append (new Launchers.Bottles (InstallationTypes.FLATPAK));

			launchers.append (new Launchers.HeroicGamesLauncher (InstallationTypes.SYSTEM));
			launchers.append (new Launchers.HeroicGamesLauncher (InstallationTypes.FLATPAK));

			launchers.append (new Launchers.WineZGUI (InstallationTypes.SYSTEM));
			launchers.append (new Launchers.WineZGUI (InstallationTypes.FLATPAK));

			launchers.foreach ((launcher) => {
				if (!launcher.installed)
					launchers.remove (launcher);
			});

			var initialized = yield initialize_launchers (launchers);
			if (!initialized)
				return null;
		
			return (owned) launchers;
		}

		class JsonGroupItem {
			public string title;
			public string description;
			public Json.Array runners;
		}

		class JsonLauncherGroupItem {
			public string title;
			public string directory;
		}

		class JsonLauncherItem {
			public string title;
			public JsonLauncherGroupItem[] groups;
		}

		class JsonRunnerItem {
			public string title;
			public string description;
			public string endpoint;
			public int asset_position;
			public Json.Array directory_name_formats;
			public string type;
			public bool has_latest_support;
			public string url_template;
			public string[] request_asset_exclude;
			public string[] request_asset_filter;
		}

		static async bool initialize_launchers (List<Launcher> launchers) {
			var root_object = yield get_runners_json_object ();
			if (root_object == null)
				return false;

			// Groups
			var groups_array = root_object.get_array_member ("compat_layers");
			if (groups_array == null)
				return false;

			var groups_length = groups_array.get_length ();
			if (groups_length == 0)
				return false;

			var json_group_items = new HashTable<string, JsonGroupItem> (str_hash, str_equal);
			
			for (var i = 0; i < groups_length; i++) {
				var group_object = groups_array.get_object_element (i);

				var json_group_item = new JsonGroupItem ();
				json_group_item.title = group_object.get_string_member ("title");
				json_group_item.description = group_object.get_string_member ("description");
				json_group_item.runners = group_object.get_array_member ("runners");

				json_group_items.set (json_group_item.title, json_group_item);

				// message ("Group #%i: %s - %s".printf (i, json_group_item.title, json_group_item.description));
			}

			// Launchers
			var launchers_array = root_object.get_array_member ("launchers");
			if (launchers_array == null)
				return false;

			var launchers_length = launchers_array.get_length ();
			if (launchers_length == 0)
				return false;

			var json_launcher_items = new HashTable<string, JsonLauncherItem> (str_hash, str_equal);
			
			for (var i = 0; i < launchers_length; i++) {
				var launcher_object = launchers_array.get_object_element (i);

				var launcher_group_array = launcher_object.get_array_member ("compat_layers");
				if (launcher_group_array == null)
					return false;

				var launcher_groups_length = launcher_group_array.get_length ();
				if (launcher_groups_length == 0)
					return false;

				var json_launcher_group_items = new JsonLauncherGroupItem[launcher_groups_length];
				
				for (var y = 0; y < launcher_groups_length; y++) {
					var launcher_group_object = launcher_group_array.get_object_element (y);

					var json_launcher_group_item = new JsonLauncherGroupItem ();
					json_launcher_group_item.title = launcher_group_object.get_string_member ("title");
					json_launcher_group_item.directory = launcher_group_object.get_string_member ("directory");
					
					json_launcher_group_items[y] = json_launcher_group_item;

					// message ("Launcher Group #%i: %s".printf (y, json_launcher_group_item.title));
				}

				var json_launcher_item = new JsonLauncherItem ();
				json_launcher_item.title = launcher_object.get_string_member ("title");
				json_launcher_item.groups = json_launcher_group_items;

				json_launcher_items.set (json_launcher_item.title, json_launcher_item);

				// message ("Launcher #%i: %s".printf (i, json_launcher_item.title));
			}

			foreach (var launcher in launchers) {
				var json_launcher_item = json_launcher_items.get (launcher.title);
				if (json_launcher_item == null)
					return false;

				var groups = new Group[json_launcher_item.groups.length];

				for (var i = 0; i < groups.length; i++) {
					var json_launcher_group_item = json_launcher_item.groups[i];

					var json_group_item = json_group_items.get (json_launcher_group_item.title);
					
					if (json_group_item == null)
						return false;
					
					groups[i] = new Group (json_launcher_group_item.title, Utils.safe_translate(json_group_item.description), json_launcher_group_item.directory, launcher);
            		
					groups[i].runners = new List<Runner> ();

					var json_runner_items = yield get_json_runner_items_from_array (json_group_item.runners);
					if (json_runner_items == null)
						return false;
					
					foreach (var json_runner_item in json_runner_items) {
						var runner = yield create_runner_from_json_runner_item (json_runner_item, groups[i]);
						if (runner == null)
							continue;

						groups[i].runners.append (runner);
					}

					if (launcher.title == "Steam") {
						var stl_runner = new Runners.SteamTinkerLaunch (groups[i]);

						groups[i].runners.append (stl_runner);
					}
				}

				launcher.groups = groups;

				if (launcher.installed) {
					var games_loaded = yield launcher.load_game_library ();
					if (!games_loaded)
						return false;

					if (launcher is Launchers.Steam) {
						var steam_launcher = launcher as Launchers.Steam;

						steam_launcher.profiles = SteamProfile.get_profiles(steam_launcher);

						foreach(var profile in steam_launcher.profiles) {
							yield profile.load_extra_data ();
						}
					}
				}
			}

			return true;
		}

		static async Json.Object? get_runners_json_object () {
			var download_url = "https://raw.githubusercontent.com/Vysp3r/ProtonPlus/refs/heads/main/data/runners.json";
			var download_path = "%s/ProtonPlus".printf (Environment.get_user_data_dir ());
			var download_full_path = "%s/runners.json".printf (download_path);
			var backup_full_path = "%s/runners.json.bak".printf (download_path);
			var resource_full_path = "resource://com/vysp3r/ProtonPlus/runners.json";

			if (!FileUtils.test (download_path, FileTest.IS_DIR))
				yield Utils.Filesystem.create_directory (download_path);

			if (FileUtils.test (download_full_path, FileTest.IS_REGULAR))
				yield Utils.Filesystem.move_file (download_full_path, backup_full_path);

			var downloaded = yield Utils.Web.Download (download_url, download_full_path);
			if (!downloaded && FileUtils.test (backup_full_path, FileTest.IS_REGULAR))
				yield Utils.Filesystem.move_file (backup_full_path, download_full_path);
			else
				Utils.Filesystem.delete_file (backup_full_path);

			var json = "";
			
			if (!downloaded && !FileUtils.test (download_full_path, FileTest.IS_REGULAR)) {
				json = Utils.Filesystem.get_file_content (resource_full_path, true);
			} else {
				json = Utils.Filesystem.get_file_content (download_full_path, false);
			}

			if (json == "")
				return null;

			var root_node = Utils.Parser.get_node_from_json (json);
			if (root_node == null)
				return null;
			
			var root_object = root_node.get_object ();
			if (root_object == null)
				return null;

			var version = root_object.get_int_member_with_default ("version", 0);
			if (version == 0)
				return null;

			return root_object;
		}

		static async JsonRunnerItem[]? get_json_runner_items_from_array (Json.Array runners_array) {
			var runners_length = runners_array.get_length ();
			if (runners_length == 0)
				return null;
			
			var json_runner_items = new JsonRunnerItem[runners_length];
			
			for (var i = 0; i < runners_length; i++) {
				var runner_object = runners_array.get_object_element (i);
				
				string[] members = { "title", "description", "endpoint", "asset_position", "directory_name_formats", "type" };
				var members_valid = true;
				foreach (var member in members) {
					if (!runner_object.has_member (member)) {
						members_valid = false;
						break;
					}
				}
				if (!members_valid)
					continue;

				var json_runner_item = new JsonRunnerItem ();
				json_runner_item.title = runner_object.get_string_member ("title");
				json_runner_item.description = runner_object.get_string_member ("description");
				json_runner_item.endpoint = runner_object.get_string_member ("endpoint");
				json_runner_item.asset_position = (int) runner_object.get_int_member ("asset_position");
				json_runner_item.directory_name_formats = runner_object.get_array_member ("directory_name_formats");
				json_runner_item.type = runner_object.get_string_member ("type");

				if (runner_object.has_member ("support_latest"))
					json_runner_item.has_latest_support = runner_object.get_boolean_member ("support_latest");

				if (runner_object.has_member ("url_template"))
					json_runner_item.url_template = runner_object.get_string_member ("url_template");

				if (runner_object.has_member ("request_asset_exclude")) {
					var request_asset_exclude_array = runner_object.get_array_member ("request_asset_exclude");

					var request_asset_exclude_length = request_asset_exclude_array.get_length ();
					if (request_asset_exclude_length == 0)
						return null;

					var request_asset_exclude = new string[request_asset_exclude_length];

					for (var y = 0; y < request_asset_exclude_length; y++) {
						request_asset_exclude[y] = request_asset_exclude_array.get_string_element (y);
					}

					json_runner_item.request_asset_exclude = request_asset_exclude;
				}

				if (runner_object.has_member ("request_asset_filter")) {
					var request_asset_filter_array = runner_object.get_array_member ("request_asset_filter");

					var request_asset_filter_length = request_asset_filter_array.get_length ();
					if (request_asset_filter_length == 0)
						return null;

					var request_asset_filter = new string[request_asset_filter_length];

					for (var y = 0; y < request_asset_filter_length; y++) {
						request_asset_filter[y] = request_asset_filter_array.get_string_element (y);
					}

					json_runner_item.request_asset_filter = request_asset_filter;
				}

				if (runner_object.has_member ("asset_position_hwcaps_condition")) {
					var asset_position_hwcaps_condition = runner_object.get_string_member ("asset_position_hwcaps_condition");

                	var split = asset_position_hwcaps_condition.split (":");
					if (split.length != 2)
						return null;

					foreach (var item in Globals.HWCAPS) {
						if (item != split[0])
							continue;

						int asset_position = 0;
						var parsed = int.try_parse (split[1], out asset_position);
						if (!parsed)
							return null;

						json_runner_item.asset_position = asset_position;
					}
				}

				json_runner_items[i] = json_runner_item;

				// message ("Runner #%i: %s - %s".printf (i, json_runner_item.title, json_runner_item.description));
			}

			return json_runner_items;
		}

		static async string? get_directory_name_format_from_array (Json.Array directory_name_formats, string launcher_title) {
			var runners_length = directory_name_formats.get_length ();
			if (runners_length == 0)
				return null;
			
			var directory_name_format_items = new HashTable<string, string> (str_hash, str_equal);
			
			for (var i = 0; i < runners_length; i++) {
				var directory_name_format_object = directory_name_formats.get_object_element (i);

				var launcher = directory_name_format_object.get_string_member ("launcher");
				var directory_name_format = directory_name_format_object.get_string_member ("directory_name_format");

				directory_name_format_items.set (launcher, directory_name_format);
			}

			var directory_name_format_item = directory_name_format_items.get (launcher_title);
			if (directory_name_format_item == null) {
				directory_name_format_item = directory_name_format_items.get ("default");
				if (directory_name_format_item == null)
					return null;
			}

			return directory_name_format_item;
		}

		static async Runners.Basic? create_runner_from_json_runner_item (JsonRunnerItem json_runner_item, Models.Group group) {
			Runners.Basic runner = null;

			var directory_name_format = yield get_directory_name_format_from_array(json_runner_item.directory_name_formats, group.launcher.title);
				if (directory_name_format == null)
					return null;

			switch (json_runner_item.type) {
				case "github":
					var github_runner = new Runners.GitHub ();

					github_runner.request_asset_exclude = json_runner_item.request_asset_exclude;
					github_runner.request_asset_filter = json_runner_item.request_asset_filter;
					
					runner = github_runner;
					break;
				case "github-action":
					var github_action_runner = new Runners.GitHubAction ();

					github_action_runner.url_template = json_runner_item.url_template;

					runner = github_action_runner;
					break;
				case "gitlab":
					var gitlab_runner = new Runners.GitLab ();

					gitlab_runner.request_asset_exclude = json_runner_item.request_asset_exclude;

					runner = gitlab_runner;
					break;
				default:
					message ("%s %s".printf ("Invalid type for runner named", json_runner_item.title));
					break;
			}

			if (runner != null) {
				runner.title = json_runner_item.title;
				runner.description = Utils.safe_translate(json_runner_item.description);
				runner.endpoint = json_runner_item.endpoint;
				runner.asset_position = json_runner_item.asset_position;
				runner.directory_name_format = yield get_directory_name_format_from_array(json_runner_item.directory_name_formats, group.launcher.title);
				runner.has_latest_support = json_runner_item.has_latest_support;
				runner.group = group;
			}
				
			return runner;
		}

		public virtual int get_compatibility_tool_usage_count (string compatibility_tool_name) {
			return 0;
		}
	}
}
