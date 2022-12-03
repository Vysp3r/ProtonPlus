namespace ProtonPlus.Windows {
    public class Preferences : Adw.PreferencesWindow {
        // Widgets
        Widgets.ProtonComboRow crStyles;

        // Values
        Stores.Preferences preferences;

        public Preferences (ref Stores.Preferences preferences) {
            set_title ("Preferences");
            set_can_navigate_back (true);
            set_default_size (0, 0);

            this.preferences = preferences;

            // Initialize shared widgets
            var styles = Models.Preferences.Style.GetAll ();
            crStyles = new Widgets.ProtonComboRow ("Styles", Models.Preferences.Style.GetStore (styles), preferences.Style.Position);

            // Setup mainPage
            var mainPage = new Adw.PreferencesPage ();
            mainPage.set_name ("Appearance");
            mainPage.set_title ("Appearance");
            add (mainPage);

            // Setup crStyles
            crStyles.set_selected (preferences.Style.Position);
            crStyles.notify.connect (crStyles_Notify);

            // Setup stylesGroup
            var stylesGroup = new Adw.PreferencesGroup ();
            stylesGroup.add (crStyles);
            mainPage.add (stylesGroup);

            // Show the window
            show ();
        }

        // Events
        void crStyles_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "selected") {
                preferences.Style = (Models.Preferences.Style) crStyles.get_selected_item ();
                Manager.Preference.Apply (ref preferences);
                Manager.Preference.Update (ref preferences);
            }
        }
    }
}
