namespace ProtonPlus.Services {
    public enum HeroicStore {
        LEGENDARY,
        GOG,
        NILE,
        SIDELOAD;

        public string protocol_id () {
            switch (this) {
            case LEGENDARY: return "legendary";
            case GOG: return "gog";
            case NILE: return "nile";
            default: return "sideload";
            }
        }
    }

    internal class HeroicGameRecord : Object {
        public HeroicStore store;
        public string app_name;
        public string title;
        public bool native_game;
        public string game_directory;
        public string prefix_directory = "";
        public string? runner_name;
        public bool inherits_runner;
        public bool settings_available;
    }

    internal class HeroicLibrary : Object {
        private string root;
        private string home;

        public HeroicLibrary (string root, string home) {
            this.root = root;
            this.home = home;
        }

        public Gee.List<HeroicGameRecord> read () throws Error {
            var games = new Gee.ArrayList<HeroicGameRecord> ();
            Error? failure = null;
            foreach (var store in new HeroicStore[] { HeroicStore.LEGENDARY, HeroicStore.GOG,
                HeroicStore.NILE, HeroicStore.SIDELOAD }) {
                try {
                    read_store (store, games);
                } catch (Error error) {
                    debug ("Could not read Heroic %s metadata: %s", store.protocol_id (), error.message);
                    if (failure == null)
                        failure = error;
                }
            }
            if (games.is_empty && failure != null)
                throw (owned) failure;

            Json.Object? defaults = null;
            bool defaults_read = false;
            foreach (var game in games) {
                if (game.native_game)
                    continue;
                var settings = read_game_settings (game.app_name);
                if (settings == null)
                    continue;
                if (!defaults_read && (!settings.has_member ("wineVersion") || !settings.has_member ("winePrefix"))) {
                    defaults = read_defaults ();
                    defaults_read = true;
                }
                apply_settings (game, settings, defaults);
            }
            return games;
        }

        private void read_store (HeroicStore store, Gee.List<HeroicGameRecord> games) throws Error {
            string path;
            switch (store) {
            case LEGENDARY:
                // Heroic sets LEGENDARY_CONFIG_PATH to its managed directory.
                path = Path.build_filename (root, "legendaryConfig", "legendary", "installed.json");
                break;
            case GOG:
                path = Path.build_filename (root, "gog_store", "installed.json");
                break;
            case NILE:
                path = Path.build_filename (root, "nile_config", "nile", "installed.json");
                break;
            default:
                path = Path.build_filename (root, "sideload_apps", "library.json");
                break;
            }
            var json = read_json (path);
            if (json == null)
                return;

            var records = new Gee.HashMap<string, HeroicGameRecord> ();
            if (store == HeroicStore.LEGENDARY) {
                var installed = as_object (json);
                if (installed == null)
                    throw invalid_metadata (path);
                foreach (var id in installed.get_members ())
                    add_record (records, store, id, as_object (installed.get_member (id)));
            } else {
                var array = json;
                if (store == HeroicStore.GOG)
                    array = as_object (json)?.get_member ("installed");
                else if (store == HeroicStore.SIDELOAD)
                    array = as_object (json)?.get_member ("games");
                if (array == null || array.get_node_type () != Json.NodeType.ARRAY) {
                    // Electron stores can exist before Heroic has populated the collection.
                    if (as_object (json)?.get_size () == 0 && store != HeroicStore.NILE)
                        return;
                    throw invalid_metadata (path);
                }
                var id_key = store == HeroicStore.GOG ? "appName" :
                    (store == HeroicStore.NILE ? "id" : "app_name");
                foreach (var node in array.get_array ().get_elements ()) {
                    var entry = as_object (node);
                    add_record (records, store, get_string (entry, id_key), entry);
                }
            }
            games.add_all (records.values);
        }

        private void add_record (Gee.Map<string, HeroicGameRecord> records, HeroicStore store,
            string? id, Json.Object? entry) {
            if (id == null || id.strip () == "" || id.contains ("/") || entry == null)
                return;
            if (!get_boolean (entry, "is_installed", store != HeroicStore.SIDELOAD)) {
                records.unset (id);
                return;
            }
            var install = store == HeroicStore.SIDELOAD ? as_object (entry.get_member ("install")) : entry;
            if (install == null || get_boolean (install, "is_dlc", false))
                return;

            string? directory = absolute_path (get_string (install,
                store == HeroicStore.NILE ? "path" : "install_path"));
            if (store == HeroicStore.SIDELOAD && directory == null) {
                var executable = absolute_path (get_string (install, "executable"));
                if (executable != null)
                    directory = Path.get_dirname (executable);
            }
            var platform = (get_string (install, "platform") ?? "").ascii_down ();
            var title = get_string (entry, "title");
            if (title == null || title.strip () == "") {
                // GOG and Nile records can omit titles.
                title = directory != null && directory != "/" ? Path.get_basename (directory) : id;
            }
            records[id] = new HeroicGameRecord () {
                store = store,
                app_name = id,
                title = title,
                native_game = (store == HeroicStore.GOG && platform == "linux") ||
                    (store == HeroicStore.SIDELOAD && (platform == "linux" || platform == "browser")),
                game_directory = accessible_directory (directory)
            };
        }

