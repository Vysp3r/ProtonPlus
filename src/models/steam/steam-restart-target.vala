namespace ProtonPlus.Models {
    /* Physical Steam locations are intentionally independent from launcher
     * selection IDs and compatibility-tool storage target IDs. */
    public enum SteamInstallationKind {
        NATIVE,
        FLATPAK,
        SNAP,
        CUSTOM,
        UNKNOWN
    }

    public class SteamRestartTarget : Object {
        public string id { get; private set; }
        public string display_name { get; private set; }
        public string data_root { get; private set; }
        public SteamInstallationKind installation_kind { get; private set; }
        public string? flatpak_application_id { get; private set; }
        public string? executable_hint { get; private set; }
        public string? desktop_entry_id { get; private set; }
        public bool storage_only { get; private set; }

        public SteamRestartTarget (
            string data_root,
            SteamInstallationKind installation_kind,
            string display_name = "Steam",
            string? flatpak_application_id = null,
            string? executable_hint = null,
            string? desktop_entry_id = null,
            bool storage_only = false
        ) {
            this.data_root = normalize_data_root (data_root);
            this.installation_kind = installation_kind;
            this.display_name = display_name;
            this.flatpak_application_id = flatpak_application_id;
            this.executable_hint = executable_hint;
            this.desktop_entry_id = desktop_entry_id;
            this.storage_only = storage_only;
            this.id = build_id ();
        }

        public static SteamRestartTarget for_native (
            string data_root, string display_name = "Steam", string? desktop_entry_id = "steam.desktop"
        ) {
            return new SteamRestartTarget (data_root, SteamInstallationKind.NATIVE, display_name,
                                           null, "/usr/bin/steam", desktop_entry_id);
        }

        public static SteamRestartTarget for_flatpak (string data_root) {
            return new SteamRestartTarget (data_root, SteamInstallationKind.FLATPAK, "Steam (Flatpak)",
                                           "com.valvesoftware.Steam", null,
                                           "com.valvesoftware.Steam.desktop");
        }

        public static SteamRestartTarget for_snap (string data_root) {
            return new SteamRestartTarget (data_root, SteamInstallationKind.SNAP, "Steam (Snap)",
                                           null, "/snap/bin/steam", "steam.desktop");
        }

        public static string normalize_data_root (string value) {
            var canonical = Filename.canonicalize (value, null);
            var resolved = Posix.realpath (canonical);
            return resolved ?? canonical;
        }

        private string build_id () {
            var kind = "unknown";
            switch (installation_kind) {
            case SteamInstallationKind.NATIVE: kind = "native"; break;
            case SteamInstallationKind.FLATPAK: kind = "flatpak"; break;
            case SteamInstallationKind.SNAP: kind = "snap"; break;
            case SteamInstallationKind.CUSTOM: kind = "custom"; break;
            default: break;
            }
            var app = flatpak_application_id ?? "";
            return "steam:%s:%s:%s".printf (kind, app, data_root);
        }
    }
}
