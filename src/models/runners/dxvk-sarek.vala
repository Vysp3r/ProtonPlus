namespace ProtonPlus.Models.Runners {
    public class DXVK_Sarek : GitHub {
        public DXVK_Sarek (Group group) {
            Object (group: group,
                    title: "DXVK-Sarek",
                    description:  _("DXVK Builds that work with pre-Vulkan 1.3 versions"),
                    endpoint: "https://api.github.com/repos/pythonlover02/DXVK-Sarek/releases",
                    asset_position: 1);
        }

        public override string get_directory_name (string release_name) {
            return release_name;
        }
    }
}