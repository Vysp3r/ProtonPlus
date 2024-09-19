namespace ProtonPlus.Models.Runners {
    public class Wine_Lutris : GitHub {
        public Wine_Lutris (Models.Group group) {
            var request_asset_exclude = new string[] { "ge-lol" };
            Object (group: group,
                    title: "Wine-Lutris",
                    description: _("Improved by Lutris to offer better compatibility or performance in certain games."),
                    endpoint: "https://api.github.com/repos/lutris/wine/releases",
                    asset_position: 0,
                    request_asset_exclude: request_asset_exclude);
        }

        public override string get_directory_name (string release_name) {
            switch (group.launcher.title) {
            case "Lutris":
                return release_name.replace ("-wine", "") + "-x86_64";

            case "Bottles":
                if (release_name.contains ("LoL")) {
                    var parts = release_name.split ("-");
                    return "lutris-ge-lol-" + parts[0] + "-" + parts[2];
                }
                if (release_name.contains ("LOL")) {
                    return "lutris-" + release_name.down ();
                }
                return release_name.down ().replace ("-wine", "");
            default:
                return release_name;
            }
        }

        public override string get_directory_name_reverse (string release_name) {
            switch (group.launcher.title) {
            case "Lutris":
                if (release_name.contains ("Proton") || release_name.contains ("ge-lol")) {
                    return "";
                }
                return release_name.replace ("lutris", "lutris-wine").replace ("-x86_64", "");

            case "Bottles":
                if (!release_name.contains ("lutris-ge-lol-p")) {
                    return release_name.replace ("lutris-ge-lol-", "").replace ("-", "-GE-") + "-LoL";
                }
                return release_name.replace ("lutris-ge-lol-p", "GE-LOL-p");
            default:
                return release_name;
            }
        }
    }
}