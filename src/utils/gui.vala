namespace ProtonPlus.Utils {
    public class GUI {
        public static void send_toast (Adw.ToastOverlay toast_overlay, string content, int duration) {
            var toast = new Adw.Toast (content);
            toast.set_timeout (duration);

            toast_overlay.add_toast (toast);
        }

        public static Gtk.Button create_button (string? icon_name, string? tooltip_text) {
            var icon = new Gtk.Image.from_icon_name (icon_name);
            icon.set_pixel_size (20);

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