namespace ProtonPlus.Services {
    public interface BottlesCliBackend : Object {
        public abstract string query (string[] argv) throws Error;
        public abstract Subprocess? launch (string[] argv) throws Error;
    }

    private class HostBottlesCliBackend : Object, BottlesCliBackend {
        public string query (string[] argv) throws Error {
            return Utils.System.query_process (argv, _("The Bottles command did not complete successfully."));
        }

        public Subprocess? launch (string[] argv) throws Error {
            return Utils.System.spawn_detached (argv);
        }
    }

    internal class BottlesProgram : Object {
        public string bottle;
        public string name;
        public string path;
        public string? id;
        public bool unique_id;
        public string? registration;
        public string? runner;
        public string directory = "";
        public string prefix = "";
        public string? launch_flag;
        public string? launch_value;

        public BottlesProgram (string bottle, string name, string path, string? id) {
            this.bottle = bottle;
            this.name = name;
            this.path = path;
            this.id = id;
        }

        public Variant identity (string launcher_id) {
            var program = unique_id ? new Variant ("(ss)", "id", id)
                : registration != null ? new Variant ("(ss)", "registration", registration)
                : new Variant ("(sss)", "program", name, path);
            return new Variant ("(ssv)", launcher_id, bottle, program);
        }

        public bool matches (BottlesProgram other) {
            return bottle == other.bottle && id == other.id &&
                ((unique_id && other.unique_id) ||
                    (registration == other.registration && name == other.name && path == other.path));
        }
    }

    internal class BottlesLibraryResult : Object {
        public Gee.List<BottlesProgram> programs = new Gee.ArrayList<BottlesProgram> ();
        public bool partial;
    }

    public class BottlesLibrary : Object {
        public const string APP_ID = "com.usebottles.bottles";

        private BottlesCliBackend backend;
        private string[] command;
        private bool flatpak;
        private string flatpak_data_home;

        public BottlesLibrary (bool flatpak, bool through_host, BottlesCliBackend? backend = null,
            string? home = null) {
            this.backend = backend ?? new HostBottlesCliBackend ();
            this.flatpak = flatpak;
            flatpak_data_home = Path.build_filename (home ?? Environment.get_home_dir (), ".var", "app", APP_ID, "data");
            command = through_host ? new string[] { "flatpak-spawn", "--host" } : new string[] {};
            if (flatpak) {
                command += "flatpak";
                command += "run";
                command += "--command=bottles-cli";
                command += APP_ID;
            } else {
                command += "bottles-cli";
            }
        }

        private string[] argv (string[] arguments) {
            var result = command.copy ();
            foreach (var argument in arguments)
                result += argument;
            return result;
        }

        internal BottlesLibraryResult read () throws Error {
            var bottles = list_bottles ();
            var result = new BottlesLibraryResult ();
            if (bottles.get_size () == 0)
                return result;

            var supports_ids = supports_program_ids ();
            var root = bottles_root ();
            foreach (var bottle in bottles.get_members ()) {
                var metadata = object_value (bottles.get_member (bottle));
                if (bottle == "" || metadata == null) {
                    result.partial = true;
                    continue;
                }

                try {
                    var prefix = bottle_prefix (metadata, root);
                    var runner = string_value (metadata.get_member ("Runner"));
                    foreach (var program in list_programs (bottle, metadata, supports_ids, prefix, ref result.partial)) {
                        program.runner = runner;
                        result.programs.add (program);
                    }
                } catch (Error error) {
                    debug ("Could not list programs in Bottles bottle %s: %s", bottle, error.message);
                    result.partial = true;
                }
            }
            return result;
        }

        internal Subprocess? launch (BottlesProgram expected) throws Error {
            // A name can become ambiguous after the Games list was loaded.
            var bottles = list_bottles ();
            var metadata = object_value (bottles.get_member (expected.bottle));
            if (metadata != null) {
                bool partial = false;
                var current = list_programs (expected.bottle, metadata, supports_program_ids (), null, ref partial);
                var matching = current.iterator ().filter (program => expected.matches (program));
                if (matching.next ()) {
                    var program = matching.get ();
                    if (!matching.next () && program.launch_flag != null) {
                        // Bottles strips one pair of surrounding quotes on run.
                        var bottle = program.bottle;
                        if ((bottle.has_prefix ("\"") && bottle.has_suffix ("\"")) ||
                            (bottle.has_prefix ("'") && bottle.has_suffix ("'")))
                            bottle = "\"" + bottle + "\"";
                        return backend.launch (argv ({ "run", "--bottle=" + bottle,
                            program.launch_flag + "=" + program.launch_value }));
                    }
                }
            }
            throw new IOError.NOT_FOUND (_("The selected Bottles program is no longer uniquely available. Reload the games list and try again."));
        }

