namespace ProtonPlus.Models {
    public abstract class Game : Object {
        public string name { get; set; }
        public string installdir { get; set; }
        public string prefixdir { get; set; }
        public uint prefix { get; set; }
        public string compatibility_tool { get; set; }
        public Launcher launcher { get; set; }
        public virtual bool is_native { get; set; default = false; }

        internal Game (string name, string installdir, string prefixdir, uint prefix, Launcher launcher) {
            this.name = name;
            this.installdir = installdir;
            this.prefixdir = prefixdir;
            this.prefix = prefix;
            this.launcher = launcher;
        }

        public abstract bool change_compatibility_tool (string compat_tool);

        public virtual async bool change_compatibility_tool_async (string compat_tool, Cancellable? cancellable = null) {
            return change_compatibility_tool (compat_tool);
        }
    }
}
