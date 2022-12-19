namespace ProtonPlus.Windows {
    public class Preferences : Adw.PreferencesWindow {
        // Widgets
        Widgets.ProtonComboRow crStyles;
        Gtk.Switch rememberLastLauncherSwitch;

        // Values
        Stores.Preferences preferences;

        public Preferences (Gtk.ApplicationWindow parent, ref Stores.Preferences preferences) {
            set_transient_for (parent);
            set_modal (true);
            set_title (_ ("Preferences"));
            set_can_navigate_back (true);
            set_default_size (0, 0);

            this.preferences = preferences;

            var styles = Models.Preferences.Style.GetAll ();

            // Initialize shared widgets
            crStyles = new Widgets.ProtonComboRow (_ ("Styles"), Models.Preferences.Style.GetStore (styles), preferences.Style.Position);
            rememberLastLauncherSwitch = new Gtk.Switch ();

            // Setup mainPage
            var mainPage = new Adw.PreferencesPage ();
            mainPage.set_name (_ ("Main"));
            mainPage.set_title (_ ("Main"));
            add (mainPage);

            // Setup crStyles
            crStyles.set_selected (preferences.Style.Position);
            crStyles.notify.connect (crStyles_Notify);

            // Setup stylesGroup
            var apperanceGroup = new Adw.PreferencesGroup ();
            apperanceGroup.add (crStyles);
            mainPage.add (apperanceGroup);

            // Setup rememberLastLauncherSwitch
            rememberLastLauncherSwitch.set_active (preferences.RememberLastLauncher);
            rememberLastLauncherSwitch.notify.connect (rememberLastLauncherSwitch_Notify);

            // Setup rememberLastLauncherBox
            var rememberLastLauncherBox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            rememberLastLauncherBox.set_valign (Gtk.Align.CENTER);
            rememberLastLauncherBox.append (rememberLastLauncherSwitch);

            // Setup rememberLastLauncherRow
            var rememberLastLauncherRow = new Adw.ActionRow ();
            rememberLastLauncherRow.set_title (_ ("Remember last launcher"));
            rememberLastLauncherRow.add_suffix (rememberLastLauncherBox);

            // Setup stylesGroup
            var otherGroup = new Adw.PreferencesGroup ();
            otherGroup.add (rememberLastLauncherRow);
            mainPage.add (otherGroup);

            // Show the window
            show ();
        }

        // Events
        void crStyles_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "selected") {
                preferences.Style = (Models.Preferences.Style) crStyles.get_selected_item ();
                Utils.Preference.Apply (ref preferences);
                Utils.Preference.Update (ref preferences);
            }
        }

        void rememberLastLauncherSwitch_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "active") {
                preferences.RememberLastLauncher = rememberLastLauncherSwitch.get_state ();
                Utils.Preference.Update (ref preferences);
            }
        }
    }
}
