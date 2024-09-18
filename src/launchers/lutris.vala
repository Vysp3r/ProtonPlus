namespace ProtonPlus.Launchers {
    public class Lutris : Models.Launcher {
        public Lutris (Models.Launcher.InstallationTypes installation_type) {
            string[] directories = null;;

            switch (installation_type) {
            case Models.Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "/.local/share/lutris" };
                break;
            case Models.Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "/.var/app/net.lutris.Lutris/data/lutris" };
                break;
            case Models.Launcher.InstallationTypes.SNAP:
                break;
            }

            base ("Lutris", installation_type, Constants.RESOURCE_BASE + "/lutris.png", directories);

            if (installed) {
                groups = get_groups ();
            }
        }

        Models.Group[] get_groups () {
            var groups = new Models.Group[3];

            groups[0] = new Models.Group ("Wine", _("Compatibility tools for running Windows software on Linux."), "/runners/wine", this);
            groups[0].runners = get_wine_runners (groups[0]);

            groups[1] = new Models.Group ("DXVK", _("Vulkan-based implementation of Direct3D 9, 10 and 11 for Linux/Wine."), "/runtime/dxvk", this);
            groups[1].runners = get_dxvk_runners (groups[1]);

            groups[2] = new Models.Group ("VKD3D", _("Variant of Wine's VKD3D which aims to implement the full Direct3D 12 API on top of Vulkan."), "/runtime/vkd3d", this);
            groups[2].runners = get_vkd3d_runners (groups[2]);

            return groups;
        }

        List<Models.Runner> get_wine_runners (Models.Group group) {
            var runners = new List<Models.Runner> ();

            runners.append (new Runners.Wine_GE (group));
            runners.append (new Runners.Wine_Lutris (group));
            runners.append (new Runners.Wine_Vanilla_Kron4ek (group));
            runners.append (new Runners.Wine_Staging_Kron4ek (group));
            runners.append (new Runners.Wine_Staging_Tkg_Kron4ek (group));

            return runners;
        }

        List<Models.Runner> get_dxvk_runners (Models.Group group) {
            var runners = new List<Models.Runner> ();

            runners.append (new Runners.DXVK_doitsujin (group));
            runners.append (new Runners.DXVK_Async_Sporif (group));
            runners.append (new Runners.DXVK_Async_gnusenpai (group));
            runners.append (new Runners.DXVK_GPL_Async_Ph42oN (group));

            return runners;
        }

        List<Models.Runner> get_vkd3d_runners (Models.Group group) {
            var runners = new List<Models.Runner> ();

            runners.append (new Runners.VKD3D_Lutris (group));
            runners.append (new Runners.VKD3D_Proton (group));

            return runners;
        }
    }
}