namespace Models {
    public class Launcher : Object {
        public string Title;
        public string FullPath;
        public string Description;
        public string InstallMessage;
        public List<Models.Tool> Tools;
        public bool Installed {
            public get { return FullPath.length > 0; }
        }

        public delegate void Callback (Models.Release release);
        public signal void install (Models.Release release);
        public signal void uninstall (Models.Release release);

        public Launcher (string title, string[] directories, string toolDirectory, Callback? installCallback = null, Callback? uninstallCallback = null) {
            Title = title;
            FullPath = verifyDirectories (directories, toolDirectory);

            if (installCallback != null) install.connect ((release) => installCallback (release));
            if (uninstallCallback != null) uninstall.connect ((release) => uninstallCallback (release));
        }

        string verifyDirectories (string[] directories, string toolDirectory) {
            string dir = "";

            // Check if any of the given directories exists
            foreach (var item in directories) {
                if (FileUtils.test (GLib.Environment.get_home_dir () + item, FileTest.IS_DIR)) {
                    dir = item + toolDirectory;
                    break;
                }
            }

            // If a directory exist, it makes sure that the tool directory is created
            if (dir.length > 0) {
                if (!FileUtils.test (GLib.Environment.get_home_dir () + dir, FileTest.IS_DIR)) {
                    Utils.File.CreateDirectory (GLib.Environment.get_home_dir () + dir);
                }
            }

            return dir == "" ? dir : GLib.Environment.get_home_dir () + dir;
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

        public static GLib.List<Launcher> GetAll () {
            var launchers = new GLib.List<Launcher> ();

            // Steam
            var steamToolDir = "/compatibilitytools.d";
            var steamInstallMessage = _("Make sure to restart Steam if it's open to be able to use it otherwise you will not see it.\n");
            var steam = new Launcher (
                                      "Steam",
                                      new string[] {
                "/.local/share/Steam",
                "/.steam/root",
                "/.steam/steam",
                "/.steam/debian-installation"
            },
                                      steamToolDir
            );
            if (steam.Installed) {
                steam.Tools = Models.Tool.Steam (steam);
                launchers.append (steam);
                steam.InstallMessage = steamInstallMessage;
            }


            var steamFlatpak = new Launcher (
                                             "Steam (Flatpak)",
                                             new string[] {
                "/.var/app/com.valvesoftware.Steam/data/Steam"
            },
                                             steamToolDir
            );
            if (steamFlatpak.Installed) {
                steamFlatpak.Tools = Models.Tool.Steam (steamFlatpak);
                steamFlatpak.Description = _("If you're using gamescope with Steam (Flatpak), those tools will not work. Make sure to use the community builds from Flathub.");
                steamFlatpak.InstallMessage = steamInstallMessage;
                launchers.append (steamFlatpak);
            }

            var steamSnap = new Launcher (
                                          "Steam (Snap)",
                                          new string[] {
                "/snap/steam/common/.steam/root"
            },
                                          steamToolDir
            );
            if (steamSnap.Installed) {
                steamSnap.Tools = Models.Tool.Steam (steamSnap);
                steamSnap.InstallMessage = steamInstallMessage;
                launchers.append (steamSnap);
            }


            // Lutris
            var lutrisToolDir = "/wine";

            var lutris = new Launcher (
                                       "Lutris",
                                       new string[] {
                "/.local/share/lutris/runners"
            },
                                       lutrisToolDir
            );
            if (lutris.Installed) {
                lutris.Tools = Models.Tool.Lutris (lutris);
                launchers.append (lutris);
            }

            var lutrisFlatpak = new Launcher (
                                              "Lutris (Flatpak)",
                                              new string[] {
                "/.var/app/net.lutris.Lutris/data/lutris/runners"
            },
                                              lutrisToolDir
            );
            if (lutrisFlatpak.Installed) {
                lutrisFlatpak.Tools = Models.Tool.Lutris (lutrisFlatpak);
                launchers.append (lutrisFlatpak);
            }

            // Lutris DXVK
            var lutrisDxvkToolDir = "/dxvk";

            var lutrisDXVK = new Launcher (
                                           "Lutris DXVK",
                                           new string[] {
                "/.local/share/lutris/runtime"
            },
                                           lutrisDxvkToolDir
            );
            if (lutrisDXVK.Installed) {
                lutrisDXVK.Tools = Models.Tool.LutrisDXVK (lutrisDXVK);
                launchers.append (lutrisDXVK);
            }

            var lutrisDXVKFlatpak = new Launcher (
                                                  "Lutris DXVK (Flatpak)",
                                                  new string[] {
                "/.var/app/net.lutris.Lutris/data/lutris/runtime"
            },
                                                  lutrisDxvkToolDir
            );
            if (lutrisDXVKFlatpak.Installed) {
                lutrisDXVKFlatpak.Tools = Models.Tool.LutrisDXVK (lutrisDXVKFlatpak);
                launchers.append (lutrisDXVKFlatpak);
            }

            // Heroic Games Launcher - Proton
            var HGLProtonToolDir = "/proton";

            var HGLProton = new Launcher (
                                          "Heroic Games Launcher - Proton",
                                          new string[] {
                "/.config/heroic/tools"
            },
                                          HGLProtonToolDir,
                                          HGL_Install_Script,
                                          HGL_Uninstall_Script
            );
            if (HGLProton.Installed) {
                HGLProton.Tools = Models.Tool.HeroicProton (HGLProton);
                launchers.append (HGLProton);
            }

            var HGLProtonFlatpak = new Launcher (
                                                 "Heroic Games Launcher - Proton (Flatpak)",
                                                 new string[] {
                "/.var/app/com.heroicgameslauncher.hgl/config/heroic/tools"
            },
                                                 HGLProtonToolDir,
                                                 HGL_Install_Script,
                                                 HGL_Uninstall_Script
            );
            if (HGLProtonFlatpak.Installed) {
                HGLProtonFlatpak.Tools = Models.Tool.HeroicProton (HGLProtonFlatpak);
                launchers.append (HGLProtonFlatpak);
            }

            // Heroic Games Launcher - Wine
            var HGLWineToolDir = "/wine";

            var HGLWine = new Launcher (
                                        "Heroic Games Launcher - Wine",
                                        new string[] {
                "/.config/heroic/tools"
            },
                                        HGLWineToolDir,
                                        HGL_Install_Script,
                                        HGL_Uninstall_Script
            );
            if (HGLWine.Installed) {
                HGLWine.Tools = Models.Tool.HeroicWine (HGLWine);
                launchers.append (HGLWine);
            }

            var HGLWineFlatpak = new Launcher (
                                               "Heroic Games Launcher - Wine (Flatpak)",
                                               new string[] {
                "/.var/app/com.heroicgameslauncher.hgl/config/heroic/tools"
            },
                                               HGLWineToolDir,
                                               HGL_Install_Script,
                                               HGL_Uninstall_Script
            );
            if (HGLWineFlatpak.Installed) {
                HGLWineFlatpak.Tools = Models.Tool.HeroicWine (HGLWineFlatpak);
                launchers.append (HGLWineFlatpak);
            }

            // Bottles
            var bottlesToolDir = "/runners";

            var bottles = new Launcher (
                                        "Bottles",
                                        new string[] {
                "/.local/share/bottles"
            },
                                        bottlesToolDir
            );
            if (bottles.Installed) {
                bottles.Tools = Models.Tool.Bottles (bottles);
                launchers.append (bottles);
            }

            var bottlesFlatpak = new Launcher (
                                               "Bottles (Flatpak)",
                                               new string[] {
                "/.var/app/com.usebottles.bottles/data/bottles"
            },
                                               bottlesToolDir
            );
            if (bottlesFlatpak.Installed) {
                bottlesFlatpak.Tools = Models.Tool.Bottles (bottlesFlatpak);
                launchers.append (bottlesFlatpak);
            }

            // Bottles DXVK
            var bottlesDXVKToolDir = "/dxvk";

            var bottlesDXVK = new Launcher (
                                            "Bottles DXVK",
                                            new string[] {
                "/.local/share/bottles"
            },
                                            bottlesDXVKToolDir
            );
            if (bottlesDXVK.Installed) {
                bottlesDXVK.Tools = Models.Tool.BottlesDXVK (bottlesDXVK);
                launchers.append (bottlesDXVK);
            }

            var bottlesDXVKFlatpak = new Launcher (
                                                   "Bottles DXVK (Flatpak)",
                                                   new string[] {
                "/.var/app/com.usebottles.bottles/data/bottles"
            },
                                                   bottlesDXVKToolDir
            );
            if (bottlesDXVKFlatpak.Installed) {
                bottlesDXVKFlatpak.Tools = Models.Tool.BottlesDXVK (bottlesDXVKFlatpak);
                launchers.append (bottlesDXVKFlatpak);
            }

            return (owned) launchers;
        }

        static void HGL_Install_Script (Models.Release release) {
            try {
                string path = "/.config";
                if (release.Tool.Launcher.Title.contains ("Flatpak")) path = "/.var/app/com.heroicgameslauncher.hgl/config";

                GLib.File file = GLib.File.new_for_path (GLib.Environment.get_home_dir () + path + "/heroic/store/wine-downloader-info.json");

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

                    if (obj.get_string_member ("version").contains (release.GetDirectoryName ())) {
                        obj.set_boolean_member ("isInstalled", true);
                        obj.set_boolean_member ("hasUpdate", false);
                        obj.set_string_member ("installDir", GLib.Environment.get_home_dir () + "/" + obj.get_string_member ("version"));

                        var util = new Utils.DirUtil (obj.get_string_member ("installDir"));
                        obj.set_int_member ("disksize", (int64) util.get_total_size ());

                        found = true;
                    }
                }

                if (!found) {
                    var obj = new Json.Object ();

                    obj.set_string_member ("version", release.GetDirectoryName ());
                    obj.set_string_member ("type", release.Tool.Title);
                    obj.set_string_member ("date", release.ReleaseDate);
                    obj.set_string_member ("checksum", release.ChecksumURL);
                    obj.set_string_member ("download", release.DownloadURL);
                    obj.set_int_member ("downsize", release.DownloadSize);

                    obj.set_boolean_member ("isInstalled", true);
                    obj.set_boolean_member ("hasUpdate", false);
                    obj.set_string_member ("installDir", release.Tool.Launcher.FullPath + "/" + obj.get_string_member ("version"));

                    var util = new Utils.DirUtil (obj.get_string_member ("installDir"));
                    obj.set_int_member ("disksize", (int64) util.get_total_size ());

                    objArray.add_object_element (obj);
                }

                var util = new Utils.DirUtil (GLib.Environment.get_home_dir () + path + "/heroic/store");
                util.remove_file ("wine-downloader-info.json");
                Utils.File.Write (GLib.Environment.get_home_dir () + path + "/heroic/store/wine-downloader-info.json", Json.to_string (rootNode, true));
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        static void HGL_Uninstall_Script (Models.Release release) {
            try {
                string path = "/.config";
                if (release.Tool.Launcher.Title.contains ("Flatpak")) path = "/.var/app/com.heroicgameslauncher.hgl/config";

                GLib.File file = GLib.File.new_for_path (GLib.Environment.get_home_dir () + path + "/heroic/store/wine-downloader-info.json");

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

                    if (obj.get_string_member ("version").contains (release.GetDirectoryName ())) {
                        obj.remove_member ("isInstalled");
                        obj.remove_member ("hasUpdate");
                        obj.remove_member ("installDir");
                        obj.set_int_member ("disksize", 0);
                    }
                }

                var util = new Utils.DirUtil (GLib.Environment.get_home_dir () + path + "/heroic/store");
                util.remove_file ("wine-downloader-info.json");
                Utils.File.Write (GLib.Environment.get_home_dir () + path + "/heroic/store/wine-downloader-info.json", Json.to_string (rootNode, true));
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
            }
        }
    }
}
