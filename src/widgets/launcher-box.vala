namespace ProtonPlus.Widgets {
    public class LauncherBox : Gtk.Widget {
        Models.Launcher launcher { get; set; }
        Gtk.Box content { get; set; }
        Adw.Clamp clamp { get; set; }
        Gtk.ScrolledWindow scrolled_window { get; set; }
        public List<RunnerGroup> group_rows;

        public LauncherBox (Models.Launcher launcher) {
            this.launcher = launcher;

            group_rows = new List<RunnerGroup> ();

            var bin = new Gtk.BinLayout ();
            set_layout_manager (bin);

            content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);

            clamp = new Adw.Clamp ();
            clamp.set_maximum_size (700);
            clamp.set_child (content);

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_child (clamp);
            scrolled_window.set_parent (this);

            set_vexpand (true);

            foreach (var group in launcher.groups) {
                var runner_group = new RunnerGroup (group);
                group_rows.append (runner_group);
                content.append (runner_group);
            }
        }
    }
}