namespace ProtonPlus.Models {
	public class Group : Object {
		public string title { get; set; }
		public string description { get; set; }
		public string directory { get; set; }
		public Launcher launcher { get; set; }

		public List<Runner> runners;

		public Group(string title, string description, string directory, Launcher launcher) {
			this.title = title;
			this.description = description;
			this.directory = directory;
			this.launcher = launcher;

			if (!FileUtils.test(launcher.directory + directory, FileTest.IS_DIR)) {
				Utils.Filesystem.create_directory.begin(launcher.directory + directory, (obj, res) => {
					Utils.Filesystem.create_directory.end(res);
				});
			}
		}

		public List<string> get_compatibility_tool_directories() {
			var directories = new List<string> ();

			try {
				var directory_path = launcher.directory + directory;
				File directory = File.new_for_path(directory_path);
				FileEnumerator? enumerator = directory.enumerate_children("standard::*", FileQueryInfoFlags.NONE, null);

				if (enumerator != null) {
					FileInfo? file_info;
					while ((file_info = enumerator.next_file()) != null) {
						if (file_info.get_file_type() != FileType.DIRECTORY)
							continue;

						var title = file_info.get_name();

						if (title != "LegacyRuntime")
							directories.append(title);
					}
				}
			} catch (Error e) {
				warning (e.message);
			}

			return directories;
		}

		public void bob () {
			
		}
	}
}
