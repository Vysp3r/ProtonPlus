namespace ProtonPlus.Widgets.Preferences {
    public class PreferencesDialog : Adw.PreferencesDialog {
        construct {
            var theme_row = new ThemeRow ();

            var refresh_launchers_runners_row = new RefreshLaunchersRunnersRow (this);

            var general_group = new Adw.PreferencesGroup () {
                title = _ ("General"),
            };
            general_group.add (theme_row);

            var save_history_row = new Adw.SwitchRow () {
                title = _ ("Save download history"),
                subtitle = _ ("Save the download history to a file"),
            };
            general_group.add (save_history_row);

            general_group.add (refresh_launchers_runners_row);

            var automatic_updates_row = new Adw.SwitchRow () {
                title = _ ("Automatic updates"),
                subtitle = _ ("Update the installed 'Latest' runners when the application starts"),
            };

            var check_updates_row = new CheckUpdatesRow (this);

            var latest_group = new Adw.PreferencesGroup () {
                title = _ ("Latest"),
            };
            latest_group.add (automatic_updates_row);
            latest_group.add (check_updates_row);

            var proxy_mode_row = new ProxyModeRow ();

            var proxy_url_row = new Adw.EntryRow () {
                title = _ ("Proxy URL"),
            };
            proxy_url_row.set_tooltip_text (_ ("Example: http://127.0.0.1:7890 or socks5://127.0.0.1:1080"));

            var network_group = new Adw.PreferencesGroup () {
                title = _ ("Network"),
            };
            network_group.add (proxy_mode_row);
            network_group.add (proxy_url_row);

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
                title = _ ("Remember last used profile"),
                subtitle = _ ("Remember the last used Steam profile"),
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
            page.add (network_group);
            page.add (github_group);
            page.add (gitlab_group);
            page.add (steam_group);

            if (Globals.SETTINGS != null) {
                Globals.SETTINGS.bind ("automatic-updates", automatic_updates_row, "active", SettingsBindFlags.DEFAULT);
                Globals.SETTINGS.bind ("github-api-key", github_access_token_row, "text", SettingsBindFlags.DEFAULT);
                Globals.SETTINGS.bind ("gitlab-api-key", gitlab_access_token_row, "text", SettingsBindFlags.DEFAULT);
                Globals.SETTINGS.bind ("steam-remember-last-profile", steam_remember_last_used_profile_row, "active", SettingsBindFlags.DEFAULT);
                Globals.SETTINGS.bind ("save-history", save_history_row, "active", SettingsBindFlags.DEFAULT);
                Globals.SETTINGS.bind ("proxy-url", proxy_url_row, "text", SettingsBindFlags.DEFAULT);

                proxy_url_row.set_sensitive (Globals.SETTINGS.get_enum ("proxy-mode") == 1);
                Globals.SETTINGS.changed["proxy-mode"].connect (() => {
                    proxy_url_row.set_sensitive (Globals.SETTINGS.get_enum ("proxy-mode") == 1);
                    Utils.Web.update_proxy_settings ();
                });
                Globals.SETTINGS.changed["proxy-url"].connect (() => {
                    Utils.Web.update_proxy_settings ();
                });
            }

            set_search_enabled (true);
            add (page);
        }
    }
}