namespace ProtonPlus.Runners {
    public class DXVK_GPL_Async_Ph42oN : GitLab {
        public DXVK_GPL_Async_Ph42oN (Models.Group group) {
            Object (group: group,
                    title: "DXVK GPL+Async (Ph42oN)",
                    description: _(""),
                    endpoint: "https://gitlab.com/api/v4/projects/Ph42oN%2Fdxvk-gplasync/releases",
                    asset_position: 0);
        }

        public override string get_directory_name (string release_name) {
            return @"dxvk-gplasync-" + release_name;
        }

        public override string get_directory_name_reverse (string release_name) {
            return release_name.replace ("dxvk-gplasync-", "");
        }
    }
}