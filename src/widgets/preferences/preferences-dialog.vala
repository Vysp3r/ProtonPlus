namespace ProtonPlus.Widgets.Preferences {
    public class PreferencesDialog : Adw.PreferencesDialog {
        construct {
        // General
            var theme_row = new ThemeRow ();

            var save_history_row = new Adw.SwitchRow () {
                title = _ ("Save download history"),
                subtitle = _ ("Save the download history to a file"),
            };
            Globals.SETTINGS.bind ("save-history", save_history_row, "active", SettingsBindFlags.DEFAULT);

            var general_group = new Adw.PreferencesGroup ();
            general_group.add (theme_row);
            general_group.add (save_history_row);

        // Tools

            var automatic_updates_row = new Adw.SwitchRow () {
                title = _ ("Automatic updates"),
                subtitle = "%s\n\n%s".printf (_ ("Check if any tool needs to be updated when the application starts"), _ ("When disabled a button to check for updates will be shown in the Tools tab")),
            };
            Globals.SETTINGS.bind ("automatic-updates", automatic_updates_row, "active", SettingsBindFlags.DEFAULT);

            var tools_group = new Adw.PreferencesGroup ();
            tools_group.add (automatic_updates_row);

        // Launchers

            var launcher_groups = new List<Adw.PreferencesGroup>();

            foreach (var launcher in ProtonPlus.Widgets.Application.window.launchers) {
                if (launcher is ProtonPlus.Models.Launchers.Steam) {
                    var steam_launcher = launcher as ProtonPlus.Models.Launchers.Steam;

                    var model = new GLib.ListStore (typeof (ProtonPlus.Models.SimpleRunner));
                    foreach (var compatibility_tool in steam_launcher.compatibility_tools) {
                        model.append (compatibility_tool);
                    }

                    var expression = new Gtk.PropertyExpression (typeof (ProtonPlus.Models.SimpleRunner), null, "display_title");

                    var compatibility_tool_row = new ProtonPlus.Widgets.CompatibilityToolRow (model, expression);
                    compatibility_tool_row.title = _ ("Default compatibility tool");
                    compatibility_tool_row.subtitle = _ ("The compatibility tool games will use by default");

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

                    var steam_remember_last_used_profile_row = new Adw.SwitchRow () {
                        title = _ ("Remember last used profile"),
                    };
                    Globals.SETTINGS.bind ("steam-remember-last-profile", steam_remember_last_used_profile_row, "active", SettingsBindFlags.DEFAULT);

                    var steam_group = new Adw.PreferencesGroup () {
                        title = "Steam",
                    };
                    steam_group.add (compatibility_tool_row);
                    steam_group.add (steam_remember_last_used_profile_row);

                    launcher_groups.append (steam_group);

                    break;
                }
            }

        // Advanced

            var experimental_switch = new Adw.SwitchRow () {
                title = _ ("Preview features"),
                subtitle = _ ("Enable experimental features for early testing"),
            };
            Globals.SETTINGS.bind ("experimental-mode", experimental_switch, "active", SettingsBindFlags.DEFAULT);

            var refresh_application_data_row = new RefreshApplicationDataRow (this);

            var advanced_group = new Adw.PreferencesGroup ();
            advanced_group.add (experimental_switch);
            advanced_group.add (refresh_application_data_row);

        // API Tokens

            var github_access_token_row = new AccessTokenRow ("GitHub", "github-symbolic");
            Globals.SETTINGS.bind ("github-api-key", github_access_token_row, "text", SettingsBindFlags.DEFAULT);

            var gitlab_access_token_row = new AccessTokenRow ("GitLab", "gitlab-symbolic");
            Globals.SETTINGS.bind ("gitlab-api-key", gitlab_access_token_row, "text", SettingsBindFlags.DEFAULT);

            var tokens_group = new Adw.PreferencesGroup () {
                title = "API Tokens",
            };
            tokens_group.add (github_access_token_row);
            tokens_group.add (gitlab_access_token_row);

        //

            Adw.PreferencesPage[] ctrl_pages = {};

            var general_page = new Adw.PreferencesPage ();
            general_page.set_title (_ ("General"));
            general_page.set_icon_name ("home-symbolic");
            general_page.add (general_group);
            add (general_page);
            ctrl_pages += general_page;

            var tools_page = new Adw.PreferencesPage ();
            tools_page.set_title (_ ("Tools"));
            tools_page.set_icon_name ("toolbox-symbolic");
            tools_page.add (tools_group);
            add (tools_page);
            ctrl_pages += tools_page;

            if (launcher_groups.length () > 0) {
                var launchers_page = new Adw.PreferencesPage ();
                launchers_page.set_title (_ ("Launchers"));
                launchers_page.set_icon_name ("grip-symbolic");
                foreach (var group in launcher_groups)
                launchers_page.add (group);
                add (launchers_page);
                ctrl_pages += launchers_page;
            }

            var advanced_page = new Adw.PreferencesPage ();
            advanced_page.set_title (_ ("Advanced"));
            advanced_page.set_icon_name ("bolt-2-symbolic");
            advanced_page.add (advanced_group);
            advanced_page.add (tokens_group);
            add (advanced_page);
            ctrl_pages += advanced_page;

            Application.window.set_controller_preferences_dialog (this, ctrl_pages);
            this.closed.connect (() => Application.window.set_controller_preferences_dialog (null, null));

            set_search_enabled (true);
        }
    }
}