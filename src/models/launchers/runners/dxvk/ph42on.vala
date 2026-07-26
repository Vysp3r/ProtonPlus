namespace ProtonPlus.Models.Launchers.Runners.DXVK {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Ph42on : Base {
        public Ph42on () {
            base (
                SourceType.GITLAB,
                "DXVK GPL+Async (Ph42oN)",
                "DXVK builds with gplasync patch by Ph42oN.",
                "https://gitlab.com/api/v4/projects/Ph42oN%2Fdxvk-gplasync/releases"
            );

            sort_priority = 2;

            // GitLab release links are not stable in order: v3.0-1 lists the
            // CI artifact ZIP before the distributable tarball.  Match the
            // published archive explicitly instead of falling back to the
            // first link.
            add_variant ("default", "dxvk-gplasync-$release_name.tar.gz", true);
            add_directory_name_format ("default", "dxvk-gplasync-$release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Gitlab.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
