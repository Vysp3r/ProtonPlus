namespace ProtonPlus.Widgets {
    public class ControllerHintBar : Gtk.Box {
        Gtk.Revealer revealer;
        Gtk.Box essential_box;
        Gtk.Box secondary_box;

        public ControllerHintBar () {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                hexpand: true,
                can_target: false,
                focusable: false
            );

            revealer = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.SLIDE_UP,
                transition_duration = 160,
                can_target = false,
                focusable = false
            };

            essential_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            essential_box.set_halign (Gtk.Align.CENTER);

            secondary_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            secondary_box.set_halign (Gtk.Align.CENTER);
            secondary_box.add_css_class ("controller-hint-secondary");

            var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            content.set_halign (Gtk.Align.CENTER);
            content.set_hexpand (true);
            content.append (essential_box);
            content.append (secondary_box);

            var responsive = new Adw.BreakpointBin ();
            responsive.set_size_request (360, 42);
            responsive.set_child (content);
            responsive.add_css_class ("controller-hint-bar");
            var narrow = new Adw.Breakpoint (new Adw.BreakpointCondition.length (
                Adw.BreakpointConditionLengthType.MAX_WIDTH, 520, Adw.LengthUnit.PX
            ));
            narrow.apply.connect (() => secondary_box.set_visible (false));
            narrow.unapply.connect (() => secondary_box.set_visible (true));
            responsive.add_breakpoint (narrow);
            revealer.set_child (responsive);
            append (revealer);
        }

        public void update_state (Utils.ControllerPresentationState state) {
            clear_box (essential_box);
            clear_box (secondary_box);
            unowned Utils.ControllerHintKind[] hints = state.get_hints ();

            int essential_count = 0;
            foreach (var hint in hints) {
                if (is_essential (hint)) {
                    essential_box.append (create_hint (hint, state));
                    essential_count++;
                }
            }
            foreach (var hint in hints) {
                if (is_essential (hint))
                    continue;
                var row = create_hint (hint, state);
                if (essential_count == 0) {
                    essential_box.append (row);
                    essential_count++;
                } else {
                    secondary_box.append (row);
                }
            }

            revealer.set_reveal_child (state.controller_mode_active && hints.length > 0);
        }

        bool is_essential (Utils.ControllerHintKind hint) {
            switch (hint) {
            case SELECT:
            case TOGGLE:
            case OPEN:
            case BACK:
            case EXIT:
            case CLOSE:
            case TEXT_INPUT:
                return true;
            default:
                return false;
            }
        }

        Gtk.Widget create_hint (Utils.ControllerHintKind hint,
            Utils.ControllerPresentationState state) {
            Utils.ControllerPhysicalButtonLabel? physical = null;
            string capsule_text;
            string capsule_accessible;
            string action;

            switch (hint) {
            case SELECT:
                physical = state.prompt_labels.confirm;
                action = _("Select");
                break;
            case TOGGLE:
                physical = state.prompt_labels.confirm;
                action = _("Toggle");
                break;
            case OPEN:
                physical = state.prompt_labels.confirm;
                action = _("Open");
                break;
            case BACK:
                physical = state.prompt_labels.back;
                action = _("Back");
                break;
            case EXIT:
                physical = state.prompt_labels.back;
                action = _("Exit");
                break;
            case CLOSE:
                physical = state.prompt_labels.back;
                action = _("Close");
                break;
            case ADJUST_HORIZONTAL:
                capsule_text = "←/→";
                capsule_accessible = _("Left and right");
                action = _("Adjust");
                return create_hint_row (capsule_text, capsule_accessible, action);
            case ADJUST_VERTICAL:
                capsule_text = "↑/↓";
                capsule_accessible = _("Up and down");
                action = _("Adjust");
                return create_hint_row (capsule_text, capsule_accessible, action);
            case TEXT_INPUT:
                capsule_text = "⌨";
                capsule_accessible = _("Keyboard");
                action = _("Enter text");
                return create_hint_row (capsule_text, capsule_accessible, action);
            case SWITCH_SECTION:
                capsule_text = _("Shoulders");
                capsule_accessible = _("Shoulder buttons");
                action = _("Switch section or page");
                return create_hint_row (capsule_text, capsule_accessible, action);
            case SEARCH:
                physical = state.face_labels.west;
                action = _("Search");
                break;
            case FILTER:
                physical = state.face_labels.north;
                action = _("Filter");
                break;
            default:
                assert_not_reached ();
            }

            physical_label ((!) physical, out capsule_text, out capsule_accessible);
            return create_hint_row (capsule_text, capsule_accessible, action);
        }

        Gtk.Widget create_hint_row (string capsule_text, string capsule_accessible,
            string action) {
            var capsule = new Gtk.Label (capsule_text);
            capsule.add_css_class ("controller-hint-button");
            capsule.set_tooltip_text (capsule_accessible);
            capsule.update_property (Gtk.AccessibleProperty.LABEL, capsule_accessible, -1);

            var action_label = new Gtk.Label (action);
            action_label.add_css_class ("controller-hint-action");
            action_label.set_wrap (false);

            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            row.set_can_target (false);
            row.set_focusable (false);
            row.append (capsule);
            row.append (action_label);
            return row;
        }

        void physical_label (Utils.ControllerPhysicalButtonLabel label,
            out string text, out string accessible) {
            switch (label) {
            case A:
                text = "A";
                accessible = _("A button");
                break;
            case B:
                text = "B";
                accessible = _("B button");
                break;
            case X:
                text = "X";
                accessible = _("X button");
                break;
            case Y:
                text = "Y";
                accessible = _("Y button");
                break;
            case CROSS:
                text = "×";
                accessible = _("Cross button");
                break;
            case CIRCLE:
                text = "○";
                accessible = _("Circle button");
                break;
            case SQUARE:
                text = "□";
                accessible = _("Square button");
                break;
            case TRIANGLE:
                text = "△";
                accessible = _("Triangle button");
                break;
            case BOTTOM:
                text = _("Bottom");
                accessible = _("Bottom face button");
                break;
            case RIGHT:
                text = _("Right");
                accessible = _("Right face button");
                break;
            case LEFT:
                text = _("Left");
                accessible = _("Left face button");
                break;
            case TOP:
                text = _("Top");
                accessible = _("Top face button");
                break;
            default:
                assert_not_reached ();
            }
        }

        void clear_box (Gtk.Box box) {
            Gtk.Widget? child;
            while ((child = box.get_first_child ()) != null)
                box.remove ((!) child);
        }
    }
}
