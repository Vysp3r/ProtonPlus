namespace ProtonPlus.Models.Launchers.Runners.Wine {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Proton : Base {
        public Proton () {
            base (
                "Wine-Proton (Kron4ek)",
                "Wine build modified by Valve and other contributors.",
                "https://api.github.com/repos/Kron4ek/Wine-Builds/releases"
            );
        }
    }
}
