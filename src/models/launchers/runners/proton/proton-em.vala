namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class ProtonEM : Base {

        public ProtonEM () {
            base (
                SourceType.GITHUB,
                "Proton-EM",
                "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. By Etaash Mathamsetty adding FSR4 support and wine wayland tweaks.",
                "https://api.github.com/repos/Etaash-mathamsetty/Proton/releases"
            );

            support_latest = true;
            add_variant ("default", "$release_name", true);
            add_directory_name_format ("default", "$release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
