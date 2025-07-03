namespace ProtonPlus.Widgets {
	public class RunnerGroup : Adw.PreferencesGroup {
		List<Adw.PreferencesRow> rows;

		public Models.Group group;

		public RunnerGroup(Models.Group group, bool installed_only) {
			this.group = group;

			set_title(group.title);
			set_description(group.description);

			load(installed_only);
		}

		public void load(bool installed_only) {
			clear();

			if (installed_only)
				load_installed_only();
			else
				load_normal();
		}

		void load_normal() {
			foreach (var runner in group.runners) {
				var runner_row = new RunnerRow(runner);
				add(runner_row);
				rows.append(runner_row);
			}
		}

		void load_installed_only() {
			foreach (var directory in group.get_compatibility_tool_directories()) {
				var runner = new Models.Runners.Installed(group);
				var release = new Models.Releases.Basic.simple(runner, directory, group.launcher.directory + group.directory + "/" + directory);

				var row = new Widgets.ReleaseRows.InstalledRow(release);
				row.remove_from_parent.connect(row_remove_from_parent);

				add(row);
				
				rows.append(row);
			}
		}

		void clear() {
			if (rows == null)return;

			rows.foreach((row) => {
				if (row.parent != null)
					remove(row);

				rows.remove(row);
			});
		}

		void row_remove_from_parent(ReleaseRows.InstalledRow row) {
			remove(row);
		}
	}
}
