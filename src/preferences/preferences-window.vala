namespace ProtonPlus.Preferences {
    public class PreferencesWindow : Adw.PreferencesWindow {
        public Adw.ApplicationWindow window { get; construct; }

        public PreferencesWindow (Adw.ApplicationWindow window) {
            Object (window: window);
        }

        construct {
            //
            set_transient_for (window);
            set_modal (true);
            set_title (_("Preferences"));
            set_can_navigate_back (true);

            //
            var settings = new Settings ("com.vysp3r.ProtonPlus");

            //
            var mainPage = new Adw.PreferencesPage ();
            mainPage.set_name (_("Main"));
            mainPage.set_title (_("Main"));

            //
            var group = new Adw.PreferencesGroup ();
            mainPage.add (group);

            //
            add (mainPage);
        }
    }
}