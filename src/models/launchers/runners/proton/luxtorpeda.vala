namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Providers.Sources;

    public class Luxtorpeda : Base {

        public Luxtorpeda () {
            base (
                SourceType.FORGEJO,
                "luxtorpeda",
                "Luxtorpeda",
                "Luxtorpeda provides Linux-native game engines for certain Windows-only games.",
                "https://codeberg.org/api/v1/repos/luxtorpeda/luxtorpeda/releases"
            );

            sort_priority = 8;
            add_variant ("standard", "default", "$title-$release_name", true);
            add_directory_name_format ("default", "$title $release_name");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Forgejo.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
