namespace ProtonPlus.Utils {
    public class CommandResult : Object {
        public string stdout { get; private set; }
        public string stderr { get; private set; }
        public int exit_status { get; private set; }

        public CommandResult (string stdout, string stderr, int exit_status) {
            this.stdout = stdout;
            this.stderr = stderr;
            this.exit_status = exit_status;
        }
    }

    public class System {
        static bool systemd_update_running = false;
        static bool systemd_update_pending = false;

        public static async CommandResult run_command (string command) {
            try {
                var argv = get_command_argv (command);

                var subprocess = new Subprocess.newv (argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                Bytes stdout_bytes;
                Bytes stderr_bytes;
                yield subprocess.communicate_async (null, null, out stdout_bytes, out stderr_bytes);

                var stdout = stdout_bytes != null ? Parser.data_to_string (stdout_bytes.get_data ()) : "";
                var stderr = stderr_bytes != null ? Parser.data_to_string (stderr_bytes.get_data ()) : "";
                var exit_status = subprocess.get_if_exited () ? subprocess.get_exit_status () : -1;

                return new CommandResult (stdout, stderr, exit_status);
            } catch (Error e) {
                warning (e.message);
                return new CommandResult ("", e.message, -1);
            }
        }

        public static string run_command_sync (string command) {
            string output = "";
            try {
                var argv = get_command_argv (command);

                var subprocess = new Subprocess.newv (argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_MERGE);
                Bytes stdout_bytes;
                subprocess.communicate (null, null, out stdout_bytes, null);

                if (stdout_bytes != null)
                    output = Parser.data_to_string (stdout_bytes.get_data ());
            } catch (Error e) {
                warning (e.message);
            }

            return output;
        }

        private static string[] get_command_argv (string command) throws ShellError {
            var command_line = Globals.IS_FLATPAK ? "flatpak-spawn --host " + command : command;
            string[] argv;
            Shell.parse_argv (command_line, out argv);
            return argv;
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
                bool has_v4 = has_v3
                              && flag_set.contains ("avx512f")
                              && flag_set.contains ("avx512bw")
                              && flag_set.contains ("avx512cd")
                              && flag_set.contains ("avx512dq")
                              && flag_set.contains ("avx512vl");

                if (has_v4) hwcaps.append ("x86_64_v4");
                if (has_v3) hwcaps.append ("x86_64_v3");
                if (has_v2) hwcaps.append ("x86_64_v2");
            }

            hwcaps.append ("x86_64");

            return (owned) hwcaps;
        }

        public static async bool check_dependency (string name) {
            if (!Globals.IS_FLATPAK)
                return Environment.find_program_in_path (name) != null;

            var output = (yield run_command ("which %s".printf (Shell.quote (name)))).stdout;
            return output != "" && !output.contains ("which: no");
        }

        public static bool check_dependency_sync (string name) {
            if (!Globals.IS_FLATPAK)
                return Environment.find_program_in_path (name) != null;

            var output = run_command_sync ("which %s".printf (Shell.quote (name)));
            return output != "" && !output.contains ("which: no");
        }

        public static bool check_flatpak_dependency_sync (string name) {
            if (!Globals.IS_FLATPAK) {
                return false;
            }
            var output = run_command_sync ("flatpak info %s".printf (Shell.quote (name)));
            return output != "" && !output.contains ("error:");
        }

