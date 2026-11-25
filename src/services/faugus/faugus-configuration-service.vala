namespace ProtonPlus.Services {
    using ProtonPlus.Models;

    internal class FaugusGameRecord : Object {
        public string id;
        public string title;
        public string source_path;
        public Json.Object entry;
        public string runner;
        public string game_directory;
        public string prefix_directory;
        public bool legacy;
        public bool settings_available = true;
        public bool launchable = true;

        public FaugusGameRecord (string id, string title, string source_path, Json.Object entry,
            string game_directory, string prefix_directory, bool legacy) {
            this.id = id;
            this.title = title;
            this.source_path = source_path;
            this.entry = entry;
            this.runner = FaugusConfigurationService.string_member (entry, "runner") ?? "";
            this.game_directory = game_directory;
            this.prefix_directory = prefix_directory;
            this.legacy = legacy;
        }

        public bool can_edit () {
            var node = entry.get_member ("runner");
            return settings_available && !legacy && runner != "Steam" && runner != "Linux-Native" &&
                (node == null || node.is_null () || node.get_value_type () == typeof (string));
        }
    }

    internal class FaugusLibrary : Object {
        public File? file;
        public string? etag;
        public Json.Array entries = new Json.Array ();
        public bool show_hidden;
        public bool legacy;
        public bool from_legacy_root;
        public string? settings_error;
        public string default_runner = FaugusConfigurationService.BUILTIN_DEFAULT;
    }

    public class FaugusConfigurationService : Object {
        internal const string BUILTIN_DEFAULT = "Proton-CachyOS Latest";
        private const string DIRECTORY = "faugus-launcher";
        private const string GAMES = "games.json";
        private const string DEFAULT = "Default";

        private string home;
        private string data_root;
        private string config_root;
        private bool flatpak;
        private bool through_host;
        private FaugusBackend backend;
        private Mutex write_lock;

        public FaugusConfigurationService (bool flatpak, string home, string config_home, string data_home,
            FaugusBackend? backend = null, bool through_host = false) {
            this.flatpak = flatpak;
            this.home = home;
            this.through_host = through_host;
            if (flatpak) {
                var app = Path.build_filename (home, ".var", "app", Launchers.FaugusLauncher.FLATPAK_ID);
                config_root = Path.build_filename (app, "config", DIRECTORY);
                data_root = Path.build_filename (app, "data", DIRECTORY);
            } else {
                config_root = Path.build_filename (config_home, DIRECTORY);
                data_root = Path.build_filename (data_home, DIRECTORY);
            }
            this.backend = backend ?? new HostFaugusBackend ();
        }

        internal static string? string_member (Json.Object object, string key) {
            var node = object.get_member (key);
            return node != null && node.get_value_type () == typeof (string) ? node.get_string () : null;
        }

        private static bool truthy_member (Json.Object object, string key) {
            var node = object.get_member (key);
            if (node == null || node.is_null ())
                return false;
            if (node.get_value_type () == typeof (bool))
                return node.get_boolean ();
            var text = string_member (object, key);
            return text != null && text != "";
        }

        private static Json.Object? game_entry (Json.Node node) {
            return node.get_node_type () == Json.NodeType.OBJECT ? node.get_object () : null;
        }

        private Json.Node? read_json (string path, out string? etag) throws Error {
            var file = File.new_for_path (path);
            uint8[] content;
            etag = null;
            try {
                var info = file.query_info (FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                if (info.get_file_type () != FileType.REGULAR)
                    throw new IOError.INVALID_DATA (_("Expected a regular Faugus file: %s").printf (path));
                file.load_contents (null, out content, out etag);
            } catch (IOError.NOT_FOUND error) {
                if (!through_host || !backend.host_path_exists (path))
                    return null;
                throw new IOError.PERMISSION_DENIED (_("ProtonPlus cannot access this Faugus file: %s").printf (path));
            } catch (IOError.PERMISSION_DENIED error) {
                throw new IOError.PERMISSION_DENIED (_("ProtonPlus cannot access this Faugus file: %s").printf (path));
            }
            var parser = new Json.Parser ();
            if (!((string) content).validate_len (content.length))
                throw invalid_file (path);
            try {
                parser.load_from_data ((string) content, content.length);
            } catch (Error error) {
                throw invalid_file (path);
            }
            var node = parser.get_root ();
            if (node == null)
                throw invalid_file (path);
            return node.copy ();
        }

        private static Error invalid_file (string path) {
            return new IOError.INVALID_DATA (_("The Faugus JSON file is invalid: %s").printf (path));
        }

        private FaugusLibrary read_library (bool allow_partial_settings = false) throws Error {
            var library = new FaugusLibrary ();
            var path = Path.build_filename (data_root, GAMES);
            var node = read_json (path, out library.etag);
            if (node == null && data_root != config_root) {
                path = Path.build_filename (config_root, GAMES);
                node = read_json (path, out library.etag);
                library.from_legacy_root = node != null;
            }
            if (node == null)
                return library;
            if (node.get_node_type () != Json.NodeType.ARRAY)
                throw invalid_file (path);
            library.file = File.new_for_path (path);
            library.entries = node.get_array ();
            try {
                read_settings (library);
            } catch (Error error) {
                if (!allow_partial_settings)
                    throw error;
                library.settings_error = error.message;
            }
            return library;
        }

        private void read_settings (FaugusLibrary library) throws Error {
            var config_path = Path.build_filename (config_root, "config.json");
            string? unused_etag;
            var settings = read_json (config_path, out unused_etag);
            if (settings != null) {
                if (settings.get_node_type () != Json.NodeType.OBJECT)
                    throw invalid_file (config_path);
                var config = settings.get_object ();
                library.show_hidden = string_member (config, "show-hidden") == "True" ||
                    (config.get_member ("show-hidden")?.get_value_type () == typeof (bool) &&
                     truthy_member (config, "show-hidden"));
                library.default_runner = (string_member (config, "default-runner") ?? BUILTIN_DEFAULT).replace ("\"", "");
            } else if (library.from_legacy_root) {
                // Releases before per-game inheritance used an unsectioned config.ini.
                try {
                    string text;
                    FileUtils.get_contents (Path.build_filename (config_root, "config.ini"), out text);
                    library.legacy = true;
                    foreach (var line in text.split ("\n")) {
                        var pair = line.strip ().split ("=", 2);
                        if (pair.length == 2 && pair[0].strip () == "show-hidden")
                            library.show_hidden = pair[1].strip () == "True";
                    }
                } catch (FileError.NOENT error) {
                    // A newer release can migrate a library without a legacy config.
                }
            }
        }

        private string accessible_directory (string? value, bool executable = false) {
            var path = value ?? "";
            if (path == "")
                return "";
            if (path.has_prefix ("~/"))
                path = Path.build_filename (home, path.substring (2));
            else if (path.has_prefix ("$HOME/"))
                path = Path.build_filename (home, path.substring (6));
            else if (path.has_prefix ("${HOME}/"))
                path = Path.build_filename (home, path.substring (8));
            if (!Path.is_absolute (path))
                return "";
            if (executable && !FileUtils.test (path, FileTest.IS_DIR))
                path = Path.get_dirname (path);
            return FileUtils.test (path, FileTest.IS_DIR) && Posix.access (path, Posix.R_OK | Posix.X_OK) == 0
                ? path : "";
        }

        private FaugusGameRecord? record (FaugusLibrary library, Json.Object entry) {
            var id = string_member (entry, "gameid");
            var title = string_member (entry, "title");
            if (id == null || !Regex.match_simple ("^[\\p{L}\\p{N}_][\\p{L}\\p{N}_-]*\\z", id) ||
                title == null || title.strip () == "")
                return null;
            var runner = string_member (entry, "runner");
            var settings_available = library.settings_error == null;
            var effective = runner == DEFAULT && settings_available ? library.default_runner : runner;
            var game_dir = effective == "Steam" ? "" : accessible_directory (string_member (entry, "path"), true);
            var prefix_dir = effective == "Steam" || effective == "Linux-Native" ? "" :
                accessible_directory (string_member (entry, "prefix"));
            return new FaugusGameRecord (id, title, library.file.get_path (), entry,
                game_dir, prefix_dir, library.legacy) {
                settings_available = settings_available,
                launchable = settings_available || !library.from_legacy_root
            };
        }

        internal Gee.List<FaugusGameRecord> list_games (out string inherited, out string? settings_error) throws Error {
            var library = read_library (true);
            inherited = library.default_runner;
            settings_error = library.settings_error;
            var games = new Gee.ArrayList<FaugusGameRecord> ();
            var ids = new Gee.HashSet<string> ();
            var duplicates = new Gee.HashSet<string> ();
            foreach (var node in library.entries.get_elements ()) {
                var entry = game_entry (node);
                if (entry == null)
                    continue;
                var id = string_member (entry, "gameid");
                if (id != null && !ids.add (id))
                    duplicates.add (id);
                if (library.show_hidden || !truthy_member (entry, "hidden")) {
                    var game = record (library, entry);
                    if (game != null)
                        games.add (game);
                }
            }
            for (var index = games.size - 1; index >= 0; index--) {
                if (duplicates.contains (games[index].id))
                    games.remove_at (index);
            }
            return games;
        }

        internal Gee.List<CompatibilityTool> runners () throws Error {
            var tools = new Gee.ArrayList<CompatibilityTool> ();
            tools.add (new CompatibilityTool (BUILTIN_DEFAULT, BUILTIN_DEFAULT));
            tools.add (new CompatibilityTool ("GE-Proton Latest", "Proton-GE Latest"));
            tools.add (new CompatibilityTool ("DW-Proton Latest", "DW-Proton Latest"));
            tools.add (new CompatibilityTool ("Proton-Wineland Latest", "Proton-Wineland Latest"));
            foreach (var tool in backend.installed_runners (flatpak)) {
                var id = tool.internal_title;
                if (id != "" && id != DEFAULT && id != "Steam" && id != "Linux-Native" &&
                    !tools.any_match (existing => existing.internal_title == id))
                    tools.add (tool);
            }
            return tools;
        }

        private static Error stale_game () {
            return new IOError.WRONG_ETAG (_("This Faugus game changed or its ID is no longer unique. Reload the library and try again."));
        }

        private FaugusGameRecord find_game (FaugusLibrary library, string id) throws Error {
            Json.Object? match = null;
            foreach (var node in library.entries.get_elements ()) {
                var entry = game_entry (node);
                if (entry == null || string_member (entry, "gameid") != id)
                    continue;
                if (match != null)
                    throw stale_game ();
                match = entry;
            }
            if (match == null)
                throw stale_game ();
            var current = record (library, match);
            if (current == null)
                throw stale_game ();
            return current;
        }

        private FaugusGameRecord revalidate (FaugusLibrary library, FaugusGameRecord expected) throws Error {
            var current = find_game (library, expected.id);
            if (current.source_path != expected.source_path || !current.entry.equal (expected.entry) ||
                (!library.show_hidden && truthy_member (current.entry, "hidden")))
                throw stale_game ();
            if (!current.can_edit ())
                throw new IOError.NOT_SUPPORTED (_("This Faugus game does not support changing its Proton runner."));
            return current;
        }

        internal Gee.List<CompatibilityTool> editor_choices (FaugusGameRecord expected,
            out FaugusGameRecord current, out string inherited) throws Error {
            var library = read_library ();
            current = find_game (library, expected.id);
            if (current.source_path != expected.source_path || current.title != expected.title ||
                string_member (current.entry, "path") != string_member (expected.entry, "path") ||
                string_member (current.entry, "prefix") != string_member (expected.entry, "prefix") ||
                (!library.show_hidden && truthy_member (current.entry, "hidden")))
                throw stale_game ();
            if (!current.can_edit ())
                throw new IOError.NOT_SUPPORTED (_("This Faugus game does not support changing its Proton runner."));
            inherited = library.default_runner;
            return runners ();
        }

        internal FaugusGameRecord save_runner (FaugusGameRecord expected, string runner,
            Cancellable? cancellable, out string inherited, out Gee.List<CompatibilityTool>? choices) throws Error {
            inherited = "";
            choices = null;
            write_lock.lock ();
            try {
                if (cancellable != null)
                    cancellable.set_error_if_cancelled ();
                choices = runners ();
                var library = read_library ();
                var current = revalidate (library, expected);
                inherited = library.default_runner;
                if (runner != DEFAULT && !choices.any_match (tool =>
                    tool.is_assignable && tool.internal_title == runner))
                    throw new IOError.INVALID_ARGUMENT (_("The selected Faugus runner is no longer available."));
                if (!backend.is_closed (flatpak))
                    throw new IOError.BUSY (_("Close the selected Faugus installation and its running games before applying changes."));
                if (library.etag == null)
                    throw new IOError.FAILED (_("The Faugus library cannot be updated atomically."));
                if (current.runner == runner)
                    return current;

                // Faugus rewrites this array from its in-memory library. Check
                // the selected instance above and use the fresh file's etag.
                current.entry.set_string_member ("runner", runner);
                var node = new Json.Node (Json.NodeType.ARRAY);
                node.set_array (library.entries);
                var generator = new Json.Generator ();
                generator.set_pretty (true);
                generator.set_indent (4);
                generator.set_root (node);
                var data = generator.to_data (null) + "\n";
                string? new_etag;
                try {
                    library.file.replace_contents (data.data, library.etag, false,
                        FileCreateFlags.REPLACE_DESTINATION, out new_etag, cancellable);
                } catch (IOError.WRONG_ETAG error) {
                    throw stale_game ();
                }
                return (!) record (library, current.entry);
            } finally {
                write_lock.unlock ();
            }
        }

        internal Subprocess? launch (FaugusGameRecord expected) throws Error {
            var library = read_library (true);
            var current = find_game (library, expected.id);
            if (current.source_path != expected.source_path)
                throw stale_game ();
            if (!current.launchable)
                throw new IOError.INVALID_DATA (library.settings_error);
            string[] argv;
            if (flatpak) {
                argv = { "flatpak", "run" };
                if (current.legacy)
                    argv += "--command=faugus-run";
                argv += Launchers.FaugusLauncher.FLATPAK_ID;
            } else {
                argv = { current.legacy ? "faugus-run" : "faugus-launcher" };
            }
            argv += "--game";
            argv += current.id;
            return backend.spawn (HostFaugusBackend.on_host (argv, through_host), current.game_directory);
        }
    }
}
