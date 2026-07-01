namespace ProtonPlus.Models.Launchers.Runners.Wine {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Vanilla : Base {
        public Vanilla () {
            base (
                SourceType.GITHUB,
                "Wine-Vanilla (Kron4ek)",
                "Wine build compiled from the official WineHQ sources.",
                "https://api.github.com/repos/Kron4ek/Wine-Builds/releases"
            );

            request_asset_exclude = new Gee.ArrayList<string> ();
            request_asset_exclude.add ("proton");
            request_asset_exclude.add (".0.");
            add_variant ("default", "wine-$tag_name-amd64", true);
            add_variant ("wow64", "wine-$tag_name-amd64-wow64", false);
            add_directory_name_format ("default", "wine-$release_name-amd64");
            add_directory_name_format ("Bottles", "kron4ek-wine-$release_name-amd64");
        }

        public override async IReleases? request_releases (int page, int limit, out ReturnCode code) {
            var request = new Github.Request ();
            return yield request.request_endpoint (endpoint, page, limit, out code);
        }
    }
}
