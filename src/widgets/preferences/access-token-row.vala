namespace ProtonPlus.Widgets.Preferences {
    public class AccessTokenRow : Adw.EntryRow {
        construct {
            set_tooltip_text (_ ("Enter an access token to reduce your chances of being rate limited"));
        }

        public AccessTokenRow (string source, string icon_name) {
            set_title (_ ("%s access token").printf (source));
            add_prefix (new Gtk.Image.from_icon_name (icon_name));
        }
    }
}