        public static string get_distribution_name () {
            string distro_name = "Unknown";
            try {
                var file = File.new_for_path ("/etc/os-release");
                if (!file.query_exists ()) {
                    file = File.new_for_path ("/usr/lib/os-release");
                }

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

        public static bool is_kde () {
            string[] desktop_identifiers = {
                Environment.get_variable ("XDG_CURRENT_DESKTOP") ?? "",
                Environment.get_variable ("XDG_SESSION_DESKTOP") ?? "",
                Environment.get_variable ("DESKTOP_SESSION") ?? ""
            };

            foreach (var identifier in desktop_identifiers) {
                var desktop = identifier.ascii_down ();

                if (desktop.contains ("kde") || desktop.contains ("plasma"))
                    return true;
            }

            return false;
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

        public static void systemd_handler () {
            systemd_update_pending = true;
            if (systemd_update_running)
                return;

            systemd_update_running = true;
            update_systemd_files.begin ();
        }

        private static async void update_systemd_files () {
            do {
                systemd_update_pending = false;

                if (!Globals.SETTINGS.get_boolean ("background-updates") && !Globals.SETTINGS.get_boolean ("check-updates-on-boot")) {
                    yield uninstall_systemd_files ();
                } else if (systemd_files_exist ()) {
                    yield modify_systemd_files ();
                } else {
                    yield install_systemd_files ();
                }
            } while (systemd_update_pending);

            systemd_update_running = false;
        }

        private static string get_systemd_dir () {
            return Path.build_filename (Environment.get_user_config_dir (), "systemd", "user");
        }

        private static bool systemd_files_exist () {
            string systemd_dir = get_systemd_dir ();
            return File.new_for_path (Path.build_filename (systemd_dir, "protonplus.service")).query_exists () &&
                   File.new_for_path (Path.build_filename (systemd_dir, "protonplus.timer")).query_exists ();
        }

        public static async void install_systemd_files () {
            if (!write_systemd_files ()) {
                return;
            }

            if (yield run_systemctl ("daemon-reload"))
                yield run_systemctl ("enable protonplus.timer");
        }

        public static async void modify_systemd_files () {
            if (!write_systemd_files ()) {
                return;
            }

            yield run_systemctl ("daemon-reload");
        }

        private static async bool run_systemctl (string arguments) {
            var command = "systemctl --user " + arguments;
            var result = yield run_command (command);

            if (result.exit_status == 0)
                return true;

            var error_output = result.stderr.strip ();
            if (error_output == "")
                error_output = result.stdout.strip ();
            if (error_output == "")
                error_output = "no output";

            warning ("%s failed with exit status %d: %s", command, result.exit_status, error_output);
            return false;
        }

        private static bool write_systemd_files () {
            string executable = Globals.IS_FLATPAK ?
                "/usr/bin/flatpak run com.vysp3r.ProtonPlus" :
                Environment.find_program_in_path ("protonplus") ?? "protonplus";
            string exec_start = "%s update all".printf (executable);
            string on_unit_active_sec = "1h";

            switch (Globals.SETTINGS.get_enum ("background-updates-frequency")) {
                case 1:
                    on_unit_active_sec = "3h";
                    break;
                case 2:
                    on_unit_active_sec = "6h";
                    break;
                case 3:
                    on_unit_active_sec = "12h";
                    break;
                case 0:
                default:
                    on_unit_active_sec = "1h";
                    break;
            }

            try {
                bool check_on_boot = Globals.SETTINGS.get_boolean ("check-updates-on-boot");
                bool background_updates = Globals.SETTINGS.get_boolean ("background-updates");

                var service_resource = resources_lookup_data ("/com/vysp3r/ProtonPlus/protonplus.service", ResourceLookupFlags.NONE);
                var timer_resource = resources_lookup_data ("/com/vysp3r/ProtonPlus/protonplus.timer", ResourceLookupFlags.NONE);

                string service_content = Parser.data_to_string (service_resource.get_data ())
                    .replace ("{ExecStart}", exec_start);
                string timer_content = Parser.data_to_string (timer_resource.get_data ());

                if (!check_on_boot) {
                    timer_content = timer_content.replace ("OnBootSec=1min", "");
                }

                if (background_updates) {
                    timer_content = timer_content.replace ("{OnUnitActiveSec}", on_unit_active_sec);
                } else {
                    timer_content = timer_content.replace ("OnUnitActiveSec={OnUnitActiveSec}\n", "").replace ("OnUnitActiveSec={OnUnitActiveSec}", "");
                }

                string systemd_dir = get_systemd_dir ();
                var dir = File.new_for_path (systemd_dir);
                if (!dir.query_exists ()) {
                    dir.make_directory_with_parents ();
                }

                FileUtils.set_contents (Path.build_filename (systemd_dir, "protonplus.service"), service_content);
                FileUtils.set_contents (Path.build_filename (systemd_dir, "protonplus.timer"), timer_content);
            } catch (Error e) {
                warning (e.message);
                return false;
            }

            return true;
        }

        public static async void uninstall_systemd_files () {
            try {
                yield run_systemctl ("disable --now protonplus.timer");

                string systemd_dir = get_systemd_dir ();
                var service_file = File.new_for_path (Path.build_filename (systemd_dir, "protonplus.service"));
                if (service_file.query_exists ()) {
                    service_file.delete ();
                }

                var timer_file = File.new_for_path (Path.build_filename (systemd_dir, "protonplus.timer"));
                if (timer_file.query_exists ()) {
                    timer_file.delete ();
                }

                yield run_systemctl ("daemon-reload");
            } catch (Error e) {
                warning (e.message);
            }
        }
    }
}
