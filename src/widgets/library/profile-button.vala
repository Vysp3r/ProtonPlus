namespace ProtonPlus.Widgets {
	public class ProfileButton : Gtk.Box {
		Models.SteamProfile profile { get; set; }
		ProfileDialog profile_dialog { get; set; }
		Gtk.Image profile_image { get; set; }
		Adw.Avatar profile_avatar { get; set; }
		Gtk.Label profile_label { get; set; }
		public Gtk.GestureClick gesture_click { get; set; }

		public ProfileButton (Models.SteamProfile profile, ProfileDialog profile_dialog) {
			this.profile = profile;
			this.profile_dialog = profile_dialog;

			gesture_click = new Gtk.GestureClick ();

			profile_image = new Gtk.Image.from_file (profile.image_path);

			profile_avatar = new Adw.Avatar (96, null, false);
			profile_avatar.set_custom_image (profile_image.get_paintable ());
			profile_avatar.set_can_focus (true);

			profile_label = new Gtk.Label (profile.username);

			set_orientation (Gtk.Orientation.VERTICAL);
			set_halign (Gtk.Align.CENTER);
			set_spacing (10);
			set_margin_start (10);
			set_margin_end (10);
			set_margin_bottom (10);
			add_css_class ("p-10");
			add_css_class ("activatable");
			add_css_class ("card");
			add_controller (gesture_click);
			append (profile_avatar);
			append (profile_label);
		}
	}
}
