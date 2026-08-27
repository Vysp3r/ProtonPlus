namespace ProtonPlus.Models {
    /* A Steam-library compatibility tool or runtime (Proton, Steam Linux
     * Runtime) whose appmanifest claims a fully installed state with an
     * invalid buildid, while nothing usable is on disk. Diagnostic data only;
     * ProtonPlus never rewrites Steam's own install state to "fix" this. */
    public class SteamRuntimeRepairCandidate : Object {
        public uint appid { get; construct set; }
        public string internal_title { get; construct set; }
        public string display_title { get; construct set; }
        public string install_path { get; construct set; }

        public SteamRuntimeRepairCandidate (
            uint appid, string internal_title, string display_title, string install_path
        ) {
            Object (
                appid: appid,
                internal_title: internal_title,
                display_title: display_title,
                install_path: install_path
            );
        }
    }
}
