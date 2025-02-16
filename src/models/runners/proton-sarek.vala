namespace ProtonPlus.Models.Runners {
    public class Proton_Sarek : GitHub {
        public Proton_Sarek (Group group) {
            Object (group: group,
                    title: "Proton-Sarek",
                    description:  _("Steam compatibility tool based on Proton-GE with modifications for very old GPUs, with %s.").printf ("DXVK"),
                    endpoint: "https://api.github.com/repos/pythonlover02/Proton-Sarek/releases",
                    asset_position: 1,
                    request_asset_exclude: new string[] { "Sarek9-13" });
        }

        public override string get_directory_name (string release_name) {
            return release_name;
        }
    }
}