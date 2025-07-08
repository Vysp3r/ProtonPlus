namespace ProtonPlus.Widgets {
    public class SwitchProfileButton : Gtk.Button {
        Models.Launchers.Steam launcher;
        GamesBox.load_steam_profile_func load_steam_profile;
        Gtk.ListBox game_list_box;

        Gtk.Image image;
        Gtk.Label label;
        Gtk.Box content;

        public SwitchProfileButton () {
            image = new Gtk.Image ();

            label = new Gtk.Label (_("Switch profile"));

            content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            content.append (image);
            content.append (label);

            clicked.connect(switch_profile_button_clicked);

            set_child (content);
            set_tooltip_text(_("Switch to another profile"));
			add_css_class("flat");
        }

        public void load (Models.Launchers.Steam launcher, GamesBox.load_steam_profile_func load_steam_profile, Gtk.ListBox game_list_box) {
            this.launcher = launcher;
            this.load_steam_profile = load_steam_profile;
            this.game_list_box = game_list_box;

            image.set_visible (false);

            launcher.notify["profile"].connect (() => {
                profile_changed();
            });
        }

        void profile_changed () {
            var profile_valid = launcher.profile != null && launcher.profile.image_path != null;
            if (profile_valid)
                image.set_from_file (launcher.profile.image_path);
            
            image.set_visible (profile_valid);
        }

        void switch_profile_button_clicked() {
            game_list_box.remove_all();

			var dialog = new ProfileDialog(launcher, load_steam_profile);
			dialog.present(Application.window);
		}
    }
}