namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Roberta : Base {

        public Roberta () {
            base (
                "Roberta",
                "Steam compatibility tool for running adventure games using ScummVM for Linux.",
                "https://api.github.com/repos/dreamer/roberta/releases"
            );
        }
    }
}
