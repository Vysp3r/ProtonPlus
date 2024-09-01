namespace ProtonPlus.Utils {
    public class System {
        public static bool IS_FLATPAK = false;

        public static bool is_dependency_installed (string name) {
            try {
                string command_line = "";
                if (IS_FLATPAK) command_line += "flatpak-spawn --host ";
                command_line += @"which $name";

                string stdout = "";
                var valid = Process.spawn_command_line_sync (command_line, out stdout, null, null);
                if (!valid) return false;

                return stdout.strip () == "" ? false : true;
            } catch (GLib.Error e) {
                message (e.message);
                return false;
            }
        }

        public static bool check_yad_version () {
            try {
                string command_line = "";
                if (IS_FLATPAK) command_line += "flatpak-spawn --host ";
                command_line += "yad --version";
                
                string stdout = "";
                var valid = Process.spawn_command_line_sync (command_line, out stdout, null, null);
                if (!valid) return false;

                float version = float.parse (stdout.split (" ")[0]);

                return version >= 7.2 ? true : false;
            } catch (GLib.Error e) {
                message (e.message);
                return false;
            }
        }
    }
}