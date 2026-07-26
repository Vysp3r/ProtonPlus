namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class CachyOS : Base {

        public CachyOS () {
            base (
                SourceType.GITHUB,
                "proton-cachyos",
                "Proton-CachyOS",
                "Steam compatibility tool from the CachyOS Linux distribution for running Windows games with improvements over Valve's default Proton.",
                "https://api.github.com/repos/CachyOS/proton-cachyos/releases"
            );

            sort_priority = 1;
            tag = "Recommended";
            add_variant ("x86-64", "x86_64", "proton-$tag_name-x86_64", true);
            add_variant ("x86-64-v3", "x86_64_v3", "proton-$tag_name-x86_64_v3", false);
            add_variant ("arm64", "arm64", "proton-$tag_name-arm64", false);
            add_directory_name_format ("default", "$release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
