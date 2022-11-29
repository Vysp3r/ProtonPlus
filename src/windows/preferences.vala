namespace ProtonPlus.Windows {
    public class Preferences : Adw.PreferencesWindow {
        // Widgets
        Adw.ComboRow crStyles;
        Stores.Preferences preferences;

        public Preferences (ref Stores.Preferences preferences) {
            this.set_title ("Preferences");
            this.set_can_navigate_back (true);
            this.set_default_size (0, 0);

            this.preferences = preferences;

            var mainPage = new Adw.PreferencesPage ();
            mainPage.set_name ("Appearance");
            mainPage.set_title ("Appearance");
            this.add (mainPage);

            var factoryStyles = new Gtk.SignalListItemFactory ();
            factoryStyles.setup.connect (factoryStyles_Setup);
            factoryStyles.bind.connect (factoryStyles_Bind);

            crStyles = new Adw.ComboRow ();
            crStyles.set_title ("Styles");
            crStyles.set_model (Models.Preferences.Style.GetStore (Models.Preferences.Style.GetAll ()));
            crStyles.set_factory (factoryStyles);
            crStyles.set_selected (preferences.Style.Position);
            crStyles.notify.connect (crStyles_Notify);

            var stylesGroup = new Adw.PreferencesGroup ();
            stylesGroup.add (crStyles);

            mainPage.add (stylesGroup);

            this.show ();
        }

        void crStyles_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "selected") {
                preferences.Style = (Models.Preferences.Style) crStyles.get_selected_item ();
                Manager.Preferences.Apply (ref preferences);
                Manager.Preferences.Update (ref preferences);
            }
        }

        void factoryStyles_Bind (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var string_holder = list_item.get_item () as Models.Preferences.Style;

            var title = list_item.get_data<Gtk.Label> ("title");
            title.label = string_holder.Title;
        }

        void factoryStyles_Setup (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var title = new Gtk.Label ("");
            title.xalign = 0.0f;

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.append (title);

            list_item.set_data ("title", title);
            list_item.set_child (box);
        }
    }
}
