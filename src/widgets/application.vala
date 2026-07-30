namespace ProtonPlus.Widgets {
    [CCode (cheader_filename = "gtk/gtk.h", cname = "gtk_style_context_add_provider_for_display")]
    public static extern void add_provider_for_display (Gdk.Display display, Gtk.StyleProvider provider, uint priority);

    public class Application : Adw.Application {
        Preferences.PreferencesDialog? active_preferences_dialog = null;
        bool reopen_preferences_after_close = false;
        ProtonPlus.Services.Migrations.Manager? migration_manager = null;
        ProtonPlus.Services.SteamSessionService? steam_session_service = null;
        ProtonPlus.Services.SteamRestartManager? steam_restart_manager = null;
        ProtonPlus.Services.SteamRestartOrchestrator? steam_restart_orchestrator = null;
        bool show_introduction = false;

        construct {
            application_id = Config.APP_ID;
            flags |= ApplicationFlags.FLAGS_NONE;

            ActionEntry[] action_entries = {
                { "report", this.on_report_action },
                { "preferences", this.on_preferences_action },
                { "about", this.on_about_action },
                { "donate", this.on_donate_action },
                { "reload", this.on_reload_action },
                { "introduction", this.on_introduction_action },
                { "on_language_change", this.on_language_change },
                { "quit", this.on_quit_action },
            };
            this.add_action_entries (action_entries, this);
            this.set_accels_for_action ("app.quit", { "<Ctrl>Q" });
            this.set_accels_for_action ("app.preferences", { "<Ctrl>comma" });
        }

        public override void activate () {
            base.activate ();

            var window = this.active_window as Window;
            if (window != null) {
                window.present ();
                return;
            }

            window = new Window ((!) steam_restart_manager, (!) steam_restart_orchestrator);

            Globals.SETTINGS.bind ("width",
                                   window,
                                   "default-width",
                                   SettingsBindFlags.DEFAULT);
            Globals.SETTINGS.bind ("height",
                                   window,
                                   "default-height",
                                   SettingsBindFlags.DEFAULT);
            Globals.SETTINGS.bind ("is-maximized",
                                   window,
                                   "maximized",
                                   SettingsBindFlags.DEFAULT);
            Globals.SETTINGS.bind ("is-fullscreen",
                                   window,
                                   "fullscreened",
                                   SettingsBindFlags.DEFAULT);

            window.present ();

            if (show_introduction) {
                show_introduction = false;
                present_introduction (window);
            }

            if (migration_manager != null) {
                migration_manager.post_migrate (new ProtonPlus.Services.Migrations.MigrationContext (window));
                migration_manager = null;
            }
        }

        public override void startup () {
            base.startup ();

            var display = Gdk.Display.get_default ();

            Gtk.IconTheme.get_for_display (display).add_resource_path ("/com/vysp3r/ProtonPlus/icons");

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/com/vysp3r/ProtonPlus/style.css");
            add_provider_for_display (display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var status_provider = new Gtk.CssProvider ();
            status_provider.load_from_resource ("/com/vysp3r/ProtonPlus/status.css");
            add_provider_for_display (display, status_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 2);

            Globals.load ();
            Globals.setupLanguage ();
            Notify.init (Config.APP_NAME);

            /* This graph belongs to the GUI process, not individual rebuilt
             * windows.  CLI execution never instantiates Application. */
            steam_session_service = new ProtonPlus.Services.SteamSessionService ();
            steam_restart_manager = new ProtonPlus.Services.SteamRestartManager ((!) steam_session_service, new ProtonPlus.Services.SteamRestartStateStore ());
            steam_restart_orchestrator = new ProtonPlus.Services.SteamRestartOrchestrator ((!) steam_session_service, (!) steam_restart_manager);
            steam_restart_manager.start_observation ();

            if (Globals.SETTINGS != null) {
                migration_manager = new ProtonPlus.Services.Migrations.Manager ();
                migration_manager.check_and_migrate_sync (Config.APP_VERSION);

                show_introduction = Globals.SETTINGS.get_boolean ("first-run");
                if (show_introduction)
                    Globals.SETTINGS.set_boolean ("first-run", false);

                Utils.ThemeManager.get_default ().apply_theme ();

                Globals.SETTINGS.changed["check-updates-on-boot"].connect (Utils.System.systemd_handler);
                Globals.SETTINGS.changed["background-updates"].connect (Utils.System.systemd_handler);
                Globals.SETTINGS.changed["background-updates-frequency"].connect (Utils.System.systemd_handler);
                Globals.SETTINGS.changed["proxy-mode"].connect (Utils.Web.update_proxy_settings);
                Globals.SETTINGS.changed["proxy-url"].connect (Utils.Web.update_proxy_settings);
            } else {
                error ("GSettings schema not found or invalid: 'com.vysp3r.ProtonPlus.State'");
            }
        }

        public override void shutdown () {
            var window = this.active_window as Window;
            if (window != null)
                window.main_box.cancel_steam_restart ();
            if (steam_restart_manager != null)
                steam_restart_manager.stop_observation ();
            Notify.uninit ();
            base.shutdown ();
        }

        void on_introduction_action () {
            var window = this.active_window as Window;
            if (window == null)
                return;

            present_introduction (window);
        }

        void present_introduction (Window window) {
            var dialog = new Introduction.Introduction ();
            window.present_controller_dialog (dialog);
        }

        void on_report_action () {
            Utils.System.open_uri ("https://github.com/Vysp3r/ProtonPlus/issues/new?template=bug_report.md");
        }

        void on_preferences_action () {
            var window = this.active_window as Window;
            if (window == null || active_preferences_dialog != null)
                return;

            var preferences_dialog = new Preferences.PreferencesDialog (window.launchers);
            active_preferences_dialog = preferences_dialog;
            preferences_dialog.closed.connect (on_preferences_dialog_closed);
            window.present_controller_dialog (preferences_dialog);
        }

        void on_preferences_dialog_closed () {
            active_preferences_dialog = null;

            if (reopen_preferences_after_close) {
                reopen_preferences_after_close = false;
                on_preferences_action ();
            }
        }

        void on_donate_action () {
            Utils.System.open_uri ("https://protonplus.vysp3r.com/#donate");
        }

        void on_reload_action () {
            (this.active_window as Window) ? .reload ();
        }

        void on_quit_action () {
            var window = this.active_window as Window;
            if (window != null)
                window.close ();
            else
                quit ();
        }

        public void on_language_change () {
            var main_window = this.active_window as Window;

            if (main_window != null) {
                main_window.reload_ui ();
                main_window.reload ();

                if (active_preferences_dialog != null) {
                    reopen_preferences_after_close = true;
                    active_preferences_dialog.close ();
                }
            }
        }

        void on_about_action () {
            const string[] devs = {
                "Vysp3r https://github.com/Vysp3r",
                "nick.exe https://github.com/nickexe",
                "windblows95 https://github.com/windblows95",
                "JanGalek https://github.com/JanGalek",
                null
            };

            const string[] thanks = {
                "GNOME Project https://www.gnome.org/",
                "ProtonUp-Qt Project https://davidotek.github.io/protonup-qt/",
                "LUG Helper Project https://github.com/starcitizen-lug/lug-helper/",
                "Font Awesome https://fontawesome.com/",
                null
            };

            var meta = new Utils.Internal.MetaInfoLoader ();
            var model = meta.load ();


            var about_dialog = new Adw.AboutDialog ();
            about_dialog.set_application_name (Config.APP_NAME);
            about_dialog.set_application_icon (Config.APP_ID);
            about_dialog.set_version ("v" + Config.APP_VERSION);
            about_dialog.set_comments (_("A modern compatibility tools manager"));
            about_dialog.add_link ("GitHub", "https://github.com/Vysp3r/ProtonPlus");
            about_dialog.add_link (_("Website"), "https://protonplus.vysp3r.com/");
            about_dialog.set_issue_url ("https://github.com/Vysp3r/ProtonPlus/issues/new/choose");
            about_dialog.set_copyright (get_copyright ());
            about_dialog.set_license_type (Gtk.License.GPL_3_0);
            about_dialog.set_developers (devs);
            about_dialog.set_translator_credits (_("translator-credits"));
            about_dialog.add_credit_section (_("Special thanks to"), thanks);

            if (model != null) {
                var last_release = model.get_last_release ();

                about_dialog.set_release_notes (last_release.description);
                about_dialog.set_release_notes_version (last_release.version);
            }
            Window.present_dialog_for_controller (about_dialog, this.active_window);
        }

        private static string get_copyright () {
            var current = new DateTime.now_local ();
            if (current == null) {
                return "© 2022 Vysp3r";
            }

            var current_year = current.get_year ();

            return "© 2022-" + current_year.to_string () + " Vysp3r";
        }
    }
}
