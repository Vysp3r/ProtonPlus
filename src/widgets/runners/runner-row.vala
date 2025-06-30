namespace ProtonPlus.Widgets {
	public class RunnerRow : Adw.ExpanderRow {
		Models.Runner runner { get; set; }
		Gtk.Spinner spinner { get; set; }
		LoadMoreRow load_more_row { get; set; }

		int count { get; set; }

		public RunnerRow (Models.Runner runner) {
			this.runner = runner;

			count = 0;

			load_more_row = new LoadMoreRow ();
			load_more_row.activated.connect (load_more_row_activated);

			spinner = new Gtk.Spinner ();
			spinner.set_visible (false);

			notify["expanded"].connect (() => expanded_changed (false));

			set_title (runner.title);
			set_subtitle (runner.description);
			add_suffix (spinner);
		}

		void expanded_changed (bool force_load = false) {
			if (get_expanded ()) {
				var a = runner.releases.length () == 0 || force_load;
				var b = runner.releases.length () >= 0 && count == 0;
				if (a || b) {
					spinner.start ();
					spinner.set_visible (true);

					if (a) {
						runner.load.begin ((obj, res) => {
							insert_loaded_releases (runner.load.end (res));
						});
					} else if (b) {
						insert_loaded_releases (runner.releases);
					}
				}
			}
		}

		void insert_loaded_releases (List<Models.Release> releases) {
			foreach (var release in releases) {
				if (release is Models.Releases.Basic || release is Models.Releases.GitHubAction) {
					var row = new Widgets.ReleaseRows.BasicRow ((Models.Releases.Basic) release);
					add_row (row);
				} else if (release is Models.Releases.SteamTinkerLaunch) {
					var row = new Widgets.ReleaseRows.SteamTinkerLaunchRow ((Models.Releases.SteamTinkerLaunch) release);
					add_row (row);
				}

				count++;
			}

			if (runner.has_more)
				add_row (load_more_row);

			spinner.stop ();
			spinner.set_visible (false);
		}

		void load_more_row_activated () {
			remove (load_more_row);
			expanded_changed (true);
		}
	}
}
