namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class ProtonGE : Base {

        public ProtonGE () {
            base (
                "Proton GE",
                "Steam compatibility tool for running Windows games with improvements over Valve's default Proton.",
                "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases"
            );
        }
    }
}
