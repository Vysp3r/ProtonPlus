namespace ProtonPlus.Utils {
    public class System {
        public static async string run_command (string command) {
            string output = "";
            try {
                string command_line = "";
                if (Globals.IS_FLATPAK)
                    command_line += "flatpak-spawn --host ";
                command_line += command;

                string[] argv;
                Shell.parse_argv (command_line, out argv);

                var subprocess = new Subprocess.newv (argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_MERGE);
                Bytes stdout_bytes;
                yield subprocess.communicate_async (null, null, out stdout_bytes, null);

                if (stdout_bytes != null) {
                    unowned uint8[] data = stdout_bytes.get_data ();
                    char[] str_data = new char[data.length + 1];
                    Memory.copy (str_data, data, data.length);
                    str_data[data.length] = '\0';
                    output = (string) str_data;
                }
            } catch (Error e) {
                warning (e.message);
            }

            return output;
        }

        public static List<string> get_hwcaps () {
            var hwcaps = new List<string> ();
            string flags = "";

            try {
                File file = File.new_for_path ("/proc/cpuinfo");
                if (file.query_exists ()) {
                    InputStream input_stream = file.read ();
                    DataInputStream dis = new DataInputStream (input_stream);

                    string? line;
                    while ((line = dis.read_line ()) != null) {
                        if (line.has_prefix ("flags")) {
                            flags = line;
                            break;
                        }
                    }
                }
            } catch (Error e) {
                warning ("Error: %s\n", e.message);
            }

            if (flags != "") {
                string[] f = flags.split (" ");
                var flag_set = new Gee.HashSet<string> ();
                foreach (var s in f)
                    flag_set.add (s);

                bool has_v2 = flag_set.contains ("sse4_1") && flag_set.contains ("sse4_2") && flag_set.contains ("ssse3");
                bool has_v3 = has_v2 && flag_set.contains ("avx") && flag_set.contains ("avx2");
                bool has_v4 = has_v3 && flag_set.contains ("avx512f") && flag_set.contains ("avx512bw") && flag_set.contains ("avx512cd") && flag_set.contains ("avx512dq") && flag_set.contains ("avx512vl");

                if (has_v4) hwcaps.append ("x86_64_v4");
                if (has_v3) hwcaps.append ("x86_64_v3");
                if (has_v2) hwcaps.append ("x86_64_v2");
            }

            hwcaps.append ("x86_64");

            return (owned) hwcaps;
        }

        public static async bool check_dependency (string name) {
            return (yield run_command (@"which $name")).contains("which: no") ? false : true;
        }

        public static async string get_distribution_name () {
            string distro_name = "Unknown";
            try {
                var file = File.new_for_path ("/etc/os-release");
                if (!file.query_exists ())
                    file = File.new_for_path ("/usr/lib/os-release");

                if (file.query_exists ()) {
                    var dis = new DataInputStream (file.read ());
                    string line;
                    while ((line = dis.read_line ()) != null) {
                        if (line.has_prefix ("NAME=")) {
                            distro_name = line.substring (5).replace ("\"", "").replace ("'", "");
                            break;
                        }
                    }
                }
            } catch (Error e) {
                warning (e.message);
            }

            return distro_name;
        }

        public static void open_uri (string uri) {
            AppInfo.launch_default_for_uri_async.begin (uri, null, null, (obj, res) => {
                try {
                    AppInfo.launch_default_for_uri_async.end (res);
                } catch (Error error) {
                    GLib.warning (error.message);
                }
            });
        }

        public static async string? get_protontricks_exec() {
            string[] protontricks_execs = { "protontricks", "com.github.Matoking.protontricks" };
			
            foreach (var protontricks_exec in protontricks_execs) {
                if (yield Utils.System.check_dependency (protontricks_exec))
                    return protontricks_exec;
            }

			return null;
		}
    }
}
