namespace ProtonPlus.Models.Runners {
    public class Proton_Kron4ek : GitHub {
        public Proton_Kron4ek (Group group) {
            var request_asset_exclude = new string[] { "wine" };
            Object (group: group,
                    title: "Proton (Kron4ek)",
                    description: _("Wine build modified by Valve and other contributors."),
                    endpoint: "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    asset_position: 0,
                    request_asset_exclude: request_asset_exclude);
        }

        public override string get_directory_name (string release_name) {
        	return @"wine-proton-$release_name-amd64";
        }
    }
}
