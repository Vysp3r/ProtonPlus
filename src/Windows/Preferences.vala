namespace Windows {
    public class Preferences : Adw.PreferencesWindow {
        Widgets.ProtonComboRow crStyles;
        GLib.Settings settings;

        public Preferences (Gtk.ApplicationWindow parent) {
            set_transient_for (parent);
            set_modal (true);
            set_title (_ ("Preferences"));
            set_can_navigate_back (true);
            set_default_size (0, 0);

            settings = new Settings ("com.vysp3r.ProtonPlus");

            // Setup mainPage
            var mainPage = new Adw.PreferencesPage ();
            mainPage.set_name (_ ("Main"));
            mainPage.set_title (_ ("Main"));
            add (mainPage);

            // Setup crStyles
            crStyles = new Widgets.ProtonComboRow (_ ("Styles"), Models.Preferences.Style.GetStore (Models.Preferences.Style.GetAll ()), 0);
            settings.bind ("window-style", crStyles, "selected", GLib.SettingsBindFlags.DEFAULT);
            crStyles.notify.connect ((param) => {
                if (param.get_name () == "selected") {
                    Utils.Theme.Apply ();
                }
            });

            // Setup stylesGroup
            var apperanceGroup = new Adw.PreferencesGroup ();
            apperanceGroup.add (crStyles);
            mainPage.add (apperanceGroup);

            // Setup rememberLastLauncherSwitch
            var rememberLastLauncherSwitch = new Gtk.Switch ();
            settings.bind ("remember-last-launcher", rememberLastLauncherSwitch, "active", GLib.SettingsBindFlags.DEFAULT);

            // Setup showGamescopeWarningSwitch
            var showGamescopeWarningSwitch = new Gtk.Switch ();
            settings.bind ("show-gamescope-warning", showGamescopeWarningSwitch, "active", GLib.SettingsBindFlags.DEFAULT);

            // Setup stylesGroup
            var otherGroup = new Adw.PreferencesGroup ();
            otherGroup.add (CreateRow (rememberLastLauncherSwitch, _ ("Remember last launcher")));
            otherGroup.add (CreateRow (showGamescopeWarningSwitch, _ ("Show gamescope warning")));
            mainPage.add (otherGroup);

            // Show the window
            show ();
        }

        Adw.ActionRow CreateRow (Gtk.Widget widget, string row_title) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.set_valign (Gtk.Align.CENTER);
            box.append (widget);

            var row = new Adw.ActionRow ();
            row.set_title (row_title);
            row.add_suffix (box);

            return row;
        }
    }
}
