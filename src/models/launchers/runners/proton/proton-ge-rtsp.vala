namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class ProtonGERtsp : Base {

        public ProtonGERtsp () {
            base (
                "Proton-GE RTSP",
                "Steam compatibility tool based on Proton-GE with additional patches to improve RTSP codecs for VRChat.",
                "https://api.github.com/repos/SpookySkeletons/proton-ge-rtsp/releases"
            );
        }
    }
}
