namespace ProtonPlus.Models.Launchers {
    public class Lutris : Launcher {
        public Lutris (Launcher.InstallationTypes installation_type) {
            string[] directories = null;

            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                directories = new string[] { "/.local/share/lutris" };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                directories = new string[] { "/.var/app/net.lutris.Lutris/data/lutris" };
                break;
            case Launcher.InstallationTypes.SNAP:
                break;
            }

            base ("Lutris", installation_type, "%s/lutris.svg".printf (Globals.RESOURCE_BASE), directories);

            if (installed) {
                Utils.Filesystem.create_directory.begin (directory + "/runners/proton", (obj, res) => {
                    Utils.Filesystem.create_directory.end (res);
                });
            }
        }
    }
}
