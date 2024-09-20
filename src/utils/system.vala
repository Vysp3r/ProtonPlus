namespace ProtonPlus.Utils {
    public class System {
        public static bool IS_STEAM_OS = false;
        public static bool IS_GAMESCOPE = false;
        public static bool IS_FLATPAK = false;

        public static void initialize () {
            IS_FLATPAK = FileUtils.test ("/.flatpak-info", FileTest.IS_REGULAR);
            IS_GAMESCOPE = Environment.get_variable ("DESKTOP_SESSION") == "gamescope-wayland";
            IS_STEAM_OS = get_distribution_name ().ascii_down () == "steamos";
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

        public static bool check_dependency (string name) {
            return run_command (@"which $name") == "" ? false : true;
        }

        static string get_distribution_name () {
            var distro_info = run_command ("cat /etc/lsb-release /etc/os-release").split ("\n", 1)[0];

            var distro_name = "Unknown";
            MatchInfo m;
            if (/^NAME = "\s*(.+?)\s*"/m.match (distro_info, 0, out m))
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

        public static async void sleep (int miliseconds) {
            SourceFunc callback = sleep.callback;

            new Thread<void> ("sleep", () => {
                Thread.usleep (miliseconds * 1000);
                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
        }
    }
}