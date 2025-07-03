namespace ProtonPlus.Models.Launchers {
    public class HeroicGamesLauncher : Launcher {
        public HeroicGamesLauncher (Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "/.config/heroic" };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "/.var/app/com.heroicgameslauncher.hgl/config/heroic" };
                break;
            case Launcher.InstallationTypes.SNAP:
                break;
            }

            base ("Heroic Games Launcher", installation_type, Globals.RESOURCE_BASE + "/hgl.svg", directories);

            if (installed) {
                install.connect ((release) => install_script (release));
                uninstall.connect ((release) => uninstall_script (release));
            }
        }

        bool install_script (Release release) {
            try {
                string path = "/.config";
                if (release.runner.group.launcher.installation_type == Launcher.InstallationTypes.FLATPAK)path = "/.var/app/com.heroicgameslauncher.hgl/config";
                path = Environment.get_home_dir () + path + "/heroic/store/wine-downloader-info.json";

                Json.Node root_node = Json.from_string (Utils.Filesystem.get_file_content (path));
                Json.Object root_object = root_node.get_object ();

                var wine_release_array = root_object.get_array_member ("wine-releases");
                if (wine_release_array == null)
                    return false;

                bool found = false;

                var runner = release.runner as Runners.Basic;

                var installDirBase = release.runner.group.launcher.directory + release.runner.group.directory + "/";

                for (var i = 0; i < wine_release_array.get_length (); i++) {
                    var obj = wine_release_array.get_object_element (i);

                    if (obj.get_string_member ("version").contains (runner.get_directory_name (release.title))) {
                        obj.set_boolean_member ("isInstalled", true);
                        obj.set_boolean_member ("hasUpdate", false);
                        obj.set_string_member ("installDir", installDirBase + obj.get_string_member ("version"));

                        obj.set_int_member ("disksize", (int64) Utils.Filesystem.get_directory_size (obj.get_string_member ("installDir")));

                        found = true;
                    }
                }

                if (!found) {
                    var obj = new Json.Object ();

                    obj.set_string_member ("version", runner.get_directory_name (release.title));
                    obj.set_string_member ("type", release.runner.title);
                    obj.set_string_member ("date", "");
                    obj.set_string_member ("checksum", "");
                    obj.set_string_member ("download", "");
                    obj.set_int_member ("downsize", 0);

                    obj.set_boolean_member ("isInstalled", true);
                    obj.set_boolean_member ("hasUpdate", false);
                    obj.set_string_member ("installDir", installDirBase + obj.get_string_member ("version"));

                    obj.set_int_member ("disksize", (int64) Utils.Filesystem.get_directory_size (obj.get_string_member ("installDir")));

                    wine_release_array.add_object_element (obj);
                }

                Utils.Filesystem.modify_file (path, Json.to_string (root_node, true));

                return true;
            } catch (Error e) {
                message (e.message);

                return false;
            }
        }

        bool uninstall_script (Release release) {
            try {
                string path = "/.config";
                if (release.runner.group.launcher.installation_type == Launcher.InstallationTypes.FLATPAK)path = "/.var/app/com.heroicgameslauncher.hgl/config";
                path = Environment.get_home_dir () + path + "/heroic/store/wine-downloader-info.json";

                Json.Node root_node = Json.from_string (Utils.Filesystem.get_file_content (path));
                Json.Object root_object = root_node.get_object ();

                var wine_release_array = root_object.get_array_member ("wine-releases");
                if (wine_release_array == null)
                    return false;

                for (var i = 0; i < wine_release_array.get_length (); i++) {
                    var obj = wine_release_array.get_object_element (i);

                    var runner = release.runner as Runners.Basic;

                    if (obj.get_string_member ("version").contains (runner.get_directory_name (release.title))) {
                        obj.remove_member ("isInstalled");
                        obj.remove_member ("hasUpdate");
                        obj.remove_member ("installDir");
                        obj.set_int_member ("disksize", 0);
                    }
                }

                Utils.Filesystem.modify_file (path, Json.to_string (root_node, true));

                return true;
            } catch (Error e) {
                message (e.message);

                return false;
            }
        }
    }
}
