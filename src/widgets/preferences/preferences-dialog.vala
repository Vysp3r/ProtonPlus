namespace ProtonPlus.Widgets.Preferences {
    public class PreferencesDialog : Adw.PreferencesDialog {
        construct {
            var theme_row = new ThemeRow ();

            var refresh_launchers_runners_row = new RefreshLaunchersRunnersRow (this);

            var general_group = new Adw.PreferencesGroup ();
            general_group.set_title (_("General"));
            general_group.add (theme_row);
            general_group.add (refresh_launchers_runners_row);

            var automatic_update_row = new Adw.SwitchRow ();
            automatic_update_row.set_title (_("Automatic updates"));
            automatic_update_row.set_tooltip_text (_("Whether or not to update the installed 'Latest' runners when the application start"));

            var check_updates_row = new CheckUpdatesRow (this);

            var latest_group = new Adw.PreferencesGroup ();
            latest_group.set_title (_("Latest"));
            latest_group.add (automatic_update_row);
            latest_group.add (check_updates_row);

            var remember_steam_last_used_profile_row = new Adw.SwitchRow ();
            remember_steam_last_used_profile_row.set_title (_("Remember last used profile"));
            remember_steam_last_used_profile_row.set_tooltip_text (_("Whether or not to remember the last used Steam profile"));

            var refresh_steam_profiles_row = new RefreshSteamProfilesRow (this);

            var steam_group = new Adw.PreferencesGroup ();
            steam_group.set_title ("Steam");
            steam_group.add (remember_steam_last_used_profile_row);
            steam_group.add (refresh_steam_profiles_row);
            
            var page = new Adw.PreferencesPage ();
            page.add (general_group);
            page.add (latest_group);
            page.add (steam_group);

            if (Globals.SETTINGS != null) {
                Globals.SETTINGS.bind ("steam-remember-last-profile", remember_steam_last_used_profile_row, "active", SettingsBindFlags.DEFAULT);
                Globals.SETTINGS.bind ("automatic-update", automatic_update_row, "active", SettingsBindFlags.DEFAULT);
            }
                
            set_search_enabled (true);
            add (page);
        }
    }
}