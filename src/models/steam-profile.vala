namespace ProtonPlus.Models {
	public class SteamProfile : Object {
		public Launchers.Steam launcher { get; set; }
		public string userdata_path { get; set; }
		public string localconfig_path { get; set; }
		public VDF.Shortcuts shortcut_file { get; set; }
		public string id { get; set; }
		public string username { get; set; }
		public string image_path { get; set; }
		public string default_compatibility_tool { get; set; }

		public SteamProfile (Launchers.Steam launcher, string username, string id, string userdata_path) {
			this.launcher = launcher;
			this.id = id;
			this.username = username;
			this.userdata_path = userdata_path;

			this.localconfig_path = "%s/config/localconfig.vdf".printf (userdata_path);

			this.image_path = "%s/config/avatarcache/%s.png".printf (launcher.directory, id);

			try {
				var shortcut_file_path = "%s/config/shortcuts.vdf".printf (userdata_path);

				if (!FileUtils.test (shortcut_file_path, FileTest.IS_REGULAR))
					VDF.Shortcuts.create_new_shortcuts_file_at (shortcut_file_path);

				shortcut_file = new VDF.Shortcuts (shortcut_file_path);
			} catch (Error e) {
				message (e.message);
			}
		}

		public static List<SteamProfile> get_profiles (Launchers.Steam launcher) {
			var profiles = new List<SteamProfile> ();

			var path = "%s/config/loginusers.vdf".printf (launcher.directory);
			var content = Utils.Filesystem.get_file_content (path);
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
								var localconfig_path = "%s/config/localconfig.vdf".printf (file.get_path ());
								var localconfig_content = Utils.Filesystem.get_file_content (localconfig_path);

								var start_text = "GetEquippedProfileItemsForUser";
								var start_pos = localconfig_content.index_of (start_text, 0) + start_text.length;
								if (start_pos == -1)
									break;

								var end_text = "\"";
								var end_pos = localconfig_content.index_of (end_text, start_pos);
								if (end_pos == -1)
									break;

								var id = localconfig_content.substring (start_pos, end_pos - start_pos);
								message("start: %i, end: %i, id: %s", start_pos, end_pos, id);

								userdata_hashtable.set (id, file.get_path ());
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
