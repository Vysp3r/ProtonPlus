namespace ProtonPlus.Models.Launchers {
    public class WineZGUI : Launcher {
        public const string FAMILY_ID = "winezgui";

        public WineZGUI (Launcher.InstallationTypes installation_type) {
            string[] directories = null;
            var custom_dir = Globals.SETTINGS != null
                ? Globals.SETTINGS.get_string ("winezgui-dir-custom").strip ()
                : "";

            switch (installation_type) {
                case Launcher.InstallationTypes.SYSTEM:
                    directories = new string[] {
                        Path.build_filename (Environment.get_user_data_dir (), "winezgui"),
                        Path.build_filename (Environment.get_home_dir (), ".local", "share", "winezgui")
                    };
                    break;
                case Launcher.InstallationTypes.FLATPAK:
                    directories = new string[] { "%s/.var/app/io.github.fastrizwaan.WineZGUI/data/winezgui".printf (Environment.get_home_dir ()) };
                    break;
                case Launcher.InstallationTypes.SNAP:
                    break;
            }

            if (custom_dir.length > 0) {
                directories += custom_dir;
            }

            base ("WineZGUI", installation_type, "%s/winezgui.svg".printf (Config.RESOURCE_BASE), directories, FAMILY_ID);
        }
    }
}
