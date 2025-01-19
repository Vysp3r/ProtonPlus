namespace ProtonPlus.Models.Runners {
    public class Wine_Staging_Tkg_Kron4ek : GitHub {
        public Wine_Staging_Tkg_Kron4ek (Group group) {
            var request_asset_exclude = new string[] { "proton", ".0." };
            Object (group: group,
                    title: "Wine-Staging-Tkg (Kron4ek)",
                    description: _("Wine build with the Staging patchset and many other useful patches."),
                    endpoint: "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    asset_position: 3,
                    request_asset_exclude: request_asset_exclude);
        }

        public override string get_directory_name (string release_name) {
            return @"wine-$release_name-staging-tkg-amd64";
        }
    }
}