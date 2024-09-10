namespace ProtonPlus.Utils {
    public class GUI {
        public enum UIState {
            // WARNING: `NO_STATE` *MUST* be FIRST entry in this list, to become
            // the "unitialized default value" for Gtk Object properties, since
            // nullable properties aren't allowed for Gtk Objects. You should
            // treat the `NO_STATE` value the same as you would treat `null`.
            NO_STATE,
            BUSY_INSTALLING,
            BUSY_REMOVING,
            UP_TO_DATE,
            UPDATE_AVAILABLE,
            NOT_INSTALLED
        }

        public static void send_toast (Adw.ToastOverlay toast_overlay, string content, int duration) {
            var toast = new Adw.Toast (content);
            toast.set_timeout (duration);

            toast_overlay.add_toast (toast);
        }

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