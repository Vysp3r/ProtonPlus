namespace ProtonPlus.Widgets.Preferences {
    public class RefreshSteamProfilesRow : Adw.ActionRow {
        PreferencesDialog dialog;
        Gtk.Button refresh_profiles_button;
        Adw.Spinner spinner;

        construct {
            refresh_profiles_button = new Gtk.Button.from_icon_name ("arrow-rotate-symbolic");
            refresh_profiles_button.add_css_class ("flat");
            refresh_profiles_button.set_valign (Gtk.Align.CENTER);
            refresh_profiles_button.clicked.connect (() => refresh_profiles.begin ());

            spinner = new Adw.Spinner ();

            set_title (_("Refresh profiles"));
            add_suffix (refresh_profiles_button);
        }

        public RefreshSteamProfilesRow (PreferencesDialog dialog) {
            this.dialog = dialog;
        }

        async void refresh_profiles () {
            dialog.set_can_close (false);

            refresh_profiles_button.set_child (spinner);

            foreach (var launcher in Application.window.launchers) {
                if (launcher is Models.Launchers.Steam) {
                    var steam_launcher = launcher as Models.Launchers.Steam;

                    steam_launcher.profiles = Models.SteamProfile.get_profiles(steam_launcher);

                    foreach(var profile in steam_launcher.profiles) {
                        yield profile.load_extra_data ();
                    }

                    break;
                }
            }

            spinner.unparent ();

            refresh_profiles_button.set_icon_name ("arrow-rotate-symbolic");

            dialog.set_can_close (true);
        }
    }
}