        private Json.Object? read_defaults () {
            var path = Path.build_filename (root, "config.json");
            try {
                var json = read_json (path);
                if (json == null)
                    return new Json.Object ();
                return as_object (as_object (json)?.get_member ("defaultSettings"));
            } catch (Error error) {
                debug ("Could not read Heroic defaults: %s", error.message);
                return null;
            }
        }

        private Json.Object? read_game_settings (string app_name) {
            // Heroic keys its settings file by app_name, even across stores.
            var path = Path.build_filename (root, "GamesConfig", app_name + ".json");
            try {
                var json = read_json (path);
                if (json == null)
                    return new Json.Object ();
                var wrapper = as_object (json);
                if (wrapper == null)
                    return null;
                var entry = wrapper.get_member (app_name);
                return entry == null ? new Json.Object () : as_object (entry);
            } catch (Error error) {
                debug ("Could not read Heroic game settings: %s", error.message);
                return null;
            }
        }

        private void apply_settings (HeroicGameRecord game, Json.Object settings, Json.Object? defaults) {
            var override_runner = settings.get_member ("wineVersion");
            var effective_runner = override_runner ?? defaults?.get_member ("wineVersion");
            var runner = as_object (effective_runner);
            game.inherits_runner = override_runner == null;
            game.runner_name = get_string (runner, "name");
            game.settings_available = effective_runner == null ? defaults != null :
                game.runner_name != null && game.runner_name.strip () != "";
            var type = get_string (runner, "type");
            if (type != "wine" && type != "proton")
                return;
            string? prefix;
            if (settings.has_member ("winePrefix")) {
                prefix = get_string (settings, "winePrefix");
            } else if (defaults != null) {
                var configured_prefix = defaults.get_member ("winePrefix");
                prefix = get_string (defaults, "winePrefix");
                if (configured_prefix != null && !configured_prefix.is_null () && prefix == null)
                    return;
                if (prefix == null || prefix == "")
                    prefix = Path.build_filename (home, "Games", "Heroic", "Prefixes", "shared");
            } else {
                return;
            }
            prefix = absolute_path (prefix);
            if (prefix != null && type == "proton")
                prefix = Path.build_filename (prefix, "pfx");
            game.prefix_directory = accessible_directory (prefix);
        }

        private string? absolute_path (string? value) {
            if (value == null)
                return null;
            if (value == "~")
                return home;
            if (value.has_prefix ("~/"))
                return Path.build_filename (home, value.substring (2));
            return Path.is_absolute (value) ? value : null;
        }

        private static string accessible_directory (string? path) {
            return path != null && FileUtils.test (path, FileTest.IS_DIR) &&
                Posix.access (path, Posix.R_OK | Posix.X_OK) == 0 ? path : "";
        }

        private static Json.Node? read_json (string path) throws Error {
            var file = File.new_for_path (path);
            try {
                var info = file.query_info (FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                if (info.get_file_type () != FileType.REGULAR)
                    throw invalid_metadata (path);
            } catch (IOError.NOT_FOUND error) {
                return null;
            }
            var parser = new Json.Parser ();
            parser.load_from_file (path);
            var json = parser.get_root ();
            if (json == null)
                throw invalid_metadata (path);
            return json.copy ();
        }

        private static Error invalid_metadata (string path) {
            return new IOError.INVALID_DATA (_("Invalid Heroic metadata in %s.").printf (path));
        }

        private static Json.Object? as_object (Json.Node? node) {
            return node != null && node.get_node_type () == Json.NodeType.OBJECT ? node.get_object () : null;
        }

        private static string? get_string (Json.Object? object, string key) {
            var node = object?.get_member (key);
            return node != null && node.get_value_type () == typeof (string) ? node.get_string () : null;
        }

        private static bool get_boolean (Json.Object object, string key, bool fallback) {
            var node = object.get_member (key);
            return node != null && node.get_value_type () == typeof (bool) ? node.get_boolean () : fallback;
        }
    }
}
