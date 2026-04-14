namespace ProtonPlus.Models.Releases {
    public class History : BaseRelease {
        public History (string title, string? displayed_title, string icon_path, bool is_finished, bool install_success, bool canceled) {
            this.title = title;
            this.displayed_title = displayed_title;
            this.is_finished = is_finished;
            this.install_success = install_success;
            this.canceled = canceled;

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
        public override async bool remove (Parameters parameters) { return false; }
        protected override void refresh_state () {}
    }

    public class HistoryRunner : Runner {
        public override async ReturnCode load (out GLib.List<Release> releases) {
            releases = new List<Release> ();
            return ReturnCode.VALID_REQUEST;
        }
    }
}
