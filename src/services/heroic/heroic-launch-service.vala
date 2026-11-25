namespace ProtonPlus.Services {
    public delegate Subprocess? HeroicProcessSpawner (string[] argv) throws Error;

    public class HeroicLaunchService : Object {
        public const string FLATPAK_ID = "com.heroicgameslauncher.hgl";

        private bool through_host;
        private string applications;
        private HeroicProcessSpawner spawn;

        public HeroicLaunchService (bool through_host, string applications, owned HeroicProcessSpawner? spawn = null) {
            this.through_host = through_host;
            this.applications = applications;
            if (spawn != null)
                this.spawn = (owned) spawn;
            else
                this.spawn = spawn_process;
        }

        internal static HeroicLaunchService for_package (bool through_host, string home) {
            var data_home = through_host
                ? Environment.get_variable ("HOST_XDG_DATA_HOME") : Environment.get_user_data_dir ();
            if (data_home == null || !Path.is_absolute (data_home))
                data_home = Path.build_filename (home, ".local", "share");
            return new HeroicLaunchService (through_host, Path.build_filename (data_home, "applications"));
        }

        public Subprocess? launch (bool flatpak, HeroicStore store, string app_name) throws Error {
            var uri = "heroic://launch?appName=%s&runner=%s".printf (
                Uri.escape_string (app_name, null, false), store.protocol_id ());
            string[] command = {};
            if (through_host)
                command = { "flatpak-spawn", "--host" };
            if (flatpak) {
                command += "flatpak";
                command += "run";
                command += FLATPAK_ID;
            } else {
                foreach (var argument in native_command ())
                    command += argument;
            }
            command += uri;
            return spawn (command);
        }

        private string[] native_command () {
            // AppImage launchers are commonly registered only in the user's
            // applications directory. Read these entries directly so that a
            // Flatpak association for heroic:// cannot redirect a native launch.
            try {
                var entries = new Gee.ArrayList<string> ();
                var directory = Dir.open (applications);
                string? filename;
                while ((filename = directory.read_name ()) != null) {
                    var name = filename.ascii_down ();
                    if (name.contains ("heroic") && name.has_suffix (".desktop"))
                        entries.add (filename);
                }
                entries.sort ((a, b) => strcmp (a, b));
                foreach (var entry in entries) {
                    var command = desktop_command (Path.build_filename (applications, entry));
                    if (command.length > 0)
                        return command;
                }
            } catch (FileError error) {
                debug ("Could not list Heroic desktop entries: %s", error.message);
            }
            return { "heroic" };
        }

        private static string[] desktop_command (string filename) {
            try {
                var desktop = new KeyFile ();
                desktop.load_from_file (filename, KeyFileFlags.NONE);
                if (desktop.has_key ("Desktop Entry", "Hidden") && desktop.get_boolean ("Desktop Entry", "Hidden"))
                    return {};
                string[] args;
                Shell.parse_argv (desktop.get_string ("Desktop Entry", "Exec"), out args);
                var executable = args[0];
                var name = Path.get_basename (executable).ascii_down ();
                var appimage = name.has_suffix (".appimage");
                if (!Path.is_absolute (executable) ||
                    (name != "heroic" && !appimage) ||
                    !FileUtils.test (executable, FileTest.IS_REGULAR) ||
                    Posix.access (executable, Posix.X_OK) != 0)
                    return {};
                if (appimage && !name.has_prefix ("heroic")) {
                    var title = desktop.get_string ("Desktop Entry", "Name");
                    if (title != "Heroic Games Launcher" && title != "Heroic")
                        return {};
                }
                string[] command = { executable };
                foreach (var argument in args[1:args.length]) {
                    switch (argument) {
                    case "%u":
                    case "%U":
                    case "%f":
                    case "%F":
                        break;
                    default:
                        if (argument.has_prefix ("heroic://") || argument.replace ("%%", "").contains ("%"))
                            return {};
                        command += argument.replace ("%%", "%");
                        break;
                    }
                }
                if (appimage && !("--no-sandbox" in command))
                    command += "--no-sandbox";
                return command;
            } catch (Error error) {
                return {};
            }
        }

        private static Subprocess spawn_process (string[] argv) throws Error {
            return new Subprocess.newv (argv, SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE);
        }
    }
}
