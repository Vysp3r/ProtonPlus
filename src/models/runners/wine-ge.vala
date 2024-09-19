namespace ProtonPlus.Models.Runners {
    public class Wine_GE : GitHub {
        public Wine_GE (Group group) {
            Object (group: group,
                    title: "Wine-GE",
                    description: _("Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris."),
                    endpoint: "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases",
                    asset_position: 1,
                    old_asset_location: 83,
                    old_asset_position: 0);
        }

        public override string get_directory_name (string release_name) {
            switch (group.launcher.title) {
            case "Lutris":
                if (release_name.contains ("LOL")) {
                    return @"lutris-$release_name-x86_64".down ();
                }
                if (release_name.contains ("LoL")) {
                    var parts = release_name.split ("-");
                    return "lutris-ge-lol-" + parts[0] + "-" + parts[2] + "-x86_64";
                }
                return @"lutris-$release_name-x86_64";
            case "Bottles":
                return "wine-" + release_name.down ();
            case "Heroic Games Launcher":
                return @"Wine-$release_name";
            default:
                return release_name;
            }
        }

        public override string get_directory_name_reverse (string release_name) {
            switch (group.launcher.title) {
            case "Lutris":
                if (!release_name.contains ("GE-Proton") && !release_name.contains ("lol")) {
                    return "";
                }
                if (release_name.contains ("lol") && release_name.contains ("p")) {
                    return release_name.replace ("lutris-ge-lol-", "GE-LOL-").replace ("-x86_64", "");
                }
                if (release_name.contains ("lol")) {
                    return release_name.replace ("lutris-ge-lol-", "").replace ("-x86_64", "").replace ("-", "-GE-") + "-LoL";
                }
                return release_name.replace ("lutris-", "").replace ("-x86_64", "");

            case "Bottles":
                return release_name.replace ("wine-ge-proton", "GE-Proton");

            case "Heroic Games Launcher":
                return release_name.replace ("Wine-", "");
            default:
                return release_name;
            }
        }
    }
}