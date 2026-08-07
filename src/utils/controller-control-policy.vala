namespace ProtonPlus.Utils {
    public enum ControllerControlKind {
        DEFAULT,
        HORIZONTAL_RANGE,
        VERTICAL_RANGE
    }

    public enum ControllerDirectionAction {
        MOVE_FOCUS,
        ADJUST_BACKWARD,
        ADJUST_FORWARD
    }

    /* Display-independent control semantics. GTK widget inspection and range
     * mutation remain in ControllerManager. */
    public class ControllerControlPolicy : Object {
        public static ControllerDirectionAction get_direction_action (
            ControllerControlKind control, ControllerNavigationDirection direction) {
            switch (control) {
            case HORIZONTAL_RANGE:
                if (direction == ControllerNavigationDirection.LEFT)
                    return ControllerDirectionAction.ADJUST_BACKWARD;
                if (direction == ControllerNavigationDirection.RIGHT)
                    return ControllerDirectionAction.ADJUST_FORWARD;
                break;
            case VERTICAL_RANGE:
                if (direction == ControllerNavigationDirection.UP)
                    return ControllerDirectionAction.ADJUST_BACKWARD;
                if (direction == ControllerNavigationDirection.DOWN)
                    return ControllerDirectionAction.ADJUST_FORWARD;
                break;
            default:
                break;
            }

            return ControllerDirectionAction.MOVE_FOCUS;
        }
    }
}
