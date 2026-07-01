namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class DW : Base {

        public DW () {
            base (
                SourceType.FORGEJO,
                "DW-Proton",
                "Dawn Winery's custom Proton fork with fixes for various games :xdd:",
                "https://dawn.wine/api/v1/repos/dawn-winery/dwproton/releases"
            );

            asset_position = 1;
            support_latest = true;
            add_variant ("x86_64", "$release_name-x86_64", true);
            add_directory_name_format ("default", "$release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Forgejo.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
