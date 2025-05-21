namespace ProtonPlus.Models.Launchers {
    public class Steam : Launcher {
        public static bool IS_SHORTCUT_INSTALLED = false;
        private Utils.VDF.Shortcuts shortcuts_file;
        private int shortcut_status = 0;

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
            runners.append (new Runners.Proton_CachyOS (group));
            runners.append (new Runners.Proton_EM (group));
            runners.append (new Runners.Proton_Sarek (group));
            runners.append (new Runners.Proton_Sarek_Async (group));
            runners.append (new Runners.Proton_GE_RSTP (group));
            runners.append (new Runners.Proton_Tkg (group));
            runners.append (new Runners.Northstar_Proton (group));
            runners.append (new Runners.Luxtorpeda (group));
            runners.append (new Runners.Boxtron (group));
            runners.append (new Runners.Roberta (group));
            runners.append (new Runners.SteamTinkerLaunch (group));

            return runners;
        }

        public bool install_shortcut() {
            Utils.VDF.Shortcut pp_shortcut = {};

            try {
                pp_shortcut.AppID = 0;
                pp_shortcut.AllowDesktopConfig = true;
                pp_shortcut.AllowOverlay = true;
                pp_shortcut.AppName = "ProtonPlus";
                pp_shortcut.Devkit = 0;
                pp_shortcut.DevkitGameID = "\0";
                pp_shortcut.DevkitOverrideAppID = 0;
                pp_shortcut.Exe = "\"/usr/bin/flatpak\"";
                pp_shortcut.FlatpakAppID = "";
                pp_shortcut.IsHidden = false;
                pp_shortcut.LastPlayTime = 0;
                pp_shortcut.LaunchOptions = "\"run\" \"--branch=stable\" \"--arch=x86_64\" \"--command=com.vysp3r.ProtonPlus\" \"com.vysp3r.ProtonPlus\"";
                pp_shortcut.OpenVR = 0;
                pp_shortcut.ShortcutPath = "/var/lib/flatpak/exports/share/applications/com.vysp3r.ProtonPlus.desktop";
                pp_shortcut.StartDir = "\"/usr/bin/\"";
                pp_shortcut.Icon = "\0";

                shortcuts_file.append_shortcut(pp_shortcut);
                shortcuts_file.save();

                return true;
            } catch (Error e) {
                message(e.message);
                return false;
            }
        }

        public bool uninstall_shortcut() {
            try {
                shortcuts_file.remove_shortcut_by_name("ProtonPlus");
                shortcuts_file.save();
                return true;
            } catch (Error e) {
                message(e.message);
                return true;
            }
            
        }
    }
}