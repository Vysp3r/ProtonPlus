namespace ProtonPlus.Widgets.Preferences {
    public class ThemeRow : Adw.ComboRow {
        class Theme : Object {
            public string title { get; private set; }
            public Adw.ColorScheme color_scheme { get; private set; }

            public Theme (string title, Adw.ColorScheme color_scheme) {
                this.title = title;
                this.color_scheme = color_scheme;
            }
        }

        construct {
            var model = new ListStore(typeof (Theme));
			model.append (new Theme(_("System"), Adw.ColorScheme.DEFAULT));
            model.append (new Theme(_("Light"), Adw.ColorScheme.FORCE_LIGHT));
            model.append (new Theme(_("Dark"), Adw.ColorScheme.FORCE_DARK));

			var expression = new Gtk.PropertyExpression(typeof (Theme), null, "title");

            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect (factory_setup);
            factory.bind.connect (factory_bind);

            set_title (_("Current theme"));
            set_model(model);
			set_expression (expression);
			set_list_factory(factory);

            if (Globals.SETTINGS != null) {
                var theme = Globals.SETTINGS.get_enum ("theme");
                
                set_selected (theme == 4 ? 2 : theme);
            }
            
            notify["selected-item"].connect(selected_item_changed);
        }

		void selected_item_changed () {
			var theme = get_selected_item () as Theme;

			var style_manager = Adw.StyleManager.get_default();
            style_manager.set_color_scheme(theme.color_scheme);

            if (Globals.SETTINGS != null)
                Globals.SETTINGS.set_enum ("theme", theme.color_scheme);
		}

		void factory_bind (Object object) {
            var list_item = object as Gtk.ListItem;
			var theme = list_item.get_item() as Theme;

            object.get_data<Gtk.Label> ("title").set_label (theme.title);
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
    }
}