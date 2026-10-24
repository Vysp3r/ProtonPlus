namespace ProtonPlus.Services {
    public class TinkerGameContext : Object {
        public string install_location { get; private set; }
        public TinkerGameContext (Models.Tool tool, string? location = null) {
            install_location = location ?? Path.build_filename (
                tool.group.launcher.get_primary_managed_tool_directory (tool.group), "TinkerGame");
        }
    }
}
