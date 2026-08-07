namespace ProtonPlus.Widgets {
    public class ControllerChoiceBox : Gtk.Box, Utils.ControllerDirectionalFocus {
        public ControllerChoiceBox () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12);
        }

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            var focused = focused_object as Gtk.Widget;
            var option = find_option_ancestor (focused);
            if (option == null)
                return false;

            if (direction == Utils.ControllerNavigationDirection.UP ||
                direction == Utils.ControllerNavigationDirection.DOWN) {
                var adjacent = find_adjacent_option (
                    (!) option,
                    direction == Utils.ControllerNavigationDirection.DOWN
                );
                if (adjacent != null)
                    ((!) adjacent).grab_focus ();
                return true;
            }

            if (direction == Utils.ControllerNavigationDirection.LEFT ||
                direction == Utils.ControllerNavigationDirection.RIGHT)
                return true;

            return false;
        }

        Gtk.Widget? find_option_ancestor (Gtk.Widget? focused) {
            var current = focused;
            while (current != null && current != this) {
                if (current.get_parent () == this)
                    return current;
                current = current.get_parent ();
            }
            return null;
        }

        Gtk.Widget? find_adjacent_option (Gtk.Widget option, bool forward) {
            var sibling = forward
                ? option.get_next_sibling () : option.get_prev_sibling ();
            while (sibling != null) {
                if (sibling.get_mapped () && sibling.is_visible () &&
                    sibling.is_sensitive () && sibling.get_focusable ())
                    return sibling;
                sibling = forward
                    ? sibling.get_next_sibling () : sibling.get_prev_sibling ();
            }
            return null;
        }
    }
}
