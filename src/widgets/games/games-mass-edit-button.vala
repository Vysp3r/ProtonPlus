namespace ProtonPlus.Widgets.Games {
    public class MassEditButton : Gtk.Button, Utils.ControllerDirectionalFocus {
        public signal void mass_edit_requested (GameRow[] rows);

        Gtk.ListBox game_list_box { get; set; }
        Adw.ButtonContent mass_edit_button_content { get; set; }

        construct {
            mass_edit_button_content = new Adw.ButtonContent ();
            mass_edit_button_content.set_label (_ ("Modify the selected games"));
            mass_edit_button_content.set_icon_name ("screwdriver-wrench-symbolic");

            set_tooltip_text (_ ("Modify the selected games all at once"));
            set_halign (Gtk.Align.CENTER);
            add_css_class ("pill");
            add_css_class ("suggested-action");
            set_child (mass_edit_button_content);

            clicked.connect (mass_edit_button_clicked);
        }

        public MassEditButton (Gtk.ListBox game_list_box) {
            this.game_list_box = game_list_box;
        }

        public void set_selected_count (int count) {
            mass_edit_button_content.set_label (
                ngettext ("Modify %d selected game", "Modify %d selected games", count).printf (count)
            );
            set_tooltip_text (
                ngettext ("Modify %d selected game all at once", "Modify %d selected games all at once", count).printf (count)
            );
        }

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            var focused = focused_object as Gtk.Widget;
            if (focused == null ||
                (focused != this && !((!) focused).is_ancestor (this)) ||
                direction != Utils.ControllerNavigationDirection.UP)
                return false;

            var child = game_list_box.get_last_child ();
            while (child != null) {
                if (child is GameRow && child.get_mapped () && child.is_visible () &&
                    child.get_child_visible () && child.is_sensitive () &&
                    child.get_focusable ())
                    return child.grab_focus ();
                child = child.get_prev_sibling ();
            }
            return false;
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
                var dialog = new Main.WarningDialog (_ ("Warning"), _ ("Please make sure to select at least one game before using the mass edit feature."));
                ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ());
            }
        }
    }
}
