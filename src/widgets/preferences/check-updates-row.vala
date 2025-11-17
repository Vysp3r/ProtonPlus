namespace ProtonPlus.Widgets.Preferences {
    public class CheckUpdatesRow : Adw.ActionRow {
        PreferencesDialog dialog;
        Gtk.Button check_updates_button;
        Adw.Spinner spinner;

        construct {
            check_updates_button = new Gtk.Button.from_icon_name ("arrow-rotate-symbolic");
            check_updates_button.add_css_class ("flat");
            check_updates_button.set_valign (Gtk.Align.CENTER);
            check_updates_button.set_tooltip_text (_("Check if any of the installed 'Latest' runners needs to be updated"));
            check_updates_button.clicked.connect (() => check_for_updates.begin ());

            spinner = new Adw.Spinner ();

            set_title (_("Check for updates"));
            add_suffix (check_updates_button);
        }

        public CheckUpdatesRow (PreferencesDialog dialog) {
            this.dialog = dialog;
        }

        async void check_for_updates () {
            dialog.set_can_close (false);

            check_updates_button.set_child (spinner);

            yield Application.window.check_for_updates ();

            spinner.unparent ();

            check_updates_button.set_icon_name ("arrow-rotate-symbolic");

            dialog.set_can_close (true);
        }
    }
}