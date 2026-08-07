namespace ProtonPlus.Utils {
    [CCode (cheader_filename = "gtk/gtk.h", cname = "gtk_style_context_add_provider_for_display")]
    private static extern void add_provider_for_display (Gdk.Display display, Gtk.StyleProvider provider, uint priority);

    [CCode (cheader_filename = "gtk/gtk.h", cname = "gtk_style_context_remove_provider_for_display")]
    private static extern void remove_provider_for_display (Gdk.Display display, Gtk.StyleProvider provider);

    public class ThemeManager : Object {
        private static ThemeManager _instance;
        private Gtk.CssProvider? custom_theme_provider;

        public static ThemeManager get_default () {
            if (_instance == null)
            _instance = new ThemeManager ();

            return _instance;
        }

        construct {
            var application = (Adw.Application) GLib.Application.get_default ();
            var style_manager = Adw.StyleManager.get_default ();

            Globals.SETTINGS.changed["theme"].connect (() => {
                apply_theme ();
            });

            style_manager.notify["dark"].connect (() => {
                if (get_effective_theme (Globals.SETTINGS.get_enum ("theme")) == 2)
                apply_custom_theme (2);
            });
        }

        public void apply_theme () {
            var theme = get_effective_theme (Globals.SETTINGS.get_enum ("theme"));

            var style_manager = Adw.StyleManager.get_default ();
            style_manager.set_color_scheme (
                theme == 3 || theme == 4 ?
                Adw.ColorScheme.FORCE_DARK :
                Adw.ColorScheme.DEFAULT
            );
            apply_custom_theme (theme);
        }

        private int get_effective_theme (int theme) {
            if (theme != Adw.ColorScheme.DEFAULT)
            return theme;

            if (Globals.IS_STEAM_OS)
            return 3;

            if (System.is_kde ())
            return 2;

            return 1;
        }

        private void apply_custom_theme (int theme) {
            var display = Gdk.Display.get_default ();

            if (display == null)
            return;

            if (custom_theme_provider != null) {
                remove_provider_for_display (display, custom_theme_provider);
                custom_theme_provider = null;
            }

            string? stylesheet = null;

            switch (theme) {
                case 2:
                    stylesheet = Adw.StyleManager.get_default ().get_dark () ?
                        "/com/vysp3r/ProtonPlus/breeze-dark.css" :
                        "/com/vysp3r/ProtonPlus/breeze-light.css";
                    break;
                case 3:
                    stylesheet = "/com/vysp3r/ProtonPlus/steamos.css";
                    break;
                case 4:
                    stylesheet = "/com/vysp3r/ProtonPlus/oled.css";
                    break;
            }

            if (stylesheet == null)
            return;

            custom_theme_provider = new Gtk.CssProvider ();
            custom_theme_provider.load_from_resource (stylesheet);
            add_provider_for_display (
                display,
                custom_theme_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1
            );
        }
    }
}
