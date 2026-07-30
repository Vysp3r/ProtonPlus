namespace ProtonPlus.Models.Games {
    public class Steam : Game {
        public uint appid { get; set; }
        public int library_folder_id { get; set; }
        public string library_folder_path { get; set; }
        public string awacy_name { get; set; }
        public string awacy_status { get; set; }
        public string launch_options { get; set; }
        public bool is_non_steam { get; set; }

        private bool? _is_native = null;
        public override bool is_native {
            get {
                if (_is_native == null)
                    _is_native = detect_native ();

                return _is_native;
            }
            set {
                _is_native = value;
            }
        }

        public Steam (
            uint appid,
            string name,
            string game_folder_name,
            int library_folder_id,
            string library_folder_path,
            Launchers.Steam launcher
        ) {
            base (
                name,
                Path.build_filename (library_folder_path, "steamapps", "common", game_folder_name),
                Path.build_filename (library_folder_path, "steamapps", "compatdata", appid.to_string ()),
                appid,
                launcher
            );

            this.appid = appid;
            this.library_folder_id = library_folder_id;
            this.library_folder_path = library_folder_path;
            this.launcher = launcher;
        }

        public Steam.non_steam (uint appid, string name, string launch_options, string compatibility_tool, Launchers.Steam launcher) {
            base (name, "", "%s/steamapps/compatdata/%u".printf (launcher.directory, appid), appid, launcher);

            this.appid = appid;
            this.launch_options = launch_options;
            this.compatibility_tool = compatibility_tool;
            this.is_non_steam = true;
        }

        private bool detect_native () {
            if (is_non_steam) {
                return true;
            }

            if (FileUtils.test (installdir, FileTest.IS_DIR)) {
                if (!FileUtils.test (prefixdir, FileTest.IS_DIR))
                    return true;

                try {
                    var dir = Dir.open (installdir, 0);
                    string? name;
                    while ((name = dir.read_name ()) != null) {
                        var path = Path.build_filename (installdir, name);
                        if (FileUtils.test (path, FileTest.IS_REGULAR) && FileUtils.test (path, FileTest.IS_EXECUTABLE)) {
                            var file = FileStream.open (path, "r");
                            if (file != null) {
                                uint8 magic[4];
                                if (file.read (magic) == 4) {
                                    if (magic[0] == 0x7f && magic[1] == 'E' && magic[2] == 'L' && magic[3] == 'F') {
                                        return true;
                                    }
                                }
                            }
                        }
                    }
                } catch (Error e) {
                    debug ("Could not inspect %s for native executables: %s", installdir, e.message);
                }
            }

            return false;
        }

        public override bool change_compatibility_tool (string compatibility_tool) {
            var configuration = ProtonPlus.Services.SteamConfigurationService.instance;
            if (configuration == null) {
                warning ("Steam compatibility change rejected because SteamConfigurationService is not configured.");
                return false;
            }

            var outcome = ((!) configuration).change_game_compatibility_tool (this, compatibility_tool);
            if (!outcome.accepted)
                return false;
            this.compatibility_tool = compatibility_tool;
            if (is_non_steam)
                _is_native = null;
            return true;
        }

        public bool change_launch_options (string launch_options, string localconfig_path) {
            var configuration = ProtonPlus.Services.SteamConfigurationService.instance;
            if (configuration == null) {
                warning ("Steam launch-options change rejected because SteamConfigurationService is not configured.");
                return false;
            }

            var outcome = ((!) configuration).change_game_launch_options (this, launch_options, localconfig_path);
            if (!outcome.accepted)
                return false;
            this.launch_options = launch_options;
            var configured_launcher = launcher as Launchers.Steam;
            if (configured_launcher.profile != null && configured_launcher.profile.launch_options_hashtable != null)
                configured_launcher.profile.launch_options_hashtable.set (appid, launch_options);
            return true;
        }

        public class AwacyGame {
            public uint appid { get; set; }
            public string name { get; set; }
            public string status { get; set; }

            public AwacyGame (uint appid, string name, string status) {
                this.appid = appid;
                this.name = name;
                this.status = status;
            }

            public static async Gee.HashMap<uint, Models.Games.Steam.AwacyGame?> get_awacy_games () {
                var games = new Gee.HashMap<uint, Models.Games.Steam.AwacyGame?> ();

                var response = yield Utils.Web.get_request (
                    "https://raw.githubusercontent.com/AreWeAntiCheatYet/AreWeAntiCheatYet/refs/heads/master/games.json",
                    Utils.Web.GetRequestType.OTHER
                );

                if (response.code != ReturnCode.VALID_REQUEST)
                    return games;

                var root_node = Utils.Parser.get_node_from_json (response.body);

                if (root_node == null)
                    return games;

                if (root_node.get_node_type () != Json.NodeType.ARRAY)
                    return games;

                var root_array = root_node.get_array ();
                if (root_array == null)
                    return games;

                for (var i = 0; i < root_array.get_length (); i++) {
                    var object = root_array.get_object_element (i);

                    var storeids_object = object.get_object_member ("storeIds");
                    if (storeids_object == null)
                        continue;

                    if (!storeids_object.has_member ("steam"))
                        continue;

                    uint appid = 0;
                    if (!uint.try_parse (storeids_object.get_string_member ("steam"), out appid))
                        continue;

                    if (!object.has_member ("slug"))
                        continue;

                    var name = object.get_string_member ("slug");

                    if (!object.has_member ("status"))
                        continue;

                    var status = object.get_string_member ("status");

                    var game = new AwacyGame (appid, name, status);

                    games.set (appid, game);
                }

                return games;
            }
        }
    }
}
