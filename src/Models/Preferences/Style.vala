namespace Models.Preferences {
    public class Style : Object, Interfaces.IModel {
        public string Title { get; set; }
        public string JsonValue;
        public Adw.ColorScheme ColorScheme;
        public int Position;

        public Style (string title, Adw.ColorScheme color_scheme, int position) {
            this.Title = title;
            this.ColorScheme = color_scheme;
            this.Position = position;
        }

        public static GLib.ListStore GetStore (GLib.List<Style> styles) {
            var model = new GLib.ListStore (typeof (Style));

            styles.@foreach ((style) => {
                model.append (style);
            });

            return model;
        }

        public static GLib.List<Style> GetAll () {
            var styles = new GLib.List<Style> ();

            styles.append (new Style (_ ("System"), Adw.ColorScheme.DEFAULT, 0));
            styles.append (new Style (_ ("Light"), Adw.ColorScheme.FORCE_LIGHT, 1));
            styles.append (new Style (_ ("Dark"), Adw.ColorScheme.FORCE_DARK, 2));

            return styles;
        }
    }
}
