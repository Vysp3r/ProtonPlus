namespace ProtonPlus.Models.Launchers.Runners.DXVK {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Doitsujin : Base {
        public Doitsujin () {
            base (
                SourceType.GITHUB,
                "DXVK (doitsujin)",
                "",
                "https://api.github.com/repos/doitsujin/dxvk/releases"
            );

            support_latest = true;
            add_variant ("default", "$release_name", true);
            add_directory_name_format ("default", "!$release_name:v:dxvk-");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
