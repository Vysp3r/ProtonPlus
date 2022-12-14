namespace Windows {
    public class Preferences : Adw.PreferencesWindow {
        // Widgets
        Widgets.ProtonComboRow crStyles;
        Gtk.Switch rememberLastLauncherSwitch;

        // Values1
        Stores.Main mainStore;

        public Preferences (Gtk.ApplicationWindow parent) {
            set_transient_for (parent);
            set_modal (true);
            set_title (_ ("Preferences"));
            set_can_navigate_back (true);
            set_default_size (0, 0);

            mainStore = Stores.Main.get_instance ();

            var styles = Models.Preferences.Style.GetAll ();

            // Initialize shared widgets
            crStyles = new Widgets.ProtonComboRow (_ ("Styles"), Models.Preferences.Style.GetStore (styles), mainStore.Preference.Style.Position);
            rememberLastLauncherSwitch = new Gtk.Switch ();

            // Setup mainPage
            var mainPage = new Adw.PreferencesPage ();
            mainPage.set_name (_ ("Main"));
            mainPage.set_title (_ ("Main"));
            add (mainPage);

            // Setup crStyles
            crStyles.set_selected (mainStore.Preference.Style.Position);
            crStyles.notify.connect (crStyles_Notify);

            // Setup stylesGroup
            var apperanceGroup = new Adw.PreferencesGroup ();
            apperanceGroup.add (crStyles);
            mainPage.add (apperanceGroup);

            // Setup rememberLastLauncherSwitch
            rememberLastLauncherSwitch.set_active (mainStore.Preference.RememberLastLauncher);
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
                mainStore.Preference.Style = (Models.Preferences.Style) crStyles.get_selected_item ();
                Utils.Preference.Apply (mainStore.Preference);
                Utils.Preference.Update (mainStore.Preference);
            }
        }

        void rememberLastLauncherSwitch_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "active") {
                mainStore.Preference.RememberLastLauncher = rememberLastLauncherSwitch.get_state ();
                Utils.Preference.Update (mainStore.Preference);
            }
        }
    }
}
