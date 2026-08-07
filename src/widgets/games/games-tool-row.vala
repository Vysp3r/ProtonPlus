namespace ProtonPlus.Widgets.Games {
    public class CompatibilityToolRow : Adw.ComboRow {
        Gtk.SignalListItemFactory compatibility_tool_factory;
        HashTable<Models.CompatibilityTool, Gtk.ListItem> hast_table;

        public CompatibilityToolRow (ListStore model, Gtk.PropertyExpression expression) {
            hast_table = new HashTable<Models.CompatibilityTool, Gtk.ListItem> (null, (a, b) => {
                return a.internal_title == b.internal_title;
            });

            compatibility_tool_factory = new Gtk.SignalListItemFactory ();
            compatibility_tool_factory.setup.connect (compatibility_tool_factory_setup);
            compatibility_tool_factory.bind.connect (compatibility_tool_factory_bind);
            compatibility_tool_factory.unbind.connect (compatibility_tool_factory_unbind);

            notify["selected-item"].connect (compatibility_tool_row_selected_item_changed);

            set_title (_ ("New tool"));
            set_model (model);
            set_expression (expression);
            set_list_factory (compatibility_tool_factory);
        }

        void compatibility_tool_row_selected_item_changed () {
            var compatibility_tool = get_selected_item () as Models.CompatibilityTool;

            if (compatibility_tool == null)
                return;

            set_tooltip_text (compatibility_tool.display_title);

            hast_table.foreach ((tool, list_item) => {
                list_item.get_data<Gtk.Image> ("check").set_visible (tool == compatibility_tool);
            });
        }

        void compatibility_tool_factory_bind (Object object) {
            var list_item = object as Gtk.ListItem;
            var compatibility_tool = list_item.get_item () as Models.CompatibilityTool;

            hast_table.set (compatibility_tool, list_item);

            object.get_data<Gtk.Label> ("title").set_label (compatibility_tool.display_title);

            object.get_data<Gtk.Image> ("check").set_visible (compatibility_tool == get_selected_item ());

            object.get_data<Gtk.Box> ("box").set_tooltip_text (compatibility_tool.display_title);
        }

        void compatibility_tool_factory_unbind (Object object) {
            var list_item = object as Gtk.ListItem;
            var compatibility_tool = list_item.get_item () as Models.CompatibilityTool;

            if (hast_table.get (compatibility_tool) == list_item)
                hast_table.remove (compatibility_tool);
        }

        void compatibility_tool_factory_setup (Object object) {
            var list_item = object as Gtk.ListItem;

            var title_label = new Gtk.Label (null);
            title_label.set_xalign (0.0f);
            title_label.set_max_width_chars (30);
            title_label.set_ellipsize (Pango.EllipsizeMode.END);
            title_label.set_hexpand (true);

            var check_image = new Gtk.Image.from_icon_name ("object-select-symbolic");
            check_image.set_visible (false);

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.append (title_label);
            box.append (check_image);

            object.set_data ("title", title_label);
            object.set_data ("check", check_image);
            object.set_data ("box", box);

            list_item.set_child (box);
        }
    }
}
