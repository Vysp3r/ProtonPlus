namespace ProtonPlus.Models.Launchers.Runners.Wine {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Vanilla : Base {
        public Vanilla () {
            base (
                "Wine-Vanilla (Kron4ek)",
                "Wine build compiled from the official WineHQ sources.",
                "https://api.github.com/repos/Kron4ek/Wine-Builds/releases"
            );
        }
    }
}
