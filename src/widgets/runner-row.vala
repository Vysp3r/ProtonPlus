namespace ProtonPlus.Widgets {
    public class RunnerRow : Adw.ExpanderRow {
        Models.Runner runner { get; set; }
        Gtk.Spinner spinner { get; set; }
        public LoadMoreRow load_more_row { get; set; }
        public List<ReleaseRow> release_rows;

        public RunnerRow (Models.Runner runner) {
            this.runner = runner;

            release_rows = new List<ReleaseRow> ();

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
            if ((get_expanded () && runner.releases.length () == 0) || force_load) {
                spinner.start ();
                spinner.set_visible (true);
                runner.load.begin ((obj, res) => {
                    var releases = runner.load.end (res);

                    foreach (var release in releases) {
                        if (release is Models.Releases.Basic || release is Models.Releases.GitHubAction) {
                            var row = new Widgets.ReleaseRows.Basic ((Models.Releases.Basic) release);
                            release_rows.append (row);
                            add_row (row);
                        } else if (release is Models.Releases.SteamTinkerLaunch) {
                            var row = new Widgets.ReleaseRows.SteamTinkerLaunch ((Models.Releases.SteamTinkerLaunch) release);
                            release_rows.append (row);
                            add_row (row);
                        }
                    }

                    if (runner.has_more)
                        add_row (load_more_row);

                    spinner.stop ();
                    spinner.set_visible (false);
                });
            }
        }

        void load_more_row_activated () {
            remove (load_more_row);
            expanded_changed (true);
        }
    }
}