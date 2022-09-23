namespace ProtonPlus.Models {
    public class Preference<T>: Object {

        public string Title { public get; private set; }
        public T[] ObjectList { public get; private set; }

        public Preference (string title, T[] object_list) {
            this.Title = title;
            this.ObjectList = object_list;
        }

        public static Style[] GetStyles () {
            Style[] styles = new Style[3];
            styles[0] = new Style ("System", Adw.ColorScheme.DEFAULT, 0);
            styles[1] = new Style ("Light", Adw.ColorScheme.FORCE_LIGHT, 1);
            styles[2] = new Style ("Dark", Adw.ColorScheme.FORCE_DARK, 2);
            return styles;
        }

        public static Style FindStyle (string label) {
            switch (label) {
            case "Light":
                return Preference.GetStyles ()[1];
            case "Dark":
                return Preference.GetStyles ()[2];
            default:
                return Preference.GetStyles ()[0];
            }
        }

        public static Gtk.ListStore GetStyleModel () {
            Gtk.ListStore model = new Gtk.ListStore (2, typeof (string), typeof (Style));
            Gtk.TreeIter iter;

            foreach (var item in GetStyles ()) {
                model.append (out iter);
                model.set (iter, 0, item.Label, 1, item, -1);
            }

            return model;
        }

        public class Style : Object {
            public string Label { public get; private set; }
            public Adw.ColorScheme ColorScheme { public get; private set; }
            public int Position { public get; private set; }

            public Style (string label, Adw.ColorScheme color_scheme, int position) {
                this.Label = label;
                this.ColorScheme = color_scheme;
                this.Position = position;
            }
        }

        public static Preference[] GetPreferences () {
            Preference[] preferences = new Preference[1];
            preferences[0] = new Preference<Style> ("Styles", GetStyles ());
            return preferences;
        }
    }
}