namespace ProtonPlus.Widgets {
	public class MassEditButton : Gtk.Button {
		Gtk.ListBox game_list_box { get; set; }
		ListStore model { get; set; }
		Gtk.PropertyExpression expression { get; set; }
		Adw.ButtonContent mass_edit_button_content { get; set; }

		construct {
			mass_edit_button_content = new Adw.ButtonContent ();
			mass_edit_button_content.set_label (_("Mass edit"));
			mass_edit_button_content.set_icon_name ("edit-symbolic");

			set_tooltip_text (_("Edit the compatibility tool of the selected games at once"));
			add_css_class ("flat");
			set_child (mass_edit_button_content);

			clicked.connect (mass_edit_button_clicked);
		}

		public MassEditButton (Gtk.ListBox game_list_box) {
			this.game_list_box = game_list_box;
		}

		public void load (ListStore model, Gtk.PropertyExpression expression) {
			this.model = model;
			this.expression = expression;
		}

		void mass_edit_button_clicked () {
			var rows = game_list_box.get_selected_rows ();

			if (rows.length () > 0) {
				var game_rows = new GameRow[rows.length ()];
				for (var i = 0; i < rows.length (); i++) {
					var game_row = (GameRow) rows.nth_data (i);
					game_rows[i] = game_row;
				}

				var mass_edit_dialog = new MassEditDialog (game_rows, model, expression);
				mass_edit_dialog.present (Application.window);
			} else {
				var dialog = new Adw.AlertDialog (_("Warning"), _("Please make sure to select at least one game before using the mass edit feature."));
				dialog.add_response ("ok", _("OK"));
				dialog.present (Application.window);
			}
		}
	}
}
