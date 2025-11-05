namespace ProtonPlus.Widgets {
	public class UnselectButton : Gtk.Button {
		Gtk.ListBox game_list_box { get; set; }
		Adw.ButtonContent selection_button_content { get; set; }

		construct {
			selection_button_content = new Adw.ButtonContent ();
			selection_button_content.set_label (_("Unselect all"));
			selection_button_content.set_icon_name ("deselect-symbolic");

			set_tooltip_text (_("Unselect all the games"));
			add_css_class ("flat");
			set_child (selection_button_content);

			clicked.connect (unselect_button_clicked);
		}

		public UnselectButton (Gtk.ListBox game_list_box) {
			this.game_list_box = game_list_box;
		}

		void unselect_button_clicked () {
			foreach (var row in game_list_box.get_selected_rows ()) {
				if (row is GameRow)
					((GameRow) row).selected = false;
			}
			
			game_list_box.unselect_all ();
		}
	}
}
