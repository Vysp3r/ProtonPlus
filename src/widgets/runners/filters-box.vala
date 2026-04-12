namespace ProtonPlus.Widgets {
	public class FiltersBox : Gtk.Box {
        Gtk.ToggleButton installed_only_button;
        Gtk.ToggleButton used_only_button;
        Gtk.ToggleButton unused_only_button;
        public weak List<RunnerGroup> runner_groups;

        public FiltersBox () {
            set_orientation (Gtk.Orientation.HORIZONTAL);
            set_halign (Gtk.Align.CENTER);
            set_spacing (10);
            add_css_class ("card");
            add_css_class ("p-10");

            installed_only_button = new Gtk.ToggleButton ();
            installed_only_button.set_child (new Adw.ButtonContent () {
                icon_name = "boxes-stacked-symbolic",
                label = _("Installed")
            });
            installed_only_button.set_tooltip_text (_("Show installed runners"));
            installed_only_button.add_css_class ("flat");
            installed_only_button.notify["active"].connect (installed_only_button_active_changed);

            used_only_button = new Gtk.ToggleButton ();
            used_only_button.set_child (new Adw.ButtonContent () {
                icon_name = "box-open-symbolic",
                label = _("Used")
            });
            used_only_button.set_tooltip_text (_("Show runners that are used by one game or more"));
            used_only_button.add_css_class ("flat");
            used_only_button.notify["active"].connect (used_only_button_active_changed);

            unused_only_button = new Gtk.ToggleButton ();
            unused_only_button.set_child (new Adw.ButtonContent () {
                icon_name = "box-archive-symbolic",
                label = _("Unused")
            });
            unused_only_button.set_tooltip_text (_("Show runners that aren't used by any games"));
            unused_only_button.add_css_class ("flat");
            unused_only_button.notify["active"].connect (unused_only_button_active_changed);

            append (installed_only_button);
            append (new Gtk.Separator (Gtk.Orientation.VERTICAL));
            append (used_only_button);
            append (new Gtk.Separator (Gtk.Orientation.VERTICAL));
            append (unused_only_button);
        }

        public void apply_filters () {
            if (installed_only_button.active)
                installed_only_button_active_changed();
            
            if (used_only_button.active)
                used_only_button_active_changed ();
            
            if (unused_only_button.active)
                unused_only_button_active_changed ();
        }

        void installed_only_button_active_changed () {
            foreach (var runner_group in runner_groups) {
				runner_group.load (installed_only_button.active);
			}
		}

        void used_only_button_active_changed () {
            if (used_only_button.active) {
                unused_only_button.active = false;
                Application.window.only_show_unused = false;
            }

            Application.window.only_show_used = used_only_button.active;
		}

        void unused_only_button_active_changed () {
            if (unused_only_button.active) {
                used_only_button.active = false;
                Application.window.only_show_used = false;
            }

            Application.window.only_show_unused = unused_only_button.active;
		}
    }
}