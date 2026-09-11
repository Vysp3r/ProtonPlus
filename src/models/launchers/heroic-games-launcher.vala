namespace ProtonPlus.Models.Launchers {
    public class HeroicGamesLauncher : Launcher {
        public const string FAMILY_ID = "heroic";

        public HeroicGamesLauncher (Launcher.InstallationTypes installation_type) {
            string[] directories = null;
            var custom_dir = Globals.SETTINGS != null
                ? Globals.SETTINGS.get_string ("heroic-dir-custom").strip ()
                : "";

            switch (installation_type) {
                case Launcher.InstallationTypes.SYSTEM:
                    directories = new string[] {
                        Path.build_filename (Environment.get_user_config_dir (), "heroic"),
                        Path.build_filename (Environment.get_home_dir (), ".config", "heroic")
                    };
                    break;
                case Launcher.InstallationTypes.FLATPAK:
                    directories = new string[] { "%s/.var/app/com.heroicgameslauncher.hgl/config/heroic".printf (Environment.get_home_dir ()) };
                    break;
                case Launcher.InstallationTypes.SNAP:
                    break;
            }

            if (custom_dir.length > 0) {
                directories += custom_dir;
            }

            base ("Heroic Games Launcher", installation_type, "%s/hgl.svg".printf (Config.RESOURCE_BASE), directories, FAMILY_ID);
        }
    }
}
