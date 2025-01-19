namespace ProtonPlus.Models.Runners {
    public class Wine_Staging_Kron4ek : GitHub {
        public Wine_Staging_Kron4ek (Group group) {
            var request_asset_exclude = new string[] { "proton", ".0." };
            Object (group: group,
                    title: "Wine-Staging (Kron4ek)",
                    description: _("Wine build with the Staging patchset."),
                    endpoint: "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    asset_position: 2,
                    request_asset_exclude: request_asset_exclude);
            // https://api.github.com/repos/Kron4ek/Wine-Builds/releases
            // 2
            // Models.Runner.title_types.KRON4EK_STAGING
            // kron4ek_staging.request_asset_exclude = { "proton", ".0." };
        }

        public override string get_directory_name (string release_name) {
            return @"wine-$release_name-staging-amd64";
        }
    }
}