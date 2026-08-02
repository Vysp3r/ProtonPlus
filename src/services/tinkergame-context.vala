namespace ProtonPlus.Services {
    /// Target-specific state for the TinkerGame workflow.  Keeping this
    /// together prevents generic jobs from accumulating nullable TinkerGame fields.
    public class TinkerGameContext : Object {
        internal string home_location { get; private set; }
        internal string base_location { get; private set; }
        internal string binary_location { get; private set; }
        internal string meta_location { get; private set; }
        internal string link_parent_location { get; private set; }
        internal string link_location { get; private set; }
        internal string config_location { get; private set; }
        internal string manual_remove_location { get; private set; }
        internal string compat_location { get; private set; }
        internal string latest_date { get; set; default = ""; }
        internal string latest_hash { get; set; default = ""; }
        internal string local_date { get; set; default = ""; }
        internal string local_hash { get; set; default = ""; }
        internal List<string> external_locations;
        public bool remove_config { get; set; default = false; }
        public bool user_requested_removal { get; set; default = false; }

        internal TinkerGameContext (Models.Tool tool, string? home_override = null) {
            home_location = home_override ?? Environment.get_home_dir ();
            compat_location = tool.group.launcher.directory + tool.group.directory;
            if (Globals.IS_STEAM_OS) {
                base_location = "%s/tinkergame/prefix".printf (home_location);
                manual_remove_location = "%s/tinkergame".printf (home_location);
            } else {
                base_location = "%s/.local/share/tinkergame".printf (home_location);
                manual_remove_location = base_location;
            }
            binary_location = "%s/tinkergame".printf (base_location);
            meta_location = "%s/ProtonPlus.meta".printf (base_location);
            link_parent_location = "%s/.local/bin".printf (home_location);
            link_location = "%s/tinkergame".printf (link_parent_location);
            config_location = "%s/.config/tinkergame".printf (home_location);
            external_locations = new List<string> ();
        }
    }
}
