namespace ProtonPlus.Models.Launchers.Runners.VKD3D {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Proton : Base {
        public Proton () {
            base (
                SourceType.GITHUB,
                "VKD3D-Proton",
                "",
                "https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases"
            );

            add_variant ("default", "$release_name", true);
            add_directory_name_format ("default", "!$release_name:v:vkd3d-proton-");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
