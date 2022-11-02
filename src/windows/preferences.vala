namespace ProtonPlus.Windows {
    public class Preferences : Adw.PreferencesWindow {
        //Widgets
        Adw.ComboRow crStyles;

        //Stores
        ProtonPlus.Stores.Preferences store;

        public Preferences () {
            this.set_title ("Preferences");
            this.set_can_navigate_back (true);
            this.set_default_size (0, 0);

            store = ProtonPlus.Stores.Preferences.instance ();

            var mainPage = new Adw.PreferencesPage ();
            mainPage.set_name ("Appearance");
            mainPage.set_title ("Appearance");
            this.add (mainPage);

            var factoryStyles = new Gtk.SignalListItemFactory ();
            factoryStyles.setup.connect (factoryStyles_Setup);
            factoryStyles.bind.connect (factoryStyles_Bind);

            crStyles = new Adw.ComboRow ();
            crStyles.set_title ("Styles");
            crStyles.set_model (ProtonPlus.Models.Preference.GetStyleStore ());
            crStyles.set_factory (factoryStyles);
            crStyles.set_selected (store.CurrentStyle.Position);
            crStyles.notify.connect (crStyles_Notify);

            var stylesGroup = new Adw.PreferencesGroup ();
            stylesGroup.add (crStyles);

            mainPage.add (stylesGroup);

            this.show ();
        }

        public void crStyles_Notify (GLib.ParamSpec param) {
            if(param.get_name () == "selected"){
                store.CurrentStyle = (ProtonPlus.Models.Preference.Style) crStyles.get_selected_item ();
                ProtonPlus.Manager.Preferences.Apply ();
                ProtonPlus.Manager.Preferences.Update ();
            }
        }

        void factoryStyles_Bind (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var string_holder = list_item.get_item () as ProtonPlus.Models.Preference.Style;

            var title = list_item.get_data<Gtk.Label>("title");
            title.label = string_holder.Label;
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
