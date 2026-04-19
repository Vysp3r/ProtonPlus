namespace ProtonPlus.Widgets {
    public class MassEditButton : Gtk.Button {
        public signal void mass_edit_requested (GameRow[] rows);

        Gtk.ListBox game_list_box { get; set; }
        Adw.ButtonContent mass_edit_button_content { get; set; }

        construct {
            mass_edit_button_content = new Adw.ButtonContent ();
            mass_edit_button_content.set_label (_ ("Modify the selected games"));
            mass_edit_button_content.set_icon_name ("screwdriver-wrench-symbolic");

            set_tooltip_text (_ ("Modify the selected games all at once"));
            add_css_class ("flat");
            set_child (mass_edit_button_content);

            clicked.connect (mass_edit_button_clicked);
        }

        public MassEditButton (Gtk.ListBox game_list_box) {
            this.game_list_box = game_list_box;
        }

        void mass_edit_button_clicked () {
            var count = 0;
            var child = game_list_box.get_first_child ();
            while (child != null) {
                if (child is GameRow && ((GameRow)child).selected) {
                    count++;
                }
                child = child.get_next_sibling ();
            }

            if (count > 0) {
                var game_rows = new GameRow[count];
                var i = 0;
                child = game_list_box.get_first_child ();
                while (child != null) {
                    if (child is GameRow && ((GameRow)child).selected) {
                        game_rows[i] = (GameRow) child;
                        i++;
                    }
                    child = child.get_next_sibling ();
                }

                mass_edit_requested (game_rows);
            } else {
                var dialog = new WarningDialog (_ ("Warning"), _ ("Please make sure to select at least one game before using the mass edit feature."));
                dialog.present (Application.window);
            }
        }
    }
}
