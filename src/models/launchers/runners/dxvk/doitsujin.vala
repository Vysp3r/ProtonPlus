namespace ProtonPlus.Models.Launchers.Runners.DXVK {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Doitsujin : Base {
        public Doitsujin () {
            base (
                "Doitsujin",
                "",
                "https://api.github.com/repos/doitsujin/dxvk/releases"
            );
        }
    }
}
