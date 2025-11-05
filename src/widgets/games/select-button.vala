namespace ProtonPlus.Widgets {
	public class SelectButton : Gtk.Button {
		Gtk.ListBox game_list_box { get; set; }
		Adw.ButtonContent selection_button_content { get; set; }

		construct {
			selection_button_content = new Adw.ButtonContent ();
			selection_button_content.set_label (_("Select all"));
			selection_button_content.set_icon_name ("select-all-symbolic");

			set_tooltip_text (_("Select all the games"));
			add_css_class ("flat");
			set_child (selection_button_content);

			clicked.connect (selection_button_clicked);
		}

		public SelectButton (Gtk.ListBox game_list_box) {
			this.game_list_box = game_list_box;
		}

		void selection_button_clicked () {
			game_list_box.select_all ();

			foreach (var row in game_list_box.get_selected_rows ()) {
				message ("bob");
				if (row is GameRow)
					((GameRow) row).selected = true;
			}
		}
	}
}
