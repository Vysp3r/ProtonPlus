namespace ProtonPlus.Models.Launchers {
    public class Lutris : Launcher {
        public const string FAMILY_ID = "lutris";

        public Lutris (Launcher.InstallationTypes installation_type) {
            string[] directories = null;
            var custom_dir = Globals.SETTINGS != null
                ? Globals.SETTINGS.get_string ("lutris-dir-custom").strip ()
                : "";

            switch (installation_type) {
                case Launcher.InstallationTypes.SYSTEM:
                    directories = new string[] {
                        Path.build_filename (Environment.get_user_data_dir (), "lutris"),
                        Path.build_filename (Environment.get_home_dir (), ".local", "share", "lutris")
                    };
                    break;
                case Launcher.InstallationTypes.FLATPAK:
                    directories = new string[] { "%s/.var/app/net.lutris.Lutris/data/lutris".printf (Environment.get_home_dir ()) };
                    break;
                case Launcher.InstallationTypes.SNAP:
                    break;
            }

            if (custom_dir.length > 0) {
                directories += custom_dir;
            }

            base ("Lutris", installation_type, "%s/lutris.svg".printf (Config.RESOURCE_BASE), directories, FAMILY_ID);
        }
    }
}
