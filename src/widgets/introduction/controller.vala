namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Controller : Gtk.Box {
        public Controller () {
            Object (orientation: Gtk.Orientation.VERTICAL);
            hexpand = true;
            vexpand = true;

            var scrolled = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                hexpand = true,
                vexpand = true
            };

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            content.hexpand = true;
            content.vexpand = true;
            content.valign = Gtk.Align.CENTER;
            content.margin_top = 16;
            content.margin_bottom = 16;
            content.margin_start = 16;
            content.margin_end = 16;

            var image = new Gtk.Image.from_icon_name ("gamepad-symbolic");
            image.pixel_size = 56;
            content.append (image);

            var title_label = new Gtk.Label (_("Controller support"));
            title_label.add_css_class ("title-1");
            title_label.wrap = true;
            title_label.justify = Gtk.Justification.CENTER;
            title_label.max_width_chars = 25;
            content.append (title_label);

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

            var responsive = new Adw.BreakpointBin ();
            responsive.set_size_request (360, 1);
            responsive.set_child (feature_rows);

            var narrow = new Adw.Breakpoint (new Adw.BreakpointCondition.length (
                Adw.BreakpointConditionLengthType.MAX_WIDTH, 420, Adw.LengthUnit.PX
            ));
            narrow.apply.connect (() => {
                row0.set_orientation (Gtk.Orientation.VERTICAL);
                row0.set_homogeneous (false);
                row1.set_orientation (Gtk.Orientation.VERTICAL);
                row1.set_homogeneous (false);
            });
            narrow.unapply.connect (() => {
                row0.set_orientation (Gtk.Orientation.HORIZONTAL);
                row0.set_homogeneous (true);
                row1.set_orientation (Gtk.Orientation.HORIZONTAL);
                row1.set_homogeneous (true);
            });
            responsive.add_breakpoint (narrow);

            content.append (responsive);
            scrolled.set_child (content);
            this.append (scrolled);
        }

        private Gtk.Widget create_feature (string title, string description) {
            var feature = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            feature.set_valign (Gtk.Align.START);
            feature.hexpand = true;

            var title_label = new Gtk.Label (title);
            title_label.add_css_class ("heading");
            title_label.set_xalign (0);
            title_label.set_wrap (true);
            title_label.set_max_width_chars (15);
            feature.append (title_label);

            var description_label = new Gtk.Label (description);
            description_label.add_css_class ("caption");
            description_label.add_css_class ("dim-label");
            description_label.set_xalign (0);
            description_label.set_wrap (true);
            description_label.set_max_width_chars (28);
            feature.append (description_label);

            return feature;
        }
    }
}
