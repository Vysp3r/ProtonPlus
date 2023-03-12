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
        public bool Installed {
            public get { return directory.length > 0; }
        }

        public delegate void Callback ();
        public signal void install ();
        public signal void uninstall ();

        public Launcher (string title, string[] directories, string toolDirectory, List<Models.Tool> tools, Callback? installCallback = null, Callback? uninstallCallback = null) {
            homeDirectory = GLib.Environment.get_home_dir ();

            this.Title = title;
            this.Directory = verifyDirectories (directories, toolDirectory);

            if (installCallback != null) install.connect (() => installCallback ());
            if (uninstallCallback != null) uninstall.connect (() => uninstallCallback ());

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

            // Heroic Games Launcher - Proton
            var HGLProtonToolDir = "/proton";
            var HGLProtonTools = Models.Tool.HeroicProton ();

            var HGLProton = new Launcher (
                "Heroic Games Launcher - Proton",
                new string[] {
                "/.config/heroic/tools"
            },
                HGLProtonToolDir,
                HGLProtonTools,
                HGL_Install_Script,
                HGL_Uninstall_Script
            );
            if (HGLProton.Installed) launchers.append (HGLProton);

            var HGLProtonFlatpak = new Launcher (
                "Heroic Games Launcher - Proton (Flatpak)",
                new string[] {
                "/.var/app/com.heroicgameslauncher.hgl/config/heroic/tools"
            },
                HGLProtonToolDir,
                HGLProtonTools,
                HGL_Install_Script,
                HGL_Uninstall_Script
            );
            if (HGLProtonFlatpak.Installed) launchers.append (HGLProtonFlatpak);

            // Heroic Games Launcher - Wine
            var HGLWineToolDir = "/wine";
            var HGLWineTools = Models.Tool.HeroicWine ();

            var HGLWine = new Launcher (
                "Heroic Games Launcher - Wine",
                new string[] {
                "/.config/heroic/tools"
            },
                HGLWineToolDir,
                HGLWineTools,
                HGL_Install_Script,
                HGL_Uninstall_Script
            );
            if (HGLWine.Installed) launchers.append (HGLWine);

            var HGLWineFlatpak = new Launcher (
                "Heroic Games Launcher - Wine (Flatpak)",
                new string[] {
                "/.var/app/com.heroicgameslauncher.hgl/config/heroic/tools"
            },
                HGLWineToolDir,
                HGLWineTools,
                HGL_Install_Script,
                HGL_Uninstall_Script
            );
            if (HGLWineFlatpak.Installed) launchers.append (HGLWineFlatpak);

            return (owned) launchers;
        }

        static void HGL_Install_Script () {
            try {
                var store = Stores.Main.get_instance ();

                string path = "/.config";
                if (store.CurrentLauncher.Title.contains ("Flatpak")) path = "/.var/app/com.heroicgameslauncher.hgl/config";

                GLib.File file = GLib.File.new_for_path (store.CurrentLauncher.HomeDirectory + path + "/heroic/store/wine-downloader-info.json");

                uint8[] contents;
                string etag_out;
                file.load_contents (null, out contents, out etag_out);

                Json.Node rootNode = Json.from_string ((string) contents);
                Json.Object rootObj = rootNode.get_object ();

                var objArray = rootObj.get_array_member ("wine-releases");
                if (objArray == null) return;

                bool found = false;

                for (var i = 0; i < objArray.get_length (); i++) {
                    var tempNode = objArray.get_element (i);
                    var obj = tempNode.get_object ();

                    if (obj.get_string_member ("version").contains (store.CurrentRelease.GetFolderTitle (store.CurrentLauncher, store.CurrentTool))) {
                        obj.set_boolean_member ("isInstalled", true);
                        obj.set_boolean_member ("hasUpdate", false);
                        obj.set_string_member ("installDir", store.CurrentLauncher.Directory + "/" + obj.get_string_member ("version"));

                        var util = new Utils.DirUtil (obj.get_string_member ("installDir"));
                        obj.set_int_member ("disksize", (int64) util.get_total_size ());

                        found = true;
                    }
                }

                if (!found) {
                    var obj = new Json.Object ();

                    obj.set_string_member ("version", store.CurrentRelease.GetFolderTitle (store.CurrentLauncher, store.CurrentTool));
                    obj.set_string_member ("type", store.CurrentTool.Title);
                    obj.set_string_member ("date", store.CurrentRelease.Release_Date);
                    obj.set_string_member ("checksum", store.CurrentRelease.Checksum_URL);
                    obj.set_string_member ("download", store.CurrentRelease.Download_URL);
                    obj.set_int_member ("downsize", store.CurrentRelease.Download_Size);

                    obj.set_boolean_member ("isInstalled", true);
                    obj.set_boolean_member ("hasUpdate", false);
                    obj.set_string_member ("installDir", store.CurrentLauncher.Directory + "/" + obj.get_string_member ("version"));

                    var util = new Utils.DirUtil (obj.get_string_member ("installDir"));
                    obj.set_int_member ("disksize", (int64) util.get_total_size ());

                    objArray.add_object_element (obj);
                }

                var util = new Utils.DirUtil (store.CurrentLauncher.HomeDirectory + path + "/heroic/store");
                util.remove_file ("wine-downloader-info.json");
                Utils.File.Write (store.CurrentLauncher.HomeDirectory + path + "/heroic/store/wine-downloader-info.json", Json.to_string (rootNode, true));
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        static void HGL_Uninstall_Script () {
            try {
                var store = Stores.Main.get_instance ();

                string path = "/.config";
                if (store.CurrentLauncher.Title.contains ("Flatpak")) path = "/.var/app/com.heroicgameslauncher.hgl/config";

                GLib.File file = GLib.File.new_for_path (store.CurrentLauncher.HomeDirectory + path + "/heroic/store/wine-downloader-info.json");

                uint8[] contents;
                string etag_out;
                file.load_contents (null, out contents, out etag_out);

                Json.Node rootNode = Json.from_string ((string) contents);
                Json.Object rootObj = rootNode.get_object ();

                var objArray = rootObj.get_array_member ("wine-releases");
                if (objArray == null) return;

                for (var i = 0; i < objArray.get_length (); i++) {
                    var tempNode = objArray.get_element (i);
                    var obj = tempNode.get_object ();

                    if (obj.get_string_member ("version").contains (store.CurrentRelease.GetFolderTitle (store.CurrentLauncher, store.CurrentTool))) {
                        obj.remove_member ("isInstalled");
                        obj.remove_member ("hasUpdate");
                        obj.remove_member ("installDir");
                        obj.set_int_member ("disksize", 0);
                    }
                }

                var util = new Utils.DirUtil (store.CurrentLauncher.HomeDirectory + path + "/heroic/store");
                util.remove_file ("wine-downloader-info.json");
                Utils.File.Write (store.CurrentLauncher.HomeDirectory + path + "/heroic/store/wine-downloader-info.json", Json.to_string (rootNode, true));
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
            }
        }
    }
}