        private Json.Object list_bottles () throws Error {
            try {
                var root = read_json ({ "--json", "list", "bottles" });
                var bottles = object_value (root);
                if (bottles != null)
                    return bottles;
            } catch (Error error) {
                debug ("Could not list Bottles bottles: %s", error.message);
            }
            throw new IOError.FAILED (_("Could not read the bottle list from the selected Bottles CLI."));
        }

        private Json.Node read_json (string[] arguments) throws Error {
            var parser = new Json.Parser ();
            parser.load_from_data (backend.query (argv (arguments)));
            var root = parser.get_root ();
            if (root == null)
                throw new IOError.INVALID_DATA (_("Bottles returned invalid library data."));
            return root.copy ();
        }

        private bool supports_program_ids () {
            try {
                var help = backend.query (argv ({ "run", "--help" }));
                return help.contains ("--program-id");
            } catch (Error error) {
                debug ("Could not read Bottles launch options: %s", error.message);
                return false;
            }
        }

        private Gee.List<BottlesProgram> list_programs (string bottle, Json.Object metadata, bool supports_ids,
            string? prefix, ref bool partial) throws Error {
            var root = read_json ({ "--json", "programs", "--bottle=" + bottle });
            if (root.get_node_type () != Json.NodeType.ARRAY)
                throw new IOError.INVALID_DATA (_("Bottles returned invalid library data."));

            var registrations = object_value (metadata.get_member ("External_Programs"));
            var names = new Gee.HashMultiSet<string> ();
            var ids = new Gee.HashMultiSet<string> ();
            var programs = new Gee.ArrayList<BottlesProgram> ();

            // 'programs' omits removed shortcuts, but 'run' still matches them.
            if (registrations != null) {
                foreach (var key in registrations.get_members ()) {
                    var entry = object_value (registrations.get_member (key));
                    if (entry != null && bool_value (entry.get_member ("removed")))
                        count_selectors (entry, names, ids);
                }
            }

            foreach (unowned var node in root.get_array ().get_elements ()) {
                var entry = object_value (node);
                var name = entry != null ? string_value (entry.get_member ("name")) : null;
                var path = entry != null ? string_value (entry.get_member ("path")) : null;
                if (entry != null)
                    count_selectors (entry, names, ids);
                if (name == null || path == null) {
                    partial = true;
                    continue;
                }
                var id = string_value (entry.get_member ("id"));
                var program = new BottlesProgram (bottle, name, path, id);
                if (registrations != null)
                    program.registration = find_registration (registrations, program);
                if (bool_value (entry.get_member ("removed")) || bool_value (entry.get_member ("auto_discovered")) ||
                    (registrations != null && program.registration == null))
                    continue;
                if (prefix != null) {
                    program.prefix = prefix;
                    program.directory = program_directory (prefix, path);
                }
                programs.add (program);
            }

            foreach (var program in programs) {
                program.unique_id = program.id != null && ids.count (program.id) == 1;
                if (supports_ids && program.unique_id) {
                    program.launch_flag = "--program-id";
                    program.launch_value = program.id;
                } else if ((!supports_ids || program.id == null) && names.count (program.name) == 1) {
                    program.launch_flag = "--program";
                    program.launch_value = program.name;
                }
            }
            return programs;
        }

        private static void count_selectors (Json.Object entry, Gee.HashMultiSet<string> names,
            Gee.HashMultiSet<string> ids) {
            var name = string_value (entry.get_member ("name"));
            var id = string_value (entry.get_member ("id"));
            if (name != null)
                names.add (name);
            if (id != null)
                ids.add (id);
        }

        private static string? find_registration (Json.Object registrations, BottlesProgram program) {
            foreach (var key in registrations.get_members ()) {
                var entry = object_value (registrations.get_member (key));
                if (entry != null && !bool_value (entry.get_member ("removed")) &&
                    string_value (entry.get_member ("id")) == program.id &&
                    string_value (entry.get_member ("name")) == program.name &&
                    string_value (entry.get_member ("path")) == program.path)
                    return key;
            }
            return null;
        }

