namespace ProtonPlus.Widgets {
    public class ThemeManager : Object {
        private static ThemeManager _instance;

        public static ThemeManager get_default () {
            if (_instance == null)
            _instance = new ThemeManager ();

            return _instance;
        }

        construct {
            var application = (Adw.Application) GLib.Application.get_default ();

            application.window_added.connect (apply_to_window);

            if (Globals.SETTINGS != null) {
                Globals.SETTINGS.changed["theme"].connect (() => {
                    apply_theme ();
                });
            }
        }

        public void apply_theme () {
            if (Globals.SETTINGS == null)
            return;

            var theme = Globals.SETTINGS.get_enum ("theme");

            var style_manager = Adw.StyleManager.get_default ();
            style_manager.set_color_scheme (theme == 5 || theme == 6 ? Adw.ColorScheme.FORCE_DARK : (Adw.ColorScheme) theme);

            var application = (Adw.Application) GLib.Application.get_default ();

            foreach (var window in application.get_windows ()) {
                apply_to_window (window);
            }
        }

        public void apply_to_window (Gtk.Window window) {
            if (Globals.SETTINGS == null)
            return;

            var theme = Globals.SETTINGS.get_enum ("theme");

            if (theme == 5) {
                window.add_css_class ("steamos");
                window.remove_css_class ("oled");
            } else if (theme == 6) {
                window.remove_css_class ("steamos");
                window.add_css_class ("oled");
            } else {
                window.remove_css_class ("steamos");
                window.remove_css_class ("oled");
            }
        }
    }
}
