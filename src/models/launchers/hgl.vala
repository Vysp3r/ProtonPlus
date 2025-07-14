namespace ProtonPlus.Models.Launchers {
    public class HeroicGamesLauncher : Launcher {
        public HeroicGamesLauncher (Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "/.config/heroic" };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "/.var/app/com.heroicgameslauncher.hgl/config/heroic" };
                break;
            case Launcher.InstallationTypes.SNAP:
                break;
            }

            base ("Heroic Games Launcher", installation_type, "%s/hgl.svg".printf (Globals.RESOURCE_BASE), directories);
        }
    }
}
