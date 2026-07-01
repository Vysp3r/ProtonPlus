namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class ProtonTKG : Base {

        public ProtonTKG () {
            base (
                SourceType.GITHUB_ACTION,
                "Proton-Tkg",
                "Custom Proton build for running Windows games, based on Wine-tkg.",
                "https://api.github.com/repos/Frogging-Family/wine-tkg-git/actions/workflows/29873769/runs"
            );

            url_template = "https://nightly.link/Frogging-Family/wine-tkg-git/actions/runs/{id}/proton-tkg-build.zip";
            add_variant ("default", "$title-$release_name", true);
            add_directory_name_format ("default", "$title-$release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new GithubAction.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
