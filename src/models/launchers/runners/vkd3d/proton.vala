namespace ProtonPlus.Models.Launchers.Runners.VKD3D {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Proton : Base {
        public Proton () {
            base (
                "VKD3D-Proton",
                "",
                "https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases"
            );
        }
    }
}
