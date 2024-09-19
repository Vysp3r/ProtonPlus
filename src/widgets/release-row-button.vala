namespace ProtonPlus.Widgets {
    public class ReleaseRowButton : Gtk.Button {
        Gtk.Image icon { get; set; }

        public ReleaseRowButton (string? icon_name = null, string? tooltip_text = null) {
            icon = new Gtk.Image ();
            icon.set_pixel_size (20);
            if (icon_name != null)
                icon.set_from_icon_name (icon_name);

            set_child (icon);
            set_tooltip_text (tooltip_text);
            add_css_class ("flat");
            width_request = 40;
            height_request = 40;
        }
    }
}