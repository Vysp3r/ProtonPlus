namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class ProtonGERtsp : Base {

        public ProtonGERtsp () {
            base (
                SourceType.GITHUB,
                "Proton-GE RTSP",
                "Steam compatibility tool based on Proton-GE with additional patches to improve RTSP codecs for VRChat.",
                "https://api.github.com/repos/SpookySkeletons/proton-ge-rtsp/releases"
            );

            support_latest = true;
            add_variant ("default", "$tag_name", true);
            add_directory_name_format ("default", "$release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
