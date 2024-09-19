namespace ProtonPlus.Models.Runners {
    public class Wine_Vanilla_Kron4ek : GitHub {
        public Wine_Vanilla_Kron4ek (Models.Group group) {
            var request_asset_exclude = new string[] { "proton", ".0." };
            Object (group: group,
                    title: "Wine-Vanilla (Kron4ek)",
                    description: _("Wine build compiled from the official WineHQ sources."),
                    endpoint: "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    asset_position: 1,
                    request_asset_exclude: request_asset_exclude);
        }

        public override string get_directory_name (string release_name) {
            return @"wine-$release_name-amd64";
        }

        public override string get_directory_name_reverse (string release_name) {
            if (release_name.contains ("staging")) {
                return "";
            }
            return release_name.replace ("wine-", "").replace ("-amd64", "");
        }
    }
}