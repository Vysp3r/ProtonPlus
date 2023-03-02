namespace Utils {
    public class Theme {
        public static void Load() {
            var provider = new Gtk.CssProvider();
            provider.load_from_resource("/com/vysp3r/ProtonPlus/application.css");
            Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(),
                                                      provider,
                                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        public static void Apply() {
            var settings = new Settings("com.vysp3r.ProtonPlus");

            Adw.StyleManager.get_default().set_color_scheme(Models.Preferences.Style.GetAll().nth_data(settings.get_int("window-style")).ColorScheme);
        }
    }
}
