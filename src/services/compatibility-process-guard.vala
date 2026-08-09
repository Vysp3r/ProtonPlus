namespace ProtonPlus.Services {
    /* Process records deliberately separate the executable from argv so the
     * guard can make token-based decisions without scraping `ps` text. */
    public class CompatibilityProcessRecord : Object {
        public string executable_path { get; private set; }
        public Gee.List<string> argv { get; private set; }

        public CompatibilityProcessRecord (string executable_path, Gee.List<string>? argv = null) {
            this.executable_path = executable_path;
            this.argv = argv ?? new Gee.ArrayList<string> ();
        }
    }

    public interface CompatibilityProcessQueryBackend : Object {
        public abstract Gee.List<CompatibilityProcessRecord> query_processes ();
    }

    private class HostCompatibilityProcessQueryBackend : Object, CompatibilityProcessQueryBackend {
        public Gee.List<CompatibilityProcessRecord> query_processes () {
            var result = new Gee.ArrayList<CompatibilityProcessRecord> ();
            try {
                var directory = File.new_for_path ("/proc").enumerate_children (
                    "standard::name", FileQueryInfoFlags.NONE, null
                );
                FileInfo? info;
                while ((info = directory.next_file (null)) != null) {
                    var name = info.get_name ();
                    if (name.length == 0 || !name.get_char (0).isdigit ())
                        continue;
                    var root = "/proc/%s".printf (name);
                    string executable;
                    string command_line;
                    try {
                        executable = FileUtils.read_link (Path.build_filename (root, "exe"));
                        FileUtils.get_contents (Path.build_filename (root, "cmdline"), out command_line);
                    } catch (FileError e) {
                        continue;
                    }
                    var argv = new Gee.ArrayList<string> ();
                    /* GLib's split cannot accept a NUL delimiter.  Normalize
                     * procfs argv into ordinary whitespace-separated tokens. */
                    foreach (var value in command_line.replace ("\0", " ").split (" ")) {
                        if (value != "")
                            argv.add (value);
                    }
                    result.add (new CompatibilityProcessRecord (executable, argv));
                }
            } catch (Error e) {
                warning ("Unable to inspect compatibility processes: %s", e.message);
            }
            return result;
        }
    }

    public class CompatibilityProcessGuard : Object {
        private CompatibilityProcessQueryBackend backend;

        public CompatibilityProcessGuard (CompatibilityProcessQueryBackend? backend = null) {
            this.backend = backend ?? new HostCompatibilityProcessQueryBackend ();
        }

        public ReturnCode check () {
            return has_active_processes () ? ReturnCode.RUNNERS_IN_USE : ReturnCode.RUNNER_INSTALLED;
        }

        public bool has_active_processes () {
            foreach (var process in backend.query_processes ()) {
                if (is_compatibility_token (process.executable_path))
                    return true;
                foreach (var argument in process.argv) {
                    if (is_compatibility_token (argument))
                        return true;
                }
            }
            return false;
        }

        /* Only complete path tokens are accepted.  In particular,
         * protonplus-tests and a sentence mentioning Proton cannot match. */
        private bool is_compatibility_token (string value) {
            var basename = Path.get_basename (value);
            try {
                return new Regex (
                    "^(?:proton(?:[-_][^/[:space:]]*)?|umu(?:[-_][^/[:space:]]*)?|wine(?:64)?(?:[-_][^/[:space:]]*)?|[^/[:space:]]+\\.exe)$"
                ).match (basename);
            } catch (RegexError e) {
                warning (e.message);
                return false;
            }
        }
    }
}
