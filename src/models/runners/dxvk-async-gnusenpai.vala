namespace ProtonPlus.Models.Runners {
    public class DXVK_Async_gnusenpai : GitHub {
        public DXVK_Async_gnusenpai (Models.Group group) {
            Object (group: group,
                    title: "DXVK Async (gnusenpai)",
                    description: _("Contains RTX fix for Star Citizen."),
                    endpoint: "https://api.github.com/repos/gnusenpai/dxvk/releases",
                    asset_position: 0);
        }

        public override string get_directory_name (string release_name) {
            return @"dxvk-sc-async-" + release_name.replace ("v", "").replace ("-sc-async", "");
        }

        public override string get_directory_name_reverse (string release_name) {
            return "v" + release_name.replace ("dxvk-sc-async-", "") + "-sc-async";
        }
    }
}