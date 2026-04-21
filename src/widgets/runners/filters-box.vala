namespace ProtonPlus.Widgets {
    public class FiltersBox : Gtk.Box {
        private Gtk.ToggleButton installed_only_button;
        private Gtk.ToggleButton used_only_button;
        private Gtk.ToggleButton unused_only_button;

        public bool installed_only {
            get { return installed_only_button.active; }
            set { installed_only_button.active = value; }
        }

        public FiltersBox () {
            Object (orientation: Gtk.Orientation.VERTICAL);

            var action_bar = new Gtk.ActionBar ();
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 15);
            box.set_halign (Gtk.Align.CENTER);
            action_bar.set_center_widget (box);
            append (action_bar);

            var check_updates_button = new Gtk.Button.from_icon_name ("arrow-rotate-symbolic");
            check_updates_button.add_css_class ("suggested-action");
            check_updates_button.set_valign (Gtk.Align.CENTER);
            check_updates_button.set_tooltip_text (_ ("Check if any tool needs to be updated"));
            check_updates_button.clicked.connect (() => {
                check_updates_button.set_sensitive (false);
                check_updates_button.set_child (new Adw.Spinner ());
                Application.window.check_for_updates.begin (null, (obj, res) => {
                    Application.window.check_for_updates.end (res);
                    check_updates_button.set_child (null);
                    check_updates_button.set_icon_name ("arrow-rotate-symbolic");
                    check_updates_button.set_sensitive (true);
                });
            });
            Globals.SETTINGS.bind ("automatic-updates", check_updates_button, "visible", SettingsBindFlags.INVERT_BOOLEAN);

            action_bar.pack_end (check_updates_button);

            installed_only_button = new Gtk.ToggleButton ();
            installed_only_button.set_child (new Adw.ButtonContent () {
                icon_name = "boxes-stacked-symbolic",
                label = _ ("Installed")
            });
            installed_only_button.set_tooltip_text (_ ("Show installed tools"));
            installed_only_button.add_css_class ("flat");
            installed_only_button.notify["active"].connect (() => {
                notify_property ("installed-only");
            });

            used_only_button = new Gtk.ToggleButton ();
            used_only_button.set_child (new Adw.ButtonContent () {
                icon_name = "box-open-symbolic",
                label = _ ("Used")
            });
            used_only_button.set_tooltip_text (_ ("Show tools that are used by one game or more"));
            used_only_button.add_css_class ("flat");
            used_only_button.notify["active"].connect (used_only_button_active_changed);

            unused_only_button = new Gtk.ToggleButton ();
            unused_only_button.set_child (new Adw.ButtonContent () {
                icon_name = "box-archive-symbolic",
                label = _ ("Unused")
            });
            unused_only_button.set_tooltip_text (_ ("Show tools that aren't used by any games"));
            unused_only_button.add_css_class ("flat");
            unused_only_button.notify["active"].connect (unused_only_button_active_changed);

            box.append (installed_only_button);
            box.append (used_only_button);
            box.append (unused_only_button);
        }

        public void apply_filters () {
            if (used_only_button.active)
            used_only_button_active_changed ();

            if (unused_only_button.active)
            unused_only_button_active_changed ();
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