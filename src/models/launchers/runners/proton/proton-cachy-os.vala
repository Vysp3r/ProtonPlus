namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Request;

    public class CachyOS : Base {

        public CachyOS () {
            base (
                "Proton-CachyOS",
                "Steam compatibility tool from the CachyOS Linux distribution for running Windows games with improvements over Valve's default Proton.",
                "https://api.github.com/repos/CachyOS/proton-cachyos/releases"
            );
        }
    }
}
