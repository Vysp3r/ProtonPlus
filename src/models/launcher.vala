namespace ProtonPlus.Models {
    public class Launcher : Object {
        public string title;
        public string icon_path;
        public string directory;
        public bool installed;
        public bool has_library_support;
        public List<Game> games;
        public List<SimpleRunner> compatibility_tools;

        public Group[] groups;

        public InstallationTypes installation_type;
        public enum InstallationTypes {
            SYSTEM,
            FLATPAK,
            SNAP
        }

        public delegate bool callback (Release release);
        public signal bool install (Release release);
        public signal bool uninstall (Release release);

        public Launcher (string title, InstallationTypes installation_type, string icon_path, string[] directories) {
            this.title = title;
            this.installation_type = installation_type;
            this.icon_path = icon_path;
            this.directory = "";

            foreach (var directory in directories) {
                var current_path = Environment.get_home_dir () + directory;
                if (FileUtils.test (current_path, FileTest.IS_DIR)) {
                    if (!(this is Launchers.Steam) || (FileUtils.test (current_path + "/steamclient.dll", FileTest.IS_REGULAR) && FileUtils.test (current_path + "/steamclient64.dll", FileTest.IS_REGULAR))) {
                        this.directory = current_path;
                        break;
                    }
                }
            }

            installed = directory.length > 0;
        }

        public string get_installation_type_title () {
            switch (installation_type) {
            case InstallationTypes.SYSTEM:
                return "System";
            case InstallationTypes.FLATPAK:
                return "Flatpak";
            case InstallationTypes.SNAP:
                return "Snap";
            default:
                return "Invalid type";
            }
        }

        public virtual async bool load_game_library () {
            return false;
        }

        public static List<Launcher> get_all () {
            var launchers = new List<Launcher> ();

            launchers.append (new Launchers.Steam (InstallationTypes.SYSTEM));
            launchers.append (new Launchers.Steam (InstallationTypes.FLATPAK));
            launchers.append (new Launchers.Steam (InstallationTypes.SNAP));

            launchers.append (new Launchers.Lutris (InstallationTypes.SYSTEM));
            launchers.append (new Launchers.Lutris (InstallationTypes.FLATPAK));

            launchers.append (new Launchers.Bottles (InstallationTypes.SYSTEM));
            launchers.append (new Launchers.Bottles (InstallationTypes.FLATPAK));

            launchers.append (new Launchers.HeroicGamesLauncher (InstallationTypes.SYSTEM));
            launchers.append (new Launchers.HeroicGamesLauncher (InstallationTypes.FLATPAK));

            launchers.foreach ((launcher) => {
                if (!launcher.installed)launchers.remove (launcher);
            });

            return (owned) launchers;
        }
    }
}