namespace ProtonPlus.Windows {
    public class Preferences : Gtk.ApplicationWindow {
        //Widgets
        Gtk.Box boxMain;
        Gtk.Label labelStyles;
        ProtonPlus.Widgets.ProtonComboBox cbStyles;

        //Stores
        ProtonPlus.Stores.Preferences store;

        public Preferences (Gtk.Application app) {
            this.set_application (app);
            this.set_title ("Preferences");
            this.set_default_size (400, 0);

            store = ProtonPlus.Stores.Preferences.instance ();

            boxMain = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);
            boxMain.set_margin_bottom(15);
            boxMain.set_margin_end(15);
            boxMain.set_margin_start(15);
            boxMain.set_margin_top(15);

            this.set_child (boxMain);

            labelStyles = new Gtk.Label ("Styles");
            labelStyles.add_css_class ("bold");
            boxMain.append (labelStyles);

            cbStyles = new ProtonPlus.Widgets.ProtonComboBox (ProtonPlus.Models.Preference.GetStyleModel ());
            cbStyles.GetChild ().changed.connect (() => cbStyles_Changed (cbStyles));
            cbStyles.GetChild ().set_active (store.CurrentStyle.Position);
            boxMain.append (cbStyles);

            this.show ();
        }

        private void cbStyles_Changed (ProtonPlus.Widgets.ProtonComboBox cbStyles) {
            store.CurrentStyle = (ProtonPlus.Models.Preference.Style) cbStyles.GetCurrentObject ();
            ProtonPlus.Manager.Preferences.Apply ();
            ProtonPlus.Manager.Preferences.Update ();
        }
    }
}
