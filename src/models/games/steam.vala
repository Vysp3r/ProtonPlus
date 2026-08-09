namespace ProtonPlus.Models.Games {
    public interface AwacyGameSource : Object {
        public abstract async Gee.HashMap<uint, Steam.AwacyGame?>? load (Cancellable? cancellable);
    }

    public class RemoteAwacyGameSource : Object, AwacyGameSource {
        private const string GAMES_URI = "https://raw.githubusercontent.com/AreWeAntiCheatYet/AreWeAntiCheatYet/refs/heads/master/games.json";

        public async Gee.HashMap<uint, Steam.AwacyGame?>? load (Cancellable? cancellable) {
            var games = new Gee.HashMap<uint, Steam.AwacyGame?> ();
            Utils.Web.Response? response = yield Utils.Web.get_request (
                GAMES_URI,
                Utils.Web.GetRequestType.OTHER,
                cancellable
            );

            if (response == null || ((!) response).code != ReturnCode.VALID_REQUEST || ((!) response).body == null)
                return games;

            var root_node = Utils.Parser.get_node_from_json ((!) ((!) response).body);
            if (root_node == null || root_node.get_node_type () != Json.NodeType.ARRAY)
                return games;

            var root_array = root_node.get_array ();
            if (root_array == null)
                return games;

            for (var i = 0; i < root_array.get_length (); i++) {
                var object = root_array.get_object_element (i);
                var storeids_object = object.get_object_member ("storeIds");
                if (storeids_object == null || !storeids_object.has_member ("steam"))
                    continue;

                uint appid = 0;
                if (!uint.try_parse (storeids_object.get_string_member ("steam"), out appid))
                    continue;
                if (!object.has_member ("slug") || !object.has_member ("status"))
                    continue;

                games.set (appid, new Steam.AwacyGame (
                    appid,
                    object.get_string_member ("slug"),
                    object.get_string_member ("status")
                ));
            }

            return games;
        }
    }

    public class AwacyGameCatalog : Object {
        public const uint DEFAULT_TIMEOUT_MILLISECONDS = 3000;

        private static AwacyGameCatalog? shared_catalog;
        private AwacyGameSource source;
        private uint timeout_milliseconds;
        private Gee.HashMap<uint, Steam.AwacyGame?>? cached_games;
        private bool is_loading;

        private signal void fetch_completed ();

        public AwacyGameCatalog (
            AwacyGameSource? source = null,
            uint timeout_milliseconds = DEFAULT_TIMEOUT_MILLISECONDS
        ) {
            this.source = source ?? new RemoteAwacyGameSource ();
            this.timeout_milliseconds = timeout_milliseconds;
        }

        public static AwacyGameCatalog get_shared () {
            if (shared_catalog == null)
                shared_catalog = new AwacyGameCatalog ();
            return (!) shared_catalog;
        }

        public async Gee.HashMap<uint, Steam.AwacyGame?> get_games () {
            if (cached_games != null)
                return (!) cached_games;

            if (is_loading) {
                var handler_id = fetch_completed.connect (() => {
                    get_games.callback ();
                });
                yield;
                disconnect (handler_id);
                return (!) cached_games;
            }

            is_loading = true;
            var cancellable = new Cancellable ();
            uint timeout_source_id = 0;
            if (timeout_milliseconds > 0) {
                timeout_source_id = Timeout.add (timeout_milliseconds, () => {
                    timeout_source_id = 0;
                    cancellable.cancel ();
                    return Source.REMOVE;
                });
            }

            var loaded_games = yield source.load (cancellable);
            cached_games = loaded_games ?? new Gee.HashMap<uint, Steam.AwacyGame?> ();
            if (timeout_source_id != 0)
                Source.remove (timeout_source_id);

            is_loading = false;
            fetch_completed ();
            return (!) cached_games;
        }
    }

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

        }
    }
}
