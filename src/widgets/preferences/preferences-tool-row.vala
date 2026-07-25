namespace ProtonPlus.Widgets.Preferences {
    public class ToolRow : Adw.ComboRow {
        Gtk.SignalListItemFactory compatibility_tool_factory;
        HashTable<Models.Tools.Simple, Gtk.ListItem> hast_table;

        public ToolRow (ListStore model, Gtk.PropertyExpression expression) {
            hast_table = new HashTable<Models.Tools.Simple, Gtk.ListItem> (null, (a, b) => {
                return a.internal_title == b.internal_title;
            });

            compatibility_tool_factory = new Gtk.SignalListItemFactory ();
            compatibility_tool_factory.setup.connect (compatibility_tool_factory_setup);
            compatibility_tool_factory.bind.connect (compatibility_tool_factory_bind);
            compatibility_tool_factory.unbind.connect (compatibility_tool_factory_unbind);

            notify["selected-item"].connect (compatibility_tool_row_selected_item_changed);

            set_title (_ ("Select your desired compatibility tool"));
            set_model (model);
            set_expression (expression);
            set_list_factory (compatibility_tool_factory);
        }

        void compatibility_tool_row_selected_item_changed () {
            var simple_runner = get_selected_item () as Models.Tools.Simple;

            if (simple_runner == null)
                return;

            set_tooltip_text (simple_runner.display_title);

            hast_table.foreach ((tool, list_item) => {
                list_item.get_data<Gtk.Image> ("check").set_visible (tool == simple_runner);
            });
        }

        void compatibility_tool_factory_bind (Object object) {
            var list_item = object as Gtk.ListItem;
            var simple_runner = list_item.get_item () as Models.Tools.Simple;

            hast_table.set (simple_runner, list_item);

            object.get_data<Gtk.Label> ("title").set_label (simple_runner.display_title);

            object.get_data<Gtk.Image> ("check").set_visible (simple_runner == get_selected_item ());

            object.get_data<Gtk.Box> ("box").set_tooltip_text (simple_runner.display_title);
        }

        void compatibility_tool_factory_unbind (Object object) {
            var list_item = object as Gtk.ListItem;
            var simple_runner = list_item.get_item () as Models.Tools.Simple;

            if (hast_table.get (simple_runner) == list_item)
                hast_table.remove (simple_runner);
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
