namespace ProtonPlus.Widgets {
	public class FiltersBox : Gtk.Widget {
        Gtk.Switch installed_only_switch;
        Gtk.Switch used_only_switch;
        Gtk.Switch unused_only_switch;
        public weak List<RunnerGroup> runner_groups;

        public FiltersBox () {
            installed_only_switch = new Gtk.Switch ();
			installed_only_switch.notify["active"].connect (installed_only_switch_active_changed);

			var installed_only_label = new Gtk.Label (_("Show installed only"));

			var installed_only_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
			installed_only_box.append (installed_only_switch);
			installed_only_box.append (installed_only_label);

            used_only_switch = new Gtk.Switch ();
			used_only_switch.notify["active"].connect (used_only_switch_active_changed);

			var used_only_label = new Gtk.Label (_("Show used only"));

			var used_only_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
			used_only_box.append (used_only_switch);
			used_only_box.append (used_only_label);

            unused_only_switch = new Gtk.Switch ();
			unused_only_switch.notify["active"].connect (unused_only_switch_active_changed);

			var unused_only_label = new Gtk.Label (_("Show unused only"));

			var unused_only_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
			unused_only_box.append (unused_only_switch);
			unused_only_box.append (unused_only_label);

            var separator1 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);

            var separator2 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);

            var flow_box = new Gtk.FlowBox ();
			flow_box.set_margin_bottom (15);
			flow_box.add_css_class("card");
			flow_box.add_css_class("p-10");
			flow_box.set_halign(Gtk.Align.CENTER);
			flow_box.append(installed_only_box);
            flow_box.append(separator1);
            flow_box.append(used_only_box);
            flow_box.append(separator2);
            flow_box.append(unused_only_box);
			flow_box.set_selection_mode(Gtk.SelectionMode.NONE);
            flow_box.set_parent (this);

            var bin_layout = new Gtk.BinLayout();

			set_layout_manager(bin_layout);
        }

        public void apply_filters () {
            if (installed_only_switch.active)
                installed_only_switch_active_changed();
            
            if (used_only_switch.get_active ())
                used_only_switch_active_changed ();
            
            if (unused_only_switch.get_active ())
                unused_only_switch_active_changed ();
        }

        void installed_only_switch_active_changed () {
            foreach (var runner_group in runner_groups) {
				runner_group.load (installed_only_switch.active);
			}
		}

        void used_only_switch_active_changed () {
            if (used_only_switch.get_active ()) {
                unused_only_switch.set_active (false);
                Application.window.only_show_unused = false;
            }

            used_only_switch.set_active (used_only_switch.get_active ());
            Application.window.only_show_used = used_only_switch.get_active ();
		}

        void unused_only_switch_active_changed () {
            if (unused_only_switch.get_active ()) {
                used_only_switch.set_active (false);
                Application.window.only_show_used = false;
            }

            unused_only_switch.set_active (unused_only_switch.get_active ());
            Application.window.only_show_unused = unused_only_switch.get_active ();
		}
    }
}