namespace ProtonPlus.Launchers {
    public class HeroicGamesLauncher {
        static Models.Group[] get_groups (Models.Launcher launcher) {
            var groups = new Models.Group[4];

            groups[0] = new Models.Group ("Proton", "/tools/proton", launcher);
            groups[0].description = _("Steam compatibility tool for running Windows games.");
            groups[0].runners = get_proton_runners (groups[0]);

            groups[1] = new Models.Group ("Wine", "/tools/wine", launcher);
            groups[1].description = _("Wine is a program which allows running Microsoft Windows programs.");
            groups[1].runners = get_wine_runners (groups[1]);

            groups[2] = new Models.Group ("DXVK", "/tools/dxvk", launcher);
            groups[2].description = _("Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine.");
            groups[2].runners = get_dxvk_runners (groups[2]);

            groups[3] = new Models.Group ("VKD3D", "/tools/vkd3d", launcher);
            groups[3].description = _("Fork of Wine's VKD3D which aims to implement the full Direct3D 12 API on top of Vulkan.");
            groups[3].runners = get_vkd3d_runners (groups[3]);

            return groups;
        }

        public static Models.Launcher get_launcher () {
            var directories = new string[] { "/.config/heroic" };

            var launcher = new Models.Launcher (
                                                "Heroic Games Launcher",
                                                "System",
                                                Constants.RESOURCE_BASE + "/hgl.png",
                                                directories
            );

            launcher.setup_callbacks (install_script, uninstall_script);

            if (launcher.installed)launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static Models.Launcher get_flatpak_launcher () {
            var directories = new string[] { "/.var/app/com.heroicgameslauncher.hgl/config/heroic" };

            var launcher = new Models.Launcher (
                                                "Heroic Games Launcher",
                                                "Flatpak",
                                                Constants.RESOURCE_BASE + "/hgl.png",
                                                directories
            );

            launcher.setup_callbacks (install_script, uninstall_script);

            if (launcher.installed)launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static List<Models.Runner> get_wine_runners (Models.Group group) {
            var runners = new List<Models.Runner> ();

            var wine_ge = new Models.Runner (group, "Wine-GE", _("Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris."), "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1, Models.Runner.title_types.HGL_WINE_GE);
            wine_ge.old_asset_location = 83;
            wine_ge.old_asset_position = 0;

            var kron4ek_vanilla = new Models.Runner (group, "Wine-Vanilla (Kron4ek)", _("Wine build compiled from the official WineHQ sources."), "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 1, Models.Runner.title_types.KRON4EK_VANILLA);
            kron4ek_vanilla.request_asset_exclude = { "proton", ".0." };

            var kron4ek_staging = new Models.Runner (group, "Wine-Staging (Kron4ek)", _("Wine build with the Staging patchset applied."), "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 2, Models.Runner.title_types.KRON4EK_STAGING);
            kron4ek_staging.request_asset_exclude = { "proton", ".0." };

            var kron4ek_staging_tkg = new Models.Runner (group, "Wine-Staging-Tkg (Kron4ek)", _("Wine build with the Staging patchset applied and with many additional useful patches."), "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 3, Models.Runner.title_types.KRON4EK_STAGING_TKG);
            kron4ek_staging_tkg.request_asset_exclude = { "proton", ".0." };

            runners.append (wine_ge);
            runners.append (kron4ek_vanilla);
            runners.append (kron4ek_staging);
            runners.append (kron4ek_staging_tkg);

            return runners;
        }

        public static List<Models.Runner> get_proton_runners (Models.Group group) {
            var runners = new List<Models.Runner> ();

            var proton_ge = new Models.Runner (group, "Proton-GE", _("Contains improvements over Valve's default Proton."), "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1, Models.Runner.title_types.HGL_PROTON_GE);
            proton_ge.old_asset_location = 95;
            proton_ge.old_asset_position = 0;

            var proton_tkg = new Models.Runner (group, "Proton-Tkg", _("Custom Proton build for running Windows games, built with the Wine-tkg build system."), "https://api.github.com/repos/Frogging-Family/wine-tkg-git/actions/workflows/29873769/runs", 0, Models.Runner.title_types.PROTON_TKG);
            proton_tkg.is_using_github_actions = true;

            runners.append (proton_ge);
            runners.append (proton_tkg);

            return runners;
        }

        public static List<Models.Runner> get_dxvk_runners (Models.Group group) {
            var runners = new List<Models.Runner> ();

            runners.append (new Models.Runner (group, "DXVK (doitsujin)", "", "https://api.github.com/repos/doitsujin/dxvk/releases", 0, Models.Runner.title_types.DXVK));

            return runners;
        }

        public static List<Models.Runner> get_vkd3d_runners (Models.Group group) {
            var runners = new List<Models.Runner> ();

            runners.append (new Models.Runner (group, "VKD3D-Lutris", "", "https://api.github.com/repos/lutris/vkd3d/releases", 0, Models.Runner.title_types.HGL_VKD3D));
            runners.append (new Models.Runner (group, "VKD3D-Proton", "", "https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases", 0, Models.Runner.title_types.LUTRIS_VKD3D_PROTON));

            return runners;
        }

        static void install_script (Models.Release release) {
            try {
                string path = "/.config";
                if (release.runner.group.launcher.title.contains ("Flatpak"))path = "/.var/app/com.heroicgameslauncher.hgl/config";
                path = Environment.get_home_dir () + path + "/heroic/store/wine-downloader-info.json";

                Json.Node rootNode = Json.from_string (Utils.Filesystem.get_file_content (path));
                Json.Object rootObj = rootNode.get_object ();

                var objArray = rootObj.get_array_member ("wine-releases");
                if (objArray == null)return;

                bool found = false;

                for (var i = 0; i < objArray.get_length (); i++) {
                    var tempNode = objArray.get_element (i);
                    var obj = tempNode.get_object ();

                    if (obj.get_string_member ("version").contains (release.get_directory_name ())) {
                        obj.set_boolean_member ("isInstalled", true);
                        obj.set_boolean_member ("hasUpdate", false);
                        obj.set_string_member ("installDir", Environment.get_home_dir () + "/" + obj.get_string_member ("version"));

                        obj.set_int_member ("disksize", (int64) Utils.Filesystem.get_directory_size (obj.get_string_member ("installDir")));

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

                    obj.set_int_member ("disksize", (int64) Utils.Filesystem.get_directory_size (obj.get_string_member ("installDir")));

                    objArray.add_object_element (obj);
                }

                Utils.Filesystem.modify_file (path, Json.to_string (rootNode, true));
            } catch (Error e) {
                message (e.message);
            }
        }

        static void uninstall_script (Models.Release release) {
            try {
                string path = "/.config";
                if (release.runner.group.launcher.title.contains ("Flatpak"))path = "/.var/app/com.heroicgameslauncher.hgl/config";
                path = Environment.get_home_dir () + path + "/heroic/store/wine-downloader-info.json";

                Json.Node rootNode = Json.from_string (Utils.Filesystem.get_file_content (path));
                Json.Object rootObj = rootNode.get_object ();

                var objArray = rootObj.get_array_member ("wine-releases");
                if (objArray == null)return;

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

                Utils.Filesystem.modify_file (path, Json.to_string (rootNode, true));
            } catch (Error e) {
                message (e.message);
            }
        }
    }
}