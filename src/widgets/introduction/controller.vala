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
            this.append (image);

            var title_label = new Gtk.Label (_("Controller support"));
            title_label.add_css_class ("title-1");
            title_label.wrap = true;
            title_label.justify = Gtk.Justification.CENTER;
            title_label.width_chars = 25;
            title_label.max_width_chars = 25;
            this.append (title_label);

            var feature_rows = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            feature_rows.set_hexpand (true);

            var row0 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 24);
            row0.set_hexpand (true);
            row0.set_homogeneous (true);
            row0.append (create_feature (
                _("Navigation"),
                _("Use the D-pad or sticks to move through pages, dialogs, and menus. Switch sections with the shoulder buttons.")
            ));
            row0.append (create_feature (
                _("Actions"),
                _("Use the face buttons for Confirm, Back, Search, and Filter. Hints match your controller's button labels.")
            ));

            var row1 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 24);
            row1.set_hexpand (true);
            row1.set_homogeneous (true);
            row1.append (create_feature (
                _("Preferences"),
                _("Choose the Confirm button and enable controller vibration in Preferences.")
            ));
            row1.append (create_feature (
                _("Text input"),
                _("On Steam Deck, focus a text field and press Steam + X. Other systems may require a physical or system keyboard.")
            ));

            feature_rows.append (row0);
            feature_rows.append (row1);
            this.append (feature_rows);
        }

        private Gtk.Widget create_feature (string title, string description) {
            var feature = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            feature.set_valign (Gtk.Align.START);
            feature.hexpand = true;
            feature.vexpand = true;

            var title_label = new Gtk.Label (title);
            title_label.add_css_class ("heading");
            title_label.set_xalign (0);
            title_label.set_wrap (true);
            title_label.set_width_chars (15);
            title_label.set_max_width_chars (15);
            feature.append (title_label);

            var description_label = new Gtk.Label (description);
            description_label.add_css_class ("caption");
            description_label.add_css_class ("dim-label");
            description_label.set_xalign (0);
            description_label.set_wrap (true);
            description_label.set_width_chars (28);
            description_label.set_max_width_chars (28);
            feature.append (description_label);

            return feature;
        }
    }
}
