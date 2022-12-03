namespace ProtonPlus.Models {
    public class Launcher : Object, Interfaces.IModel {
        string homeDirectory;
        string directory;

        public string Title { get; set; }
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
                if (Posix.opendir (homeDirectory + item) != null) {
                    dir = item + toolDirectory;
                    break;
                }
            }

            // If a directory exist, it makes sure that the tool directory is created
            if (dir.length > 0) {
                if (Posix.opendir (homeDirectory + dir) == null) {
                    Posix.mkdir (homeDirectory + dir, 0777);
                }
            }

            return dir;
        }

        public static GLib.ListStore GetStore (GLib.List<Launcher> launchers) {
            var store = new GLib.ListStore (typeof (Launcher));

            launchers.@foreach ((launcher) => {
                if (launcher.Installed == true) {
                    store.append (launcher);
                }
            });

            return store;
        }

        public static GLib.List GetAll () {
            var launchers = new GLib.List<Launcher> ();

            // Steam
            var steamToolDir = "/compatibilitytools.d";
            var steamTools = Models.Tool.Steam ();

            launchers.append (new Launcher (
                                  "Steam",
                                  new string[] {
                "/.local/share/Steam",
                "/.steam/root",
                "/.steam/steam",
                "/.steam/debian-installation"
            },
                                  steamToolDir,
                                  steamTools
            ));
            launchers.append (new Launcher (
                                  "Steam (Flatpak)",
                                  new string[] {
                "/.var/app/com.valvesoftware.Steam/data/Steam"
            },
                                  steamToolDir,
                                  steamTools
            ));
            launchers.append (new Launcher (
                                  "Steam (Snap)",
                                  new string[] {
                "/snap/steam/common/.steam/root"
            },
                                  steamToolDir,
                                  steamTools
            ));

            // Lutris
            var lutrisToolDir = "/wine";
            var lutrisTools = Models.Tool.Lutris ();

            launchers.append (new Launcher (
                                  "Lutris",
                                  new string[] {
                "/.local/share/lutris/runners"
            },
                                  lutrisToolDir,
                                  lutrisTools
            ));
            launchers.append (new Launcher (
                                  "Lutris (Flatpak)",
                                  new string[] {
                "/.var/app/net.lutris.Lutris/data/lutris/runners"
            },
                                  lutrisToolDir,
                                  lutrisTools
            ));

            // Lutris DXVK
            var lutrisDxvkToolDir = "/dxvk";
            var lutrisDxvkTools = Models.Tool.LutrisDXVK ();

            launchers.append (new Launcher (
                                  "Lutris DXVK",
                                  new string[] {
                "/.local/share/lutris/runtime"
            },
                                  lutrisDxvkToolDir,
                                  lutrisDxvkTools
            ));
            launchers.append (new Launcher (
                                  "Lutris DXVK (Flatpak)",
                                  new string[] {
                "/.var/app/net.lutris.Lutris/data/lutris/runtime"
            },
                                  lutrisDxvkToolDir,
                                  lutrisDxvkTools
            ));

            // Heroic Games Launcher (Proton)
            // var heroicProtonToolDir = "/proton";
            // var heroicProtonTools = Models.Tool.HeroicProton ();

            // launchers.append(new Launcher (
            // "Heroic Proton",
            // new string[] {
            // "/.config/heroic/tools"
            // },
            // heroicProtonToolDir,
            // heroicProtonTools
            // ));
            // launchers.append(new Launcher (
            // "Heroic Proton (Flatpak)",
            // new string[] {
            // "/.var/app/com.heroicgameslauncher.hgl/config/heroic/tools"
            // },
            // heroicProtonToolDir,
            // heroicProtonTools
            // ));

            // Heroic Games Launcher (Wine)
            // var heroicWineToolDir = "/wine";
            // var heroicWineTools = Models.Tool.HeroicWine ();

            // launchers.append(new Launcher (
            // "Heroic Wine",
            // new string[] {
            // "/.config/heroic/tools"
            // },
            // heroicWineToolDir,
            // heroicWineTools
            // ));
            // launchers.append(new Launcher (
            // "Heroic Wine (Flatpak)",
            // new string[] {
            // "/.var/app/com.heroicgameslauncher.hgl/config/heroic/tools"
            // },
            // heroicWineToolDir,
            // heroicWineTools
            // ));

            // Bottles
            // var bottlesToolDir = "/runners";
            // var bottlesTools = Models.Tool.Bottles ();

            // launchers.append (new Launcher (
            // "Bottles",
            // new string[] {
            // "/.local/share/bottles"
            // },
            // bottlesToolDir,
            // bottlesTools
            // ));
            // launchers.append (new Launcher (
            // "Bottles (Flatpak)",
            // new string[] {
            // "/.var/app/com.usebottles.bottles/data/bottles"
            // },
            // bottlesToolDir,
            // bottlesTools
            // ));

            return launchers;
        }
    }
}
