namespace ProtonPlus.Widgets {
	public class RunnerRow : Adw.ExpanderRow {
		int count;

		public List<ReleaseRow> rows;

		Models.Runner runner;
		Gtk.Spinner spinner;
		LoadMoreRow load_more_row;

		public RunnerRow (Models.Runner runner) {
			this.runner = runner;

			count = 0;

			rows = new List<ReleaseRow>();

			load_more_row = new LoadMoreRow ();
			load_more_row.activated.connect (load_more_row_activated);

			spinner = new Gtk.Spinner ();
			spinner.set_visible (false);

			notify["expanded"].connect (() => expanded_changed (false));

			set_title (runner.title);
			set_subtitle (runner.description);
			add_suffix (spinner);

			if (runner.title == "Proton-CachyOS")
                title += " (%s)".printf (Globals.HWCAPS.nth_data (0));
		}

		void expanded_changed (bool force_load = false) {
			if (get_expanded ()) {
				var a = runner.releases.length () == 0 || force_load;
				var b = runner.releases.length () >= 0 && count == 0;
				if (a || b) {
					spinner.start ();
					spinner.set_visible (true);

					if (a) {
						List<Models.Release> releases = null;
						
						runner.load.begin ((obj, res) => {
							var code = runner.load.end (res, out releases);

							if (code != ReturnCode.RELEASES_LOADED) {
								if (count == 0)
									set_expanded (false);

								Adw.AlertDialog dialog;

								switch (code) {
									case ReturnCode.API_LIMIT_REACHED:
										dialog = new WarningDialog (_("API limit reached"), _("Try again in a few minutes."));
										break;
									case ReturnCode.CONNECTION_ISSUE:
										dialog = new WarningDialog (_("Unable to reach the API"), _("Make sure you're connected to the internet."));
										break;
									case ReturnCode.INVALID_ACCESS_TOKEN:
										dialog = new WarningDialog (_("Invalid access token"), _("Make sure the access token you provided is valid."));
										break;
									default:
										dialog = new ErrorDialog (_("Unknown error"), _("Please report this issue on GitHub."));
										break;
								}

								dialog.present(Application.window);
							} else if (runner is Models.Runners.Basic && releases.length () > 0 && count == 0 && runner.has_latest_support) {
								var latest_release = releases.nth_data (0);

								var release = new Models.Releases.Latest (runner as Models.Runners.Basic, "%s Latest".printf (runner.title), latest_release.description, latest_release.release_date, latest_release.download_url, latest_release.page_url);
								releases.prepend (release);
							}

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
					var row = new Widgets.BasicRow ((Models.Releases.Basic) release);
					add_row (row);
					rows.append (row);
				} else if (release is Models.Releases.SteamTinkerLaunch) {
					var row = new Widgets.SteamTinkerLaunchRow ((Models.Releases.SteamTinkerLaunch) release);
					add_row (row);
					rows.append (row);
				} else {
					continue;
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

			GLib.Idle.add (() => {
				remove (load_more_row);
				expanded_changed (true);

				scroll_ctrl.restore(10);
				return false;
			});
		}
	}
}
