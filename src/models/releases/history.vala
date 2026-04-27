namespace ProtonPlus.Models.Releases {
    public class History : Release {
        public History (string title, string? displayed_title, string icon_path, bool is_finished, bool install_success, bool canceled, string? error_message = null) {
            this.title = title;
            this.displayed_title = displayed_title;
            this.is_finished = is_finished;
            this.install_success = install_success;
            this.canceled = canceled;
            this.error_message = error_message;

            var launcher = Object.new (typeof (Launcher)) as Launcher;
            launcher.icon_path = icon_path;

            var group = Object.new (typeof (Group)) as Group;
            group.launcher = launcher;

            var runner = Object.new (typeof (HistoryRunner)) as HistoryRunner;
            runner.group = group;

            this.runner = runner;
        }

        public override async bool install () { return false; }
        protected override async bool _start_install () { return false; }
        public override async bool remove () { return false; }
        protected async override bool _start_remove () { return false; }
        protected async override bool _start_update () { return false; }
        protected override void refresh_state () {}
    }

    public class HistoryRunner : Tool {
        public override async Gee.LinkedList<Release> load_more (out ReturnCode code) {
            code = ReturnCode.RELEASES_LOADED;

            return new Gee.LinkedList<Release> ();
        }
    }
}
