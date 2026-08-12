namespace ProtonPlus.Widgets.Games {
    public delegate bool FocusLastVisibleGameRequest ();

    public class MassEditButton : Gtk.Button, Utils.ControllerDirectionalFocus {
        public signal void mass_edit_requested ();

        Adw.ButtonContent mass_edit_button_content;
        unowned FocusLastVisibleGameRequest focus_last_game;

        public MassEditButton (FocusLastVisibleGameRequest focus_last_game) {
            this.focus_last_game = focus_last_game;

            mass_edit_button_content = new Adw.ButtonContent () {
                label = _("Modify the selected games"),
                icon_name = "screwdriver-wrench-symbolic"
            };
            set_tooltip_text (_("Modify the selected games all at once"));
            set_halign (Gtk.Align.CENTER);
            add_css_class ("pill");
            add_css_class ("suggested-action");
            set_child (mass_edit_button_content);
            clicked.connect (() => mass_edit_requested ());
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
            return focus_last_game ();
        }
    }
}
