namespace ProtonPlus.Models.Launchers {
    public class Bottles : Launcher {
        public const string FAMILY_ID = "bottles";

        public Bottles (Launcher.InstallationTypes installation_type) {
            string[] directories = null;
            var custom_dir = Globals.SETTINGS != null
                ? Globals.SETTINGS.get_string ("bottles-dir-custom").strip ()
                : "";

            switch (installation_type) {
                case Launcher.InstallationTypes.SYSTEM:
                    directories = new string[] {
                        Path.build_filename (Environment.get_user_data_dir (), "bottles"),
                        Path.build_filename (Environment.get_home_dir (), ".local", "share", "bottles")
                    };
                    break;
                case Launcher.InstallationTypes.FLATPAK:
                    directories = new string[] { "%s/.var/app/com.usebottles.bottles/data/bottles".printf (Environment.get_home_dir ()) };
                    break;
                case Launcher.InstallationTypes.SNAP:
                    break;
            }

            if (custom_dir.length > 0) {
                directories += custom_dir;
            }

            base ("Bottles", installation_type, "%s/bottles.svg".printf (Config.RESOURCE_BASE), directories, FAMILY_ID);
        }
    }
}
