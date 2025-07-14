namespace ProtonPlus.Models.Launchers {
    public class WineZGUI : Launcher {
        public WineZGUI (Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "/.local/share/winezgui" };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "/.var/app/io.github.fastrizwaan.WineZGUI/data/winezgui" };
                break;
            case Launcher.InstallationTypes.SNAP:
                break;
            }

            base ("WineZGUI", installation_type, "%s/winezgui.svg".printf (Globals.RESOURCE_BASE), directories);
        }
    }
}
