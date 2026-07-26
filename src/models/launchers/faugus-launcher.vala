namespace ProtonPlus.Models.Launchers {
    public class FaugusLauncher : Launcher {
        public const string FAMILY_ID = "faugus";
        public const string FLATPAK_ID = "io.github.Faugus.faugus-launcher";

        public FaugusLauncher (
            Launcher.InstallationTypes installation_type,
            string? home_directory_override = null,
            string? host_data_home_override = null,
            string? config_home_override = null,
            string? data_home_override = null,
            string? state_home_override = null
        ) {
            var home_directory = home_directory_override ?? Environment.get_home_dir ();
            var config_home = config_home_override ?? Environment.get_user_config_dir ();
            var data_home = data_home_override ?? Environment.get_user_data_dir ();
            var state_home = state_home_override ?? Environment.get_variable ("XDG_STATE_HOME");
            if (state_home == null || state_home == "")
                state_home = Path.build_filename (home_directory, ".local", "state");
            var host_data_home = host_data_home_override ?? Environment.get_variable ("HOST_XDG_DATA_HOME");
            if (host_data_home == null || host_data_home == "")
                host_data_home = Path.build_filename (home_directory, ".local", "share");

            string[] detection_markers;
            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                // Faugus uses XDG config and data locations. Keep the HOME
                // fallbacks for installations using the standard XDG values.
                detection_markers = {
                    Path.build_filename (config_home, "faugus-launcher"),
                    Path.build_filename (data_home, "faugus-launcher"),
                    Path.build_filename ((!) state_home, "faugus-launcher"),
                    Path.build_filename (home_directory, ".config", "faugus-launcher"),
                    Path.build_filename (home_directory, ".local", "share", "faugus-launcher")
                };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                detection_markers = {
                    Path.build_filename (home_directory, ".var", "app", FLATPAK_ID, "config", "faugus-launcher"),
                    Path.build_filename (home_directory, ".var", "app", FLATPAK_ID, "data", "faugus-launcher"),
                    Path.build_filename (home_directory, ".var", "app", FLATPAK_ID, ".local", "state", "faugus-launcher")
                };
                break;
            default:
                detection_markers = {};
                break;
            }

            base (
                "Faugus Launcher",
                installation_type,
                "%s/faugus-launcher.svg".printf (Config.RESOURCE_BASE),
                {},
                FAMILY_ID,
                detection_markers,
                Path.build_filename ((!) host_data_home, "Steam"),
                Steam.FAMILY_ID,
                "steam-system"
            );
        }

        public override async bool ensure_group_directory (string group_directory) {
            return yield Utils.Filesystem.create_directory_async (directory + group_directory);
        }

        public override bool supports_provider_definition (Providers.ProviderDefinition definition) {
            switch (definition.provider_id) {
            case "proton-ge":
            case "proton-em":
            case "proton-cachyos":
            case "dw-proton":
                return true;
            default:
                return false;
            }
        }
    }
}
