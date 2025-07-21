namespace ProtonPlus.Models {
	public class SteamProfile : Object {
		const int64 steamid64ident = 76561197960265728;
		public Launchers.Steam launcher { get; set; }
		public string userdata_path { get; set; }
		public string localconfig_path { get; set; }
		public VDF.Shortcuts shortcuts { get; set; }
		public string steam_id { get; set; }
		public string account_id { get; set; }
		public string username { get; set; }
		public string image_path { get; set; }
		public string default_compatibility_tool { get; set; }
		public HashTable<uint, string> launch_options_hashtable;
		public List<Games.Steam> non_steam_games;

		public SteamProfile (Launchers.Steam launcher, string username, string steam_id, string userdata_path) {
			this.launcher = launcher;
			this.steam_id = steam_id;
			this.username = username;
			this.userdata_path = userdata_path;

			this.account_id = steam_id_to_account_id(steam_id);

			this.localconfig_path = "%s/config/localconfig.vdf".printf (userdata_path);

			this.image_path = "%s/config/avatarcache/%s.png".printf (launcher.directory, steam_id);

			try {
				var shortcuts_file_path = "%s/config/shortcuts.vdf".printf (userdata_path);

				if (!FileUtils.test (shortcuts_file_path, FileTest.IS_REGULAR))
					VDF.Shortcuts.create_new_shortcuts_file_at (shortcuts_file_path);

				shortcuts = new VDF.Shortcuts (shortcuts_file_path);
			} catch (Error e) {
				message (e.message);
			}
		}

		public async bool load_extra_data () {
			var launch_options_loaded = yield load_launch_options ();
			if (!launch_options_loaded)
				return false;

			var non_steam_games_loaded = yield load_non_steam_games ();
			if (!non_steam_games_loaded)
				return false;

			return true;
		}

		async bool load_launch_options() {
            this.launch_options_hashtable = new HashTable<uint, string> (null, null);

            var content = Utils.Filesystem.get_file_content(localconfig_path);
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
                return false;

            end_text = "\n\t\t\t\t}";
            end_pos = content.index_of(end_text, start_pos);

            if (end_pos == -1)
                return false;

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

                    end_text = "\"\n\t";
                    end_pos = app.index_of(end_text, start_pos);

                    if (end_pos == -1)
                        break;
                        
                    launch_options = app.substring(start_pos, end_pos - start_pos).replace("\\\"", "\"");
                    // message("start: %i, end: %i, launch_options: %s", start_pos, end_pos, launch_options);

                    launch_options_hashtable.set(id, launch_options);
                }
            }

			foreach (var game in (List<Games.Steam>) launcher.games) {
                launch_options = launch_options_hashtable.get(game.appid);
                if (launch_options == null)
                    launch_options = "";
                this.launch_options_hashtable.set (game.appid, launch_options);
            }

            return true;
        }

		async bool load_non_steam_games () {
			this.non_steam_games = new List<Games.Steam> ();

			foreach (var entry in shortcuts.nodes.entries) {
                if (entry.key.contains("shortcuts.") && !entry.key.contains(".tags")) {
					uint appid = entry.value.get("appid").get_int32();
					if (appid < 0)
						appid += (1u << 32);

					if (!entry.value.has_key ("AppName"))
						continue;

					string name = entry.value.get("AppName").get_string();

					string launch_options = entry.value.get("LaunchOptions").get_string().replace("\\\"", "\"");

					var compatibility_tool = launcher.compatibility_tool_hashtable.get (appid);
					if (compatibility_tool == null)
                        compatibility_tool = "Undefined";
                        
					var game = new Games.Steam.non_steam (appid, name, launch_options, compatibility_tool, launcher);

					non_steam_games.append (game);
                }
            }
			
			return true;
		}

		static string steam_id_to_account_id (string steam_id) {
			var steam_id2 = "STEAM_0:";
			var steam_id2_account = int64.parse(steam_id) - steamid64ident;

  			if (steam_id2_account % 2 == 0)
      			steam_id2 += "0:";
  			else
      			steam_id2 += "1:";

  			steam_id2 += Math.floor (steam_id2_account / 2).to_string();

  			// message("SteamID2: %s".printf (steam_id2));

			var steam_id2_split = steam_id2.split(":");
  			var steam_id3 = "[U:1:";

  			var y = int.parse(steam_id2_split[1]);
  			var z = int.parse(steam_id2_split[2]);

  			var account_id = z * 2 + y;

  			steam_id3 += "%i]".printf (account_id);

			// message("SteamID3: %s".printf (steam_id3));

			return account_id.to_string ();
		}

		static string account_id_to_steam_id (string account_id) {
  			var steam_id = int64.parse(account_id) + steamid64ident;

			return steam_id.to_string();
		}

		public static List<SteamProfile> get_profiles (Launchers.Steam launcher) {
			var profiles = new List<SteamProfile> ();

			var path = "%s/config/loginusers.vdf".printf (launcher.directory);
			var content = Utils.Filesystem.get_file_content (path);
			if (content.length == 0)
				return profiles;
			var start_text = "";
			var end_text = "";
			var start_pos = 0;
			var end_pos = 0;
			var users = "";
			var user = "";
			var id = "";
			var username = "";
			var userdata_path = "";

			var userdata_hashtable = get_userdata_hashtable (launcher);

			start_text = "users\"\n{";
			start_pos = content.index_of (start_text, 0) + start_text.length;

			end_pos = content.length - 3;

			users = content.substring (start_pos, end_pos - start_pos);
			// message("start: %i, end: %i, users: %s", start_pos, end_pos, users);

			int position = 0;
			while (true) {
				start_text = "\"";
				start_pos = users.index_of (start_text, position);
				if (start_pos == -1)
					break;

				end_text = "}";
				position = end_pos = users.index_of (end_text, start_pos + start_text.length) + 1;
				if (end_pos == -1)
					break;

				user = users.substring (start_pos, end_pos - start_pos);
				// message("start: %i, end: %i, user: %s", start_pos, end_pos, user);

				start_text = "\"";
				start_pos = user.index_of (start_text, 0) + start_text.length;
				if (start_pos == -1)
					break;

				end_text = "\"";
				end_pos = user.index_of (end_text, start_pos);
				if (end_pos == -1)
					break;

				id = user.substring (start_pos, end_pos - start_pos);
				// message ("start: %i, end: %i, id: %s", start_pos, end_pos, id);

				start_text = "PersonaName\"\t\t\"";
				start_pos = user.index_of (start_text, 0) + start_text.length;
				if (start_pos == -1)
					break;

				end_text = "\"";
				end_pos = user.index_of (end_text, start_pos);
				if (end_pos == -1)
					break;

				username = user.substring (start_pos, end_pos - start_pos);
				// message ("start: %i, end: %i, username: %s", start_pos, end_pos, username);

				userdata_path = userdata_hashtable.get (id);
				if (userdata_path == null)
					continue;

				var profile = new SteamProfile (launcher, username, id, userdata_path);

				profiles.append (profile);
			}

			return profiles;
		}

		static HashTable<string, string> get_userdata_hashtable (Launchers.Steam launcher) {
			var userdata_hashtable = new HashTable<string, string> (str_hash, str_equal);

			try {
				var userdata_path = "%s/userdata".printf (launcher.directory);
				if (FileUtils.test (userdata_path, FileTest.IS_DIR)) {
					Dir directory = Dir.open (userdata_path);
					string? dir;
					while ((dir = directory.read_name ()) != null) {
						if (dir != "." && dir != "..") {
							File file = File.new_for_path (userdata_path + "/" + dir);
							if (file.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY) {
								userdata_hashtable.set (account_id_to_steam_id(dir), file.get_path ());
							}
						}
					}
				}
			} catch (Error e) {
				message (e.message);
			}

			return userdata_hashtable;
		}
	}
}
