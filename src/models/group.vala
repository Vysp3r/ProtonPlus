namespace ProtonPlus.Shared.Models {
    public class Group {
        public string title;
        public string description;
        public string directory;
        public Models.Launcher launcher;

        public List<Models.Runner> runners;

        public Group (string title, string directory, Models.Launcher launcher) {
            this.title = title;
            this.directory = directory;
            this.launcher = launcher;

            if (!FileUtils.test (launcher.directory + directory, FileTest.IS_DIR)) {
                Utils.Filesystem.CreateDirectory (launcher.directory + directory);
            }
        }
    }
}