namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class ProtonGE : Base {

        public ProtonGE () {
            base (
                SourceType.GITHUB,
                "Proton-GE",
                "Steam compatibility tool for running Windows games with improvements over Valve's default Proton.",
                "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases"
            );

            asset_position = 1;
            support_latest = true;
            tag = "Recommended";
            add_variant ("x86", "$release_name", true);
            add_variant ("aarch64", "$release_name-aarch64", false);
            add_directory_name_format ("default", "$release_name");
            add_directory_name_format ("Steam", "&$release_name:.:Proton-$release_name:$release_name");
            add_directory_name_format ("Bottles", "_$release_name");
            add_directory_name_format ("Heroic Games Launcher", "Proton-$release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
