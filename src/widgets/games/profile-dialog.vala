namespace ProtonPlus.Widgets {
	public class ProfileDialog : Adw.Dialog {
		GamesBox.load_steam_profile_func load_steam_profile_func;
		Models.Launchers.Steam launcher { get; set; }
		Adw.HeaderBar header_bar { get; set; }
		Adw.ToolbarView toolbar_view { get; set; }
		Adw.WindowTitle window_title { get; set; }
		Gtk.Box content_box { get; set; }
		bool profile_selected { get; set; }

		public ProfileDialog (Models.Launchers.Steam launcher, GamesBox.load_steam_profile_func load_steam_profile_func) {
			this.launcher = launcher;
			this.load_steam_profile_func = load_steam_profile_func;

			window_title = new Adw.WindowTitle (_("Select a profile"), "");

			header_bar = new Adw.HeaderBar ();
			header_bar.set_title_widget (window_title);
			header_bar.set_show_end_title_buttons (false);

			content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
			content_box.set_margin_start (10);
			content_box.set_margin_end (10);
			content_box.set_margin_bottom (10);
			content_box.set_halign (Gtk.Align.CENTER);

			foreach (var profile in launcher.profiles) {
				var profile_button = new ProfileButton (profile, this);
				profile_button.gesture_click.released.connect (() => profile_button_clicked (profile));
				content_box.append (profile_button);
			}

			toolbar_view = new Adw.ToolbarView ();
			toolbar_view.add_top_bar (header_bar);
			toolbar_view.set_content (content_box);

			set_can_close (false);
			set_child (toolbar_view);
		}

		void profile_button_clicked (Models.SteamProfile profile) {
			profile_selected = true;
			load_steam_profile_func (profile);
			if (Globals.SETTINGS != null)
				Globals.SETTINGS.set_string ("steam-last-profile-id", profile.steam_id);
			set_can_close (true);
			close ();
		}
	}
}
