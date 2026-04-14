namespace ProtonPlus.Models.Launchers {
    public class Bottles : Launcher {
        public Bottles (Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
                case Launcher.InstallationTypes.SYSTEM:
                    directories = new string[] { "%s/bottles".printf (Environment.get_user_data_dir ()), "%s/.local/share/bottles".printf (Environment.get_home_dir ()) };
                    break;
                case Launcher.InstallationTypes.FLATPAK:
                    directories = new string[] { "%s/.var/app/com.usebottles.bottles/data/bottles".printf (Environment.get_home_dir ()) };
                    break;
                case Launcher.InstallationTypes.SNAP:
                    break;
            }

            base ("Bottles", installation_type, "%s/bottles.svg".printf (Config.RESOURCE_BASE), directories);
        }
    }
}
