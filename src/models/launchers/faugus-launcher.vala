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

        /* Faugus writes the host native Steam compatibility-tool directory.
         * Its own package type must not produce a second Steam session target. */
        public override SteamRestartTarget? get_steam_restart_target () {
            return SteamRestartTarget.for_native (directory, "Steam", "steam.desktop");
        }

        public override string? get_install_target_error (string target_directory) {
            if (!Globals.IS_FLATPAK ||
                !FileUtils.test (target_directory, FileTest.IS_SYMLINK) ||
                FileUtils.test (target_directory, FileTest.IS_DIR))
                return null;

            var command = "flatpak override --user --filesystem=\"$HOME/.local/share/Steam/compatibilitytools.d\" %s".printf (
                Config.APP_ID
            );
            return "%s\n%s\n\n%s\n%s".printf (
                _ ("Faugus Launcher uses this folder for Proton installations, but ProtonPlus cannot access its symlink target:"),
                target_directory,
                _ ("Grant ProtonPlus access, restart it, and try the installation again:"),
                command
            );
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
