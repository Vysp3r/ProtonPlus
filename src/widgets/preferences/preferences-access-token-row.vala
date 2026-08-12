namespace ProtonPlus.Widgets.Preferences {
    public class AccessTokenRow : Object {
        private AccessTokenRow () {
        }

        public static Adw.PasswordEntryRow create (string source, string icon_name,
            string token_url = "") {
            var row = new Adw.PasswordEntryRow () {
                title = _ ("%s access token").printf (source),
                tooltip_text = _ ("Enter an access token to reduce your chances of being rate limited"),
            };
            row.add_prefix (new Gtk.Image.from_icon_name (icon_name));
            Utils.TextInputMetadataPolicy.apply (row, Utils.TextInputFieldKind.SECRET);

            var resolved_token_url = token_url != "" ? token_url : get_default_token_url (source);
            if (resolved_token_url != "") {
                var open_token_url_button = new Gtk.Button.from_icon_name ("external-link-symbolic");
                open_token_url_button.add_css_class ("flat");
                var open_token_page_label = _("Open %s Token Page").printf (source);
                open_token_url_button.set_tooltip_text (open_token_page_label);
                open_token_url_button.update_property (
                    Gtk.AccessibleProperty.LABEL,
                    open_token_page_label,
                    -1
                );
                open_token_url_button.set_valign (Gtk.Align.CENTER);
                open_token_url_button.clicked.connect (() => {
                    Utils.System.open_uri (resolved_token_url);
                });
                row.add_suffix (open_token_url_button);
            }

            return row;
        }

        private static string get_default_token_url (string source) {
            var normalized_source = source.down ();

            if (normalized_source == "github")
                return "https://github.com/settings/tokens";

            if (normalized_source == "gitlab")
                return "https://gitlab.com/-/user_settings/personal_access_tokens";

            if (normalized_source == "forgejo")
                return "https://codeberg.org/user/settings/applications";

            return "";
        }
    }
}
