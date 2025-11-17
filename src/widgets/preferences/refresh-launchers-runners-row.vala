namespace ProtonPlus.Widgets.Preferences {
    public class RefreshLaunchersRunnersRow : Adw.ActionRow {
        PreferencesDialog dialog;
        Gtk.Button refresh_launchers_runners_button;
        Adw.Spinner spinner;

        construct {
            refresh_launchers_runners_button = new Gtk.Button.from_icon_name ("arrow-rotate-symbolic");
            refresh_launchers_runners_button.add_css_class ("flat");
            refresh_launchers_runners_button.set_valign (Gtk.Align.CENTER);
            refresh_launchers_runners_button.clicked.connect(() => refresh_launchers_runners.begin ());

            spinner = new Adw.Spinner ();

            set_title (_("Refresh launchers/runners"));
            add_suffix (refresh_launchers_runners_button);
        }

        public RefreshLaunchersRunnersRow (PreferencesDialog dialog) {
            this.dialog = dialog;
        }

        async void refresh_launchers_runners () {
            dialog.set_can_close (false);

            refresh_launchers_runners_button.set_child (spinner);

            yield Application.window.initialize ();

            spinner.unparent ();

            refresh_launchers_runners_button.set_icon_name ("arrow-rotate-symbolic");

            dialog.set_can_close (true);
        }
    }
}