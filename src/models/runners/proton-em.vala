namespace ProtonPlus.Models.Runners {
    public class Proton_EM : GitHub {
        public Proton_EM (Group group) {
            Object (group: group,
                    title: "Proton-EM",
                    description: _("Steam compatibility tool for running Windows games with improvements over Valve's default Proton. By Etaash Mathamsetty adding FSR4 support and wine wayland tweaks."),
                    endpoint: "https://api.github.com/repos/Etaash-mathamsetty/Proton/releases",
                    asset_position: 1);
        }

        public override string get_directory_name (string release_name) {
            switch (group.launcher.title) {
            case "Steam":
                if (title.contains (".")) {
                    return "Proton-" + release_name;
                }
                return release_name;
            case "Bottles":
                return release_name.down ();

            case "Heroic Games Launcher":
                return @"Proton-$release_name";
            default:
                return release_name;
            }
        }
    }
}
