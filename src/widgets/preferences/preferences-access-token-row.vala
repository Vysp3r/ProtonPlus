namespace ProtonPlus.Widgets.Preferences {
    public class AccessTokenRow : Adw.EntryRow {
        private string token_url { get; set; default = ""; }

        construct {
            set_tooltip_text (_ ("Enter an access token to reduce your chances of being rate limited"));
        }

        public AccessTokenRow (string source, string icon_name, string token_url = "") {
            set_title (_ ("%s access token").printf (source));
            add_prefix (new Gtk.Image.from_icon_name (icon_name));

            this.token_url = token_url;
            if (this.token_url == "") {
                this.token_url = get_default_token_url (source);
            }

            if (this.token_url != "") {
                var open_token_url_button = new Gtk.Button.from_icon_name ("external-link-symbolic");
                open_token_url_button.add_css_class ("flat");
                open_token_url_button.set_tooltip_text (_("Open token creation page"));
                open_token_url_button.clicked.connect (() => {
                    Utils.System.open_uri (this.token_url);
                });
                add_suffix (open_token_url_button);
            }
        }

        private string get_default_token_url (string source) {
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