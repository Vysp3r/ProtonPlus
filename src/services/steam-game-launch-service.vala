namespace ProtonPlus.Services {
    using ProtonPlus.Models;

    public class SteamGameLaunchService : Object {
        private SteamRestartProcessFactory process_factory;

        public SteamGameLaunchService (SteamRestartProcessFactory? process_factory = null) {
            this.process_factory = process_factory ?? new HostSteamRestartProcessFactory ();
        }

        /* Dispatch to the selected installation, independently of the user's
         * default URI handler. Do not wait for the Steam client to exit. */
        public void launch (SteamRestartTarget target, uint appid, bool is_non_steam, bool through_flatpak_host) throws Error {
            var argv = new Gee.ArrayList<string> ();
            if (through_flatpak_host) {
                argv.add ("flatpak-spawn");
                argv.add ("--host");
            }
            switch (target.installation_kind) {
            case SteamInstallationKind.NATIVE:
                argv.add ("/usr/bin/steam");
                break;
            case SteamInstallationKind.FLATPAK:
                argv.add ("flatpak");
                argv.add ("run");
                argv.add ("com.valvesoftware.Steam");
                break;
            case SteamInstallationKind.SNAP:
                argv.add ("snap");
                argv.add ("run");
                argv.add ("steam");
                break;
            default:
                throw new IOError.NOT_SUPPORTED ("No launch command for this Steam installation.");
            }
            if (is_non_steam) {
                // Keep the persisted shortcut AppID unchanged; only the launch
                // URI uses Steam's 64-bit shortcut GameID (type 2).
                uint64 game_id = ((uint64) appid << 32) | 0x02000000;
                argv.add ("steam://rungameid/" + game_id.to_string ());
            } else {
                argv.add ("steam://run/%u".printf (appid));
            }
            process_factory.spawn_detached (argv.to_array ());
        }
    }
}
