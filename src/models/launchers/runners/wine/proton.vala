namespace ProtonPlus.Models.Launchers.Runners.Wine {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Proton : Base {
        public Proton () {
            base (
                SourceType.GITHUB,
                "Wine-Proton (Kron4ek)",
                "Wine build modified by Valve and other contributors.",
                "https://api.github.com/repos/Kron4ek/Wine-Builds/releases"
            );

            support_latest = true;
            request_asset_filter = new Gee.ArrayList<string> ();
            request_asset_filter.add ("proton");
            add_variant ("default", "wine-$tag_name-amd64", true);
            add_variant ("wow64", "wine-$tag_name-amd64-wow64", false);
            add_variant ("x86", "wine-$tag_name-x86", false);
            add_directory_name_format ("default", "wine-$release_name-amd64");
            add_directory_name_format ("Bottles", "kron4ek-wine-$release_name-amd64");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
