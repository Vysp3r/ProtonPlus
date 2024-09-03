namespace ProtonPlus.Utils {
    public class System {
        public static bool IS_STEAM_OS = false;
        public static bool IS_GAMESCOPE = false;
        public static bool IS_FLATPAK = false;

        public static void initialize () {
            IS_FLATPAK = FileUtils.test ("/.flatpak-info", FileTest.IS_REGULAR);
            IS_GAMESCOPE = Environment.get_variable ("DESKTOP_SESSION") == "gamescope-wayland";
            IS_STEAM_OS = get_distribution_name () == "steamos";
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
            var distribution_info = run_command ("cat /etc/lsb-release /etc/os-release").split ("\n", 1)[0];
            var distribution_name_start = "NAME=".length + 1;
            var distribution_name_end = distribution_info.index_of ("\"", distribution_name_start);
            var distribution_name_len = distribution_name_end - distribution_name_start;
            return distribution_info.substring (distribution_name_start, distribution_name_len).ascii_down ();
        }
    }
}