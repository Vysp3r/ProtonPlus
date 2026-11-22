namespace ProtonPlus.Widgets.Games {
    public delegate bool FocusBeforeSelectionActions ();

    public class MassEditButton : Gtk.Button, Utils.ControllerDirectionalFocus {
        public signal void mass_edit_requested ();

        unowned FocusBeforeSelectionActions focus_previous;

        public MassEditButton (FocusBeforeSelectionActions focus_previous) {
            this.focus_previous = focus_previous;

            set_child (new Adw.ButtonContent () {
                label = _("Modify"),
                icon_name = "document-edit-symbolic"
            });
            set_valign (Gtk.Align.CENTER);
            add_css_class ("suggested-action");
            clicked.connect (() => mass_edit_requested ());
        }

        public void set_selected_count (int count) {
            update_property (Gtk.AccessibleProperty.LABEL,
                ngettext ("Modify %d selected game", "Modify %d selected games", count).printf (count), -1
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
            return focus_previous ();
        }
    }
}
