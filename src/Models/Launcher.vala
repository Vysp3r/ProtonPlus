namespace Models {
    public class Launcher : Object, Interfaces.IModel {
        string homeDirectory;
        string directory;

        public string Title { get; set; }
        public string HomeDirectory {
            public owned get { return homeDirectory; }
        }
        public string Folder {
            public owned get { return directory; }
        }
        public string Directory {
            public owned get { return homeDirectory + directory; }
            private set { directory = value; }
        }
        public List<Models.Tool> Tools;
        public string Scheme;
        public bool Installed {
            public get { return directory.length > 0; }
        }

        public Launcher (string title, string[] directories, string toolDirectory, List<Models.Tool> tools, string scheme = "") {
            homeDirectory = GLib.Environment.get_home_dir ();

            this.Title = title;
            this.Directory = verifyDirectories (directories, toolDirectory);
            this.Scheme = scheme;

            Tools = new List<Models.Tool> ();
            tools.@foreach ((tool) => {
                Tools.append (tool);
            });
        }

        private string verifyDirectories (string[] directories, string toolDirectory) {
            string dir = "";

            // Check if any of the given directories exists
            foreach (var item in directories) {
                if (FileUtils.test (homeDirectory + item, FileTest.IS_DIR)) {
                    dir = item + toolDirectory;
                    break;
                }
            }

            // If a directory exist, it makes sure that the tool directory is created
            if (dir.length > 0) {
                if (!FileUtils.test (homeDirectory + dir, FileTest.IS_DIR)) {
                    Utils.File.CreateDirectory (homeDirectory + dir);
                }
            }

            return dir;
        }

        public static uint GetPosition (GLib.List<Launcher> launchers, string title) {
            uint position = 0;

            uint counter = 0;
            launchers.@foreach ((launcher) => {
                if (launcher.Title == title) {
                    position = counter;
                }
                counter++;
            });

            return position;
        }

        public static GLib.ListStore GetStore (GLib.List<Launcher> launchers) {
            var store = new GLib.ListStore (typeof (Launcher));

            launchers.@foreach ((launcher) => {
                store.append (launcher);
            });

            return store;
        }

        public static GLib.List GetAll () {
            var launchers = new GLib.List<Launcher> ();

            // Steam
            var steamToolDir = "/compatibilitytools.d";
            var steamTools = Models.Tool.Steam ();

            var steam = new Launcher (
                "Steam",
                new string[] {
                "/.local/share/Steam",
                "/.steam/root",
                "/.steam/steam",
                "/.steam/debian-installation"
            },
                steamToolDir,
                steamTools
            );
            if (steam.Installed) launchers.append (steam);

            var steamFlatpak = new Launcher (
                "Steam (Flatpak)",
                new string[] {
                "/.var/app/com.valvesoftware.Steam/data/Steam"
            },
                steamToolDir,
                steamTools
            );
            if (steamFlatpak.Installed) launchers.append (steamFlatpak);

            var steamSnap = new Launcher (
                "Steam (Snap)",
                new string[] {
                "/snap/steam/common/.steam/root"
            },
                steamToolDir,
                steamTools
            );
            if (steamSnap.Installed) launchers.append (steamSnap);

            // Lutris
            var lutrisToolDir = "/wine";
            var lutrisTools = Models.Tool.Lutris ();

            var lutris = new Launcher (
                "Lutris",
                new string[] {
                "/.local/share/lutris/runners"
            },
                lutrisToolDir,
                lutrisTools
            );
            if (lutris.Installed) launchers.append (lutris);

            var lutrisFlatpak = new Launcher (
                "Lutris (Flatpak)",
                new string[] {
                "/.var/app/net.lutris.Lutris/data/lutris/runners"
            },
                lutrisToolDir,
                lutrisTools
            );
            if (lutrisFlatpak.Installed) launchers.append (lutrisFlatpak);

            // Lutris DXVK
            var lutrisDxvkToolDir = "/dxvk";
            var lutrisDxvkTools = Models.Tool.LutrisDXVK ();

            var lutrisDXVK = new Launcher (
                "Lutris DXVK",
                new string[] {
                "/.local/share/lutris/runtime"
            },
                lutrisDxvkToolDir,
                lutrisDxvkTools
            );
            if (lutrisDXVK.Installed) launchers.append (lutrisDXVK);

            var lutrisDXVKFlatpak = new Launcher (
                "Lutris DXVK (Flatpak)",
                new string[] {
                "/.var/app/net.lutris.Lutris/data/lutris/runtime"
            },
                lutrisDxvkToolDir,
                lutrisDxvkTools
            );
            if (lutrisDXVKFlatpak.Installed) launchers.append (lutrisDXVKFlatpak);

            return (owned) launchers;
        }
    }
}
