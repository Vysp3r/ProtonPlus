namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Luxtorpeda : Base {

        public Luxtorpeda () {
            base (
                SourceType.FORGEJO,
                "Luxtorpeda",
                "Luxtorpeda provides Linux-native game engines for certain Windows-only games.",
                "https://codeberg.org/api/v1/repos/luxtorpeda/luxtorpeda/releases"
            );

            support_latest = true;
            add_variant ("default", "$title-$release_name", true);
            add_directory_name_format ("default", "$title $release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Forgejo.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
