namespace ProtonPlus.Models.Launchers {
    public class Bottles : Launcher {
        public Bottles (Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "/.local/share/bottles" };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "/.var/app/com.usebottles.bottles/data/bottles" };
                break;
            case Launcher.InstallationTypes.SNAP:
                break;
            }

            base ("Bottles", installation_type, Constants.RESOURCE_BASE + "/bottles.png", directories);

            if (installed) {
                groups = get_groups ();
                install.connect ((release) => true);
                uninstall.connect ((release) => true);
            }
        }

        Group[] get_groups () {
            var groups = new Group[2];

            groups[0] = new Group (_("Runners"), _("Compatibility tools for running Windows software on Linux."), "/runners", this);
            groups[0].runners = get_runners (groups[0]);

            groups[1] = new Group ("DXVK", _("Vulkan-based implementation of Direct3D 9, 10 and 11 for Linux/Wine."), "/dxvk", this);
            groups[1].runners = get_dxvk_runners (groups[1]);

            return groups;
        }

        List<Runner> get_runners (Group group) {
            var runners = new List<Runner> ();

            runners.append (new Runners.Proton_GE (group));
            runners.append (new Runners.Wine_GE (group));
            runners.append (new Runners.Wine_Lutris (group));
            runners.append (new Runners.Other (group));

            return runners;
        }

        List<Runner> get_dxvk_runners (Group group) {
            var runners = new List<Runner> ();

            runners.append (new Runners.DXVK_doitsujin (group));
            runners.append (new Runners.DXVK_Async_Sporif (group));

            return runners;
        }
    }
}