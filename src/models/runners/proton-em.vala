namespace ProtonPlus.Models.Runners {
    public class Proton_EM : GitHub {
        public Proton_EM (Group group) {
            Object (group: group,
                    title: "Proton-EM",
                    description: _("Steam compatibility tool for running Windows games with improvements over Valve's default Proton. By Etaash Mathamsetty adding FSR4 support and wine wayland tweaks."),
                    endpoint: "https://api.github.com/repos/Etaash-mathamsetty/Proton/releases",
                    asset_position: 1);
        }

        public override string get_directory_name (string release_name) {
            return release_name;
        }
    }
}
