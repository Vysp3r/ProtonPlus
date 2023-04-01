namespace Models.Preferences {
    public class Style : Object {
        public string Title;
        public string JsonValue;
        public Adw.ColorScheme ColorScheme;
        public int Position;

        public Style (string title, Adw.ColorScheme color_scheme, int position) {
            this.Title = title;
            this.ColorScheme = color_scheme;
            this.Position = position;
        }

        public static GLib.List<Style> GetAll () {
            var styles = new GLib.List<Style> ();

            styles.append (new Style (_("System"), Adw.ColorScheme.DEFAULT, 0));
            styles.append (new Style (_("Light"), Adw.ColorScheme.FORCE_LIGHT, 1));
            styles.append (new Style (_("Dark"), Adw.ColorScheme.FORCE_DARK, 2));

            return styles;
        }

        public void SetActive (bool updateSetting = true) {
            if (updateSetting) {
                var settings = new Settings ("com.vysp3r.ProtonPlus");
                settings.set_value ("window-style", Position);
            }

            Adw.StyleManager.get_default ().set_color_scheme (ColorScheme);
        }
    }
}
