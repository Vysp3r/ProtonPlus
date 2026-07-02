namespace ProtonPlus.Models.Launchers.Runners.DXVK {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Sarek : Base {
        public Sarek () {
            base (
                SourceType.GITHUB,
                "DXVK (Sarek)",
                "DXVK builds that work with pre-Vulkan 1.3 versions.",
                "https://api.github.com/repos/pythonlover02/DXVK-Sarek/releases"
            );

            support_latest = true;
            add_variant ("default", "$release_name", true);
            add_directory_name_format ("default", "sarek-$release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
