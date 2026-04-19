namespace ProtonPlus.Widgets.Preferences {
    public class AccessTokenRow : Adw.EntryRow {
        construct {
            set_tooltip_text (_ ("Enter an access token to reduce your chances of being rate limited"));
        }

        public AccessTokenRow (string source) {
            set_title (_ ("%s Access token").printf (source));
        }
    }
}