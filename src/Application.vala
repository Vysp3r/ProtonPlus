using Utils.Constants;

public class ProtonPlus : Adw.Application {
    private static GLib.Once<ProtonPlus> _instance;

    public static unowned ProtonPlus get_instance () {
        return _instance.once (() => { return new ProtonPlus (); });
    }

    ProtonPlus () {
        application_id = APP_ID;
        flags |= ApplicationFlags.FLAGS_NONE;

        Intl.bindtextdomain (APP_ID, LOCALE_DIR);
    }

    public static int main (string[] args) {
        if (Thread.supported () == false) {
            stderr.printf ("Threads are not supported!\n");
            return -1;
        }

        return get_instance ().run (args);
    }

    public override void activate () {
        initialize ();

        ActionEntry[] action_entries = {
            { "preferences", on_preferences_action },
            { "telegram", () => Gtk.show_uri (null, "https://t.me/ProtonPlusOfficial", Gdk.CURRENT_TIME) },
            { "documentation", () => Gtk.show_uri (null, "https://github.com/Vysp3r/ProtonPlus/wiki", Gdk.CURRENT_TIME) },
            { "donation", () => Gtk.show_uri (null, "https://www.youtube.com/watch?v=dQw4w9WgXcQ", Gdk.CURRENT_TIME) },
            { "about", on_about_action },
            { "quit", quit }
        };
        add_action_entries (action_entries, this);

        Stores.Main.get_instance ().MainWindow.show ();
    }

    void initialize () {
        var mainStore = Stores.Main.get_instance ();

        //
        mainStore.Preference = new Models.Preference ();
        mainStore.InstalledLaunchers = Models.Launcher.GetAll ();

        //
        Utils.Preference.Load (mainStore.Preference);
        Utils.Preference.Apply (mainStore.Preference);

        //
        Utils.Theme.Load ();

        // Always load data first, because Windows.Home is using them
        mainStore.Application = this;
        mainStore.MainWindow = new Windows.Home (mainStore.Application);
    }

    void on_about_action () {
        string[] devs = { "Charles Malouin (Vysp3r) https://github.com/Vysp3r" };
        string[] designers = { "Charles Malouin (Vysp3r) https://github.com/Vysp3r" };
        string[] thanks = {
            "GNOME Project https://www.gnome.org/",
            "ProtonUp-Qt Project https://davidotek.github.io/protonup-qt/",
            "LUG Helper Project https://github.com/starcitizen-lug/lug-helper",
            "Lahey"
        };

        var aboutDialog = new Adw.AboutWindow ();

        aboutDialog.set_application_name ("ProtonPlus");
        aboutDialog.set_application_icon ("com.vysp3r.ProtonPlus");
        aboutDialog.set_version (@"v$APP_VERSION");
        aboutDialog.set_comments ("A simple Wine and Proton-based compatiblity tools manager for GNOME");
        aboutDialog.add_link ("Github", "https://github.com/Vysp3r/ProtonPlus");
        aboutDialog.set_release_notes ("<ul>\n" +
                                       "<li>🐛 Fixed installer tool switching</li>\n" +
                                       "<li>🔇 Remove debug log</li>\n" +
                                       "<li>💄 Updated icons</li>\n" +
                                       "<li>🐛 Fixed tools and releases not being locked when needed</li>\n" +
                                       "<li>🐛 Fixed progress bar not being hidden when needed</li>\n" +
                                       "<li>🌐 Updated translation files</li>\n" + "<li>🔨 Update appdata</li>\n" +
                                       "<li>💬 Update the release notes</li>\n" +
                                       "</ul>");
        aboutDialog.set_issue_url ("https://github.com/Vysp3r/ProtonPlus/issues/new/choose");
        aboutDialog.set_copyright ("© 2022 Vysp3r");
        aboutDialog.set_license_type (Gtk.License.GPL_3_0);
        aboutDialog.set_developers (devs);
        aboutDialog.set_designers (designers);
        aboutDialog.add_credit_section ("Special thanks to", thanks);
        aboutDialog.set_transient_for (Stores.Main.get_instance ().MainWindow);
        aboutDialog.set_modal (true);

        aboutDialog.show ();
    }

    void on_preferences_action () {
        new Windows.Preferences (Stores.Main.get_instance ().MainWindow);
    }
}
