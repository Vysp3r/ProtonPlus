namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Base : Gtk.Box {

        public Base (string title_text, string description_text, string? image_source = null) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 18);
            this.hexpand = true;
            this.vexpand = true;
            this.valign = Gtk.Align.CENTER;
            this.halign = Gtk.Align.CENTER;
            this.margin_top = 24;
            this.margin_bottom = 24;
            this.margin_start = 24;
            this.margin_end = 24;

            if (image_source != null) {
                Gtk.Image image;

                if (image_source.has_prefix ("/") || image_source.contains (Config.RESOURCE_BASE)) {
                    image = new Gtk.Image.from_resource (image_source);
                } else {
                    image = new Gtk.Image.from_icon_name (image_source);
                }

                image.pixel_size = 96;
                this.append (image);
            }

            var title_label = new Gtk.Label (title_text);
            title_label.add_css_class ("title-1");
            title_label.wrap = true;
            title_label.justify = Gtk.Justification.CENTER;
            this.append (title_label);

            var desc_label = new Gtk.Label (description_text);
            desc_label.add_css_class ("body");
            desc_label.wrap = true;
            desc_label.justify = Gtk.Justification.CENTER;
            desc_label.max_width_chars = 50;
            this.append (desc_label);
        }
    }
}