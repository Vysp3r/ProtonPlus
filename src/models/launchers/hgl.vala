namespace ProtonPlus.Models.Launchers {
    public class HeroicGamesLauncher : Launcher {
        public HeroicGamesLauncher (Launcher.InstallationTypes installation_type) {
            string[] directories = null;;

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

            base ("Heroic Games Launcher", installation_type, Constants.RESOURCE_BASE + "/hgl.png", directories);

            if (installed) {
                groups = get_groups ();
                install.connect ((release) => install_script);
                uninstall.connect ((release) => uninstall_script);
            }
        }

        Group[] get_groups () {
            var groups = new Group[4];

            groups[0] = new Group ("Proton", _("Compatibility tools by Valve for running Windows software on Linux."), "/tools/proton", this);
            groups[0].runners = get_proton_runners (groups[0]);

            groups[1] = new Group ("Wine", _("Compatibility tools for running Windows software on Linux."), "/tools/wine", this);
            groups[1].runners = get_wine_runners (groups[1]);

            groups[2] = new Group ("DXVK", _("Vulkan-based implementation of Direct3D 9, 10 and 11 for Linux/Wine."), "/tools/dxvk", this);
            groups[2].runners = get_dxvk_runners (groups[2]);

            groups[3] = new Group ("VKD3D", _("Variant of Wine's VKD3D which aims to implement the full Direct3D 12 API on top of Vulkan."), "/tools/vkd3d", this);
            groups[3].runners = get_vkd3d_runners (groups[3]);

            return groups;
        }

        List<Runner> get_wine_runners (Group group) {
            var runners = new List<Runner> ();

            runners.append (new Runners.Wine_GE (group));
            runners.append (new Runners.Wine_Vanilla_Kron4ek (group));
            runners.append (new Runners.Wine_Staging_Kron4ek (group));
            runners.append (new Runners.Wine_Staging_Tkg_Kron4ek (group));

            return runners;
        }

        List<Runner> get_proton_runners (Group group) {
            var runners = new List<Runner> ();

            runners.append (new Runners.Proton_GE (group));
            runners.append (new Runners.Proton_Tkg (group));

            return runners;
        }

        List<Runner> get_dxvk_runners (Group group) {
            var runners = new List<Runner> ();

            runners.append (new Runners.DXVK_doitsujin (group));

            return runners;
        }

        List<Runner> get_vkd3d_runners (Group group) {
            var runners = new List<Runner> ();

            runners.append (new Runners.VKD3D_Lutris (group));
            runners.append (new Runners.VKD3D_Proton (group));

            return runners;
        }

        void install_script (Release release) {
            try {
                string path = "/.config";
                if (release.runner.group.launcher.title.contains ("Flatpak"))path = "/.var/app/com.heroicgameslauncher.hgl/config";
                path = Environment.get_home_dir () + path + "/heroic/store/wine-downloader-info.json";

                Json.Node rootNode = Json.from_string (Utils.Filesystem.get_file_content (path));
                Json.Object rootObj = rootNode.get_object ();

                var objArray = rootObj.get_array_member ("wine-releases");
                if (objArray == null)return;

                bool found = false;

                var runner = release.runner as Runners.Basic;

                for (var i = 0; i < objArray.get_length (); i++) {
                    var obj = objArray.get_object_element (i);

                    if (obj.get_string_member ("version").contains (runner.get_directory_name (release.title))) {
                        obj.set_boolean_member ("isInstalled", true);
                        obj.set_boolean_member ("hasUpdate", false);
                        obj.set_string_member ("installDir", Environment.get_home_dir () + "/" + obj.get_string_member ("version"));

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
                    obj.set_string_member ("installDir", release.runner.group.launcher.directory + "/" + obj.get_string_member ("version"));

                    obj.set_int_member ("disksize", (int64) Utils.Filesystem.get_directory_size (obj.get_string_member ("installDir")));

                    objArray.add_object_element (obj);
                }

                Utils.Filesystem.modify_file (path, Json.to_string (rootNode, true));
            } catch (Error e) {
                message (e.message);
            }
        }

        void uninstall_script (Release release) {
            try {
                string path = "/.config";
                if (release.runner.group.launcher.title.contains ("Flatpak"))path = "/.var/app/com.heroicgameslauncher.hgl/config";
                path = Environment.get_home_dir () + path + "/heroic/store/wine-downloader-info.json";

                Json.Node rootNode = Json.from_string (Utils.Filesystem.get_file_content (path));
                Json.Object rootObj = rootNode.get_object ();

                var objArray = rootObj.get_array_member ("wine-releases");
                if (objArray == null)return;

                for (var i = 0; i < objArray.get_length (); i++) {
                    var obj = objArray.get_object_element (i);

                    var runner = release.runner as Runners.Basic;

                    if (obj.get_string_member ("version").contains (runner.get_directory_name (release.title))) {
                        obj.remove_member ("isInstalled");
                        obj.remove_member ("hasUpdate");
                        obj.remove_member ("installDir");
                        obj.set_int_member ("disksize", 0);
                    }
                }

                Utils.Filesystem.modify_file (path, Json.to_string (rootNode, true));
            } catch (Error e) {
                message (e.message);
            }
        }
    }
}