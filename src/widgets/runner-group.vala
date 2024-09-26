namespace ProtonPlus.Widgets {
    public class RunnerGroup : Adw.PreferencesGroup {
        public List<RunnerRow> runner_rows;

        public RunnerGroup (Models.Group group) {
            runner_rows = new List<RunnerRow> ();

            set_title (group.title);
            set_description (group.description);

            foreach (var runner in group.runners) {
                var runner_row = new RunnerRow (runner);
                runner_rows.append (runner_row);
                add (runner_row);
            }
        }
    }
}