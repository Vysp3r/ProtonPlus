namespace ProtonPlus.Models.Runners {
    public class Proton_GE_RSTP : GitHub {
        public Proton_GE_RSTP (Group group) {
            Object (group: group,
                    title: "Proton-GE RTSP",
                    description: _("Steam compatibility tool based on Proton-GE with additional patches to improve RTSP codecs for VRChat."),
                    endpoint: "https://api.github.com/repos/SpookySkeletons/proton-ge-rtsp/releases",
                    asset_position: 0);
        }

        public override string get_directory_name (string release_name) {
            return @"$title $release_name";
        }
    }
}