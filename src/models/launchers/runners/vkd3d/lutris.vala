namespace ProtonPlus.Models.Launchers.Runners.VKD3D {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Lutris : Base {
        public Lutris () {
            base (
                "VKD3D-Lutris",
                "",
                "https://api.github.com/repos/lutris/vkd3d/releases"
            );
        }
    }
}
