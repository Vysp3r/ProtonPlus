namespace ProtonPlus.Models.Runners {
    public class Proton_Tkg : GitHubAction {
        public Proton_Tkg (Group group) {
            Object (group: group,
                    title: "Proton-Tkg",
                    description: _("Custom Proton build for running Windows games, based on Wine-tkg."),
                    endpoint: "https://api.github.com/repos/Frogging-Family/wine-tkg-git/actions/workflows/29873769/runs",
                    asset_position: 0,
                    url_template: "https://nightly.link/Frogging-Family/wine-tkg-git/actions/runs/{id}/proton-tkg-build.zip");
        }

        public override string get_directory_name (string release_name) {
            return @"$title-$release_name";
        }
    }
}