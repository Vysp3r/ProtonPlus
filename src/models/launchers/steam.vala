namespace ProtonPlus.Models.Launchers {
    public class Steam : Launcher {
        public Steam (Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "/.local/share/Steam",
                                             "/.steam/root",
                                             "/.steam/steam",
                                             "/.steam/debian-installation" };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "/.var/app/com.valvesoftware.Steam/data/Steam" };
                break;
            case Launcher.InstallationTypes.SNAP:
                directories = new string[] { "/snap/steam/common/.steam/root" };
                break;
            }

            base ("Steam", installation_type, Config.RESOURCE_BASE + "/steam.png", directories);

            if (installed) {
                groups = get_groups ();
                install.connect ((release) => true);
                uninstall.connect ((release) => true);
            }
        }

        Group[] get_groups () {
            var groups = new Group[1];

            groups[0] = new Group (_("Runners"), "", "/compatibilitytools.d", this);
            groups[0].runners = get_runners (groups[0]);

            return groups;
        }

        public static List<Runner> get_runners (Group group) {
            var runners = new List<Runner> ();

            runners.append (new Runners.Proton_GE (group));
            runners.append (new Runners.Luxtorpeda (group));
            runners.append (new Runners.Boxtron (group));
            runners.append (new Runners.Roberta (group));
            runners.append (new Runners.Northstar_Proton (group));
            runners.append (new Runners.Proton_GE_RSTP (group));
            runners.append (new Runners.Proton_Tkg (group));
            runners.append (new Runners.Proton_Sarek (group));
            runners.append (new Runners.Proton_Sarek_Async (group));
            runners.append (new Runners.SteamTinkerLaunch (group));

            return runners;
        }
    }
}