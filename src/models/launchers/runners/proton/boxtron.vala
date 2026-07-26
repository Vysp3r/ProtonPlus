namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Providers.Sources;

    public class Boxtron : Base {
        public Boxtron () {
            base (
                SourceType.GITHUB,
                "boxtron",
                "Boxtron",
                "Steam compatibility tool for running DOS games using DOSBox for Linux.",
                "https://api.github.com/repos/dreamer/boxtron/releases"
            );

            sort_priority = 9;
            legacy = true;
            add_variant ("standard", "default", "$title", true);
            add_directory_name_format ("default", "$title $release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new GitHub.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
