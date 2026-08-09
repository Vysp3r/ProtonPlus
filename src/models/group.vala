namespace ProtonPlus.Models {
    public class Group : Object {
        public string id { get; private set; }
        public string title { get; set; }
        public string description { get; set; }
        public string directory { get; set; }
        public Launcher launcher { get; set; }
        public Gee.LinkedList<Tool> tools { get; set; }
        public InstalledToolInventory installed_tool_inventory { get; private set; }

        // Kept as the narrow observable boundary used by existing callers.
        // The inventory owns the state that is invalidated and refreshed.
        public signal void installed_tool_index_invalidated ();
        public signal void installed_state_refreshed ();

        public Group (string title, string description, string directory, Launcher launcher, string id = "unknown") {
            this.id = id;
            this.title = title;
            this.description = description;
            this.directory = directory;
            this.launcher = launcher;
            installed_tool_inventory = new InstalledToolInventory (this);

            if (!FileUtils.test (launcher.directory + directory, FileTest.IS_DIR)) {
                Utils.Filesystem.create_directory_async.begin (launcher.directory + directory, null);
            }
        }

        public void refresh_installed_state () {
            installed_tool_inventory.refresh ();
            installed_state_refreshed ();
        }

        public void invalidate_installed_state () {
            installed_tool_inventory.invalidate ();
            installed_tool_index_invalidated ();
        }

        public Gee.List<InstalledToolEntry> get_installed_tool_snapshot () {
            return installed_tool_inventory.get_snapshot ();
        }
    }
}
