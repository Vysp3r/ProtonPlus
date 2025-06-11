namespace ProtonPlus.Models {
    public abstract class Game : Object {
        public string name { get; set; }
        public string installdir { get; set; }
        public string compatibility_tool { get; set; }
        public Launcher launcher { get; set; }

        internal Game(string name, string installdir, Launcher launcher) {
            this.name = name;
            this.installdir = installdir;
            this.launcher = launcher;
        }

        public abstract bool change_compatibility_tool(string compat_tool);
    }
}