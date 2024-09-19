namespace ProtonPlus.Widgets {
    public class RunnerRow : Adw.ExpanderRow {
        Models.Runner runner { get; set; }
        Gtk.Spinner spinner { get; set; }

        public RunnerRow (Models.Runner runner) {
            this.runner = runner;

            spinner = new Gtk.Spinner ();
            spinner.set_visible (false);

            notify["expanded"].connect (expanded_changed);

            set_title (runner.title);
            set_subtitle (runner.description);
            add_suffix (spinner);
        }

        void expanded_changed () {
            if (get_expanded () && runner.releases.length () == 0) {
                spinner.start ();
                spinner.set_visible (true);
                runner.load.begin ((obj, res) => {
                    var releases = runner.load.end (res);

                    foreach (var release in releases) {
                        add_row (release.row);
                    }

                    // TODO Add a way to add the load more row if needed

                    spinner.stop ();
                    spinner.set_visible (false);
                });
            }
        }
    }
}