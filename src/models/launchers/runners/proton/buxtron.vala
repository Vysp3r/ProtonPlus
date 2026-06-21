namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Buxtron : Base {
        public Buxtron () {
            base (
                "Boxtron",
                "Steam compatibility tool for running DOS games using DOSBox for Linux.",
                "https://api.github.com/repos/dreamer/boxtron/releases"
            );
        }
    }
}
