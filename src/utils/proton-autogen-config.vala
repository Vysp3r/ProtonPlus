namespace ProtonPlus.Utils {
    public class ProtonAutogenProfile : Object {
        public File file { get; private set; }
        public string id { get; private set; }
        public string path { get; private set; }
        public string name { get; private set; }
        public string proton { get; private set; }
        public string? resolved_proton_path { get; private set; }

        internal ProtonAutogenProfile (File file, string id, string path, string name, string proton) {
            this.file = file;
            this.id = id;
            this.path = path;
            this.name = name;
            this.proton = proton;
            if (Path.is_absolute (proton))
                resolved_proton_path = Posix.realpath (proton);
        }
    }

    public class ProtonAutogenConfig : Object {
        private const int MAX_PROFILE_BYTES = 1024 * 1024;
        private const string FILE_ATTRIBUTES = "standard::type,standard::size,etag::value,unix::device,unix::inode";
        // Match strings as single tokens so braces and commas inside strings cannot affect depth.
        private const string JSON_TOKENS = "\"(?:[^\"\\\\]|\\\\.)*\"|[{}\\[\\],:]|[^\\s{}\\[\\],:\"]+";

        public static Gee.List<ProtonAutogenProfile> read_profiles (string directory) throws Error {
            var profiles = new Gee.ArrayList<ProtonAutogenProfile> ();
            var root = File.new_for_path (directory);
            FileEnumerator entries;
            try {
                entries = root.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            } catch (IOError.NOT_FOUND error) {
                return profiles;
            }

            FileInfo? entry;
            while ((entry = entries.next_file ()) != null) {
                if (entry.get_file_type () != FileType.REGULAR || !entry.get_name ().has_suffix (".json"))
                    continue;
                try {
                    string contents;
                    string? etag;
                    profiles.add (read_profile (entries.get_child (entry), out contents, out etag));
                } catch (Error error) {
                    debug ("Skipped a Proton-Autogen profile: %s", error.message);
                }
            }
            profiles.sort ((first, second) => strcmp (first.file.get_basename (), second.file.get_basename ()));
            return profiles;
        }

        public static ProtonAutogenProfile update_proton (ProtonAutogenProfile expected, string proton,
            Cancellable? cancellable = null) throws Error {
            string contents;
            string? etag;
            var current = read_profile (expected.file, out contents, out etag);
            if (current.id != expected.id || current.path != expected.path || current.proton != expected.proton)
                throw new IOError.WRONG_ETAG ("The Proton-Autogen profile changed since it was loaded");
            if (current.proton == proton)
                return current;

            var updated = replace_proton_value (contents, proton);
            var latest = current.file.query_info (FILE_ATTRIBUTES, FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable);
            if (latest.get_file_type () != FileType.REGULAR || etag == null || latest.get_etag () != etag)
                throw new IOError.WRONG_ETAG ("The Proton-Autogen profile changed while it was being updated");
            string? new_etag;
            current.file.replace_contents (updated.data, etag, false, FileCreateFlags.NONE, out new_etag, cancellable);
            return new ProtonAutogenProfile (current.file, current.id, current.path, current.name, proton);
        }

        private static ProtonAutogenProfile read_profile (File file, out string contents, out string? etag) throws Error {
            var info = file.query_info (FILE_ATTRIBUTES, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            if (info.get_file_type () != FileType.REGULAR || info.get_size () > MAX_PROFILE_BYTES)
                throw new IOError.INVALID_DATA ("Unsupported Proton-Autogen profile file");

            var fd = Posix.open (file.get_path (), Posix.O_RDONLY | Posix.O_NOFOLLOW | Posix.O_CLOEXEC | Posix.O_NONBLOCK);
            if (fd < 0)
                throw new IOError.FAILED ("Could not open the Proton-Autogen profile");
            var stream = new UnixInputStream (fd, true);
            Posix.Stat opened;
            if (Posix.fstat (fd, out opened) != 0 || !Posix.S_ISREG (opened.st_mode)
                || opened.st_ino != info.get_attribute_uint64 (FileAttribute.UNIX_INODE)
                || (uint32) opened.st_dev != info.get_attribute_uint32 (FileAttribute.UNIX_DEVICE))
                throw new IOError.WRONG_ETAG ("The Proton-Autogen profile changed while it was being read");

            var buffer = new uint8[MAX_PROFILE_BYTES + 1];
            size_t size;
            stream.read_all (buffer, out size);
            if (size > MAX_PROFILE_BYTES)
                throw new IOError.INVALID_DATA ("Proton-Autogen profile is too large");
            if (!((string) buffer).validate ((ssize_t) size))
                throw new IOError.INVALID_DATA ("Proton-Autogen profile must be UTF-8 JSON");
            contents = ((string) buffer).substring (0, (long) size);
            var latest = file.query_info (FILE_ATTRIBUTES, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            etag = info.get_etag ();
            if (latest.get_file_type () != FileType.REGULAR || latest.get_etag () != etag
                || latest.get_attribute_uint64 (FileAttribute.UNIX_INODE) != opened.st_ino
                || latest.get_attribute_uint32 (FileAttribute.UNIX_DEVICE) != (uint32) opened.st_dev)
                throw new IOError.WRONG_ETAG ("The Proton-Autogen profile changed while it was being read");

            var parser = new Json.Parser ();
            parser.load_from_data (contents);
            var node = parser.get_root ();
            unowned string assignment;
            if (parser.has_assignment (out assignment) || node == null || node.get_node_type () != Json.NodeType.OBJECT)
                throw new IOError.INVALID_DATA ("Proton-Autogen profile must contain a JSON object");
            var profile = node.get_object ();
            var path = optional_string (profile, "path");
            if (!Path.is_absolute (path) || path.has_suffix ("/"))
                throw new IOError.INVALID_DATA ("Proton-Autogen profile has no absolute executable path");
            var id = optional_string (profile, "id");
            var name = optional_string (profile, "name");
            var proton = optional_string (profile, "proton");
            return new ProtonAutogenProfile (file, id, path, name.strip () != "" ? name : Path.get_basename (path), proton);
        }

        private static string optional_string (Json.Object object, string member) throws Error {
            var node = object.get_member (member);
            if (node == null || node.is_null ())
                return "";
            if (node.get_node_type () != Json.NodeType.VALUE || node.get_value_type () != typeof (string))
                throw new IOError.INVALID_DATA ("Unsupported type for Proton-Autogen profile field '%s'", member);
            return node.get_string ();
        }

        private static string replace_proton_value (string contents, string proton) throws Error {
            var value = new Json.Node (Json.NodeType.VALUE);
            value.set_string (proton);
            var encoded = Json.to_string (value, false);
            var regex = new Regex (JSON_TOKENS);
            MatchInfo tokens;
            regex.match (contents, 0, out tokens);

            int depth = 0;
            int value_start = -1;
            int value_end = -1;
            int root_end = -1;
            string previous = "";
            for (; tokens.matches (); tokens.next ()) {
                var token = tokens.fetch (0);
                if (depth == 1 && (previous == "{" || previous == ",") && is_proton_key (token)) {
                    if (value_start >= 0 || !tokens.next () || tokens.fetch (0) != ":" || !tokens.next ())
                        throw new IOError.INVALID_DATA ("Ambiguous Proton-Autogen proton field");
                    tokens.fetch_pos (0, out value_start, out value_end);
                    token = tokens.fetch (0);
                }
                if (token == "{" || token == "[") {
                    depth++;
                } else if (token == "}" || token == "]") {
                    if (--depth == 0)
                        tokens.fetch_pos (0, out root_end, null);
                }
                previous = token;
            }
            if (value_start >= 0)
                return contents.substring (0, value_start) + encoded + contents.substring (value_end);
            if (root_end < 0)
                throw new IOError.INVALID_DATA ("Proton-Autogen profile has no object terminator");
            // A valid profile always has a path member, so the object is nonempty.
            var insertion = contents.substring (0, root_end).chomp ().length;
            return contents.substring (0, insertion) + ", \"proton\": " + encoded + contents.substring (insertion);
        }

        private static bool is_proton_key (string token) throws Error {
            if (token == "\"proton\"")
                return true;
            if (!token.has_prefix ("\"") || !token.contains ("\\"))
                return false;
            return Json.from_string (token)?.get_string () == "proton";
        }
    }
}
