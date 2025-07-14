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

            var icon_path = "heroic";
            if (installation_type == Launcher.InstallationTypes.FLATPAK)
                icon_path = "com.heroicgameslauncher.hgl";

            base ("Heroic Games Launcher", installation_type, icon_path, directories);
        }
    }
}
