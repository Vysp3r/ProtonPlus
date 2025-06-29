namespace ProtonPlus.Models.Launchers {
    public class Lutris : Launcher {
        public Lutris (Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "/.local/share/lutris" };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "/.var/app/net.lutris.Lutris/data/lutris" };
                break;
            case Launcher.InstallationTypes.SNAP:
                break;
            }

            base ("Lutris", installation_type, Globals.RESOURCE_BASE + "/lutris.png", directories);

            if (installed) {
                groups = get_groups ();
                install.connect ((release) => true);
                uninstall.connect ((release) => true);

                Utils.Filesystem.create_directory.begin (directory + "/runners/proton", (obj, res) => {
                    Utils.Filesystem.create_directory.end (res);
                });
            }
        }

        Group[] get_groups () {
            var groups = new Group[4];

            groups[0] = new Group ("Proton", _("Compatibility tools by Valve for running Windows software on Linux."), "/runners/proton", this);
            groups[0].runners = get_proton_runners (groups[0]);

            groups[1] = new Group ("Wine", _("Compatibility tools for running Windows software on Linux."), "/runners/wine", this);
            groups[1].runners = get_wine_runners (groups[1]);

            groups[2] = new Group ("DXVK", _("Vulkan-based implementation of Direct3D 8, 9, 10 and 11 for Linux/Wine."), "/runtime/dxvk", this);
            groups[2].runners = get_dxvk_runners (groups[2]);

            groups[3] = new Group ("VKD3D", _("Variant of Wine's VKD3D which aims to implement the full Direct3D 12 API on top of Vulkan."), "/runtime/vkd3d", this);
            groups[3].runners = get_vkd3d_runners (groups[3]);

            return groups;
        }

        List<Runner> get_proton_runners (Group group) {
            var runners = new List<Runner> ();

            runners.append (new Runners.Proton_GE (group));
            runners.append (new Runners.Proton_CachyOS (group));
            runners.append (new Runners.Proton_EM (group));
            runners.append (new Runners.Proton_Sarek (group));
            runners.append (new Runners.Proton_Sarek_Async (group));
            runners.append (new Runners.Proton_Tkg (group));

            return runners;
        }

        List<Runner> get_wine_runners (Group group) {
            var runners = new List<Runner> ();

            runners.append (new Runners.Wine_Vanilla_Kron4ek (group));
            runners.append (new Runners.Wine_Staging_Kron4ek (group));
            runners.append (new Runners.Wine_Staging_Tkg_Kron4ek (group));

            return runners;
        }

        List<Runner> get_dxvk_runners (Group group) {
            var runners = new List<Runner> ();

            runners.append (new Runners.DXVK_doitsujin (group));
            runners.append (new Runners.DXVK_GPL_Async_Ph42oN (group));
            runners.append (new Runners.DXVK_Sarek (group));
            runners.append (new Runners.DXVK_Async_Sarek (group));

            return runners;
        }

        List<Runner> get_vkd3d_runners (Group group) {
            var runners = new List<Runner> ();

            runners.append (new Runners.VKD3D_Lutris (group));
            runners.append (new Runners.VKD3D_Proton (group));

            return runners;
        }
    }
}
