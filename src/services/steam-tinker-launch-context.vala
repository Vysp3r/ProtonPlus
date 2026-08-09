namespace ProtonPlus.Services {
    /// Target-specific state for the SteamTinkerLaunch workflow.  Keeping this
    /// together prevents generic jobs from accumulating nullable STL fields.
    public class SteamTinkerLaunchContext : Object {
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

        internal SteamTinkerLaunchContext (Models.Tool tool, string? home_override = null) {
            home_location = home_override ?? Environment.get_home_dir ();
            compat_location = tool.group.launcher.get_primary_managed_tool_directory (tool.group);
            if (Globals.IS_STEAM_OS) {
                base_location = "%s/stl/prefix".printf (home_location);
                manual_remove_location = "%s/stl".printf (home_location);
            } else {
                base_location = "%s/.local/share/steamtinkerlaunch".printf (home_location);
                manual_remove_location = base_location;
            }
            binary_location = "%s/steamtinkerlaunch".printf (base_location);
            meta_location = "%s/ProtonPlus.meta".printf (base_location);
            link_parent_location = "%s/.local/bin".printf (home_location);
            link_location = "%s/steamtinkerlaunch".printf (link_parent_location);
            config_location = "%s/.config/steamtinkerlaunch".printf (home_location);
            external_locations = new List<string> ();
        }
    }
}
