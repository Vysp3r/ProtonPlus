namespace ProtonPlus.Widgets.Preferences {
    public class PreferencesDialog : Adw.PreferencesDialog, Utils.ControllerNavigationHost {
        Adw.PreferencesPage[] controller_pages = {};
        Adw.EntryRow? proxy_url_row;
        ulong proxy_mode_changed_handler = 0;

        public PreferencesDialog (Gee.LinkedList<Models.Launcher> launchers) {
            set_search_enabled (true);

            // General Page
            var general_page = new Adw.PreferencesPage () {
                title = _("General"),
                icon_name = "preferences-system-symbolic"
            };
            add_controller_page (general_page);

            var appearance_group = new Adw.PreferencesGroup () {
                title = _("Appearance")
            };
            general_page.add (appearance_group);

            var theme_row = new ThemeRow ();
            theme_row.add_prefix (new Gtk.Image.from_icon_name ("palette-symbolic"));
            appearance_group.add (theme_row);

            var language_row = new LanguageRow ();
            language_row.add_prefix (new Gtk.Image.from_icon_name ("globe-symbolic"));
            appearance_group.add (language_row);

            var controller_group = new Adw.PreferencesGroup () {
                title = _("Controller")
            };
            general_page.add (controller_group);

            var confirm_button_choices = new Gtk.StringList (null);
            confirm_button_choices.append (_("Bottom face button"));
            confirm_button_choices.append (_("Right face button"));
            var confirm_button_row = new Adw.ComboRow () {
                title = _("Confirm button"),
                subtitle = _("Choose which face button activates the selected control"),
                model = confirm_button_choices
            };
            confirm_button_row.set_selected ((uint) Globals.SETTINGS.get_enum ("controller-confirm-button"));
            confirm_button_row.notify["selected"].connect (() => {
                var selected = (int) confirm_button_row.get_selected ();
                if (selected >= 0 && selected <= 1 &&
                    Globals.SETTINGS.get_enum ("controller-confirm-button") != selected)
                    Globals.SETTINGS.set_enum ("controller-confirm-button", selected);
            });
            controller_group.add (confirm_button_row);

            var controller_haptics_row = new Adw.SwitchRow () {
                title = _("Controller vibration"),
                subtitle = _("Use subtle vibration for controller actions and navigation limits")
            };
            Globals.SETTINGS.bind ("controller-haptics-enabled", controller_haptics_row,
                "active", SettingsBindFlags.DEFAULT);
            controller_group.add (controller_haptics_row);

            var help_page = new Adw.PreferencesGroup () {
                title = _("Help"),
            };
            var introduction_btn = new Adw.ButtonRow () {
                title = _("Show Introduction")
            };
            introduction_btn.set_start_icon_name ("help-about-symbolic");
            introduction_btn.activated.connect (() => {
                var window = this.get_root () as Window;
                var dialog = new Introduction.Introduction ();
                Window.present_dialog_for_controller (dialog, window);
            });
            help_page.add (introduction_btn);
            general_page.add (help_page);

            // Tools Page
            var tools_page = new Adw.PreferencesPage () {
                title = _("Tools"),
                icon_name = "toolbox-symbolic"
            };
            add_controller_page (tools_page);

            var updates_group = new Adw.PreferencesGroup () {
                title = _("Updates")
            };
            tools_page.add (updates_group);

            var background_updates_row = new Adw.SwitchRow () {
                title = _("Background updates"),
                subtitle = _("Automatically update the tools in the background"),
            };
            Globals.SETTINGS.bind ("background-updates", background_updates_row, "active", SettingsBindFlags.DEFAULT);
            updates_group.add (background_updates_row);

            var background_updates_frequency_row = new BackgroundUpdatesFrequencyRow () {
                subtitle = _("Set how often to check for updates in the background"),
            };
            background_updates_row.bind_property ("active", background_updates_frequency_row, "sensitive", BindingFlags.SYNC_CREATE);
            updates_group.add (background_updates_frequency_row);

            var check_updates_on_boot_row = new Adw.SwitchRow () {
                title = _("Check updates on boot"),
                subtitle = _("Check for tool updates when the system starts"),
            };
            Globals.SETTINGS.bind ("check-updates-on-boot", check_updates_on_boot_row, "active", SettingsBindFlags.DEFAULT);
            updates_group.add (check_updates_on_boot_row);

            var check_updates_on_launch_row = new Adw.SwitchRow () {
                title = _("Check updates on launch"),
                subtitle = _("Update the tools when the application is launched"),
            };
            Globals.SETTINGS.bind ("check-updates-on-launch", check_updates_on_launch_row, "active", SettingsBindFlags.DEFAULT);
            updates_group.add (check_updates_on_launch_row);

            var migrate_default_prefix_row = new Adw.SwitchRow () {
                title = _("Migrate default prefix"),
                subtitle = _("Automatically migrate the default prefix when updating"),
            };
            Globals.SETTINGS.bind ("migrate-default-prefix", migrate_default_prefix_row, "active", SettingsBindFlags.DEFAULT);
            updates_group.add (migrate_default_prefix_row);

            var tools_behavior_group = new Adw.PreferencesGroup () {
                title = _("Behavior")
            };
            tools_page.add (tools_behavior_group);

            var legacy_tools_row = new Adw.SwitchRow () {
                title = _("Show legacy tools"),
                subtitle = _("Display older tools that are no longer actively maintained"),
            };
            legacy_tools_row.add_prefix (new Gtk.Image.from_icon_name ("box-archive-symbolic"));
            Globals.SETTINGS.bind ("show-legacy-tools", legacy_tools_row, "active", SettingsBindFlags.DEFAULT);
            tools_behavior_group.add (legacy_tools_row);

            // Launchers Page
            var launchers_page = new Adw.PreferencesPage () {
                title = _("Launchers"),
                icon_name = "grip-symbolic"
            };

            bool has_launchers = false;
            foreach (var launcher in launchers) {
                if (launcher is ProtonPlus.Models.Launchers.Steam) {
                    var steam_launcher = launcher as ProtonPlus.Models.Launchers.Steam;

                    var steam_group = new Adw.PreferencesGroup () {
                        title = "Steam",
                    };

                    var compatibility_tools = new Gee.ArrayList<ProtonPlus.Models.CompatibilityTool> ();
                    foreach (var compatibility_tool in steam_launcher.compatibility_tools) {
                        if (compatibility_tool.is_assignable && compatibility_tool.is_available
                            && !Models.Launchers.Steam.is_steam_linux_runtime (compatibility_tool.display_title, compatibility_tool.internal_title))
                            compatibility_tools.add (compatibility_tool);
                    }
                    compatibility_tools.sort ((a, b) => {
                        return strcmp (
                            b.display_title.collate_key_for_filename (),
                            a.display_title.collate_key_for_filename ()
                        );
                    });

                    var model = new GLib.ListStore (typeof (ProtonPlus.Models.CompatibilityTool));
                    foreach (var compatibility_tool in compatibility_tools) {
                        model.append (compatibility_tool);
                    }

                    var expression = new Gtk.PropertyExpression (typeof (ProtonPlus.Models.CompatibilityTool), null, "display_title");

                    var compatibility_tool_row = new ToolRow (model, expression) {
                        title = _("Default compatibility tool"),
                        subtitle = _("The compatibility tool games will use by default")
                    };
                    compatibility_tool_row.add_prefix (new Gtk.Image.from_icon_name ("screwdriver-wrench-symbolic"));

                    for (var i = 0; i < (int) compatibility_tools.size; i++) {
                        if (compatibility_tools[i].internal_title == steam_launcher.default_compatibility_tool) {
                            compatibility_tool_row.set_selected ((uint) i);
                            break;
                        }
                    }

                    compatibility_tool_row.notify["selected-item"].connect (() => {
                        var selected_tool = compatibility_tool_row.get_selected_item () as ProtonPlus.Models.CompatibilityTool;
                        if (selected_tool != null) {
                            steam_launcher.change_default_compatibility_tool (selected_tool.internal_title);
                        }
                    });
                    steam_group.add (compatibility_tool_row);

                    if (steam_launcher.game_library_available && steam_launcher.profile != null) {
                        var profiles_model = new GLib.ListStore (typeof (ProtonPlus.Models.SteamProfile));
                        foreach (var profile in steam_launcher.profiles) {
                            profiles_model.append (profile);
                        }

                        var profile_row = new SteamProfileRow (profiles_model) {
                            title = _("Selected profile"),
                            subtitle = _("Currently selected profile for Steam"),
                        };
                        profile_row.add_prefix (new Gtk.Image.from_icon_name ("avatar-default-symbolic"));
                        profile_row.set_sensitive (steam_launcher.profiles.length () > 1);

                        var shortcut_row = new SteamShortcutRow (steam_launcher.profile);

                        var last_profile_id = Globals.SETTINGS.get_string ("steam-selected-profile-id");
                        for (var i = 0; i < (int) steam_launcher.profiles.length (); i++) {
                            if (steam_launcher.profiles.nth_data (i).steam_id == last_profile_id) {
                                profile_row.set_selected ((uint) i);
                                break;
                            }
                        }

                        profile_row.notify["selected-item"].connect (() => {
                            var selected_profile = profile_row.get_selected_item () as ProtonPlus.Models.SteamProfile;
                            if (selected_profile != null) {
                                Globals.SETTINGS.set_string ("steam-selected-profile-id", selected_profile.steam_id);
                                shortcut_row.load (selected_profile);
                                steam_launcher.switch_profile.begin (selected_profile);
                            }
                        });
                        steam_group.add (profile_row);
                        steam_group.add (shortcut_row);
                    }

                    launchers_page.add (steam_group);
                    has_launchers = true;
                    break;
                }
            }

            if (has_launchers) {
                add_controller_page (launchers_page);
            }

            // Advanced Page
            var advanced_page = new Adw.PreferencesPage () {
                title = _("Advanced"),
                icon_name = "preferences-other-symbolic"
            };
            add_controller_page (advanced_page);

            var tokens_group = new Adw.PreferencesGroup () {
                title = _("API Tokens")
            };
            advanced_page.add (tokens_group);

            var github_access_token_row = new AccessTokenRow (
                "GitHub",
                "github-symbolic",
                "https://github.com/settings/tokens"
            );
            Globals.SETTINGS.bind ("github-api-key", github_access_token_row, "text", SettingsBindFlags.DEFAULT);
            tokens_group.add (github_access_token_row);

            var gitlab_access_token_row = new AccessTokenRow (
                "GitLab",
                "gitlab-symbolic",
                "https://gitlab.com/-/user_settings/personal_access_tokens"
            );
            Globals.SETTINGS.bind ("gitlab-api-key", gitlab_access_token_row, "text", SettingsBindFlags.DEFAULT);
            tokens_group.add (gitlab_access_token_row);

            var network_group = new Adw.PreferencesGroup () {
                title = _("Network")
            };
            advanced_page.add (network_group);

            var proxy_mode_row = new ProxyModeRow ();
            network_group.add (proxy_mode_row);

            proxy_url_row = new Adw.EntryRow () {
                title = _("Proxy URL"),
            };
            Utils.TextInputMetadataPolicy.apply ((!) proxy_url_row, Utils.TextInputFieldKind.URL);
            proxy_url_row.set_tooltip_text (_("Example: http://127.0.0.1:7890 or socks5://127.0.0.1:1080"));
            proxy_url_row.set_sensitive (Globals.SETTINGS.get_enum ("proxy-mode") == 1);
            Globals.SETTINGS.bind ("proxy-url", proxy_url_row, "text", SettingsBindFlags.DEFAULT);
            proxy_mode_changed_handler = Globals.SETTINGS.changed["proxy-mode"].connect (update_proxy_url_sensitivity);
            network_group.add (proxy_url_row);

            var experimental_group = new Adw.PreferencesGroup () {
                title = _("Experimental")
            };
            advanced_page.add (experimental_group);

            var experimental_features_row = new Adw.SwitchRow () {
                title = _("Preview features"),
                subtitle = _("Enable experimental features for early testing"),
            };
            experimental_features_row.add_prefix (new Gtk.Image.from_icon_name ("flask-symbolic"));
            Globals.SETTINGS.bind ("experimental-features", experimental_features_row, "active", SettingsBindFlags.DEFAULT);
            experimental_group.add (experimental_features_row);

            var maintenance_group = new Adw.PreferencesGroup () {
                title = _("Maintenance")
            };
            advanced_page.add (maintenance_group);
            maintenance_group.add (new RefreshApplicationDataRow ());
            maintenance_group.add (new DeleteCacheRow ());

            // System Page
            var system_page = new Adw.PreferencesPage () {
                title = _("System"),
                icon_name = "dialog-information-symbolic"
            };
            add_controller_page (system_page);

            var environment_group = new Adw.PreferencesGroup () {
                title = _("Software Environment")
            };
            system_page.add (environment_group);

            environment_group.add (new Adw.ActionRow () {
                title = _("SteamOS"),
                subtitle = Globals.IS_STEAM_OS ? _("Yes") : _("No")
            });

            environment_group.add (new Adw.ActionRow () {
                title = _("Flatpak"),
                subtitle = Globals.IS_FLATPAK ? _("Yes") : _("No")
            });

            var hardware_group = new Adw.PreferencesGroup () {
                title = _("Hardware")
            };
            system_page.add (hardware_group);

            string hwcaps_str = "";
            foreach (var hwcap in Globals.HWCAPS) {
                if (hwcaps_str != "")
                    hwcaps_str += ", ";
                hwcaps_str += hwcap;
            }

            hardware_group.add (new Adw.ActionRow () {
                title = _("HWCAPS"),
                subtitle = hwcaps_str
            });

            var dependencies_group = new Adw.PreferencesGroup () {
                title = _("Dependencies")
            };
            system_page.add (dependencies_group);

            dependencies_group.add (new Adw.ActionRow () {
                title = _("Protontricks"),
                subtitle = Globals.PROTONTRICKS_INSTALLED ? _("Yes") : _("No")
            });

            dependencies_group.add (new Adw.ActionRow () {
                title = _("Protontricks (Flatpak)"),
                subtitle = Globals.PROTONTRICKS_FLATPAK_INSTALLED ? _("Yes") : _("No")
            });

            dependencies_group.add (new Adw.ActionRow () {
                title = _("MangoHud"),
                subtitle = Globals.MANGOHUD_INSTALLED ? _("Yes") : _("No")
            });

            dependencies_group.add (new Adw.ActionRow () {
                title = _("MangoHud (Flatpak)"),
                subtitle = Globals.MANGOHUD_FLATPAK_INSTALLED ? _("Yes") : _("No")
            });

            dependencies_group.add (new Adw.ActionRow () {
                title = _("Gamescope"),
                subtitle = Globals.GAMESCOPE_INSTALLED ? _("Yes") : _("No")
            });

            dependencies_group.add (new Adw.ActionRow () {
                title = _("ScopeBuddy"),
                subtitle = Globals.SCOPEBUDDY_INSTALLED ? _("Yes") : _("No")
            });

            dependencies_group.add (new Adw.ActionRow () {
                title = _("Feral Gamemode"),
                subtitle = Globals.GAMEMODE_INSTALLED ? _("Yes") : _("No")
            });

            var detected_launchers_group = new Adw.PreferencesGroup () {
                title = _("Detected Launchers")
            };
            system_page.add (detected_launchers_group);

            ProtonPlus.Models.Launcher[] all_launchers = {
                new ProtonPlus.Models.Launchers.Steam (ProtonPlus.Models.Launcher.InstallationTypes.SYSTEM),
                new ProtonPlus.Models.Launchers.Steam (ProtonPlus.Models.Launcher.InstallationTypes.FLATPAK),
                new ProtonPlus.Models.Launchers.Steam (ProtonPlus.Models.Launcher.InstallationTypes.SNAP),
                new ProtonPlus.Models.Launchers.FaugusLauncher (ProtonPlus.Models.Launcher.InstallationTypes.SYSTEM),
                new ProtonPlus.Models.Launchers.FaugusLauncher (ProtonPlus.Models.Launcher.InstallationTypes.FLATPAK),
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
                    subtitle = launcher.installed ? _("Installed") : _("Not installed")
                });
            }
        }

        void add_controller_page (Adw.PreferencesPage page) {
            add (page);
            controller_pages += page;
        }

        void update_proxy_url_sensitivity () {
            if (proxy_url_row != null)
                proxy_url_row.set_sensitive (Globals.SETTINGS.get_enum ("proxy-mode") == 1);
        }

        public override void dispose () {
            if (proxy_mode_changed_handler != 0 && Globals.SETTINGS != null) {
                Globals.SETTINGS.disconnect (proxy_mode_changed_handler);
                proxy_mode_changed_handler = 0;
            }

            proxy_url_row = null;
            base.dispose ();
        }

        public bool controller_switch_page (int delta) {
            int count = controller_pages.length;
            if (count < 2)
                return false;

            var current = visible_page;
            int current_index = 0;
            for (int i = 0; i < count; i++) {
                if (controller_pages[i] == current) {
                    current_index = i;
                    break;
                }
            }

            for (int step = 1; step <= count; step++) {
                int index = ((current_index + delta * step) % count + count) % count;
                if (controller_pages[index].visible && controller_pages[index] != current) {
                    visible_page = controller_pages[index];
                    return true;
                }
            }
            return false;
        }

        public bool controller_can_switch_page () {
            int visible_count = 0;
            foreach (var page in controller_pages) {
                if (page.visible)
                    visible_count++;
            }
            return visible_count >= 2;
        }

        public bool controller_prefers_initial_focus_after_switch () {
            return true;
        }

        public string get_controller_page_id () {
            for (int i = 0; i < controller_pages.length; i++) {
                if (controller_pages[i] == visible_page)
                    return "preferences:%d".printf (i);
            }
            return "preferences:unknown";
        }

        public Object? get_controller_page_root () {
            return visible_page;
        }

        public Object? get_controller_initial_focus () {
            var page = visible_page;
            return page == null ? null : find_first_preferences_row (page);
        }

        Gtk.Widget? find_first_preferences_row (Gtk.Widget root) {
            if (!root.get_mapped () || !root.is_visible () || !root.is_sensitive ())
                return null;
            if (root is Adw.PreferencesRow && root.get_focusable ())
                return root;

            var child = root.get_first_child ();
            while (child != null) {
                var target = find_first_preferences_row (child);
                if (target != null)
                    return target;
                child = child.get_next_sibling ();
            }
            return null;
        }

        public bool controller_navigate_back () {
            return false;
        }

        public bool controller_can_navigate_back () {
            return false;
        }
    }
}
