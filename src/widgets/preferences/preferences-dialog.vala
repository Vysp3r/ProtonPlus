namespace ProtonPlus.Widgets.Preferences {
    public class PreferencesDialog : Adw.PreferencesDialog {
        construct {
            var theme_row = new ThemeRow ();

            var refresh_launchers_runners_row = new RefreshLaunchersRunnersRow (this);

            var general_group = new Adw.PreferencesGroup () {
                title = _("General"),
            };
            general_group.add (theme_row);
            general_group.add (refresh_launchers_runners_row);

            var automatic_updates_row = new Adw.SwitchRow () {
                title = _("Automatic updates"),
                tooltip_text = _("Whether or not to update the installed 'Latest' runners when the application start"),
            };
            
            var check_updates_row = new CheckUpdatesRow (this);

            var latest_group = new Adw.PreferencesGroup () {
                title = _("Latest"),
            };
            latest_group.add (automatic_updates_row);
            latest_group.add (check_updates_row);

            var github_access_token_row = new AccessTokenRow ();

            var github_group = new Adw.PreferencesGroup () {
                title = "GitHub",
            };
            github_group.add (github_access_token_row);

            var gitlab_access_token_row = new AccessTokenRow ();

            var gitlab_group = new Adw.PreferencesGroup () {
                title = "GitLab",
            };
            gitlab_group.add (gitlab_access_token_row);

            var steam_remember_last_used_profile_row = new Adw.SwitchRow () {
                title = _("Remember last used profile"),
                tooltip_text = _("Whether or not to remember the last used Steam profile"),
            };

            var refresh_steam_profiles_row = new RefreshSteamProfilesRow (this);

            var steam_group = new Adw.PreferencesGroup () {
                title = "Steam",
            };
            steam_group.add (steam_remember_last_used_profile_row);
            steam_group.add (refresh_steam_profiles_row);
            
            var page = new Adw.PreferencesPage ();
            page.add (general_group);
            page.add (latest_group);
            page.add (github_group);
            page.add (gitlab_group);
            page.add (steam_group);

            if (Globals.SETTINGS != null) {
                Globals.SETTINGS.bind ("automatic-updates", automatic_updates_row, "active", SettingsBindFlags.DEFAULT);
                Globals.SETTINGS.bind ("github-api-key", github_access_token_row, "text", SettingsBindFlags.DEFAULT);
                Globals.SETTINGS.bind ("gitlab-api-key", gitlab_access_token_row, "text", SettingsBindFlags.DEFAULT);
                Globals.SETTINGS.bind ("steam-remember-last-profile", steam_remember_last_used_profile_row, "active", SettingsBindFlags.DEFAULT);
            }
                
            set_search_enabled (true);
            add (page);
        }
    }
}