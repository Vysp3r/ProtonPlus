namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Request;

    public class ProtonEM : Base {

        public ProtonEM () {
            base (
                "Proton-EM",
                "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. By Etaash Mathamsetty adding FSR4 support and wine wayland tweaks.",
                "https://api.github.com/repos/Etaash-mathamsetty/Proton/releases"
            );
        }
    }
}
