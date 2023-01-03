namespace Widgets {
    public class ProtonComboRow : Adw.ComboRow {
        public ProtonComboRow (string title, ListStore model = new ListStore(typeof (Interfaces.IModel)), int selected = 0) {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect (setup);
            factory.bind.connect (bind);

            set_title (title);
            set_selected (selected);
            set_model (model);
            set_factory (factory);
        }

        void bind (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var obj = list_item.get_item () as Interfaces.IModel;

            var title = list_item.get_data<Gtk.Label> ("title");
            title.set_label (obj.Title);
        }

        void setup (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var title = new Gtk.Label ("");

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.append (title);

            list_item.set_data ("title", title);
            list_item.set_child (box);
        }
    }
}
