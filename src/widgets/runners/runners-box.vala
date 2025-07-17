namespace ProtonPlus.Widgets {
	public class RunnersBox : Gtk.Box {
		bool installed_only;

        Models.Launcher launcher;
		FiltersBox filters_box;
		Gtk.Box content;
		Adw.Clamp clamp;
		Gtk.ScrolledWindow scrolled_window;
		List<RunnerGroup> runner_groups;

        public RunnersBox () {
			set_orientation (Gtk.Orientation.VERTICAL);
            set_vexpand (true);
			set_margin_top(7);
			set_margin_start (15);
			set_margin_end (15);
			set_margin_bottom (15);

			filters_box = new FiltersBox ();

			content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);

			clamp = new Adw.Clamp ();
			clamp.set_maximum_size (975);
			clamp.set_child (content);

			scrolled_window = new Gtk.ScrolledWindow ();
			scrolled_window.set_child (clamp);
			scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
			scrolled_window.set_vexpand (true);

			append (filters_box);
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

			filters_box.runner_groups = runner_groups;
        }
    }
}