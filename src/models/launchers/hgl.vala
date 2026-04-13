namespace ProtonPlus.Models.Launchers {
    public class HeroicGamesLauncher : Launcher {
        public HeroicGamesLauncher (Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "%s/heroic".printf (Environment.get_user_config_dir ()), "%s/.config/heroic".printf (Environment.get_home_dir ()) };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "%s/.var/app/com.heroicgameslauncher.hgl/config/heroic".printf (Environment.get_home_dir ()) };
                break;
            case Launcher.InstallationTypes.SNAP:
                break;
            }

            base ("Heroic Games Launcher", installation_type, "%s/hgl.svg".printf (Config.RESOURCE_BASE), directories);
        }
    }
}
