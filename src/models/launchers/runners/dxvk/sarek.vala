namespace ProtonPlus.Models.Launchers.Runners.DXVK {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Sarek : Base {
        public Sarek () {
            base (
                "Sarek",
                "DXVK builds that work with pre-Vulkan 1.3 versions.",
                "https://api.github.com/repos/pythonlover02/DXVK-Sarek/releases"
            );
        }
    }
}
