namespace ProtonPlus.Models.Launchers.Runners.Proton {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class DW : Base {

        public DW () {
            base (
                "DW-Proto",
                "Dawn Winery's custom Proton fork with fixes for various games :xdd:",
                "https://dawn.wine/api/v1/repos/dawn-winery/dwproton/releases"
            );
        }
    }
}