        private string bottles_root () {
            try {
                var root = inspection_path (backend.query (argv ({ "info", "bottles-path" })).strip ());
                if (root == "")
                    return "";
                try {
                    string contents;
                    FileUtils.get_contents (Path.build_filename (Path.get_dirname (root), "data.yml"), out contents);
                    var custom_root = read_custom_root (contents);
                    if (custom_root == null)
                        return "";
                    var accessible = accessible_directory (inspection_path (custom_root));
                    if (accessible != "")
                        return accessible;
                    // Bottles falls back for invalid custom roots. When ProtonPlus
                    // cannot inspect a configured root, we cannot tell which it used.
                    if (custom_root != "")
                        return "";
                } catch (FileError.NOENT error) {
                    // Bottles uses the default when there is no storage setting.
                }
                return root;
            } catch (Error error) {
                debug ("Could not read the Bottles storage location: %s", error.message);
                return "";
            }
        }

        [CCode (cname = "protonplus_bottles_custom_root", cheader_filename = "services/bottles/bottles-storage.h")]
        private static extern string? read_custom_root (string contents);

        private string bottle_prefix (Json.Object metadata, string root) {
            var path = string_value (metadata.get_member ("Path"));
            if (path == null)
                return "";
            if (bool_value (metadata.get_member ("Custom_Path")))
                return accessible_directory (inspection_path (path));
            if (root == "" || path == "." || path == ".." || Path.get_basename (path) != path)
                return "";
            return accessible_directory (Path.build_filename (root, path));
        }

        private string program_directory (string prefix, string path) {
            if (Path.is_absolute (path) && !path.has_prefix ("//")) {
                var inspected = inspection_path (path);
                return inspected != "" ? accessible_directory (Path.get_dirname (inspected)) : "";
            }

            if (prefix == "" || path.length < 4 || !path[0].isalpha () || path[1] != ':' ||
                (path[2] != '\\' && path[2] != '/'))
                return "";

            var drive = path.substring (0, 2).ascii_down ();
            var mapping = Path.build_filename (prefix, "dosdevices", drive);
            try {
                var target = FileUtils.read_link (mapping);
                mapping = Path.is_absolute (target) ? inspection_path (target)
                    : Path.build_filename (Path.get_dirname (mapping), target);
            } catch (FileError.NOENT error) {
                if (drive == "c:")
                    mapping = Path.build_filename (prefix, "drive_c");
            } catch (FileError error) {
                // A directory in dosdevices also works as a mapping.
            }
            if (mapping == "")
                return "";
            var tail = path.substring (3).replace ("\\", "/");
            return windows_directory (mapping, Path.get_dirname (tail));
        }

        private static string windows_directory (string root, string relative) {
            var exact = accessible_directory (Path.build_filename (root, relative));
            if (exact != "")
                return exact;

            // Wine resolves Windows paths case-insensitively. Prefer an exact
            // component and give up when several directory entries match.
            try {
                var directory = root;
                foreach (var component in relative.split ("/")) {
                    var candidate = Path.build_filename (directory, component);
                    if (!FileUtils.test (candidate, FileTest.IS_DIR)) {
                        var entries = Dir.open (directory);
                        string? match = null;
                        string? entry;
                        var folded = component.casefold ();
                        while ((entry = entries.read_name ()) != null) {
                            if (!entry.validate () || entry.casefold () != folded)
                                continue;
                            if (match != null)
                                return "";
                            match = entry;
                        }
                        if (match == null)
                            return "";
                        candidate = Path.build_filename (directory, match);
                    }
                    directory = candidate;
                }
                return accessible_directory (directory);
            } catch (FileError error) {
                return "";
            }
        }

        private string inspection_path (string path) {
            if (!Path.is_absolute (path))
                return "";
            if (flatpak && (path == "/var/data" || path.has_prefix ("/var/data/")))
                return flatpak_data_home + path.substring ("/var/data".length);
            return path;
        }

        private static string accessible_directory (string path) {
            if (path == "")
                return "";
            var resolved = Posix.realpath (path);
            return resolved != null && FileUtils.test (resolved, FileTest.IS_DIR) &&
                Posix.access (resolved, Posix.R_OK | Posix.X_OK) == 0 ? resolved : "";
        }

        private static unowned Json.Object? object_value (Json.Node? node) {
            return node != null && node.get_node_type () == Json.NodeType.OBJECT ? node.get_object () : null;
        }

        private static string? string_value (Json.Node? node) {
            if (node == null || node.get_node_type () != Json.NodeType.VALUE || node.get_value_type () != typeof (string))
                return null;
            var value = node.get_string ();
            return value != null && value != "" ? value : null;
        }

        private static bool bool_value (Json.Node? node) {
            return node != null && node.get_node_type () == Json.NodeType.VALUE &&
                node.get_value_type () == typeof (bool) && node.get_boolean ();
        }
    }
}
