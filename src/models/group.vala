namespace ProtonPlus.Models {
    public class Group : Object {
        public string title { get; set; }
        public string description { get; set; }
        public string directory { get; set; }
        public Launcher launcher { get; set; }

        public List<Runner> runners;

        public Group (string title, string directory, Launcher launcher) {
            this.title = title;
            this.directory = directory;
            this.launcher = launcher;

            if (!FileUtils.test (launcher.directory + directory, FileTest.IS_DIR)) {
                Utils.Filesystem.create_directory (launcher.directory + directory);
            }
        }
    }
}