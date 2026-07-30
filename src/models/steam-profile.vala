namespace ProtonPlus.Models {
    public class SteamProfile : Object {
        const int64 steamid64ident = 76561197960265728;
        public Launchers.Steam launcher { get; set; }
        public string userdata_path { get; set; }
        public string localconfig_path { get; set; }
        public Utils.VDF.Shortcuts? shortcuts { get; set; }
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

            this.account_id = steam_id_to_account_id (steam_id);

            this.localconfig_path = "%s/config/localconfig.vdf".printf (userdata_path);

            this.image_path = "%s/config/avatarcache/%s.png".printf (launcher.directory, steam_id);

            try {
                var shortcuts_file_path = "%s/config/shortcuts.vdf".printf (userdata_path);

                shortcuts = FileUtils.test (shortcuts_file_path, FileTest.IS_REGULAR)
                    ? Utils.VDF.Shortcuts.load (shortcuts_file_path)
                    : Utils.VDF.Shortcuts.empty (shortcuts_file_path);
            } catch (Error e) {
                warning (e.message);
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

        async bool load_launch_options () {
            this.launch_options_hashtable = new HashTable<uint, string> (null, null);

            var content = Utils.Filesystem.get_file_content (localconfig_path);
            var document = Utils.VDF.VdfParser.parse_document (content);
            if (document == null)
                return false;

            var config_store = document.root.get_child ("UserLocalConfigStore");
            var software = config_store != null ? config_store.get_child ("Software") : null;
            var valve = software != null ? software.get_child ("Valve") : null;
            var steam = valve != null ? valve.get_child ("Steam") : null;
            var apps = steam != null ? steam.get_child ("apps") : null;
            if (apps == null)
                return false;

            foreach (var app in apps.children) {
                uint appid;
                if (!uint.try_parse (app.key, out appid))
                    continue;

                var launch_options = app.get_child ("LaunchOptions");
                if (launch_options == null || launch_options.value == null)
                    continue;

                launch_options_hashtable.set (appid, launch_options.value);
            }

            foreach (var game in (List<Games.Steam>) launcher.games) {
                var launch_options = launch_options_hashtable.get (game.appid);
                if (launch_options == null)
                    launch_options = "";
                this.launch_options_hashtable.set (game.appid, launch_options);
            }

            var configuration = ProtonPlus.Services.SteamConfigurationService.instance;
            if (configuration != null)
                configuration.overlay_profile_effective_state (this);

            return true;
        }

        async bool load_non_steam_games () {
            this.non_steam_games = new List<Games.Steam> ();
            var shortcuts = this.shortcuts;
            if (shortcuts == null)
                return false;

            foreach (var entry in shortcuts.nodes.entries) {
                if (!is_shortcut_node_path (entry.key))
                    continue;

                var appid_value = get_shortcut_field (entry.value, "appid", VariantType.INT32);
                var name_value = get_shortcut_field (entry.value, "AppName", VariantType.STRING);
                var launch_options_value = get_shortcut_field (entry.value, "LaunchOptions", VariantType.STRING);
                if (appid_value == null || name_value == null || launch_options_value == null)
                    continue;

                uint appid = (uint) appid_value.get_int32 ();
                string name = name_value.get_string ();
                if (name == "ProtonPlus")
                    continue;

                string launch_options = launch_options_value.get_string ().replace ("\\\"", "\"");

                var compatibility_tool = launcher.compatibility_tool_hashtable.get (appid);
                if (compatibility_tool == null)
                    compatibility_tool = "Default";

                var game = new Games.Steam.non_steam (appid, name, launch_options, compatibility_tool, launcher);

                non_steam_games.append (game);
            }

            return true;
        }

        private static bool is_shortcut_node_path (string path) {
            var components = path.split (".");
            int id = -1;
            return components.length == 2
                && components[0] == "shortcuts"
                && int.try_parse (components[1], out id)
                && id >= 0;
        }

        private static GLib.Variant? get_shortcut_field (Utils.VDF.Node node, string name, VariantType type) {
            if (!node.has_key (name))
                return null;

            var value = node.get (name);
            return value != null && value.is_of_type (type) ? value : null;
        }

        static string steam_id_to_account_id (string steam_id) {
            var steam_id2 = "STEAM_0:";
            var steam_id2_account = int64.parse (steam_id) - steamid64ident;

            if (steam_id2_account % 2 == 0)
            steam_id2 += "0:";
            else
            steam_id2 += "1:";

            steam_id2 += Math.floor (steam_id2_account / 2).to_string ();

            var steam_id2_split = steam_id2.split (":");
            var steam_id3 = "[U:1:";

            var y = int.parse (steam_id2_split[1]);
            var z = int.parse (steam_id2_split[2]);

            var account_id = z * 2 + y;

            steam_id3 += "%i]".printf (account_id);

            return account_id.to_string ();
        }

        static string account_id_to_steam_id (string account_id) {
            var steam_id = int64.parse (account_id) + steamid64ident;

            return steam_id.to_string ();
        }

        public static List<SteamProfile> get_profiles (Launchers.Steam launcher) {
            var profiles = new List<SteamProfile> ();

            var path = "%s/config/loginusers.vdf".printf (launcher.directory);
            var content = Utils.Filesystem.get_file_content (path);
            if (content.length == 0)
                return profiles;

            var document = Utils.VDF.VdfParser.parse_document (content);
            if (document == null)
                return profiles;

            var users = document.root.get_child ("users");
            if (users == null)
                return profiles;

            var userdata_hashtable = get_userdata_hashtable (launcher);

            foreach (var user in users.children) {
                var persona_name = user.get_child ("PersonaName");
                if (persona_name == null || persona_name.value == null)
                    continue;

                var userdata_path = userdata_hashtable.get (user.key);
                if (userdata_path == null)
                    continue;

                var profile = new SteamProfile (launcher, persona_name.value, user.key, userdata_path);

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
                                userdata_hashtable.set (account_id_to_steam_id (dir), file.get_path ());
                            }
                        }
                    }
                }
            } catch (Error e) {
                warning (e.message);
            }

            return userdata_hashtable;
        }
    }
}
