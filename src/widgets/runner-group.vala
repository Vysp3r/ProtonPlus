namespace ProtonPlus.Widgets {
    public class RunnerGroup : Adw.PreferencesGroup {
        public RunnerGroup (Models.Group group) {
            set_title (group.title);
            set_description (group.description);

            foreach (var runner in group.runners) {
                var runner_row = new RunnerRow (runner);
                add (runner_row);
            }
        }
    }
}