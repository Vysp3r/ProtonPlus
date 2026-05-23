namespace ProtonPlus.Widgets.Preferences {
    public class PreferencesDialog : Adw.PreferencesDialog {
        public PreferencesDialog (Gee.LinkedList<Models.Launcher> launchers) {
            set_search_enabled (true);

        // General Page
            var general_page = new Adw.PreferencesPage () {
                title = _ ("General"),
                icon_name = "preferences-system-symbolic"
            };
            add (general_page);

            var appearance_group = new Adw.PreferencesGroup () {
                title = _ ("Appearance")
            };
            general_page.add (appearance_group);

            var theme_row = new ThemeRow ();
            theme_row.add_prefix (new Gtk.Image.from_icon_name ("palette-symbolic"));
            appearance_group.add (theme_row);

            var behavior_group = new Adw.PreferencesGroup () {
                title = _ ("Behavior")
            };
            general_page.add (behavior_group);

            var enable_controller_row = new Adw.SwitchRow () {
                title = _ ("Controller support"),
                subtitle = _ ("Enable game controller support for navigating the user interface"),
            };
            enable_controller_row.add_prefix (new Gtk.Image.from_icon_name ("gamepad-symbolic"));
            Globals.SETTINGS.bind ("enable-controller", enable_controller_row, "active", SettingsBindFlags.DEFAULT);
            behavior_group.add (enable_controller_row);

        // Tools Page
            var tools_page = new Adw.PreferencesPage () {
                title = _ ("Tools"),
                icon_name = "toolbox-symbolic"
            };
            add (tools_page);

            var updates_group = new Adw.PreferencesGroup () {
                title = _ ("Updates")
            };
            tools_page.add (updates_group);

            var automatic_updates_row = new Adw.SwitchRow () {
                title = _ ("Automatic updates"),
                subtitle = "%s\n\n%s".printf (_ ("Check if any tool needs to be updated automatically"), _ ("When disabled a button to check for updates will be shown in the Tools tab")),
            };
            automatic_updates_row.add_prefix (new Gtk.Image.from_icon_name ("view-refresh-symbolic"));
            Globals.SETTINGS.bind ("automatic-updates", automatic_updates_row, "active", SettingsBindFlags.DEFAULT);
            updates_group.add (automatic_updates_row);

            var update_frequency_row = new UpdateFrequencyRow ();
            automatic_updates_row.bind_property ("active", update_frequency_row, "sensitive", BindingFlags.SYNC_CREATE);
            updates_group.add (update_frequency_row);

            var check_updates_on_boot_row = new Adw.SwitchRow () {
                title = _ ("Check updates on boot"),
            };
            automatic_updates_row.bind_property ("active", check_updates_on_boot_row, "sensitive", BindingFlags.SYNC_CREATE);
            Globals.SETTINGS.bind ("check-updates-on-boot", check_updates_on_boot_row, "active", SettingsBindFlags.DEFAULT);
            updates_group.add (check_updates_on_boot_row);

            var tools_behavior_group = new Adw.PreferencesGroup () {
                title = _ ("Behavior")
            };
            tools_page.add (tools_behavior_group);

            var legacy_tools_row = new Adw.SwitchRow () {
                title = _ ("Show legacy tools"),
                subtitle = _ ("Display older tools that are no longer actively maintained"),
            };
            legacy_tools_row.add_prefix (new Gtk.Image.from_icon_name ("box-archive-symbolic"));
            Globals.SETTINGS.bind ("show-legacy-tools", legacy_tools_row, "active", SettingsBindFlags.DEFAULT);
            tools_behavior_group.add (legacy_tools_row);

        // Launchers Page
            var launchers_page = new Adw.PreferencesPage () {
                title = _ ("Launchers"),
                icon_name = "grip-symbolic"
            };

            bool has_launchers = false;
            foreach (var launcher in launchers) {
                if (launcher is ProtonPlus.Models.Launchers.Steam) {
                    var steam_launcher = launcher as ProtonPlus.Models.Launchers.Steam;

                    var steam_group = new Adw.PreferencesGroup () {
                        title = "Steam",
                    };

                    var model = new GLib.ListStore (typeof (ProtonPlus.Models.Tools.Simple));
                    foreach (var compatibility_tool in steam_launcher.compatibility_tools) {
                        model.append (compatibility_tool);
                    }

                    var expression = new Gtk.PropertyExpression (typeof (ProtonPlus.Models.Tools.Simple), null, "display_title");

                    var compatibility_tool_row = new ToolRow (model, expression) {
                        title = _ ("Default compatibility tool"),
                        subtitle = _ ("The compatibility tool games will use by default")
                    };
                    compatibility_tool_row.add_prefix (new Gtk.Image.from_icon_name ("screwdriver-wrench-symbolic"));

                    for (var i = 0; i < (int) steam_launcher.compatibility_tools.size; i++) {
                        if (steam_launcher.compatibility_tools[i].internal_title == steam_launcher.default_compatibility_tool) {
                            compatibility_tool_row.set_selected ((uint) i);
                            break;
                        }
                    }

                    compatibility_tool_row.notify["selected-item"].connect (() => {
                        var selected_tool = compatibility_tool_row.get_selected_item () as ProtonPlus.Models.Tools.Simple;
                        if (selected_tool != null) {
                            steam_launcher.change_default_compatibility_tool (selected_tool.internal_title);
                        }
                    });
                    steam_group.add (compatibility_tool_row);

                    var steam_remember_last_used_profile_row = new Adw.SwitchRow () {
                        title = _ ("Remember last used profile"),
                    };
                    steam_remember_last_used_profile_row.add_prefix (new Gtk.Image.from_icon_name ("avatar-default-symbolic"));
                    Globals.SETTINGS.bind ("steam-remember-last-profile", steam_remember_last_used_profile_row, "active", SettingsBindFlags.DEFAULT);
                    steam_group.add (steam_remember_last_used_profile_row);

                    launchers_page.add (steam_group);
                    has_launchers = true;
                    break;
                }
            }

            if (has_launchers) {
                add (launchers_page);
            }

            // Advanced Page
            var advanced_page = new Adw.PreferencesPage () {
                title = _ ("Advanced"),
                icon_name = "preferences-other-symbolic"
            };
            add (advanced_page);

            var tokens_group = new Adw.PreferencesGroup () {
                title = _ ("API Tokens")
            };
            advanced_page.add (tokens_group);

            var github_access_token_row = new AccessTokenRow ("GitHub", "github-symbolic");
            Globals.SETTINGS.bind ("github-api-key", github_access_token_row, "text", SettingsBindFlags.DEFAULT);
            tokens_group.add (github_access_token_row);

            var gitlab_access_token_row = new AccessTokenRow ("GitLab", "gitlab-symbolic");
            Globals.SETTINGS.bind ("gitlab-api-key", gitlab_access_token_row, "text", SettingsBindFlags.DEFAULT);
            tokens_group.add (gitlab_access_token_row);

            var network_group = new Adw.PreferencesGroup () {
                title = _ ("Network")
            };
            advanced_page.add (network_group);

            var proxy_mode_row = new ProxyModeRow ();
            network_group.add (proxy_mode_row);

            var proxy_url_row = new Adw.EntryRow () {
                title = _ ("Proxy URL"),
            };
            proxy_url_row.set_tooltip_text (_ ("Example: http://127.0.0.1:7890 or socks5://127.0.0.1:1080"));
            proxy_url_row.set_sensitive (Globals.SETTINGS.get_enum ("proxy-mode") == 1);
            Globals.SETTINGS.bind ("proxy-url", proxy_url_row, "text", SettingsBindFlags.DEFAULT);
            Globals.SETTINGS.changed["proxy-mode"].connect (() => {
                proxy_url_row.set_sensitive (Globals.SETTINGS.get_enum ("proxy-mode") == 1);
                Utils.Web.update_proxy_settings ();
            });
            Globals.SETTINGS.changed["proxy-url"].connect (() => {
                Utils.Web.update_proxy_settings ();
            });
            network_group.add (proxy_url_row);

            var experimental_group = new Adw.PreferencesGroup () {
                title = _ ("Experimental")
            };
            advanced_page.add (experimental_group);

            var experimental_features_row = new Adw.SwitchRow () {
                title = _ ("Preview features"),
                subtitle = _ ("Enable experimental features for early testing"),
            };
            experimental_features_row.add_prefix (new Gtk.Image.from_icon_name ("flask-symbolic"));
            Globals.SETTINGS.bind ("experimental-features", experimental_features_row, "active", SettingsBindFlags.DEFAULT);
            experimental_group.add (experimental_features_row);

            var maintenance_group = new Adw.PreferencesGroup () {
                title = _ ("Maintenance")
            };
            advanced_page.add (maintenance_group);
            maintenance_group.add (new RefreshApplicationDataRow (this));
            maintenance_group.add (new DeleteCacheRow ());

            // System Page
            var system_page = new Adw.PreferencesPage () {
                title = _ ("System"),
                icon_name = "dialog-information-symbolic"
            };
            add (system_page);

            var environment_group = new Adw.PreferencesGroup () {
                title = _ ("Software Environment")
            };
            system_page.add (environment_group);

            environment_group.add (new Adw.ActionRow () {
                title = _ ("SteamOS"),
                subtitle = Globals.IS_STEAM_OS ? _ ("Yes") : _ ("No")
            });

            environment_group.add (new Adw.ActionRow () {
                title = _ ("Flatpak"),
                subtitle = Globals.IS_FLATPAK ? _ ("Yes") : _ ("No")
            });

            var hardware_group = new Adw.PreferencesGroup () {
                title = _ ("Hardware")
            };
            system_page.add (hardware_group);

            string hwcaps_str = "";
            foreach (var hwcap in Globals.HWCAPS) {
                if (hwcaps_str != "")
                hwcaps_str += ", ";
                hwcaps_str += hwcap;
            }

            hardware_group.add (new Adw.ActionRow () {
                title = _ ("HWCAPS"),
                subtitle = hwcaps_str
            });

            var dependencies_group = new Adw.PreferencesGroup () {
                title = _ ("Dependencies")
            };
            system_page.add (dependencies_group);

            dependencies_group.add (new Adw.ActionRow () {
                title = _ ("Protontricks"),
                subtitle = Globals.PROTONTRICKS_INSTALLED ? _ ("Yes") : _ ("No")
            });

            dependencies_group.add (new Adw.ActionRow () {
                title = _ ("Protontricks (Flatpak)"),
                subtitle = Globals.PROTONTRICKS_FLATPAK_INSTALLED ? _ ("Yes") : _ ("No")
            });

            dependencies_group.add (new Adw.ActionRow () {
                title = _ ("MangoHud"),
                subtitle = Globals.MANGOHUD_INSTALLED ? _ ("Yes") : _ ("No")
            });

            dependencies_group.add (new Adw.ActionRow () {
                title = _ ("MangoHud (Flatpak)"),
                subtitle = Globals.MANGOHUD_FLATPAK_INSTALLED ? _ ("Yes") : _ ("No")
            });

            dependencies_group.add (new Adw.ActionRow () {
                title = _ ("Gamescope"),
                subtitle = Globals.GAMESCOPE_INSTALLED ? _ ("Yes") : _ ("No")
            });

            dependencies_group.add (new Adw.ActionRow () {
                title = _ ("ScopeBuddy"),
                subtitle = Globals.SCOPEBUDDY_INSTALLED ? _ ("Yes") : _ ("No")
            });

            var detected_launchers_group = new Adw.PreferencesGroup () {
                title = _ ("Detected Launchers")
            };
            system_page.add (detected_launchers_group);

            ProtonPlus.Models.Launcher[] all_launchers = {
                new ProtonPlus.Models.Launchers.Steam (ProtonPlus.Models.Launcher.InstallationTypes.SYSTEM),
                new ProtonPlus.Models.Launchers.Steam (ProtonPlus.Models.Launcher.InstallationTypes.FLATPAK),
                new ProtonPlus.Models.Launchers.Steam (ProtonPlus.Models.Launcher.InstallationTypes.SNAP),
                new ProtonPlus.Models.Launchers.Lutris (ProtonPlus.Models.Launcher.InstallationTypes.SYSTEM),
                new ProtonPlus.Models.Launchers.Lutris (ProtonPlus.Models.Launcher.InstallationTypes.FLATPAK),
                new ProtonPlus.Models.Launchers.Bottles (ProtonPlus.Models.Launcher.InstallationTypes.SYSTEM),
                new ProtonPlus.Models.Launchers.Bottles (ProtonPlus.Models.Launcher.InstallationTypes.FLATPAK),
                new ProtonPlus.Models.Launchers.HeroicGamesLauncher (ProtonPlus.Models.Launcher.InstallationTypes.SYSTEM),
                new ProtonPlus.Models.Launchers.HeroicGamesLauncher (ProtonPlus.Models.Launcher.InstallationTypes.FLATPAK),
                new ProtonPlus.Models.Launchers.WineZGUI (ProtonPlus.Models.Launcher.InstallationTypes.SYSTEM),
                new ProtonPlus.Models.Launchers.WineZGUI (ProtonPlus.Models.Launcher.InstallationTypes.FLATPAK)
            };

            foreach (var launcher in all_launchers) {
                detected_launchers_group.add (new Adw.ActionRow () {
                    title = "%s (%s)".printf (launcher.title, launcher.get_installation_type_title ()),
                    subtitle = launcher.installed ? _ ("Installed") : _ ("Not installed")
                });
            }
        }
    }
}
