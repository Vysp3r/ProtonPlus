namespace ProtonPlus.Models.Launchers {
    public class WineZGUI : Launcher {
        public WineZGUI (Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "%s/winezgui".printf (Environment.get_user_data_dir ()), "%s/.local/share/winezgui".printf (Environment.get_home_dir ()) };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "%s/.var/app/io.github.fastrizwaan.WineZGUI/data/winezgui".printf (Environment.get_home_dir ()) };
                break;
            case Launcher.InstallationTypes.SNAP:
                break;
            }

            base ("WineZGUI", installation_type, "%s/winezgui.svg".printf (Config.RESOURCE_BASE), directories);
        }
    }
}
