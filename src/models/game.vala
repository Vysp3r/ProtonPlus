namespace ProtonPlus.Models {
	public abstract class Game : Object {
		public string name { get; set; }
		public string installdir { get; set; }
		public string prefixdir { get; set; }
		public int prefix { get; set; }
		public string compatibility_tool { get; set; }
		public Launcher launcher { get; set; }

		internal Game(string name, string installdir, string prefixdir, int prefix, Launcher launcher) {
			this.name = name;
			this.installdir = installdir;
			this.prefixdir = prefixdir;
			this.prefix = prefix;
			this.launcher = launcher;
		}

		public abstract bool change_compatibility_tool(string compat_tool);
	}
}
