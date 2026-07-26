namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Providers.Sources;

    public class ProtonGE : Base {

        public ProtonGE () {
            base (
                SourceType.GITHUB,
                "proton-ge",
                "Proton-GE",
                "Steam compatibility tool for running Windows games with improvements over Valve's default Proton.",
                "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases"
            );

            sort_priority = 2;
            add_variant ("x86", "x86", "$release_name", true);
            add_variant ("aarch64", "aarch64", "$release_name-aarch64", false);
            add_directory_name_format ("default", "$release_name");
            add_directory_name_format ("steam", "&$release_name:.:Proton-$release_name:$release_name");
            add_directory_name_format ("bottles", "_$release_name");
            add_directory_name_format ("heroic", "Proton-$release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new GitHub.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
