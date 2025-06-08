namespace ProtonPlus.Models.Runners {
    public class Proton_Kron4ek : GitHub {
        public Proton_Kron4ek (Group group) {
            var request_asset_filter = new string[] { "proton" };
            Object (group: group,
                    title: "Proton (Kron4ek)",
                    description: _("Wine build modified by Valve and other contributors."),
                    endpoint: "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    asset_position: 0,
                    request_asset_filter: request_asset_filter);
        }

        public override string get_directory_name (string release_name) {
            return @"wine-$release_name-amd64";
        }
    }
}
