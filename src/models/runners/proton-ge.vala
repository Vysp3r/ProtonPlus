namespace ProtonPlus.Models.Runners {
    public class Proton_GE : GitHub {
        public Proton_GE (Group group) {
            Object (group: group,
                    title: "Proton-GE",
                    description: _("Steam compatibility tool for running Windows games with improvements over Valve's default Proton."),
                    endpoint: "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases",
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