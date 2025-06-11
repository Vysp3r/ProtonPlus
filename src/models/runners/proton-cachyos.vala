namespace ProtonPlus.Models.Runners {
    public class Proton_CachyOS : GitHub {
        public Proton_CachyOS (Group group) {
            int position = 1;
            foreach (var item in Globals.HWCAPS) {
                if (item == "x86_64_v3") {
                    position = 3;
                    break;
                }
            }

            Object (group: group,
                    title: "Proton-CachyOS",
                    description: _("Steam compatibility tool from the CachyOS Linux distribution for running Windows games with improvements over Valve's default Proton."),
                    endpoint: "https://api.github.com/repos/CachyOS/proton-cachyos/releases",
                    asset_position: position);
        }

        public override string get_directory_name (string release_name) {
            return @"$title $release_name";
        }
    }
}