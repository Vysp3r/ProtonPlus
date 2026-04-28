namespace ProtonPlus.Widgets.Games {
    public class SwitchProfileButton : Gtk.Button {
        public signal void load_steam_profile (Models.SteamProfile profile);
        Models.Launchers.Steam launcher;
        Gtk.ListBox game_list_box;

        Gtk.Image content_image;
        Gtk.Label content_label;
        Gtk.Box content;

        public SwitchProfileButton () {
            content_image = new Gtk.Image ();

            content_label = new Gtk.Label (_ ("Switch profile"));

            content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            content.append (content_image);
            content.append (content_label);

            clicked.connect (switch_profile_button_clicked);

            set_child (content);
            set_tooltip_text (_ ("Switch to another profile"));
            add_css_class ("flat");
        }

        public void load (Models.Launchers.Steam launcher, Gtk.ListBox game_list_box) {
            this.launcher = launcher;
            this.game_list_box = game_list_box;

            content_image.set_visible (false);

            launcher.notify["profile"].connect (() => {
                profile_changed ();
            });
        }

        void profile_changed () {
            var profile_valid = launcher.profile != null && launcher.profile.image_path != null;
            if (profile_valid)
            content_image.set_from_file (launcher.profile.image_path);

            content_image.set_visible (profile_valid);
        }

        void switch_profile_button_clicked () {
            game_list_box.remove_all ();

        //            var dialog = new ProfileDialog(launcher);
        //            dialog.load_steam_profile.connect ((profile) => load_steam_profile (profile));
        //            dialog.present (Application.window);
        }
    }
}