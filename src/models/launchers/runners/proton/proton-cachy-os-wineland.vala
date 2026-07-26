namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class CachyOSWineland : Base {

        public CachyOSWineland () {
            base (
                SourceType.GITHUB,
                "proton-cachyos-wineland",
                "Proton-CachyOS Wineland",
                "Steam compatibility tool based on CachyOS Proton with Wayland improvements, especially for Windows launcher applications.",
                "https://api.github.com/repos/nanomatters/proton-cachyos/releases"
            );

            sort_priority = 7;
            add_variant ("x86_64", "proton-$tag_name-x86_64", true);
            add_variant ("x86_64_v3", "proton-$tag_name-x86_64_v3", false);
            add_variant ("x86_64_wow64", "proton-$tag_name-x86_64_wow64", false);
            add_directory_name_format ("default", "$release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
