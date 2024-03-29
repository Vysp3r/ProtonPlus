namespace ProtonPlus {
    public class Application : Adw.Application {
        Window window;

        construct {
            application_id = Constants.APP_ID;
            flags |= ApplicationFlags.FLAGS_NONE;

            Intl.bindtextdomain (Constants.APP_ID, Constants.LOCALE_DIR);
        }

        public override void activate () {
            //
            var display = Gdk.Display.get_default ();

            //
            Gtk.IconTheme.get_for_display (display).add_resource_path ("/com/vysp3r/ProtonPlus/icons");

            //
            var css_provider = new Gtk.CssProvider ();
            css_provider.load_from_resource ("/com/vysp3r/ProtonPlus/css/style.css");

            //
            Gtk.StyleContext.add_provider_for_display (display, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            //
            window = new Window ();
            window.initialize ();

            //
            if (GLib.Environment.get_variable ("DESKTOP_SESSION") == "gamescope-wayland")window.fullscreen ();

            //
            ActionEntry[] action_entries = {
                { "about", about_action },
            };
            add_action_entries (action_entries, this);

            //
            window.show ();
        }

        void about_action () {
            const string[] devs = {
                "Charles Malouin (Vysp3r) https://github.com/Vysp3r",
                "windblows95 https://github.com/windblows95",
                null
            };

            const string[] thanks = {
                "GNOME Project https://www.gnome.org/",
                "ProtonUp-Qt Project https://davidotek.github.io/protonup-qt/",
                "LUG Helper Project https://github.com/starcitizen-lug/lug-helper",
                null
            };

            var about_window = new Adw.AboutWindow ();

            about_window.set_application_name (Constants.APP_NAME);
            about_window.set_application_icon (Constants.APP_ID);
            about_window.set_version ("v" + Constants.APP_VERSION);
            about_window.set_comments (_("A simple Wine and Proton-based compatibility tools manager for GNOME"));
            about_window.add_link ("Github", "https://github.com/Vysp3r/ProtonPlus");
            about_window.set_issue_url ("https://github.com/Vysp3r/ProtonPlus/issues/new/choose");
            about_window.set_copyright ("© 2022-2023 Vysp3r");
            about_window.set_license_type (Gtk.License.GPL_3_0);
            about_window.set_developers (devs);
            about_window.add_credit_section (_("Special thanks to"), thanks);
            about_window.set_transient_for (window);
            about_window.set_modal (true);

            about_window.show ();
        }

        public static int main (string[] args) {
            if (Thread.supported () == false) {
                message ("Threads are not supported!");
                return -1;
            }

            var application = new Application ();

            return application.run (args);
        }
    }
}