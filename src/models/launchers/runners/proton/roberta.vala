namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Roberta : Base {

        public Roberta () {
            base (
                SourceType.GITHUB,
                "Roberta",
                "Steam compatibility tool for running adventure games using ScummVM for Linux.",
                "https://api.github.com/repos/dreamer/roberta/releases"
            );

            legacy = true;
            add_variant ("default", "$title", true);
            add_directory_name_format ("default", "$title $release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
