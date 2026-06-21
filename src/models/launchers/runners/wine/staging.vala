namespace ProtonPlus.Models.Launchers.Runners.Wine {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Staging : Base {
        public Staging () {
            base (
                "Wine-Staging (Kron4ek)",
                "Wine build with the Staging patchset.",
                "https://api.github.com/repos/Kron4ek/Wine-Builds/releases"
            );
        }
    }
}
