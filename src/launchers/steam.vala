namespace ProtonPlus.Launchers {
    public class Steam : Models.Launcher {
        public Steam (Models.Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
            case Models.Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "/.local/share/Steam",
                                             "/.steam/root",
                                             "/.steam/steam",
                                             "/.steam/debian-installation" };
                break;
            case Models.Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "/.var/app/com.valvesoftware.Steam/data/Steam" };
                break;
            case Models.Launcher.InstallationTypes.SNAP:
                directories = new string[] { "/snap/steam/common/.steam/root" };
                break;
            }

            base ("Steam", installation_type, Constants.RESOURCE_BASE + "/steam.png", directories);

            if (installed) {
                groups = get_groups ();
            }
        }

        Models.Group[] get_groups () {
            var groups = new Models.Group[1];

            groups[0] = new Models.Group (_("Runners"), _(""), "/compatibilitytools.d", this);
            groups[0].runners = get_runners (groups[0]);

            return groups;
        }

        public static List<Models.Runner> get_runners (Models.Group group) {
            var runners = new List<Models.Runner> ();

            runners.append (new Runners.Proton_GE (group));
            runners.append (new Runners.Luxtorpeda (group));
            runners.append (new Runners.Boxtron (group));
            runners.append (new Runners.Roberta (group));
            runners.append (new Runners.Northstar_Proton (group));
            runners.append (new Runners.Proton_GE_RSTP (group));
            runners.append (new Runners.Proton_Tkg (group));
            runners.append (new Runners.SteamTinkerLaunch (group));

            return runners;
        }
    }
}