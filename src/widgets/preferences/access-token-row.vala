namespace ProtonPlus.Widgets.Preferences {
    public class AccessTokenRow : Adw.EntryRow {
        construct {
            set_title (_("Access token"));
            set_tooltip_text (_("Enter an access token to reduce your chances of being rate limited"));
        }
    }
}