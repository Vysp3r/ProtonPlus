namespace ProtonPlus.Utils {
    public class System {
        public static bool IS_STEAM_OS = false;
        public static bool IS_GAMESCOPE = false;
        public static bool IS_FLATPAK = false;
        public static List<string> HWCAPS = new List<string> ();

        public static void initialize () {
            IS_FLATPAK = FileUtils.test ("/.flatpak-info", FileTest.IS_REGULAR);
            IS_GAMESCOPE = Environment.get_variable ("DESKTOP_SESSION") == "gamescope-wayland";
            IS_STEAM_OS = get_distribution_name ().ascii_down () == "steamos";
            HWCAPS = get_hwcaps ();
        }

        public static string run_command (string command) {
            try {
                string command_line = "";
                if (IS_FLATPAK)command_line += "flatpak-spawn --host ";
                command_line += command;

                string stdout = "";
                var valid = Process.spawn_command_line_sync (command_line, out stdout, null, null);
                if (!valid)return "";

                return stdout;
            } catch (Error e) {
                message (e.message);
                return "";
            }
        }

        public static List<string> get_hwcaps () {
            var hwcaps = new List<string> ();
            hwcaps.append ("x86_64");

            // flags according to https://gitlab.com/x86-psABIs/x86-64-ABI/-/blob/master/x86-64-ABI/low-level-sys-info.tex
            var flags_v2 = new List<string> ();
            flags_v2.append ("sse4_1");
            flags_v2.append ("sse4_2");
            flags_v2.append ("ssse3");

            var flags_v3 = new List<string> ();
            foreach (var flag in flags_v2)
                flags_v3.append (flag);
            flags_v3.append ("avx");
            flags_v3.append ("avx2");

            var flags_v4 = new List<string> ();
            foreach (var flag in flags_v3)
                flags_v4.append (flag);
            flags_v4.append ("avx512f");
            flags_v4.append ("avx512bw");
            flags_v4.append ("avx512cd");
            flags_v4.append ("avx512dq");
            flags_v4.append ("avx512vl");

            string flags = "";

            try {
                // Open the file for reading
                File file = File.new_for_path ("/proc/cpuinfo");
                InputStream input_stream = file.read ();
                DataInputStream dis = new DataInputStream (input_stream);

                // Read lines from the input stream
                string? line;
                while ((line = dis.read_line ()) != null) {
                    if (line.slice (0, 5) == "flags") {
                        flags = line;
                        break;
                    }
                }

                // Close the input stream
                input_stream.close ();
            } catch (Error e) {
                message ("Error: %s\n", e.message);
            }

            int count = 0;
            foreach (var flag in flags_v4) {
                if (flags.contains (flag))
                    count++;
            }
            if (flags_v4.length () == count)
                hwcaps.append ("x86_64_v4");

            count = 0;
            foreach (var flag in flags_v3) {
                if (flags.contains (flag))
                    count++;
            }
            if (flags_v3.length () == count)
                hwcaps.append ("x86_64_v3");

            count = 0;
            foreach (var flag in flags_v2) {
                if (flags.contains (flag))
                    count++;
            }
            if (flags_v2.length () == count)
                hwcaps.append ("x86_64_v2");

            return (owned) hwcaps;
        }

        public static bool check_dependency (string name) {
            return run_command (@"which $name") == "" ? false : true;
        }

        static string get_distribution_name () {
            var distro_info = run_command ("cat /etc/lsb-release /etc/os-release").split ("\n", 1)[0];

            var distro_name = "Unknown";
            MatchInfo m;
            if (/^NAME="\s*(.+?)\s*"/m.match (distro_info, 0, out m))
                distro_name = m.fetch (1);

            return distro_name;
        }

        public static void open_url (string url) {
            var uri_launcher = new Gtk.UriLauncher (url);
            uri_launcher.launch.begin (Widgets.Application.window, null, (obj, res) => {
                try {
                    uri_launcher.launch.end (res);
                } catch (Error error) {
                    message (error.message);
                }
            });
        }
    }
}