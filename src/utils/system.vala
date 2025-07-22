namespace ProtonPlus.Utils {
    public class System {
        public static async string run_command (string command) {
            SourceFunc callback = run_command.callback;

            string output = "";
            new Thread<void> ("rename", () => {
                try {
                    string command_line = "";
                    if (Globals.IS_FLATPAK)command_line += "flatpak-spawn --host ";
                    command_line += command;

                    var valid = Process.spawn_command_line_sync (command_line, out output, null, null);
                    if (!valid) output = "";
                } catch (Error e) {
                    message (e.message);
                }

                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return output;
        }

        public async static List<string> get_hwcaps () {
            var hwcaps = new List<string> ();
            
            string flags = yield run_command ("ld.so --help");
            
            
            if (flags.contains ("x86-64-v4 (supported, searched)"))
                hwcaps.append ("x86_64_v4");

            if (flags.contains ("x86-64-v3 (supported, searched)"))
                hwcaps.append ("x86_64_v3");

            if (flags.contains ("x86-64-v2 (supported, searched)"))
                hwcaps.append ("x86_64_v2");

            return (owned) hwcaps;
        }

        public static async bool check_dependency (string name) {
            return (yield run_command (@"which $name")) == "" ? false : true;
        }

        public static async string get_distribution_name () {
            var distro_info = (yield run_command ("cat /etc/lsb-release /etc/os-release")).split ("\n", 1)[0];

            var distro_name = "Unknown";
            MatchInfo m;
            if (/^NAME="\s*(.+?)\s*"/m.match (distro_info, 0, out m))
                distro_name = m.fetch (1);

            return distro_name;
        }

        public static void open_uri (string uri) {
            AppInfo.launch_default_for_uri_async.begin (uri, null, null, (obj, res) => {
                try {
                    AppInfo.launch_default_for_uri_async.end (res);
                } catch (Error error) {
                    message (error.message);
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