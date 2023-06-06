namespace ProtonPlus.Shared.Launchers {
    public class HeroicGamesLauncher {
        static Models.Group[] get_groups (Models.Launcher launcher) {
            var groups = new Models.Group[2];

            groups[0] = new Models.Group ("Proton", "/tools/proton", launcher);
            groups[0].runners = get_proton_runners (groups[0]);

            groups[1] = new Models.Group ("Wine", "/tools/wine", launcher);
            groups[1].runners = get_wine_runners (groups[1]);

            return groups;
        }

        public static Models.Launcher get_launcher () {
            var directories = new string[] { "/.config/heroic" };

            var launcher = new Models.Launcher (
                                                "Heroic Games Launcher",
                                                "System",
                                                "/com/vysp3r/ProtonPlus/hgl.png",
                                                directories
            );

            launcher.setup_callbacks (install_script, uninstall_script);

            if (launcher.installed) launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static Models.Launcher get_flatpak_launcher () {
            var directories = new string[] { "/.var/app/com.heroicgameslauncher.hgl/config/heroic" };

            var launcher = new Models.Launcher (
                                                "Heroic Games Launcher",
                                                "Flatpak",
                                                "/com/vysp3r/ProtonPlus/hgl.png",
                                                directories
            );

            launcher.setup_callbacks (install_script, uninstall_script);

            if (launcher.installed) launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static GLib.List<Models.Runner> get_wine_runners (Models.Group group) {
            var runners = new GLib.List<Models.Runner> ();

            runners.append (new Models.Runner (group, "Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1, Models.Runner.title_types.WINE_HGL));

            return runners;
        }

        public static GLib.List<Models.Runner> get_proton_runners (Models.Group group) {
            var runners = new GLib.List<Models.Runner> ();

            runners.append (new Models.Runner (group, "Proton-GE", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1, Models.Runner.title_types.PROTON_HGL));

            return runners;
        }

        static void install_script (Models.Release release) {
            try {
                string path = "/.config";
                if (release.runner.group.launcher.title.contains ("Flatpak")) path = "/.var/app/com.heroicgameslauncher.hgl/config";
                path = GLib.Environment.get_home_dir () + path + "/heroic/store/wine-downloader-info.json";

                Json.Node rootNode = Json.from_string (Utils.Filesystem.GetFileContent (path));
                Json.Object rootObj = rootNode.get_object ();

                var objArray = rootObj.get_array_member ("wine-releases");
                if (objArray == null) return;

                bool found = false;

                for (var i = 0; i < objArray.get_length (); i++) {
                    var tempNode = objArray.get_element (i);
                    var obj = tempNode.get_object ();

                    if (obj.get_string_member ("version").contains (release.get_directory_name ())) {
                        obj.set_boolean_member ("isInstalled", true);
                        obj.set_boolean_member ("hasUpdate", false);
                        obj.set_string_member ("installDir", GLib.Environment.get_home_dir () + "/" + obj.get_string_member ("version"));

                        obj.set_int_member ("disksize", (int64) Utils.Filesystem.GetDirectorySize (obj.get_string_member ("installDir")));

                        found = true;
                    }
                }

                if (!found) {
                    var obj = new Json.Object ();

                    obj.set_string_member ("version", release.get_directory_name ());
                    obj.set_string_member ("type", release.runner.title);
                    obj.set_string_member ("date", release.release_date);
                    obj.set_string_member ("checksum", release.checksum_link);
                    obj.set_string_member ("download", release.download_link);
                    obj.set_int_member ("downsize", release.download_size);

                    obj.set_boolean_member ("isInstalled", true);
                    obj.set_boolean_member ("hasUpdate", false);
                    obj.set_string_member ("installDir", release.runner.group.launcher.directory + "/" + obj.get_string_member ("version"));

                    obj.set_int_member ("disksize", (int64) Utils.Filesystem.GetDirectorySize (obj.get_string_member ("installDir")));

                    objArray.add_object_element (obj);
                }

                Utils.Filesystem.ModifyFile (path, Json.to_string (rootNode, true));
            } catch (GLib.Error e) {
                message (e.message);
            }
        }

        static void uninstall_script (Models.Release release) {
            try {
                string path = "/.config";
                if (release.runner.group.launcher.title.contains ("Flatpak")) path = "/.var/app/com.heroicgameslauncher.hgl/config";
                path = GLib.Environment.get_home_dir () + path + "/heroic/store/wine-downloader-info.json";

                Json.Node rootNode = Json.from_string (Utils.Filesystem.GetFileContent (path));
                Json.Object rootObj = rootNode.get_object ();

                var objArray = rootObj.get_array_member ("wine-releases");
                if (objArray == null) return;

                for (var i = 0; i < objArray.get_length (); i++) {
                    var tempNode = objArray.get_element (i);
                    var obj = tempNode.get_object ();

                    if (obj.get_string_member ("version").contains (release.get_directory_name ())) {
                        obj.remove_member ("isInstalled");
                        obj.remove_member ("hasUpdate");
                        obj.remove_member ("installDir");
                        obj.set_int_member ("disksize", 0);
                    }
                }

                Utils.Filesystem.ModifyFile (path, Json.to_string (rootNode, true));
            } catch (GLib.Error e) {
                message (e.message);
            }
        }
    }
}