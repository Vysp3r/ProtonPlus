namespace ProtonPlus.Runners {
    public class DXVK_doitsujin : GitHub {
        public DXVK_doitsujin (Models.Group group) {
            Object (group: group,
                    title: "DXVK Async (doitsujin)",
                    description: _(""),
                    endpoint: "https://api.github.com/repos/doitsujin/dxvk/releases",
                    asset_position: 0);
        }

        public override string get_directory_name (string release_name) {
            return release_name.replace ("v", "dxvk-");
        }

        public override string get_directory_name_reverse (string release_name) {
            if (release_name.contains ("async")) {
                return "";
            }
            return release_name.replace ("dxvk-", "v");
        }
    }
}