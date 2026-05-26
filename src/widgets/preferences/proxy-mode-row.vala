namespace ProtonPlus.Widgets.Preferences {
    public class ProxyModeRow : Adw.ComboRow {
        class ProxyMode : Object {
            public string title { get; private set; }
            public int mode { get; private set; }

            public ProxyMode (string title, int mode) {
                this.title = title;
                this.mode = mode;
            }
        }

        construct {
            var model = new ListStore(typeof (ProxyMode));
            model.append (new ProxyMode(_ ("System proxy"), 0));
            model.append (new ProxyMode(_ ("Manual proxy"), 1));

            var expression = new Gtk.PropertyExpression(typeof (ProxyMode), null, "title");

            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect (factory_setup);
            factory.bind.connect (factory_bind);

            set_title (_ ("Proxy mode"));
            set_model (model);
            set_expression (expression);
            set_list_factory (factory);

            if (Globals.SETTINGS != null) {
                var proxy_mode = Globals.SETTINGS.get_enum ("proxy-mode");

                switch (proxy_mode) {
                    case 0:
                        set_selected (0);
                        break;
                    case 1:
                        set_selected (1);
                        break;
                }
            }

            notify["selected-item"].connect (selected_item_changed);
        }

        void selected_item_changed () {
            var proxy_mode = get_selected_item () as ProxyMode;

            if (Globals.SETTINGS != null) {
                Globals.SETTINGS.set_enum ("proxy-mode", proxy_mode.mode);
                Utils.Web.update_proxy_settings ();
            }
        }

        void factory_bind (Object object) {
            var list_item = object as Gtk.ListItem;
            var proxy_mode = list_item.get_item () as ProxyMode;

            object.get_data<Gtk.Label> ("title").set_label (proxy_mode.title);
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
