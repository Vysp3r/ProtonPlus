namespace ProtonPlus.Models.Launchers.Runners.Wine {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class StagingTkg : Base {
        public StagingTkg () {
            base (
                SourceType.GITHUB,
                "Wine-Staging-Tkg (Kron4ek)",
                "Wine build with the Staging patchset and many other useful patches.",
                "https://api.github.com/repos/Kron4ek/Wine-Builds/releases"
            );

            asset_position = 6;
            request_asset_exclude = new Gee.ArrayList<string> ();
            request_asset_exclude.add ("proton");
            request_asset_exclude.add (".0.");
            add_variant ("default", "wine-$tag_name-staging-tkg-amd64", true);
            add_variant ("wow64", "wine-$tag_name-staging-tkg-amd64-wow64", false);
            add_directory_name_format ("default", "wine-$release_name-staging-tkg-amd64");
            add_directory_name_format ("Bottles", "kron4ek-wine-$release_name-staging-tkg-amd64");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
