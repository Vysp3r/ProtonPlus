namespace ProtonPlus.Models.Runners {
    public class Proton_Sarek_Async : GitHub {
        public Proton_Sarek_Async (Group group) {
            Object (group: group,
                    title: "Proton-Sarek (Async)",
                    description:  _("Steam compatibility tool based on Proton-GE with modifications for very old GPUs, with %s.").printf ("DXVK-Async"),
                    endpoint: "https://api.github.com/repos/pythonlover02/Proton-Sarek/releases",
                    asset_position: 0,
                    request_asset_exclude: new string[] { "Sarek9-13" });
        }

        public override string get_directory_name (string release_name) {
            return title + "_Async";
        }
    }
}