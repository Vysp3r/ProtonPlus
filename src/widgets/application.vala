namespace ProtonPlus.Widgets {
	public class Application : Adw.Application {
		public static Window window;

		construct {
			application_id = Config.APP_ID;
			flags |= ApplicationFlags.FLAGS_NONE;

			ActionEntry[] action_entries = {
				{ "preferences", this.on_preferences_action },
				{ "about", this.on_about_action },
				{ "quit", this.quit }
			};
			this.add_action_entries (action_entries, this);
			this.set_accels_for_action ("app.quit", { "<Ctrl>Q" });
			this.set_accels_for_action ("app.preferences", { "<Ctrl>comma" });
		}

		public override void activate () {
			base.activate ();

			var display = Gdk.Display.get_default ();

			Gtk.IconTheme.get_for_display (display).add_resource_path ("/com/vysp3r/ProtonPlus/icons");

			window = new Window ();

			Globals.load.begin ((obj, res) => {
				if (Globals.SETTINGS != null) {
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

					var style_manager = Adw.StyleManager.get_default();
					style_manager.set_color_scheme(Globals.SETTINGS.get_enum ("theme"));
				} else {
					warning ("GSettings schema not found: 'com.vysp3r.ProtonPlus.State'");

					window.default_width = 950;
					window.default_height = 600;
					window.maximized = false;
					window.fullscreened = false;
				}

				window.present ();
			});
		}

		void on_preferences_action () {
			var preferences_dialog = new Preferences.PreferencesDialog ();
			preferences_dialog.present (window);
		}

		void on_about_action () {
			const string[] devs = {
				"Vysp3r https://github.com/Vysp3r",
				"nick.exe https://github.com/nickexe",
				"windblows95 https://github.com/windblows95",
				null
			};

			const string[] thanks = {
				"GNOME Project https://www.gnome.org/",
				"ProtonUp-Qt Project https://davidotek.github.io/protonup-qt/",
				"LUG Helper Project https://github.com/starcitizen-lug/lug-helper",
				null
			};

			var about_dialog = new Adw.AboutDialog ();
			about_dialog.set_application_name (Config.APP_NAME);
			about_dialog.set_application_icon (Config.APP_ID);
			about_dialog.set_version ("v" + Config.APP_VERSION);
			about_dialog.set_comments (_("A modern compatibility tools manager"));
			about_dialog.add_link ("GitHub", "https://github.com/Vysp3r/ProtonPlus");
			about_dialog.add_link (_("Website"), "https://protonplus.vysp3r.com/");
			about_dialog.set_issue_url ("https://github.com/Vysp3r/ProtonPlus/issues/new/choose");
			about_dialog.set_copyright ("© 2022-2025 Vysp3r");
			about_dialog.set_license_type (Gtk.License.GPL_3_0);
			about_dialog.set_developers (devs);
			about_dialog.add_credit_section (_("Special thanks to"), thanks);
			about_dialog.present (window);
		}
	}
}
