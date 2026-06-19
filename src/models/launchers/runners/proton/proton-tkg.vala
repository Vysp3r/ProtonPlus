namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Request;

    public class ProtonTKG : Base {

        public ProtonTKG () {
            base (
                "Proton-Tkg",
                "Custom Proton build for running Windows games, based on Wine-tkg.",
                "https://api.github.com/repos/Frogging-Family/wine-tkg-git/actions/workflows/29873769/runs"
            );
        }
    }
}
