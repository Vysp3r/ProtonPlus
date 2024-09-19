namespace ProtonPlus.Models.Runners {
    public class VKD3D_Proton : GitHub {
        public VKD3D_Proton (Models.Group group) {
            Object (group: group,
                    title: "VKD3D-Proton",
                    description: _(""),
                    endpoint: "https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases",
                    asset_position: 0);
        }

        public override string get_directory_name (string release_name) {
            return release_name.replace ("v", "vkd3d-proton-");
        }

        public override string get_directory_name_reverse (string release_name) {
            return release_name.replace ("vkd3d-proton-", "");
        }
    }
}