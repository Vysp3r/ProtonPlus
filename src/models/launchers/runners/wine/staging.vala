namespace ProtonPlus.Models.Launchers.Runners.Wine {
    using Gee;
    using ProtonPlus.Providers.Sources;

    public class Staging : Base {
        public Staging () {
            base (
                SourceType.GITHUB,
                "wine-staging",
                "Wine-Staging (Kron4ek)",
                "Wine build with the Staging patchset.",
                "https://api.github.com/repos/Kron4ek/Wine-Builds/releases"
            );

            sort_priority = 2;
            request_asset_exclude = new Gee.ArrayList<string> ();
            request_asset_exclude.add ("proton");
            request_asset_exclude.add (".0.");
            add_variant ("x86-64", "default", "wine-$tag_name-staging-amd64", true);
            add_variant ("wow64", "wow64", "wine-$tag_name-staging-amd64-wow64", false);
            add_directory_name_format ("default", "wine-$release_name-staging-amd64");
            add_directory_name_format ("bottles", "kron4ek-wine-$release_name-staging-amd64");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new GitHub.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
