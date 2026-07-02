namespace ProtonPlus.Models.Launchers.Runners.VKD3D {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Lutris : Base {
        public Lutris () {
            base (
                SourceType.GITHUB,
                "VKD3D-Lutris",
                "",
                "https://api.github.com/repos/lutris/vkd3d/releases"
            );

            support_latest = true;
            add_variant ("default", "$release_name", true);
            add_directory_name_format ("default", "$release_name");
            add_directory_name_format ("Heroic Games Launcher", "!$release_name:v:vkd3d-lutris-");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
