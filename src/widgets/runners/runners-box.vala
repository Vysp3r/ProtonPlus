namespace ProtonPlus.Widgets {
	public class RunnersBox : Gtk.Box {
		bool installed_only;

        Models.Launcher launcher;
		Gtk.Box content;
		Adw.Clamp clamp;
		Gtk.ScrolledWindow scrolled_window;
		List<RunnerGroup> runner_groups;

        public RunnersBox () {
            set_vexpand (true);
			set_margin_start (15);
			set_margin_end (15);
			set_margin_bottom (15);

			content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);

			clamp = new Adw.Clamp ();
			clamp.set_maximum_size (975);
			clamp.set_child (content);

			scrolled_window = new Gtk.ScrolledWindow ();
			scrolled_window.set_child (clamp);

			append (scrolled_window);
        }

        public void set_selected_launcher (Models.Launcher launcher) {
            this.launcher = launcher;

			foreach (var runner_group in runner_groups) {
				content.remove (runner_group);
			}

			runner_groups = new List<RunnerGroup> ();

			foreach (var group in launcher.groups) {
				var runner_group = new RunnerGroup (group, installed_only);
				runner_groups.append (runner_group);
				content.append (runner_group);
			}
        }

        public void set_installed_only (bool installed_only) {
            this.installed_only = installed_only;

            foreach (var runner_group in runner_groups) {
				runner_group.load (!installed_only);
			}
        }
    }
}