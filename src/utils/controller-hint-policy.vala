namespace ProtonPlus.Utils {
    public enum ControllerHintKind {
        SELECT,
        TOGGLE,
        OPEN,
        BACK,
        CLOSE,
        ADJUST_HORIZONTAL,
        ADJUST_VERTICAL,
        SWITCH_SECTION
    }

    public enum ControllerHintControlKind {
        DEFAULT,
        TOGGLE,
        OPEN,
        EDITABLE,
        HORIZONTAL_RANGE,
        VERTICAL_RANGE
    }

    public enum ControllerPhysicalButtonLabel {
        A,
        B,
        X,
        Y,
        CROSS,
        CIRCLE,
        SQUARE,
        TRIANGLE,
        BOTTOM,
        RIGHT
    }

    public class ControllerHintContext : Object {
        public bool controller_mode_active { get; set; default = false; }
        public bool has_dialog { get; set; default = false; }
        public bool has_popover { get; set; default = false; }
        public ControllerHintControlKind control_kind { get; set; default = ControllerHintControlKind.DEFAULT; }
        public bool can_navigate_back { get; set; default = false; }
        public bool can_switch_section { get; set; default = false; }
    }

    public class ControllerFaceButtonLabelFacts : Object {
        public ControllerPhysicalButtonLabel south { get; private set; }
        public ControllerPhysicalButtonLabel east { get; private set; }

        public ControllerFaceButtonLabelFacts (ControllerPhysicalButtonLabel south,
            ControllerPhysicalButtonLabel east) {
            this.south = south;
            this.east = east;
        }

        public bool equal_to (ControllerFaceButtonLabelFacts other) {
            return south == other.south && east == other.east;
        }
    }

    public class ControllerPromptButtonLabels : Object {
        public ControllerPhysicalButtonLabel confirm { get; private set; }
        public ControllerPhysicalButtonLabel back { get; private set; }

        public ControllerPromptButtonLabels (ControllerPhysicalButtonLabel confirm,
            ControllerPhysicalButtonLabel back) {
            this.confirm = confirm;
            this.back = back;
        }
    }

    public class ControllerPresentationState : Object {
        public bool controller_mode_active { get; private set; }
        private ControllerHintKind[] hint_values;
        public ControllerFaceButtonLabelFacts face_labels { get; private set; }
        public ControllerPromptButtonLabels prompt_labels { get; private set; }

        public ControllerPresentationState (bool controller_mode_active,
            ControllerHintKind[] hints, ControllerFaceButtonLabelFacts face_labels,
            ControllerPromptButtonLabels prompt_labels) {
            this.controller_mode_active = controller_mode_active;
            this.hint_values = hints;
            this.face_labels = face_labels;
            this.prompt_labels = prompt_labels;
        }

        public bool equal_to (ControllerPresentationState other) {
            if (controller_mode_active != other.controller_mode_active ||
                !face_labels.equal_to (other.face_labels) ||
                prompt_labels.confirm != other.prompt_labels.confirm ||
                prompt_labels.back != other.prompt_labels.back ||
                hint_values.length != other.hint_values.length)
                return false;

            for (int i = 0; i < hint_values.length; i++) {
                if (hint_values[i] != other.hint_values[i])
                    return false;
            }
            return true;
        }

        public unowned ControllerHintKind[] get_hints () {
            return hint_values;
        }
    }

    /* Display-independent hint selection. GTK inspection and translated
     * presentation stay at the integration boundary. */
    public class ControllerHintPolicy : Object {
        public static ControllerHintKind[] get_hints (ControllerHintContext context) {
            ControllerHintKind[] hints = {};
            if (!context.controller_mode_active || context.has_dialog)
                return hints;

            switch (context.control_kind) {
            case TOGGLE:
                hints += ControllerHintKind.TOGGLE;
                break;
            case OPEN:
                hints += ControllerHintKind.OPEN;
                break;
            case HORIZONTAL_RANGE:
                hints += ControllerHintKind.ADJUST_HORIZONTAL;
                break;
            case VERTICAL_RANGE:
                hints += ControllerHintKind.ADJUST_VERTICAL;
                break;
            case EDITABLE:
                break;
            default:
                hints += ControllerHintKind.SELECT;
                break;
            }

            if (context.has_popover)
                hints += ControllerHintKind.CLOSE;
            else if (context.can_navigate_back)
                hints += ControllerHintKind.BACK;

            if (!context.has_popover && context.can_switch_section)
                hints += ControllerHintKind.SWITCH_SECTION;
            return hints;
        }
    }

    /* SDL supplies physical labels independently for South and East. This
     * resolver preserves those facts before applying the user's mapping. */
    public class ControllerPhysicalLabelResolver : Object {
        public static ControllerFaceButtonLabelFacts from_sdl (
            SDL.Gamepad.GamepadButtonLabel south, SDL.Gamepad.GamepadButtonLabel east) {
            return new ControllerFaceButtonLabelFacts (
                map_sdl_label (south, ControllerPhysicalButtonLabel.BOTTOM),
                map_sdl_label (east, ControllerPhysicalButtonLabel.RIGHT)
            );
        }

        public static ControllerPromptButtonLabels map_prompts (
            ControllerFaceButtonLabelFacts facts, ControllerConfirmButton confirm_button) {
            if (confirm_button == ControllerConfirmButton.EAST)
                return new ControllerPromptButtonLabels (facts.east, facts.south);
            return new ControllerPromptButtonLabels (facts.south, facts.east);
        }

        static ControllerPhysicalButtonLabel map_sdl_label (
            SDL.Gamepad.GamepadButtonLabel label, ControllerPhysicalButtonLabel fallback) {
            switch (label) {
            case A:
                return ControllerPhysicalButtonLabel.A;
            case B:
                return ControllerPhysicalButtonLabel.B;
            case X:
                return ControllerPhysicalButtonLabel.X;
            case Y:
                return ControllerPhysicalButtonLabel.Y;
            case CROSS:
                return ControllerPhysicalButtonLabel.CROSS;
            case CIRCLE:
                return ControllerPhysicalButtonLabel.CIRCLE;
            case SQUARE:
                return ControllerPhysicalButtonLabel.SQUARE;
            case TRIANGLE:
                return ControllerPhysicalButtonLabel.TRIANGLE;
            default:
                return fallback;
            }
        }
    }
}
