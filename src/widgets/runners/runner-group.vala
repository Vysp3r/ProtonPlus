using Gee;

namespace ProtonPlus.Widgets {
	public class RunnerGroup : Adw.PreferencesGroup {
		private ArrayList<Adw.PreferencesRow> rows = new ArrayList<Adw.PreferencesRow>();
		private Models.Group group;

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

		private void load_normal() {
			foreach (var runner in group.runners) {
				var runner_row = new RunnerRow(runner);

				add(runner_row);
				
				rows.add(runner_row);
			}
		}

		private void load_installed_only() {
			foreach (var directory in group.get_compatibility_tool_directories()) {
				var runner = new Models.Runners.Installed(group);
				var release = new Models.Releases.Basic.simple(runner, directory, group.launcher.directory + group.directory + "/" + directory);

				var row = new Widgets.InstalledRow(release);
				row.remove_from_parent.connect(row_remove_from_parent);

				add(row);
				
				rows.add(row);
			}
		}

		private void clear() {
			foreach (var row in rows) {
				remove(row);
			}

			rows.clear();
		}

		private void row_remove_from_parent(InstalledRow row) {
			remove(row);
			rows.remove(row);
		}
	}
}
