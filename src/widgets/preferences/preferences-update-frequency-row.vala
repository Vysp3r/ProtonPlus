namespace ProtonPlus.Widgets.Preferences {
    public class UpdateFrequencyRow : Adw.ComboRow {
        class Frequency : Object {
            public string title { get; private set; }
            public int value { get; private set; }

            public Frequency (string title, int value) {
                this.title = title;
                this.value = value;
            }
        }

        construct {
            var model = new ListStore(typeof (Frequency));
            model.append (new Frequency(_ ("1h"), 0));
            model.append (new Frequency(_ ("3h"), 1));
            model.append (new Frequency(_ ("6h"), 2));
            model.append (new Frequency(_ ("12h"), 3));

            var expression = new Gtk.PropertyExpression(typeof (Frequency), null, "title");

            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect (factory_setup);
            factory.bind.connect (factory_bind);

            set_title (_ ("Update frequency"));
            set_model (model);
            set_expression (expression);
            set_list_factory (factory);

            if (Globals.SETTINGS != null) {
                var frequency = Globals.SETTINGS.get_enum ("update-frequency");
                set_selected ((uint) frequency);
            }

            notify["selected-item"].connect (selected_item_changed);
        }

        void selected_item_changed () {
            var frequency = get_selected_item () as Frequency;

            if (Globals.SETTINGS != null && frequency != null)
            Globals.SETTINGS.set_enum ("update-frequency", frequency.value);
        }

        void factory_bind (Object object) {
            var list_item = object as Gtk.ListItem;
            var frequency = list_item.get_item () as Frequency;

            if (frequency != null)
            object.get_data<Gtk.Label> ("title").set_label (frequency.title);
        }

        void factory_setup (Object object) {
            var list_item = object as Gtk.ListItem;

            var title_label = new Gtk.Label (null);
            title_label.set_xalign (0.0f);
            title_label.set_max_width_chars (30);
            title_label.set_ellipsize (Pango.EllipsizeMode.END);
            title_label.set_hexpand (true);

            object.set_data ("title", title_label);

            list_item.set_child (title_label);
        }
    }
}
