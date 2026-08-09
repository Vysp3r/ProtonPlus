namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Controller : Gtk.Box {
        public Controller () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);
            hexpand = true;
            vexpand = true;
            valign = Gtk.Align.CENTER;
            margin_top = 16;
            margin_bottom = 16;
            margin_start = 16;
            margin_end = 16;

            var image = new Gtk.Image.from_icon_name ("gamepad-symbolic");
            image.pixel_size = 56;
            append (image);

            var title_label = new Gtk.Label (_("Controller support"));
            title_label.add_css_class ("title-1");
            title_label.wrap = true;
            title_label.justify = Gtk.Justification.CENTER;
            append (title_label);

            var feature_grid = new Gtk.Grid ();
            feature_grid.set_column_homogeneous (true);
            feature_grid.set_column_spacing (24);
            feature_grid.set_row_spacing (12);
            feature_grid.set_hexpand (true);

            feature_grid.attach (create_feature (
                _("Navigation"),
                _("Use the D-pad or sticks to move through pages, dialogs, and menus. Switch sections with the shoulder buttons.")
            ), 0, 0, 1, 1);
            feature_grid.attach (create_feature (
                _("Actions"),
                _("Use the face buttons for Confirm, Back, Search, and Filter. Hints match your controller's button labels.")
            ), 1, 0, 1, 1);
            feature_grid.attach (create_feature (
                _("Preferences"),
                _("Choose the Confirm button and enable controller vibration in Preferences.")
            ), 0, 1, 1, 1);
            feature_grid.attach (create_feature (
                _("Text input"),
                _("On Steam Deck, focus a text field and press Steam + X. Other systems may require a physical or system keyboard.")
            ), 1, 1, 1, 1);
            append (feature_grid);
        }

        private Gtk.Widget create_feature (string title, string description) {
            var feature = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            feature.set_valign (Gtk.Align.START);

            var title_label = new Gtk.Label (title);
            title_label.add_css_class ("heading");
            title_label.set_xalign (0);
            title_label.set_wrap (true);
            feature.append (title_label);

            var description_label = new Gtk.Label (description);
            description_label.add_css_class ("caption");
            description_label.add_css_class ("dim-label");
            description_label.set_xalign (0);
            description_label.set_wrap (true);
            feature.append (description_label);

            return feature;
        }
    }
}
