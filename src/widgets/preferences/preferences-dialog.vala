namespace ProtonPlus.Widgets.Preferences {
    public class PreferencesDialog : Adw.PreferencesDialog {
        construct {
            // General
            var theme_row = new ThemeRow ();

            var refresh_launchers_runners_row = new RefreshLaunchersRunnersRow (this);

            var save_history_row = new Adw.SwitchRow () {
                title = _ ("Save download history"),
                subtitle = _ ("Save the download history to a file"),
            };
            Globals.SETTINGS?.bind ("save-history", save_history_row, "active", SettingsBindFlags.DEFAULT);

            var general_group = new Adw.PreferencesGroup () {
                title = _ ("General"),
            };
            general_group.add (theme_row);
            general_group.add (save_history_row);
            general_group.add (refresh_launchers_runners_row);

            // Tools

            var automatic_updates_row = new Adw.SwitchRow () {
                title = _ ("Automatic updates"),
                subtitle = _ ("Update the installed 'Latest' runners when the application starts"),
            };
            Globals.SETTINGS?.bind ("automatic-updates", automatic_updates_row, "active", SettingsBindFlags.DEFAULT);

            var check_updates_row = new CheckUpdatesRow (this);

            var tools_group = new Adw.PreferencesGroup () {
                title = _ ("Tools"),
            };
            tools_group.add (automatic_updates_row);
            tools_group.add (check_updates_row);

            // Launchers

            var launcher_groups = new List<Adw.PreferencesGroup>();

            foreach (var launcher in ProtonPlus.Widgets.Application.window.launchers) {
                if (launcher is ProtonPlus.Models.Launchers.Steam) {
                    var steam_launcher = launcher as ProtonPlus.Models.Launchers.Steam;

                    var steam_remember_last_used_profile_row = new Adw.SwitchRow () {
                        title = _ ("Remember last used profile"),
                        subtitle = _ ("Remember the last used Steam profile"),
                    };
                    Globals.SETTINGS?.bind ("steam-remember-last-profile", steam_remember_last_used_profile_row, "active", SettingsBindFlags.DEFAULT);

                    var refresh_steam_profiles_row = new RefreshSteamProfilesRow (this);

                    var model = new GLib.ListStore (typeof (ProtonPlus.Models.SimpleRunner));
                    foreach (var compatibility_tool in steam_launcher.compatibility_tools) {
                        model.append (compatibility_tool);
                    }

                    var expression = new Gtk.PropertyExpression (typeof (ProtonPlus.Models.SimpleRunner), null, "display_title");

                    var compatibility_tool_row = new ProtonPlus.Widgets.CompatibilityToolRow (model, expression);
                    compatibility_tool_row.title = _ ("Default compatibility tool");

                    for (var i = 0; i < (int) steam_launcher.compatibility_tools.size; i++) {
                        if (steam_launcher.compatibility_tools[i].internal_title == steam_launcher.default_compatibility_tool) {
                            compatibility_tool_row.set_selected ((uint) i);
                            break;
                        }
                    }

                    compatibility_tool_row.notify["selected-item"].connect (() => {
                        var selected_tool = compatibility_tool_row.get_selected_item () as ProtonPlus.Models.SimpleRunner;
                        if (selected_tool != null) {
                            steam_launcher.change_default_compatibility_tool (selected_tool.internal_title);
                        }
                    });

                    var steam_group = new Adw.PreferencesGroup () {
                        title = "Steam",
                    };
                    steam_group.add (steam_remember_last_used_profile_row);
                    steam_group.add (compatibility_tool_row);
                    steam_group.add (refresh_steam_profiles_row);

                    launcher_groups.append (steam_group);

                    break;
                }
            }

            // API Tokens

            var github_access_token_row = new AccessTokenRow ("GitHub", "github-symbolic");
            Globals.SETTINGS?.bind ("github-api-key", github_access_token_row, "text", SettingsBindFlags.DEFAULT);

            var gitlab_access_token_row = new AccessTokenRow ("GitLab", "gitlab-symbolic");
            Globals.SETTINGS?.bind ("gitlab-api-key", gitlab_access_token_row, "text", SettingsBindFlags.DEFAULT);

            var tokens_group = new Adw.PreferencesGroup () {
                title = "API Tokens",
            };
            tokens_group.add (github_access_token_row);
            tokens_group.add (gitlab_access_token_row);

            //

            var general_page = new Adw.PreferencesPage ();
            general_page.set_title (_("General"));
            general_page.set_icon_name ("home-symbolic");
            general_page.add (general_group);
            add (general_page);

            var tools_page = new Adw.PreferencesPage ();
            tools_page.set_title (_("Tools"));
            tools_page.set_icon_name ("toolbox-symbolic");
            tools_page.add (tools_group);
            add (tools_page);

            if (launcher_groups.length () > 0) {
                var launchers_page = new Adw.PreferencesPage ();
                launchers_page.set_title (_("Launchers"));
                launchers_page.set_icon_name ("grip-symbolic");
                foreach (var group in launcher_groups)
                    launchers_page.add (group);
                add (launchers_page);
            }

            var advanced_page = new Adw.PreferencesPage ();
            advanced_page.set_title (_("Advanced"));
            advanced_page.set_icon_name ("bolt-2-symbolic");
            advanced_page.add (tokens_group);
            add (advanced_page);

            set_search_enabled (true);
        }
    }
}