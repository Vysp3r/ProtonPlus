namespace ProtonPlus.Services {
    internal class LutrisPaths : Object {
        public string database;
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
            database = settings.has_group ("lutris")
                ? setting_path (settings, "pga_path", default_database) : default_database;
        }

        private static string setting_path (KeyFile settings, string key, string fallback) throws Error {
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
        public bool shared_config;
        public LutrisGameConfig? config;

        public bool matches (LutrisGameRecord other) {
            return id == other.id && name == other.name && runner == other.runner &&
                directory == other.directory && config_id == other.config_id &&
                database == other.database && database_id == other.database_id &&
                slug == other.slug && installed_at == other.installed_at && config_path == other.config_path;
        }
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
        private string data;
        private string legacy_config;
        private bool flatpak;
        private bool through_host;
        private LutrisBackend backend;

        [CCode (cname = "flock", cheader_filename = "sys/file.h")]
        private static extern int flock (int fd, int operation);

        public LutrisConfigurationService (bool flatpak, string home, string data_home, string config_home,
            LutrisBackend? backend = null, bool through_host = false) {
            this.flatpak = flatpak;
            this.home = home;
            this.through_host = through_host;
            this.backend = backend ?? new HostLutrisBackend ();
            var app = Path.build_filename (home, ".var", "app", HostLutrisBackend.APP_ID);
            data = flatpak ? Path.build_filename (app, "data", "lutris") : Path.build_filename (data_home, "lutris");
            legacy_config = flatpak ? Path.build_filename (app, "config", "lutris")
                : Path.build_filename (config_home, "lutris");
        }

        internal static LutrisConfigurationService for_installation (bool flatpak) {
            var home = Environment.get_home_dir ();
            var data_home = native_data_home ();
            var config_home = Globals.IS_FLATPAK
                ? host_xdg_dir ("HOST_XDG_CONFIG_HOME", Path.build_filename (home, ".config"))
                : Environment.get_user_config_dir ();
            return new LutrisConfigurationService (flatpak, home, data_home, config_home, null, Globals.IS_FLATPAK);
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

        internal Gee.List<LutrisGameRecord> read_library (int64 id = 0) throws Error {
            var paths = new LutrisPaths (data, legacy_config);
            var db_path = Posix.realpath (paths.database);
            if (db_path == null && Posix.errno == Posix.ENOENT)
                return new Gee.ArrayList<LutrisGameRecord> ();
            if (db_path == null || !FileUtils.test (db_path, FileTest.IS_REGULAR))
                throw library_error ();
            var database_info = File.new_for_path (db_path).query_info (FileAttribute.ID_FILE, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            var database_id = database_info.get_attribute_string (FileAttribute.ID_FILE) ?? "";
            Sqlite.Database db;
            if (Sqlite.Database.open_v2 (db_path, out db, Sqlite.OPEN_READONLY) != Sqlite.OK)
                throw library_error ();
            Sqlite.Statement rows;
            var query = GAME_QUERY + (id > 0 ? " AND g.id = ?1" : "") + " ORDER BY g.id";
            if (db.prepare_v2 (query, -1, out rows) != Sqlite.OK)
                throw library_error ();
            if (id > 0)
                rows.bind_int64 (1, id);
            var records = new Gee.ArrayList<LutrisGameRecord> ();
            var inherited_custom_path = inherited_setting (paths, "custom_wine_path");
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
                load_config (record, paths.config);
                record.custom_path = record.config?.get_setting ("wine", "custom_wine_path") ?? inherited_custom_path;
                records.add (record);
            }
            if (state != Sqlite.DONE)
                throw library_error ();
            return records;
        }

        private void load_config (LutrisGameRecord record, string root) {
            record.game_directory = accessible_directory (expand_path (record.directory));
            if (record.config_id != "" && record.config_id != "." && record.config_id != ".." &&
                !record.config_id.contains ("/")) {
                var games_root = Posix.realpath (Path.build_filename (root, "games"));
                if (games_root != null) {
                    var path = Path.build_filename (games_root, record.config_id + ".yml");
                    record.config_path = path;
                    try {
                        record.config = new LutrisGameConfig (path);
                    } catch (Error error) {
                        debug ("Could not read Lutris configuration for ID %lld: %s", record.id, error.message);
                    }
                }
            }
            unowned LutrisYaml? yaml = record.config?.yaml;
            var exe = expand_path (yaml?.get ("game", "exe"));
            if (exe == "" && record.runner != "wine")
                exe = expand_path (yaml?.get ("game", "main_file"));
            if (exe != "" && !Path.is_absolute (exe) && record.game_directory != "")
                exe = Path.build_filename (record.game_directory, exe);
            if (record.game_directory == "" && Path.is_absolute (exe))
                record.game_directory = accessible_directory (Path.get_dirname (exe));
            if (record.runner == "wine") {
                var prefix = expand_path (yaml?.get ("game", "prefix"));
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

        internal static string accessible_directory (string path) {
            return Path.is_absolute (path) && FileUtils.test (path, FileTest.IS_DIR) &&
                Posix.access (path, Posix.R_OK | Posix.X_OK) == 0 ? path : "";
        }

        internal Gee.List<Models.CompatibilityTool> installed_runners () throws Error {
            return backend.get_runners (flatpak, null);
        }

        internal Gee.List<Models.CompatibilityTool> runners_for (LutrisGameRecord record) throws Error {
            var candidates = backend.get_runners (flatpak, record.custom_path);
            var result = new Gee.ArrayList<Models.CompatibilityTool> ();
            var proton_allowed = supports_proton (record);
            foreach (var tool in candidates) {
                if (tool.runtime_kind != Models.CompatibilityToolRuntimeKind.PROTON || proton_allowed)
                    result.add (tool);
            }
            return result;
        }

        internal string? inherited_runner () {
            try {
                return inherited_setting (new LutrisPaths (data, legacy_config), "version");
            } catch (Error error) {
                return null;
            }
        }

        private static string? inherited_setting (LutrisPaths paths, string key) {
            try {
                var config = new LutrisGameConfig (Path.build_filename (paths.config, "runners", "wine.yml"));
                return config.yaml.get ("wine", key);
            } catch (Error error) {
                return null;
            }
        }

        private static bool supports_proton (LutrisGameRecord record) {
            if (record.config?.get_setting ("game", "arch") == "win32")
                return false;
            if (record.prefix != "" && !Path.is_absolute (record.prefix))
                return false;
            if (record.prefix == "")
                return false;
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
                if (((string) line).contains ("win32"))
                    return false;
                if (((string) line).contains ("win64"))
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
                record.config.writable && record.config.yaml.version_editable ();
        }

        internal void save_version (LutrisGameRecord expected, string? version, Cancellable? cancellable) throws Error {
            var current = revalidate (expected);
            // Lock the existing configuration directory across ProtonPlus processes.
            // This leaves no lock file in Lutris's library.
            var lock_fd = Posix.open (Path.get_dirname (current.config_path),
                Posix.O_RDONLY | Posix.O_CLOEXEC | Posix.O_DIRECTORY | Posix.O_NOFOLLOW);
            if (lock_fd < 0)
                throw new IOError.PERMISSION_DENIED (_("The Lutris game configuration is read-only."));
            try {
                if (flock (lock_fd, 2 | 4) != 0)
                    throw new IOError.BUSY (_("Another Lutris configuration change is in progress."));
                require_closed ();
                if (version != null && !runners_for (current).any_match ((tool) =>
                    tool.internal_title == version && tool.is_available && tool.is_assignable))
                    throw new IOError.NOT_FOUND (_("This tool is no longer available. Choose a different tool."));
                var updated = current.config.yaml.set_version (version);
                LutrisYaml? updated_yaml = null;
                if (updated != null)
                    updated_yaml = LutrisYaml.parse (updated);
                if (updated_yaml == null || updated_yaml.get ("wine", "version") != version)
                    throw new IOError.INVALID_DATA (_("The Lutris game configuration is invalid."));
                // Probe work can take time. Check the process and source again
                // immediately before the etag-guarded atomic replacement.
                require_closed ();
                current = revalidate (expected);
                cancellable?.set_error_if_cancelled ();
                if (updated != current.config.text) {
                    var file = File.new_for_path (current.config_path);
                    file.replace_contents (updated.data, current.config.etag, false,
                        FileCreateFlags.NONE, null, cancellable);
                }
            } finally {
                Posix.close (lock_fd);
            }
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
            string[] argv = flatpak ? new string[] { "flatpak", "run", HostLutrisBackend.APP_ID, uri }
                : new string[] { "lutris", uri };
            return backend.spawn (HostLutrisBackend.on_host (argv, through_host));
        }

        private static IOError library_error () {
            return new IOError.INVALID_DATA (_("Could not read the Lutris game database."));
        }
    }
}
