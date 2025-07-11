namespace ProtonPlus.Widgets {
	public class RunnerRow : Adw.ExpanderRow {
		int count;

		Models.Runner runner;
		Gtk.Spinner spinner;
		LoadMoreRow load_more_row;

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
							var releases = runner.load.end (res);

							if (releases.length () + runner.releases.length () == count) {
								spinner.stop ();
								spinner.set_visible (false);
								return;
							}
							
							insert_loaded_releases (releases);
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
				}
				
				if (release is Models.Releases.SteamTinkerLaunch) {
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
			ScrollController scroll_ctrl = new ScrollController(get_ancestor(typeof(Gtk.ScrolledWindow)) as Gtk.ScrolledWindow);
			scroll_ctrl.save();

			remove (load_more_row);
			expanded_changed (true);

			scroll_ctrl.restore(10);
		}
	}
}
