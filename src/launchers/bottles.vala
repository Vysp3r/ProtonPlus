namespace ProtonPlus.Launchers {
    public class Bottles : Models.Launcher {
        public Bottles (Models.Launcher.InstallationTypes installation_type) {
            string[] directories = null;;

            switch (installation_type) {
            case Models.Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "/.local/share/bottles" };
                break;
            case Models.Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "/.var/app/com.usebottles.bottles/data/bottles" };
                break;
            case Models.Launcher.InstallationTypes.SNAP:
                break;
            }

            base ("Bottles", installation_type, Constants.RESOURCE_BASE + "/bottles.png", directories);

            if (installed) {
                groups = get_groups ();
            }
        }

        Models.Group[] get_groups () {
            var groups = new Models.Group[2];

            groups[0] = new Models.Group (_("Runners"), _("Compatibility tools for running Windows software on Linux."), "/runners", this);
            groups[0].runners = get_runners (groups[0]);

            groups[1] = new Models.Group ("DXVK", _("Vulkan-based implementation of Direct3D 9, 10 and 11 for Linux/Wine."), "/dxvk", this);
            groups[1].runners = get_dxvk_runners (groups[1]);

            return groups;
        }

        List<Models.Runner> get_runners (Models.Group group) {
            var runners = new List<Models.Runner> ();

            runners.append (new Runners.Proton_GE (group));
            runners.append (new Runners.Wine_GE (group));
            runners.append (new Runners.Wine_Lutris (group));
            runners.append (new Runners.Other (group));

            return runners;
        }

        List<Models.Runner> get_dxvk_runners (Models.Group group) {
            var runners = new List<Models.Runner> ();

            runners.append (new Runners.DXVK_doitsujin (group));
            runners.append (new Runners.DXVK_Async_Sporif (group));

            return runners;
        }
    }
}