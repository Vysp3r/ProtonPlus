namespace ProtonPlus.Models.Runners {
    public class DXVK_Async_Sporif : GitHub {
        public DXVK_Async_Sporif (Models.Group group) {
            Object (group: group,
                    title: "DXVK Async (Sporif)",
                    description: _(""),
                    endpoint: "https://api.github.com/repos/Sporif/dxvk-async/releases",
                    asset_position: 0);
        }

        public override string get_directory_name (string release_name) {
            return @"dxvk-async-$release_name";
        }

        public override string get_directory_name_reverse (string release_name) {
            if (!release_name.contains ("async")) {
                return "";
            }
            return release_name.replace ("dxvk-async-", "");
        }
    }
}