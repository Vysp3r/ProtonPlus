namespace ProtonPlus.Widgets {
	public class Application : Adw.Application {
		public static Window window { get; set; }

		construct {
			application_id = Globals.APP_ID;
			flags |= ApplicationFlags.FLAGS_NONE;

			ActionEntry[] action_entries = {
				{ "about", this.on_about_action },
				{ "quit", this.quit }
			};
			this.add_action_entries (action_entries, this);
			this.set_accels_for_action ("app.quit", { "<Ctrl>Q" });
		}

		public override void activate () {
			base.activate ();

			var display = Gdk.Display.get_default ();

			Gtk.IconTheme.get_for_display (display).add_resource_path ("/com/vysp3r/ProtonPlus/icons");

			var css_provider = new Gtk.CssProvider ();
			css_provider.load_from_resource ("/com/vysp3r/ProtonPlus/css/style.css");

			Gtk.StyleContext.add_provider_for_display (display, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

			window = new Window ();

			var settings = new Settings ("com.vysp3r.ProtonPlus.State");
			settings.bind ("width",
			               window,
			               "default-width",
			               SettingsBindFlags.DEFAULT);
			settings.bind ("height",
			               window,
			               "default-height",
			               SettingsBindFlags.DEFAULT);
			settings.bind ("is-maximized",
			               window,
			               "maximized",
			               SettingsBindFlags.DEFAULT);
			settings.bind ("is-fullscreen",
			               window,
			               "fullscreened",
			               SettingsBindFlags.DEFAULT);

			load_globals.begin ((obj, res) => {
				if (Globals.IS_GAMESCOPE)
					window.fullscreen ();

				window.present ();
			});
		}

		async void load_globals () {
			Globals.IS_FLATPAK = FileUtils.test ("/.flatpak-info", FileTest.IS_REGULAR);
			Globals.IS_GAMESCOPE = Environment.get_variable ("DESKTOP_SESSION") == "gamescope-wayland";
			Globals.IS_STEAM_OS = (yield Utils.System.get_distribution_name ()).ascii_down () == "steamos";
			Globals.HWCAPS = Utils.System.get_hwcaps ();

			Globals.DOWNLOAD_CACHE_PATH = "%s/ProtonPlus".printf (Environment.get_user_cache_dir ());
			if (!FileUtils.test (Globals.DOWNLOAD_CACHE_PATH, FileTest.IS_DIR))
				yield Utils.Filesystem.create_directory (Globals.DOWNLOAD_CACHE_PATH);
		}

		void on_about_action () {
			const string[] devs = {
				"Charles Malouin (Vysp3r) https://github.com/Vysp3r",
				"Johnny Arcitec https://github.com/Arcitec",
				"nickexe https://github.com/nickexe",
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
			about_dialog.set_application_name (Globals.APP_NAME);
			about_dialog.set_application_icon (Globals.APP_ID);
			about_dialog.set_version ("v" + Globals.APP_VERSION);
			about_dialog.set_comments (_("A modern compatibility tools manager for Linux."));
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
