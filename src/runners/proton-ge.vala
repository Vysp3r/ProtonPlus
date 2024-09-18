namespace ProtonPlus.Runners {
    public class Proton_GE : GitHub {
        public Proton_GE (Models.Group group) {
            Object (group: group,
                    title: "Proton-GE",
                    description: _("Steam compatibility tool for running Windows games with improvements over Valve's default Proton."),
                    endpoint: "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases",
                    asset_position: 1,
                    old_asset_location: 95,
                    old_asset_position: 0);
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

        public override string get_directory_name_reverse (string release_name) {
            switch (group.launcher.title) {
            case "Steam":
                if (release_name.contains ("Tkg")) {
                    return "";
                }
                return release_name.replace ("Proton-", "");

            case "Bottles":
                if (!release_name.contains ("ge-proton") || release_name.contains ("wine")) {
                    return "";
                }
                return release_name.replace ("ge-proton", "GE-Proton");

            case "Heroic Games Launcher":
                if (release_name.contains ("Tkg")) {
                    return "";
                }
                return release_name.replace ("Proton-", "");
            default:
                return release_name;
            }
        }
    }
}