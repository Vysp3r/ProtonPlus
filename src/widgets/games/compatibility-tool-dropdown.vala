namespace ProtonPlus.Widgets {
	public class CompatibilityToolDropDown : Gtk.Widget {
        Gtk.SignalListItemFactory factory;
		Gtk.SignalListItemFactory list_factory;
        Gtk.ListItem last_compatibility_tool_list_item;
		public Gtk.DropDown dropdown;
		Gtk.BinLayout bin_layout;
		Models.Game game;
		public bool skip;
		HashTable<Models.SimpleRunner, Gtk.ListItem> hast_table;

        public CompatibilityToolDropDown (Models.Game game, ListStore model, Gtk.PropertyExpression expression) {
			this.game = game;

			hast_table = new HashTable<Models.SimpleRunner, Gtk.ListItem> (null, (a, b) => {
				return a.internal_title == b.internal_title;
			});

			list_factory = new Gtk.SignalListItemFactory ();
           	list_factory.setup.connect (list_factory_setup);
            list_factory.bind.connect (list_factory_bind);

            factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect (factory_setup);
            factory.bind.connect (factory_bind);

			dropdown = new Gtk.DropDown (model, expression);
			dropdown.set_list_factory (list_factory);
			dropdown.set_factory (factory);
			dropdown.set_parent (this);
			
			if (game.compatibility_tool == _("Undefined")) {
				dropdown.set_selected(0);
			} else {
				for (var i = 0; i < game.launcher.compatibility_tools.length(); i++) {
					if (game.launcher.compatibility_tools.nth_data(i).internal_title == game.compatibility_tool) {
						dropdown.set_selected(i + 1);
						break;
					}
				}
			}

			dropdown.notify["selected-item"].connect(selected_item_changed);

			bin_layout = new Gtk.BinLayout();

			destroy.connect(on_destroy);

			set_layout_manager(bin_layout);
			set_size_request (350, 0);
        }

		void selected_item_changed () {
			var simple_runner = dropdown.get_selected_item () as Models.SimpleRunner;
			var list_item = hast_table.get (simple_runner);

			if (list_item == null)
				return;

			set_tooltip_text (simple_runner.display_title);

			list_item.get_data<Gtk.Image> ("check").set_visible (true);

			last_compatibility_tool_list_item.get_data<Gtk.Image> ("check").set_visible (false);

			last_compatibility_tool_list_item = list_item;

			if (skip) {
				skip = false;
				return;
			}

			var success = game.change_compatibility_tool(simple_runner.internal_title);
			if (!success) {
				var dialog = new Adw.AlertDialog(_("Error"), "%s\n%s".printf(_("When trying to change the compatibility tool of %s an error occurred.").printf(game.name), _("Please report this issue on GitHub.")));
				dialog.add_response("ok", "OK");
				dialog.present(Application.window);

				skip = true;

				if (game.compatibility_tool == _("Undefined")) {
					dropdown.set_selected(0);
				} else {
					for (var i = 0; i < game.launcher.compatibility_tools.length(); i++) {
						if (game.compatibility_tool == game.launcher.compatibility_tools.nth_data(i).internal_title) {
							dropdown.set_selected(i + 1);
							break;
						}
					}
				}
			}
		}

		void list_factory_bind (Object object) {
            var list_item = object as Gtk.ListItem;
			var simple_runner = list_item.get_item() as Models.SimpleRunner;

			hast_table.set (simple_runner, list_item);

            object.get_data<Gtk.Label> ("title").set_label (simple_runner.display_title);

			object.get_data<Gtk.Image> ("check").set_visible (list_item.get_selected ());

			object.get_data<Gtk.Box> ("box").set_tooltip_text (simple_runner.display_title);

			if (list_item.get_selected ())
				last_compatibility_tool_list_item = list_item;
        }

        void list_factory_setup (Object object) {
			var list_item = object as Gtk.ListItem;
			
            var title_label = new Gtk.Label (null);
			title_label.set_xalign(0.0f);
			title_label.set_max_width_chars (30);
			title_label.set_ellipsize (Pango.EllipsizeMode.END);
			title_label.set_hexpand (true);

			var check_image = new Gtk.Image.from_icon_name("object-select-symbolic");
			check_image.set_visible (false);

			var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			box.append(title_label);
			box.append(check_image);
			box.set_size_request (290, 0);

            object.set_data ("title", title_label);
			object.set_data ("check", check_image);
			object.set_data ("box", box);

			list_item.set_child(box);
        }

		void factory_bind (Object object) {
            var list_item = object as Gtk.ListItem;
			var simple_runner = list_item.get_item() as Models.SimpleRunner;

            object.get_data<Gtk.Label> ("title").set_label (simple_runner.display_title);

			dropdown.set_tooltip_text (simple_runner.display_title);
        }

        void factory_setup (Object object) {
			var list_item = object as Gtk.ListItem;
			
            var title_label = new Gtk.Label (null);
			title_label.set_xalign(0.0f);
			title_label.set_max_width_chars (30);
			title_label.set_ellipsize (Pango.EllipsizeMode.END);
			title_label.set_hexpand (true);

            object.set_data ("title", title_label);

			list_item.set_child(title_label);
        }

		void on_destroy () {
			dropdown.unparent ();
		}
    }
}