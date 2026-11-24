namespace ProtonPlus.Models {
    /* Read-only evidence for Steam-owned tools. A missing optional tool is not
     * itself an error: require either a completed install with missing files,
     * or a recent failure reported by this Steam instance. */
    public class SteamLibraryDiagnostics : Object {
        private const int MAX_FILE_BYTES = 1024 * 1024;
        private const int64 LOG_MAX_AGE_SECONDS = 24 * 60 * 60;

        private class Observation : Object {
            public uint appid;
            public string internal_title;
            public string display_title;
            public string install_path = "";
            public bool usable;
            public bool installing;
            public bool incomplete;
            public bool failed;

            public Observation (uint appid, string internal_title) {
                this.appid = appid;
                this.internal_title = internal_title;
                display_title = _("Steam app %u").printf (appid);
            }
        }

        public async Gee.List<SteamRuntimeRepairCandidate> inspect (
            string steam_root, string[] library_roots
        ) {
            SourceFunc callback = inspect.callback;
            Gee.List<SteamRuntimeRepairCandidate> result = new Gee.ArrayList<SteamRuntimeRepairCandidate> ();
            new Thread<void> ("steam-library-diagnostics", () => {
                result = inspect_sync (steam_root, library_roots);
                Idle.add ((owned) callback, Priority.DEFAULT);
            });
            yield;
            return result;
        }

        public Gee.List<SteamRuntimeRepairCandidate> inspect_sync (
            string steam_root, string[] library_roots, int64 now_unix = 0
        ) {
            var observations = new Gee.HashMap<uint, Observation> ();
            var roots = new Gee.TreeSet<string> ((a, b) => strcmp (a, b));
            roots.add (Filename.canonicalize (steam_root));
            foreach (var root in library_roots)
                roots.add (Filename.canonicalize (root));
            foreach (var root in roots)
                inspect_manifests (Path.build_filename (root, "steamapps"), observations);

            inspect_log (
                Path.build_filename (steam_root, "logs", "compat_log.txt"), observations,
                now_unix != 0 ? now_unix : new DateTime.now_local ().to_unix ()
            );

            var result = new Gee.ArrayList<SteamRuntimeRepairCandidate> ();
            foreach (var observation in observations.values) {
                if (!observation.usable && !observation.installing
                    && (observation.incomplete || observation.failed)) {
                    result.add (new SteamRuntimeRepairCandidate (
                        observation.appid, observation.internal_title,
                        observation.display_title, observation.install_path
                    ));
                }
            }
            result.sort ((a, b) => a.appid < b.appid ? -1 : a.appid > b.appid ? 1 : 0);
            return result;
        }

        private Observation? observe (Gee.HashMap<uint, Observation> observations, uint appid) {
            string internal_title;
            CompatibilityToolRuntimeKind runtime_kind;
            if (!SteamCompatibilityToolDiscovery.try_get_steam_library_tool_identity (
                    appid, out internal_title, out runtime_kind
                ))
                return null;
            var observation = observations.get (appid);
            if (observation == null) {
                observation = new Observation (appid, internal_title);
                observations.set (appid, observation);
            }
            return observation;
        }

        private void inspect_manifests (string steamapps, Gee.HashMap<uint, Observation> observations) {
            try {
                var directory = Dir.open (steamapps);
                string? name;
                while ((name = directory.read_name ()) != null) {
                    if (!name.has_prefix ("appmanifest_") || !name.has_suffix (".acf"))
                        continue;
                    uint appid;
                    var id_text = name.substring ("appmanifest_".length,
                        name.length - "appmanifest_".length - ".acf".length);
                    if (!uint.try_parse (id_text, out appid))
                        continue;
                    var observation = observe (observations, appid);
                    if (observation == null)
                        continue;
                    var content = read_bounded_file (Path.build_filename (steamapps, name));
                    var document = Utils.VDF.VdfParser.parse_document (content);
                    var state = document != null ? document.root.get_child ("AppState") : null;
                    if (state == null || value (state, "appid") != appid.to_string ())
                        continue;
                    var installdir = value (state, "installdir");
                    if (installdir == "" || installdir == "." || installdir == ".."
                        || installdir.contains ("/") || installdir.contains ("\\"))
                        continue;
                    var path = Path.build_filename (steamapps, "common", installdir);
                    var title = value (state, "name");
                    if (title != "")
                        observation.display_title = title;
                    observation.install_path = path;
                    observation.usable |= SteamCompatibilityToolDiscovery.steam_library_app_is_usable (path, appid);

                    uint flags;
                    if (!uint.try_parse (value (state, "StateFlags"), out flags))
                        continue;
                    // Only quiescent installed states establish missing files.
                    // Unknown flags and all update/validation states defer diagnosis.
                    observation.installing |= (flags & ~(2u | 4u | 32u | 64u | 128u)) != 0
                        || (flags & 4) == 0;
                    observation.incomplete |= (flags & 4) != 0;
                }
            } catch (FileError error) {
                debug ("Steam diagnostic library is unavailable: %s", error.message);
            }
        }

        private string value (Utils.VDF.VdfEntry entry, string key) {
            return entry.get_child (key)?.value ?? "";
        }

        private void inspect_log (
            string path, Gee.HashMap<uint, Observation> observations, int64 now_unix
        ) {
            var missing = /^Failed to load manifest for tool ([0-9]+)!$/;
            var unsupported = /^Tool ([0-9]+) "([^"]+)" unsupported version 0\.$/;
            var recovered = /^Command prefix for tool ([0-9]+) set to:/;
            var loaded = /^Loaded manifest for tool ([A-Za-z0-9_]+)\.$/;
            foreach (var line in read_bounded_file (path, true).split ("\n")) {
                if (line.length < 22 || line[0] != '[' || line.substring (20, 2) != "] ")
                    continue;
                var timestamp = new DateTime.from_iso8601 (
                    line.substring (1, 19).replace (" ", "T"), new TimeZone.local ()
                );
                if (timestamp == null || timestamp.to_unix () > now_unix
                    || now_unix - timestamp.to_unix () > LOG_MAX_AGE_SECONDS)
                    continue;

                var message = line.substring (22);
                MatchInfo match;
                if (unsupported.match (message, 0, out match)) {
                    uint appid;
                    if (!uint.try_parse (match.fetch (1), out appid))
                        continue;
                    var observation = observe (observations, appid);
                    if (observation != null) {
                        observation.failed = true;
                        observation.display_title = match.fetch (2);
                    }
                } else if (missing.match (message, 0, out match)) {
                    uint appid;
                    if (!uint.try_parse (match.fetch (1), out appid))
                        continue;
                    var observation = observe (observations, appid);
                    if (observation != null)
                        observation.failed = true;
                } else if (recovered.match (message, 0, out match)) {
                    uint appid;
                    if (!uint.try_parse (match.fetch (1), out appid))
                        continue;
                    var observation = observe (observations, appid);
                    if (observation != null)
                        observation.failed = false;
                } else if (loaded.match (message, 0, out match)) {
                    var identity = match.fetch (1);
                    foreach (var observation in observations.values) {
                        if (identity == observation.internal_title || identity == observation.appid.to_string ())
                            observation.failed = false;
                    }
                }
            }
        }

        /* Bound reads, reject non-regular files and never follow file symlinks.
         * Logs use only their tail; manifests exceeding the bound are ignored. */
        private string read_bounded_file (string path, bool tail = false) {
            var fd = Posix.open (path, Posix.O_RDONLY | Posix.O_CLOEXEC | Posix.O_NOFOLLOW | Posix.O_NONBLOCK);
            if (fd < 0)
                return "";
            try {
                Posix.Stat stat;
                if (Posix.fstat (fd, out stat) != 0 || !Posix.S_ISREG (stat.st_mode)
                    || (!tail && stat.st_size > MAX_FILE_BYTES))
                    return "";
                var truncated = tail && stat.st_size > MAX_FILE_BYTES;
                if (truncated && Posix.lseek (fd, stat.st_size - MAX_FILE_BYTES, Posix.SEEK_SET) < 0)
                    return "";
                var buffer = new uint8[MAX_FILE_BYTES + 1];
                int count = 0;
                while (count < MAX_FILE_BYTES) {
                    var bytes_read = Posix.read (fd, buffer[count:MAX_FILE_BYTES], MAX_FILE_BYTES - count);
                    if (bytes_read <= 0)
                        break;
                    count += (int) bytes_read;
                }
                buffer[count] = 0;
                var content = ((string) buffer).make_valid (count);
                if (truncated) {
                    var newline = content.index_of ("\n");
                    return newline < 0 ? "" : content.substring (newline + 1);
                }
                return content;
            } finally {
                Posix.close (fd);
            }
        }
    }
}
