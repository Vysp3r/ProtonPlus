namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Providers.Sources;

    public class Roberta : Base {

        public Roberta () {
            base (
                SourceType.GITHUB,
                "roberta",
                "Roberta",
                "Steam compatibility tool for running adventure games using ScummVM for Linux.",
                "https://api.github.com/repos/dreamer/roberta/releases"
            );

            sort_priority = 10;
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
