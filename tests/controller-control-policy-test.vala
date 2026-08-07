namespace AppTests.ControllerControlPolicyTest {
    using GLib;
    using ProtonPlus.Utils;

    private void assert_action (ControllerControlKind control,
        ControllerNavigationDirection direction, ControllerDirectionAction expected) {
        assert (ControllerControlPolicy.get_direction_action (control, direction) == expected);
    }

    private void test_horizontal_range () {
        assert_action (
            ControllerControlKind.HORIZONTAL_RANGE,
            ControllerNavigationDirection.LEFT,
            ControllerDirectionAction.ADJUST_BACKWARD
        );
        assert_action (
            ControllerControlKind.HORIZONTAL_RANGE,
            ControllerNavigationDirection.RIGHT,
            ControllerDirectionAction.ADJUST_FORWARD
        );
        assert_action (
            ControllerControlKind.HORIZONTAL_RANGE,
            ControllerNavigationDirection.UP,
            ControllerDirectionAction.MOVE_FOCUS
        );
        assert_action (
            ControllerControlKind.HORIZONTAL_RANGE,
            ControllerNavigationDirection.DOWN,
            ControllerDirectionAction.MOVE_FOCUS
        );
    }

    private void test_vertical_range () {
        assert_action (
            ControllerControlKind.VERTICAL_RANGE,
            ControllerNavigationDirection.UP,
            ControllerDirectionAction.ADJUST_BACKWARD
        );
        assert_action (
            ControllerControlKind.VERTICAL_RANGE,
            ControllerNavigationDirection.DOWN,
            ControllerDirectionAction.ADJUST_FORWARD
        );
        assert_action (
            ControllerControlKind.VERTICAL_RANGE,
            ControllerNavigationDirection.LEFT,
            ControllerDirectionAction.MOVE_FOCUS
        );
        assert_action (
            ControllerControlKind.VERTICAL_RANGE,
            ControllerNavigationDirection.RIGHT,
            ControllerDirectionAction.MOVE_FOCUS
        );
    }

    private void test_default_control () {
        var directions = new ControllerNavigationDirection[] {
            ControllerNavigationDirection.UP,
            ControllerNavigationDirection.DOWN,
            ControllerNavigationDirection.LEFT,
            ControllerNavigationDirection.RIGHT
        };
        foreach (var direction in directions) {
            assert_action (
                ControllerControlKind.DEFAULT,
                direction,
                ControllerDirectionAction.MOVE_FOCUS
            );
        }
    }

    private void test_adjustments_are_always_consumed () {
        var initial = ControllerControlPolicy.get_direction_action (
            ControllerControlKind.HORIZONTAL_RANGE,
            ControllerNavigationDirection.LEFT
        );
        var repeated = ControllerControlPolicy.get_direction_action (
            ControllerControlKind.HORIZONTAL_RANGE,
            ControllerNavigationDirection.LEFT
        );

        assert (initial == ControllerDirectionAction.ADJUST_BACKWARD);
        assert (repeated == initial);
        /* Bounds are deliberately absent from this policy: the native range
         * operation stays consumed whether or not GTK changes its value. */
    }

    private void test_actions_are_exclusive () {
        var controls = new ControllerControlKind[] {
            ControllerControlKind.DEFAULT,
            ControllerControlKind.HORIZONTAL_RANGE,
            ControllerControlKind.VERTICAL_RANGE
        };
        var directions = new ControllerNavigationDirection[] {
            ControllerNavigationDirection.UP,
            ControllerNavigationDirection.DOWN,
            ControllerNavigationDirection.LEFT,
            ControllerNavigationDirection.RIGHT
        };

        foreach (var control in controls) {
            foreach (var direction in directions) {
                var action = ControllerControlPolicy.get_direction_action (control, direction);
                var adjusts = action == ControllerDirectionAction.ADJUST_BACKWARD ||
                    action == ControllerDirectionAction.ADJUST_FORWARD;
                var moves_focus = action == ControllerDirectionAction.MOVE_FOCUS;
                assert (adjusts != moves_focus);
            }
        }
    }

    public void register_tests () {
        Test.add_func ("/controller-control/horizontal-range", test_horizontal_range);
        Test.add_func ("/controller-control/vertical-range", test_vertical_range);
        Test.add_func ("/controller-control/default", test_default_control);
        Test.add_func ("/controller-control/consumed-at-bounds-and-repeat", test_adjustments_are_always_consumed);
        Test.add_func ("/controller-control/exclusive-actions", test_actions_are_exclusive);
    }
}
