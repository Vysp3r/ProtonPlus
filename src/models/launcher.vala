namespace ProtonPlus.Models {
    public class Launcher {
        public string title;
        public string type;
        public string icon_path;
        public string directory;
        public bool installed;

        public Group[] groups;

        public delegate void callback (Release release);
        public signal void install (Release release);
        public signal void uninstall (Release release);

        public Launcher (string title, string type, string icon_path, string[] directories) {
            this.title = title;
            this.type = type;
            this.icon_path = icon_path;
            this.directory = "";

            foreach (var directory in directories) {
                if (FileUtils.test (GLib.Environment.get_home_dir () + directory, FileTest.IS_DIR)) {
                    this.directory = GLib.Environment.get_home_dir () + directory;
                    break;
                }
            }

            installed = directory.length > 0;
        }

        public void setup_callbacks (callback install_callback, callback uninstall_callback) {
            install.connect ((release) => install_callback (release));
            uninstall.connect ((release) => uninstall_callback (release));
        }

        public static GLib.List<Launcher> get_all () {
            var launchers = new GLib.List<Launcher> ();

            launchers.append (Launchers.Steam.get_launcher ());
            launchers.append (Launchers.Steam.get_flatpak_launcher ());
            launchers.append (Launchers.Steam.get_snap_launcher ());

            launchers.append (Launchers.Lutris.get_launcher ());
            launchers.append (Launchers.Lutris.get_flatpak_launcher ());

            launchers.append (Launchers.Bottles.get_launcher ());
            launchers.append (Launchers.Bottles.get_flatpak_launcher ());

            launchers.append (Launchers.HeroicGamesLauncher.get_launcher ());
            launchers.append (Launchers.HeroicGamesLauncher.get_flatpak_launcher ());

            launchers.foreach ((launcher) => {
                if (!launcher.installed) launchers.remove (launcher);
            });

            return (owned) launchers;
        }
    }
}