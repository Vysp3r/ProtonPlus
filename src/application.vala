namespace ProtonPlus {
    public class Application : Adw.Application {
        public Application () {
            Object (application_id: "com.vysp3r.ProtonPlus", flags : ApplicationFlags.FLAGS_NONE);
        }

        construct {
            ActionEntry[] action_entries = {
                { "preferences", this.on_preferences_action },
                { "telegram", () => Gtk.show_uri (null, "https://t.me/ProtonPlusOfficial", Gdk.CURRENT_TIME) },
                { "documentation", () => Gtk.show_uri (null, "https://github.com/Vysp3r/ProtonPlus/wiki", Gdk.CURRENT_TIME) },
                { "donation", () => Gtk.show_uri (null, "https://www.youtube.com/watch?v=dQw4w9WgXcQ", Gdk.CURRENT_TIME) },
                { "about", this.on_about_action },
                { "quit", this.quit }
            };
            this.add_action_entries (action_entries, this);
        }

        public override void activate () {
            base.activate ();

            new Windows.Home (this);

            Manager.Preferences.Load ();
            Manager.Themes.Load ();
        }

        private void on_about_action () {
            string[] authors = { "Charles \"Vysp3r\" Malouin" };
            string[] thanks = { "GNOME Team", "Lahey" };

            Gtk.AboutDialog aboutDialog = new Gtk.AboutDialog ();
            Gtk.Image logo = new Gtk.Image.from_resource ("/com/vysp3r/ProtonPlus/ProtonPlus.png");

            aboutDialog.set_logo (logo.get_paintable());
            aboutDialog.set_program_name ("ProtonPlus");
            aboutDialog.set_version ("v0.1.0");
            aboutDialog.set_comments ("A simple compatibility tool manager ");
            aboutDialog.set_website_label ("Github");
            aboutDialog.set_website ("https://github.com/Vysp3r/ProtonPlus");
            aboutDialog.set_copyright ("© 2022 Vysp3r");
            aboutDialog.set_license_type (Gtk.License.GPL_3_0);
            aboutDialog.set_authors (authors);
            aboutDialog.add_credit_section ("Special thanks to", thanks);

            aboutDialog.show ();
        }

        private void on_preferences_action () {
            new ProtonPlus.Windows.Preferences (this);
        }
    }
}
