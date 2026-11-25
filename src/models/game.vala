namespace ProtonPlus.Models {
    public abstract class Game : Object {
        public string name { get; set; }
        public string installdir { get; set; }
        public string prefixdir { get; set; }
        public uint prefix { get; set; }
        public string compatibility_tool { get; set; }
        public Launcher launcher { get; set; }
        public virtual bool is_native { get; set; default = false; }
        public virtual string? library_context { get { return null; } }

        public virtual bool has_game_directory { get { return FileUtils.test (installdir, FileTest.IS_DIR); } }
        public virtual bool has_prefix_directory { get { return FileUtils.test (prefixdir, FileTest.IS_DIR); } }
        public virtual bool can_launch { get { return false; } }
        public virtual bool can_edit_compatibility_tool { get { return true; } }
        public virtual string? compatibility_edit_error { get { return null; } }

        public virtual string? get_game_tool_title () {
            return null;
        }

        public virtual async Gee.List<CompatibilityTool>? load_game_tool_choices () {
            return null;
        }

        public virtual async Subprocess? launch_external () throws Error {
            return null;
        }

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
