namespace ProtonPlus.Services {
    internal class LutrisPaths : Object {
        public string database;
        public string wine;
        public string runtime;
        public string config;

        public LutrisPaths (string data, string legacy_config) throws Error {
            var legacy = File.new_for_path (legacy_config);
            try {
                // Lutris falls back only if the legacy root itself is absent.
                legacy.query_info (FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);
                config = legacy_config;
            } catch (IOError.NOT_FOUND error) {
                config = data;
            }

            var settings = new KeyFile ();
            try {
                settings.load_from_file (Path.build_filename (config, "lutris.conf"), KeyFileFlags.NONE);
            } catch (FileError.NOENT error) {
                // A fresh Lutris installation uses the default paths.
            }
            var default_database = Path.build_filename (data, "pga.db");
            // Python's ConfigParser does not consult DEFAULT for a missing section.
            database = setting_path (settings, "pga_path", default_database);
            wine = Path.build_filename (setting_path (settings, "runner_dir", Path.build_filename (data, "runners")), "wine");
            runtime = setting_path (settings, "runtime_dir", Path.build_filename (data, "runtime"));
        }

        private static string setting_path (KeyFile settings, string key, string fallback) throws Error {
            if (!settings.has_group ("lutris"))
                return fallback;
            var raw = read_setting (settings, key);
            if (raw == null || raw == "")
                return fallback;
            var value = expand_setting (settings, raw, 0);
            // Relative database paths depend on the working directory Lutris
            // started in. Require a path that identifies the same database.
            if (value == null || !Path.is_absolute (value))
                throw new IOError.INVALID_DATA (_("Lutris uses an unsupported path override for %s.").printf (key));
            return value;
        }

        private static string? read_setting (KeyFile settings, string key) {
            foreach (var group in new string[] { "lutris", "DEFAULT" }) {
                try {
                    foreach (var name in settings.get_keys (group)) {
                        if (name.ascii_casecmp (key) == 0)
                            return settings.get_value (group, name).strip ();
                    }
                } catch (KeyFileError error) {
                    // An absent section has no override.
                }
            }
            return null;
        }

        private static string? expand_setting (KeyFile settings, string value, int depth) {
            if (depth == 10)
                return null;
            var expanded = new StringBuilder ();
            int start = 0;
            int percent;
            while ((percent = value.index_of_char ('%', start)) >= 0) {
                expanded.append (value.substring (start, percent - start));
                if (value[percent + 1] == '%') {
                    expanded.append_c ('%');
                    start = percent + 2;
                    continue;
                }
                if (value[percent + 1] != '(')
                    return null;
                var end = value.index_of (")s", percent + 2);
                if (end < 0)
                    return null;
                var raw = read_setting (settings, value.substring (percent + 2, end - percent - 2));
                var replacement = raw != null ? expand_setting (settings, raw, depth + 1) : null;
                if (replacement == null)
                    return null;
                expanded.append (replacement);
                start = end + 2;
            }
            expanded.append (value.substring (start));
            return expanded.str;
        }

    }

    internal errordomain LutrisRunnerChangeError {
        CONFIRM_CONVERSION
    }

    internal class LutrisGameRecord : Object {
        public int64 id;
        public string name;
        public string runner;
        public string directory;
        public string config_id;
        public string database;
        public string database_id;
        public string slug;
        public int64 installed_at;
        public string config_path = "";
        public string game_directory = "";
        public string prefix = "";
        public string accessible_prefix = "";
        public string? custom_path;
        public string? runner_default;
        public LutrisGameConfig? wine_defaults;
        public string? config_error;
        public string arch = "";
        public bool proton_compatible;
        public bool shared_config;
        public LutrisGameConfig? config;

        public bool matches (LutrisGameRecord other) {
            return id == other.id && name == other.name && runner == other.runner &&
                directory == other.directory && config_id == other.config_id &&
                database == other.database && database_id == other.database_id &&
                slug == other.slug && installed_at == other.installed_at && config_path == other.config_path;
        }
    }

    public class LutrisGraphicsVersions : Object {
        public string component { get; private set; }
        public string key { get; private set; }
        public string? saved { get; internal set; }
        public string? inherited { get; internal set; }
        public bool enabled { get; internal set; }
        public bool editable { get; internal set; }
        private Gee.ArrayList<string> available = new Gee.ArrayList<string> ();
        public Gee.List<string> versions { owned get { return available.read_only_view; } }

        internal LutrisGraphicsVersions (string component) {
            this.component = component;
            key = component + "_version";
        }

        internal void add_version (string version) {
            available.add (version);
        }

        internal void sort_versions () {
            available.sort ((a, b) => strcmp (b.collate_key_for_filename (), a.collate_key_for_filename ()));
        }
    }

