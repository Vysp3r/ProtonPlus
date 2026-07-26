namespace ProtonPlus.Models.Launchers.Runners.VKD3D {
    using Gee;
    using ProtonPlus.Providers.Sources;

    public class Lutris : Base {
        public Lutris () {
            base (
                SourceType.GITHUB,
                "vkd3d-lutris",
                "VKD3D-Lutris",
                "",
                "https://api.github.com/repos/lutris/vkd3d/releases"
            );

            sort_priority = 2;
            add_variant ("standard", "default", "$release_name", true);
            add_directory_name_format ("default", "$release_name");
            add_directory_name_format ("heroic", "!$release_name:v:vkd3d-lutris-");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new GitHub.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
