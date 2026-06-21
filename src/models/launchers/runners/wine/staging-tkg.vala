namespace ProtonPlus.Models.Launchers.Runners.Wine {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class StagingTkg : Base {
        public StagingTkg () {
            base (
                "Wine-Staging-Tkg (Kron4ek)",
                "Wine build with the Staging patchset and many other useful patches.",
                "https://api.github.com/repos/Kron4ek/Wine-Builds/releases"
            );
        }
    }
}
