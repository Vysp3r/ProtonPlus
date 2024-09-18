namespace ProtonPlus.Utils {
    public class GUI {
        public static Gtk.Button create_button (string? icon_name, string? tooltip_text) {
            var icon = new Gtk.Image ();
            icon.set_pixel_size (20);
            if (icon_name != null)
                icon.set_from_icon_name (icon_name);

            var button = new Gtk.Button ();
            button.set_child (icon);
            button.set_tooltip_text (tooltip_text);
            button.add_css_class ("flat");
            button.width_request = 40;
            button.height_request = 40;

            return button;
        }
    }
}