namespace ProtonPlus.Widgets.Preferences {
    public class SteamProfileRow : Adw.ComboRow {
        Gtk.SignalListItemFactory profile_factory;

        public SteamProfileRow (GLib.ListStore model) {
            profile_factory = new Gtk.SignalListItemFactory ();
            profile_factory.setup.connect (profile_factory_setup);
            profile_factory.bind.connect (profile_factory_bind);

            set_model (model);
            set_expression (new Gtk.PropertyExpression (typeof (Models.SteamProfile), null, "username"));
            set_list_factory (profile_factory);
        }

        void profile_factory_setup (Object object) {
            var list_item = object as Gtk.ListItem;

            var avatar = new Adw.Avatar (36, null, true);
            var username_label = new Gtk.Label (null) {
                xalign = 0.0f,
                ellipsize = Pango.EllipsizeMode.END,
                hexpand = true,
            };
            var steam_id_label = new Gtk.Label (null) {
                xalign = 0.0f,
                ellipsize = Pango.EllipsizeMode.END,
            };
            steam_id_label.add_css_class ("dim-label");
            steam_id_label.add_css_class ("caption");
            var labels = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
                valign = Gtk.Align.CENTER,
            };
            labels.append (username_label);
            labels.append (steam_id_label);

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                margin_top = 6,
                margin_bottom = 6,
                margin_start = 6,
                margin_end = 6,
            };
            box.append (avatar);
            box.append (labels);

            object.set_data ("avatar", avatar);
            object.set_data ("username", username_label);
            object.set_data ("steam-id", steam_id_label);
            list_item.set_child (box);
        }

        void profile_factory_bind (Object object) {
            var list_item = object as Gtk.ListItem;
            var profile = list_item.get_item () as Models.SteamProfile;
            if (profile == null)
                return;

            var avatar = object.get_data<Adw.Avatar> ("avatar");
            avatar.set_text (profile.username);
            avatar.set_custom_image (null);
            if (FileUtils.test (profile.image_path, FileTest.IS_REGULAR)) {
                var profile_image = new Gtk.Image.from_file (profile.image_path);
                avatar.set_custom_image (profile_image.get_paintable ());
            }

            object.get_data<Gtk.Label> ("username").set_label (profile.username);
            object.get_data<Gtk.Label> ("steam-id").set_label (profile.steam_id);
        }
    }
}