    public class LutrisGameOptions : Object {
        public const string COMMAND_PREFIX = "prefix_command";
        public const string ENVIRONMENT = "env";
        internal static string[] toggle_keys () {
            return { "dxvk", "vkd3d", "esync", "fsync" };
        }

        internal Gee.HashMap<string, string?> toggles = new Gee.HashMap<string, string?> ();
        internal Gee.HashMap<string, string?> inherited_toggles = new Gee.HashMap<string, string?> ();
        public string? environment { get; internal set; }
        public string? command_prefix { get; internal set; }
        public string? inherited_prefix { get; internal set; }
        public bool command_prefix_editable { get; internal set; }

        public bool has_toggle (string key) { return toggles.has_key (key); }
        public string? get_toggle (string key) { return toggles.get (key); }
        public string? get_inherited_toggle (string key) { return inherited_toggles.get (key); }
    }

    internal class LutrisGameConfig : Object {
        private const string ATTRIBUTES = "standard::type,standard::size,etag::value,id::file,access::can-write";
        private const int MAX_CONFIG_SIZE = 1024 * 1024;

        public string path;
        public string text;
        public string etag;
        public string file_id;
        public LutrisYaml yaml;
        public bool writable;

        public LutrisGameConfig (string path) throws Error {
            this.path = path;
            var file = File.new_for_path (path);
            var info = file.query_info (ATTRIBUTES, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            if (!is_regular (info) || info.get_size () > MAX_CONFIG_SIZE)
                throw new IOError.INVALID_DATA (_("The Lutris game configuration is invalid."));
            uint8[] contents;
            string? loaded_etag;
            file.load_contents (null, out contents, out loaded_etag);
            var latest = file.query_info (ATTRIBUTES, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            if (!is_regular (latest) || loaded_etag == null || loaded_etag != info.get_etag () ||
                loaded_etag != latest.get_etag () || file_identity (info) != file_identity (latest))
                throw new IOError.WRONG_ETAG (_("The Lutris game configuration changed. Reopen the editor and try again."));
            if (contents.length > MAX_CONFIG_SIZE || !((string) contents).validate_len (contents.length))
                throw new IOError.INVALID_DATA (_("The Lutris game configuration is invalid."));
            text = (string) contents;
            var parsed = LutrisYaml.parse (text);
            if (parsed == null || !parsed.has_scalar ("wine", "version") ||
                !parsed.has_scalar ("game", "prefix") || !parsed.has_scalar ("game", "arch"))
                throw new IOError.INVALID_DATA (_("The Lutris game configuration is invalid."));
            yaml = (owned) parsed;
            etag = loaded_etag;
            file_id = file_identity (info) ?? "";
            writable = file_id != "" && info.get_attribute_boolean (FileAttribute.ACCESS_CAN_WRITE) &&
                Posix.access (Path.get_dirname (path), Posix.W_OK | Posix.X_OK) == 0;
        }

        public unowned string? get_setting (string section, string key) {
            return yaml.get (section, key);
        }

        private static string? file_identity (FileInfo info) {
            return info.get_attribute_string (FileAttribute.ID_FILE);
        }

        private static bool is_regular (FileInfo info) {
            return info.get_file_type () == FileType.REGULAR;
        }

        public bool matches (LutrisGameConfig? other) {
            return other != null && file_id == other.file_id && etag == other.etag && text == other.text;
        }
    }

    public class LutrisRemovalReview : Object {
        internal string path;
        internal string? failure;
        internal Gee.HashMap<string, string> games = new Gee.HashMap<string, string> ();

        internal LutrisRemovalReview (string path) {
            this.path = path;
        }

        public string? error {
            owned get {
                if (failure != null)
                    return _("Could not check Lutris runner usage. Restore access to the Lutris library and try again.\n%s")
                        .printf (failure);
                return null;
            }
        }

        public string? affected_games {
            owned get {
                if (games.is_empty)
                    return null;
                var names = new Gee.ArrayList<string> ();
                names.add_all (games.values);
                names.sort ((a, b) => a.collate (b));
                return string.joinv ("\n", names.to_array ());
            }
        }

        internal bool allows (LutrisRemovalReview? confirmed) {
            if (failure != null)
                return false;
            if (confirmed != null && (confirmed.failure != null || confirmed.path != path))
                return false;
            if (games.is_empty)
                return true;
            if (confirmed == null)
                return false;
            return games.keys.all_match ((key) => confirmed.games.get (key) == games.get (key));
        }
    }

    public class LutrisConfigurationService : Object {
        private const string GAME_QUERY = """
            WITH config_uses AS (SELECT configpath, count(*) AS uses FROM games GROUP BY configpath),
                 installed_ids AS (
                     SELECT id FROM games WHERE installed = 1 AND id > 0 AND typeof(id) = 'integer'
                     GROUP BY id HAVING count(*) = 1
                 )
            SELECT g.id, g.name, g.runner, g.directory, g.configpath, config_uses.uses, g.slug, g.installed_at
            FROM games g JOIN installed_ids ON installed_ids.id = g.id
            LEFT JOIN config_uses ON config_uses.configpath = g.configpath
            WHERE g.installed = 1 AND typeof(g.id) = 'integer'
            """;
        private string home;
        private string data_home;
        private string config_home;
        internal string data { get; private set; }
        internal string legacy_config { get; private set; }
        internal string previous_data { get; private set; }
        private bool flatpak;
        private bool through_host;
        private LutrisBackend backend;

        [CCode (cname = "flock", cheader_filename = "sys/file.h")]
        private static extern int flock (int fd, int operation);

        public LutrisConfigurationService (bool flatpak, string home, string data_home, string config_home,
            LutrisBackend? backend = null, bool through_host = false,
            string? flatpak_data_home = null, string? flatpak_config_home = null) {
            this.flatpak = flatpak;
            this.home = home;
            this.data_home = data_home;
            this.config_home = config_home;
            this.through_host = through_host;
            this.backend = backend ?? new HostLutrisBackend (data_home, config_home, through_host);
            var app = Path.build_filename (home, ".var", "app", HostLutrisBackend.APP_ID);
            var app_data = Path.build_filename (app, "data");
            var app_config = Path.build_filename (app, "config");
            data = Path.build_filename (flatpak ? flatpak_data_home ?? app_data : data_home, "lutris");
            legacy_config = Path.build_filename (flatpak ? flatpak_config_home ?? app_config : config_home, "lutris");
            previous_data = flatpak ? Path.build_filename (app_data, "lutris")
                : Path.build_filename (home, ".local", "share", "lutris");
        }

        internal static LutrisConfigurationService for_installation (bool flatpak) {
            var home = Environment.get_home_dir ();
            var data_home = native_data_home ();
            var config_home = Globals.IS_FLATPAK
                ? host_xdg_dir ("HOST_XDG_CONFIG_HOME", Path.build_filename (home, ".config"))
                : Environment.get_user_config_dir ();
            string? flatpak_data_home = null;
            string? flatpak_config_home = null;
            if (flatpak)
                HostLutrisBackend.read_flatpak_profile_homes (Globals.IS_FLATPAK, home,
                    out flatpak_data_home, out flatpak_config_home);
            return new LutrisConfigurationService (flatpak, home, data_home, config_home, null, Globals.IS_FLATPAK,
                flatpak_data_home, flatpak_config_home);
        }

        internal static string native_data_home () {
            return Globals.IS_FLATPAK
                ? host_xdg_dir ("HOST_XDG_DATA_HOME", Path.build_filename (Environment.get_home_dir (), ".local", "share"))
                : Environment.get_user_data_dir ();
        }

        private static string host_xdg_dir (string variable, string fallback) {
            var path = Environment.get_variable (variable);
            return path != null && Path.is_absolute (path) ? path : fallback;
        }

        internal LutrisPaths resolve_paths () throws Error {
            return new LutrisPaths (data, legacy_config);
        }

        internal Gee.List<LutrisGameRecord> read_library (int64 id = 0, bool for_dependencies = false) throws Error {
            var paths = resolve_paths ();
            var db_path = Posix.realpath (paths.database);
            if (db_path == null && Posix.errno == Posix.ENOENT && !for_dependencies)
                return new Gee.ArrayList<LutrisGameRecord> ();
            if (db_path == null || !FileUtils.test (db_path, FileTest.IS_REGULAR))
                throw library_error ();
            var database_info = File.new_for_path (db_path).query_info (FileAttribute.ID_FILE, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            var database_id = database_info.get_attribute_string (FileAttribute.ID_FILE) ?? "";
            Sqlite.Database db;
            if (Sqlite.Database.open_v2 (db_path, out db, Sqlite.OPEN_READONLY) != Sqlite.OK)
                throw library_error ();
            Sqlite.Statement rows;
            var query = for_dependencies
                ? """SELECT id, name, runner, directory, configpath, 1, slug, installed_at
                     FROM games WHERE installed = 1 AND runner = 'wine' ORDER BY id"""
                : GAME_QUERY + (id > 0 ? " AND g.id = ?1" : "") + " ORDER BY g.id";
            if (db.prepare_v2 (query, -1, out rows) != Sqlite.OK)
                throw library_error ();
            if (id > 0)
                rows.bind_int64 (1, id);
            var records = new Gee.ArrayList<LutrisGameRecord> ();
            LutrisGameConfig? defaults = null;
            string? defaults_error = null;
            try {
                defaults = new LutrisGameConfig (Path.build_filename (paths.config, "runners", "wine.yml"));
            } catch (IOError.NOT_FOUND error) {
                // An absent runner config uses Lutris's built-in defaults.
            } catch (Error error) {
                defaults_error = error.message;
            }
            int state;
            while ((state = rows.step ()) == Sqlite.ROW) {
                var record = new LutrisGameRecord () {
                    id = rows.column_int64 (0),
                    name = rows.column_text (1) ?? "",
                    runner = rows.column_text (2) ?? "",
                    directory = rows.column_text (3) ?? "",
                    config_id = rows.column_text (4) ?? "",
                    database = db_path,
                    database_id = database_id,
                    shared_config = rows.column_int (5) != 1,
                    slug = rows.column_text (6) ?? "",
                    installed_at = rows.column_int64 (7)
                };
                load_config (record, paths.config, record.runner == "wine" ? defaults : null);
                if (record.runner == "wine") {
                    record.wine_defaults = defaults;
                    record.runner_default = defaults?.get_setting ("wine", "version");
                    record.custom_path = record.config?.get_setting ("wine", "custom_wine_path") ??
                        defaults?.get_setting ("wine", "custom_wine_path");
                    record.config_error = record.config_error ?? defaults_error;
                    record.proton_compatible = supports_proton (record);
                }
                records.add (record);
            }
            if (state != Sqlite.DONE)
                throw library_error ();
            return records;
        }

        private void load_config (LutrisGameRecord record, string root, LutrisGameConfig? defaults) {
            record.game_directory = accessible_directory (expand_path (record.directory));
            if (record.config_id != "" && record.config_id != "." && record.config_id != ".." &&
                !record.config_id.contains ("/")) {
                var root_path = Path.build_filename (root, "games");
                var games_root = Posix.realpath (root_path) ?? root_path;
                var path = Path.build_filename (games_root, record.config_id + ".yml");
                record.config_path = path;
                try {
                    record.config = new LutrisGameConfig (path);
                } catch (IOError.NOT_FOUND error) {
                    // Lutris reads a missing game file as an empty override.
                } catch (Error error) {
                    record.config_error = error.message;
                    debug ("Could not read Lutris configuration for ID %lld: %s", record.id, error.message);
                }
            } else if (record.config_id != "") {
                record.config_error = _("The Lutris game configuration is invalid.");
            }
            unowned LutrisYaml? yaml = record.config?.yaml;
            var exe = expand_path (yaml?.get ("game", "exe") ?? defaults?.get_setting ("game", "exe"));
            if (exe == "" && record.runner != "wine")
                exe = expand_path (yaml?.get ("game", "main_file"));
            if (exe != "" && !Path.is_absolute (exe) && record.game_directory != "")
                exe = Path.build_filename (record.game_directory, exe);
            if (record.game_directory == "" && Path.is_absolute (exe))
                record.game_directory = accessible_directory (Path.get_dirname (exe));
            if (record.runner == "wine") {
                record.arch = yaml?.get ("game", "arch") ?? defaults?.get_setting ("game", "arch") ?? "";
                var configured_prefix = yaml?.get ("game", "prefix") ?? defaults?.get_setting ("game", "prefix");
                var prefix = expand_path (configured_prefix ?? Environment.get_variable ("WINEPREFIX"));
                if (prefix == "" && Path.is_absolute (exe)) {
                    for (var parent = Path.get_dirname (exe); parent != "/"; parent = Path.get_dirname (parent)) {
                        if (FileUtils.test (Path.build_filename (parent, "system.reg"), FileTest.IS_REGULAR)) {
                            prefix = parent;
                            break;
                        }
                    }
                }
                record.prefix = prefix;
                record.accessible_prefix = accessible_directory (prefix);
            }
        }

        private string expand_path (string? path) {
            if (path == null)
                return "";
            if (path == "~" || path.has_prefix ("~/"))
                return home + path.substring (1);
            return path;
        }

        internal void collect_runner_usage (LutrisRemovalReview review) throws Error {
            var records = read_library (0, true);
            Gee.List<Models.CompatibilityTool>? shared_candidates = null;
            foreach (var record in records) {
                if (record.config_error != null)
                    throw new IOError.INVALID_DATA ("%s: %s".printf (record.name, record.config_error));
                if (shared_candidates == null)
                    shared_candidates = installed_runners ();
                var saved = record.config?.get_setting ("wine", "version");
                var effective = effective_runner (record, saved, shared_candidates);
                var candidates = effective == "custom" ? runners_for (record) : shared_candidates;
                var tool = find_runner (candidates, effective);
                if (tool == null)
                    continue;
                var root = tool.installation_path;
                var executable = tool.path != "" ? Posix.realpath (tool.path) : null;
                if (root != review.path && executable != review.path &&
                    (executable == null || !executable.has_prefix (review.path + "/")))
                    continue;
                var instance = flatpak ? _("Lutris Flatpak") : _("Lutris System");
                var key = "%s\n%s\n%lld\n%s".printf (
                    flatpak ? "flatpak" : "system", record.database, record.id, record.config_path);
                review.games.set (key, _("%s · %s").printf (record.name, instance));
            }
        }

        internal static string accessible_directory (string path) {
            return Path.is_absolute (path) && FileUtils.test (path, FileTest.IS_DIR) &&
                Posix.access (path, Posix.R_OK | Posix.X_OK) == 0 ? path : "";
        }

        internal Gee.List<Models.CompatibilityTool> installed_runners () throws Error {
            return backend.get_runners (flatpak, null);
        }

        internal Gee.List<Models.CompatibilityTool> runners_for (LutrisGameRecord record) throws Error {
            if (record.config_error != null)
                throw new IOError.INVALID_DATA (record.config_error);
            return backend.get_runners (flatpak, record.custom_path);
        }

        internal const string LATEST = "ge-proton";

        internal LutrisGameOptions read_game_options (LutrisGameRecord record) throws Error {
            var options = new LutrisGameOptions ();
            unowned var yaml = record.config.yaml;
            foreach (var key in LutrisGameOptions.toggle_keys ()) {
                var saved = yaml.get_toggle (key);
                var inherited = record.wine_defaults == null ? -1 : record.wine_defaults.yaml.get_toggle (key);
                if (!yaml.toggle_editable (key) || inherited == -2)
                    continue;
                options.toggles[key] = toggle_string (saved);
                options.inherited_toggles[key] = inherited == -1 && key != "fsync" ? "true" : toggle_string (inherited);
            }

            options.command_prefix = yaml.get ("system", LutrisGameOptions.COMMAND_PREFIX);
            options.command_prefix_editable = yaml.setting_editable ("system", LutrisGameOptions.COMMAND_PREFIX) &&
                (options.command_prefix == null || (!options.command_prefix.contains ("\n") &&
                    !options.command_prefix.contains ("\r")));
            options.inherited_prefix = record.wine_defaults?.get_setting ("system", LutrisGameOptions.COMMAND_PREFIX);
            if (options.inherited_prefix == null) {
                try {
                    var path = Path.build_filename (resolve_paths ().config, "system.yml");
                    var defaults = new LutrisGameConfig (path);
                    options.inherited_prefix = defaults.get_setting ("system", LutrisGameOptions.COMMAND_PREFIX);
                } catch (IOError.NOT_FOUND error) {
                    // No system override was saved.
                } catch (Error error) {
                    debug ("Could not read Lutris system defaults: %s", error.message);
                }
            }
            options.environment = read_environment (yaml);
            return options;
        }

        private static string? toggle_string (int value) {
            return value == 1 ? "true" : value == 0 ? "false" : null;
        }

        private static bool component_enabled (LutrisGameRecord record, string component,
            Gee.Map<string, string?>? edits = null) {
            var inherited = record.wine_defaults == null ? -1 : record.wine_defaults.yaml.get_toggle (component);
            if (edits != null && edits.has_key (component)) {
                var requested = edits.get (component);
                return requested == null ? inherited != 0 : requested == "true";
            }
            var saved = record.config == null ? -1 : record.config.yaml.get_toggle (component);
            var effective = saved == -1 ? inherited : saved;
            return effective == -1 || effective == 1;
        }

        private static bool valid_env_name (string name) {
            return Regex.match_simple ("^[A-Za-z_][A-Za-z0-9_]*\\z", name);
        }

        private static string? read_environment (LutrisYaml yaml) {
            var mapping = yaml.get_environment ();
            if (mapping == null)
                return null;
            var parser = new Json.Parser ();
            try {
                parser.load_from_data (mapping);
            } catch (Error error) {
                return null;
            }
            var object = parser.get_root ().get_object ();
            var text = new StringBuilder ();
            foreach (var name in object.get_members ()) {
                var value = object.get_string_member (name);
                if (!valid_env_name (name) || value.contains ("\n") || value.contains ("\r"))
                    return null;
                if (text.len != 0)
                    text.append_c ('\n');
                text.append ("%s=%s".printf (name, value));
            }
            return text.str;
        }

        private static string patch_environment (string source, string input) throws Error {
            var builder = new Json.Builder ();
            builder.begin_object ();
            var names = new Gee.HashSet<string> ();
            var expected = new StringBuilder ();
            var line_number = 0;
            foreach (var line in input.split ("\n")) {
                line_number++;
                if (line == "")
                    continue;
                var equals = line.index_of_char ('=');
                if (equals <= 0 || line.contains ("\r"))
                    throw new IOError.INVALID_DATA (_("Enter an environment variable as NAME=value on line %d.").printf (line_number));
                var name = line.substring (0, equals);
                if (!valid_env_name (name) || !names.add (name))
                    throw new IOError.INVALID_DATA (_("Use a valid, unique environment variable name on line %d.").printf (line_number));
                builder.set_member_name (name);
                builder.add_string_value (line.substring (equals + 1));
                if (expected.len != 0)
                    expected.append_c ('\n');
                expected.append (line);
            }
            builder.end_object ();
            var generator = new Json.Generator ();
            generator.set_root (builder.get_root ());
            var yaml = LutrisYaml.parse (source);
            var updated = yaml?.set_environment (names.is_empty ? null : generator.to_data (null));
            var validated = updated == null ? null : LutrisYaml.parse (updated);
            if (validated == null || read_environment (validated) != expected.str)
                throw new IOError.INVALID_DATA (_("The Lutris environment variables could not be saved."));
            return (!) updated;
        }

        internal static string? ge_proton_release_tag (string version) {
            if (!Regex.match_simple ("^GE-Proton[0-9]+-[0-9]+(-x86_64|-aarch64)?\\z", version))
                return null;
            return version.has_suffix ("-x86_64") || version.has_suffix ("-aarch64")
                ? version.substring (0, version.last_index_of_char ('-')) : version;
        }

        internal static string? repairable_runner (LutrisGameRecord record, Gee.List<Models.CompatibilityTool>? choices) {
            var version = effective_runner (record, record.config?.get_setting ("wine", "version"), choices);
            var latest = find_runner (choices, LATEST);
            if (ge_proton_release_tag (version) == null || !record.proton_compatible ||
                latest == null || !latest.is_available || find_runner (choices, version) != null)
                return null;
            return version;
        }

        internal void validate_runner_repair (LutrisGameRecord expected, string version) throws Error {
            var current = revalidate (expected);
            if (repairable_runner (current, runners_for (current)) != version)
                throw new IOError.NOT_FOUND (_("The Lutris runner assignment or availability changed. Reopen the editor and try again."));
        }

        internal Gee.List<LutrisGraphicsVersions> graphics_versions (LutrisGameRecord record) throws Error {
            var result = new Gee.ArrayList<LutrisGraphicsVersions> ();
            var runtime = resolve_paths ().runtime;
            foreach (var component in new string[] { "dxvk", "vkd3d" }) {
                var choices = new LutrisGraphicsVersions (component);
                choices.saved = record.config?.get_setting ("wine", choices.key);
                choices.inherited = record.wine_defaults?.get_setting ("wine", choices.key);
                choices.enabled = component_enabled (record, component);
                choices.editable = record.config != null && record.config.yaml.setting_editable ("wine", choices.key) &&
                    (record.wine_defaults == null || record.wine_defaults.yaml.has_scalar ("wine", choices.key));
                var directory = File.new_for_path (Path.build_filename (runtime, component));
                try {
                    var entries = directory.enumerate_children ("standard::name,standard::type",
                        FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                    FileInfo? entry;
                    while ((entry = entries.next_file ()) != null) {
                        var name = entry.get_name ();
                        if (entry.get_file_type () == FileType.DIRECTORY && name.validate () &&
                            !name.has_prefix (".") && !name.has_suffix (" Backup"))
                            choices.add_version (name);
                    }
                    choices.sort_versions ();
                } catch (IOError.NOT_FOUND error) {
                    // Lutris has not created this runtime directory yet.
                } catch (Error error) {
                    choices.editable = false;
                    debug ("Could not read Lutris %s versions: %s", component, error.message);
                }
                result.add (choices);
            }
            return result.read_only_view;
        }

        internal static Models.CompatibilityTool? find_runner (
            Gee.List<Models.CompatibilityTool>? candidates, string id
        ) {
            return candidates == null ? null : candidates.first_match ((tool) => tool.internal_title == id);
        }

        internal static string effective_runner (LutrisGameRecord record, string? version,
            Gee.List<Models.CompatibilityTool>? candidates) {
            // 0.5.22 treats a saved ge-proton as inheritance. 0.5.23
            // honors it as an explicit selection.
            var latest = find_runner (candidates, LATEST);
            var explicit_latest = latest == null || latest.is_assignable;
            if (version != null && version != "" && (version != LATEST || explicit_latest))
                return version;
            var inherited = record.runner_default;
            return inherited != null && inherited != "" ? inherited : LATEST;
        }

        internal static string? runner_diagnostic (LutrisGameRecord record, Models.CompatibilityTool? tool) {
            if (tool == null)
                return _("Runner is missing");
            if (!tool.is_available)
                return tool.availability_diagnostic ?? _("Runner is missing");
            if (tool.runtime_kind == Models.CompatibilityToolRuntimeKind.PROTON && !record.proton_compatible)
                return _("Proton requires a compatible 64-bit prefix");
            return null;
        }

        private static bool supports_proton (LutrisGameRecord record) {
            if (record.arch == "win32")
                return false;
            if (record.prefix != "" && !Path.is_absolute (record.prefix))
                return false;
            if (record.prefix == "")
                return Globals.CPU_CAPABILITIES == null ||
                    Globals.CPU_CAPABILITIES.architecture != Models.CpuArchitecture.X86_32;
            var registry = Path.build_filename (record.prefix, "system.reg");
            if (!FileUtils.test (registry, FileTest.EXISTS))
                return accessible_directory (record.prefix) != "" ||
                    accessible_directory (Path.get_dirname (record.prefix)) != "";
            if (!FileUtils.test (registry, FileTest.IS_REGULAR))
                return false;
            var stream = FileStream.open (registry, "r");
            if (stream == null)
                return false;
            var line = new char[256];
            for (var i = 0; i < 5 && stream.gets (line) != null; i++) {
                var header = ((string) line).strip ();
                if (header == "#arch=win32")
                    return false;
                if (header == "#arch=win64")
                    return true;
            }
            return false;
        }

        internal LutrisGameRecord revalidate (LutrisGameRecord expected, bool compare_config = true) throws Error {
            var records = read_library (expected.id);
            if (records.size != 1 || !expected.matches (records[0]) || expected.database_id == "" ||
                !can_edit (records[0]) || (compare_config && (expected.config == null ||
                    !expected.config.matches (records[0].config))))
                throw new IOError.WRONG_ETAG (_("The Lutris game configuration changed or is read-only. Reload the Games list and try again."));
            return records[0];
        }

        internal static bool can_edit (LutrisGameRecord record) {
            return record.runner == "wine" && !record.shared_config && record.config != null &&
                record.config.writable && record.config.yaml.setting_editable ("wine", "version");
        }

        internal void save_settings (LutrisGameRecord expected, bool change_runner, string? version,
            Gee.Map<string, string?>? runner_settings, Gee.Map<string, string?>? system_settings,
            Cancellable? cancellable, string? confirmed_conversion = null) throws Error {
            var current = revalidate (expected);
            // Lock the existing configuration directory across ProtonPlus processes.
            var lock_fd = Posix.open (Path.get_dirname (current.config_path),
                Posix.O_RDONLY | Posix.O_CLOEXEC | Posix.O_DIRECTORY | Posix.O_NOFOLLOW);
            if (lock_fd < 0)
                throw new IOError.PERMISSION_DENIED (_("The Lutris game configuration is read-only."));
            try {
                if (flock (lock_fd, 2 | 4) != 0)
                    throw new IOError.BUSY (_("Another Lutris configuration change is in progress."));
                require_closed ();
                var check_runner = change_runner || (runner_settings != null && !runner_settings.is_empty);
                var candidates = check_runner ? runners_for (current) : null;
                if (!change_runner)
                    version = current.config.get_setting ("wine", "version");
                var effective = effective_runner (current, version, candidates);
                var tool = find_runner (candidates, effective);
                if (change_runner && version != null && (effective != version || (tool != null && !tool.is_assignable)))
                    throw new IOError.NOT_FOUND (_("This tool is no longer available. Choose a different tool."));
                if (check_runner) {
                    current = revalidate (expected);
                    if (effective != effective_runner (current, version, candidates) ||
                        (effective == "custom" && current.custom_path != tool?.path))
                        throw new IOError.WRONG_ETAG (_("The Lutris runner changed. Reopen the editor and try again."));
                    require_usable_runner (current, tool);
                }
                var updated = current.config.text;
                if (change_runner)
                    updated = patch_setting (updated, "wine", "version", version);
                if (runner_settings != null && !runner_settings.is_empty)
                    updated = patch_runner_options (current, updated, tool.runtime_kind, runner_settings);
                if (system_settings != null && !system_settings.is_empty)
                    updated = patch_system_options (current, updated, system_settings);
                cancellable?.set_error_if_cancelled ();
                if (change_runner && updated != current.config.text && tool.runtime_kind == Models.CompatibilityToolRuntimeKind.PROTON &&
                    is_wine_only_prefix (current.prefix)) {
                    var confirmation = "%s\n%s\n%s\n%s".printf (
                        Posix.realpath (current.prefix) ?? current.prefix, effective, tool.installation_path, current.config.etag);
                    if (confirmed_conversion != confirmation)
                        throw new LutrisRunnerChangeError.CONFIRM_CONVERSION (confirmation);
                }
                if (updated != current.config.text) {
                    require_closed ();
                    var file = File.new_for_path (current.config_path);
                    file.replace_contents (updated.data, current.config.etag, false,
                        FileCreateFlags.NONE, null, cancellable);
                }
            } finally {
                Posix.close (lock_fd);
            }
        }

        private string patch_runner_options (LutrisGameRecord record, string source,
            Models.CompatibilityToolRuntimeKind runtime, Gee.Map<string, string?> edits) throws Error {
            var wine = runtime == Models.CompatibilityToolRuntimeKind.WINE;
            var updated = source;
            var pending_versions = 0;
            foreach (var key in edits.keys) {
                if (key == "dxvk_version" || key == "vkd3d_version") {
                    pending_versions++;
                    continue;
                }
                if (!(key in LutrisGameOptions.toggle_keys ()) || (key == "vkd3d" && !wine))
                    throw new IOError.NOT_SUPPORTED (_("The selected runner does not support this Lutris option."));
                updated = patch_setting (updated, "wine", key, edits.get (key), true);
            }
            if (pending_versions == 0)
                return updated;
            if (!wine)
                throw new IOError.NOT_SUPPORTED (_("DXVK and VKD3D versions can be changed for Wine runners only."));
            foreach (var choices in graphics_versions (record)) {
                if (!edits.has_key (choices.key))
                    continue;
                var value = edits.get (choices.key);
                if (!component_enabled (record, choices.component, edits) || !choices.editable ||
                    (value != null && !(value in choices.versions)))
                    throw new IOError.NOT_FOUND (_("The selected %s version is no longer available.")
                        .printf (choices.component.up ()));
                updated = patch_setting (updated, "wine", choices.key, value);
            }
            return updated;
        }

        private string patch_system_options (LutrisGameRecord record, string source, Gee.Map<string, string?> edits) throws Error {
            var options = read_game_options (record);
            var updated = source;
            foreach (var key in edits.keys) {
                var value = edits.get (key);
                if (key == LutrisGameOptions.COMMAND_PREFIX && options.command_prefix_editable &&
                    (value == null || (!value.contains ("\n") && !value.contains ("\r")))) {
                    updated = patch_setting (updated, "system", key, value);
                } else if (key == LutrisGameOptions.ENVIRONMENT && options.environment != null) {
                    updated = patch_environment (updated, value ?? "");
                } else {
                    throw new IOError.INVALID_DATA (_("The Lutris system option cannot be edited."));
                }
            }
            return updated;
        }

        private static string patch_setting (string source, string section, string key, string? value,
            bool boolean = false) throws Error {
            var yaml = LutrisYaml.parse (source);
            var updated = yaml?.set_setting (section, key, value, boolean);
            var validated = updated != null ? LutrisYaml.parse (updated) : null;
            if (validated == null || (boolean ? toggle_string (validated.get_toggle (key)) : validated.get (section, key)) != value)
                throw new IOError.INVALID_DATA (_("The Lutris game configuration is invalid."));
            return (!) updated;
        }

        private static void require_usable_runner (LutrisGameRecord record, Models.CompatibilityTool? tool) throws Error {
            var diagnostic = runner_diagnostic (record, tool);
            if (diagnostic != null)
                throw new IOError.NOT_FOUND (_("This tool is no longer available. %s.").printf (diagnostic));
        }

        private static bool is_wine_only_prefix (string prefix) {
            return Path.is_absolute (prefix) &&
                FileUtils.test (Path.build_filename (prefix, "user.reg"), FileTest.EXISTS) &&
                !FileUtils.test (Path.build_filename (prefix, "tracked_files"), FileTest.EXISTS) &&
                !FileUtils.test (Path.build_filename (prefix, "version"), FileTest.EXISTS);
        }

        private void require_closed () throws Error {
            if (!backend.is_closed (flatpak))
                throw new IOError.BUSY (_("Close the selected Lutris installation before saving."));
        }

        internal Subprocess? launch (LutrisGameRecord expected) throws Error {
            // Native and Flatpak Lutris share a GApplication ID. If the other
            // client owns it, GLib could hand the game ID to the wrong library.
            if (!backend.is_closed (!flatpak))
                throw new IOError.BUSY (_("Close the other Lutris installation before launching this game."));
            var records = read_library (expected.id);
            if (records.size != 1 || !expected.matches (records[0]))
                throw new IOError.NOT_FOUND (_("The selected Lutris game changed or its ID is no longer unique. Reload the Games list and try again."));
            var uri = "lutris:rungameid/%lld".printf (expected.id);
            string[] argv;
            if (flatpak)
                argv = { "flatpak", "run", HostLutrisBackend.APP_ID, uri };
            else if (through_host)
                argv = { "env", "XDG_DATA_HOME=" + data_home, "XDG_CONFIG_HOME=" + config_home, "lutris", uri };
            else
                argv = { "lutris", uri };
            return backend.spawn (HostLutrisBackend.on_host (argv, through_host));
        }

        private static IOError library_error () {
            return new IOError.INVALID_DATA (_("Could not read the Lutris game database."));
        }
    }
}
