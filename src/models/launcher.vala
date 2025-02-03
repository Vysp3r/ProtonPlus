namespace ProtonPlus.Models {
    public class Launcher : Object {
        public string title;
        public string icon_path;
        public string directory;
        public bool installed;

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
                if (FileUtils.test (Environment.get_home_dir () + directory, FileTest.IS_DIR)) {
                    this.directory = Environment.get_home_dir () + directory;
                    break;
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