namespace ProtonPlus.Widgets {
	public class RunnersBox : Gtk.Box {
		bool installed_only;

        Models.Launcher launcher;
		Gtk.Switch installed_only_switch;
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

			installed_only_switch = new Gtk.Switch ();
			installed_only_switch.notify["active"].connect (installed_only_switch_active_changed);

			var installed_only_label = new Gtk.Label (_("Show installed only"));

			var installed_only_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
			installed_only_box.append (installed_only_switch);
			installed_only_box.append (installed_only_label);

			var flow_box = new Gtk.FlowBox();
			flow_box.set_margin_bottom (15);
			flow_box.add_css_class("card");
			flow_box.add_css_class("p-10");
			flow_box.set_halign(Gtk.Align.CENTER);
			flow_box.append(installed_only_box);
			flow_box.set_selection_mode(Gtk.SelectionMode.NONE);

			content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);

			clamp = new Adw.Clamp ();
			clamp.set_maximum_size (975);
			clamp.set_child (content);

			scrolled_window = new Gtk.ScrolledWindow ();
			scrolled_window.set_child (clamp);
			scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
			scrolled_window.set_vexpand (true);

			append (flow_box);
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

		void installed_only_switch_active_changed () {
            foreach (var runner_group in runner_groups) {
				runner_group.load (installed_only_switch.active);
			}
		}
    }
}