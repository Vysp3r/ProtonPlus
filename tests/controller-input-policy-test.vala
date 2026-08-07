namespace AppTests.ControllerInputPolicyTest {
    using GLib;
    using ProtonPlus.Utils;

    private int16 axis_value (double value) {
        if (value < 0)
            return (int16) Math.round (value * 32768.0);
        return (int16) Math.round (value * 32767.0);
    }

    private void assert_direction (ControllerNavigationUpdate update,
        ControllerNavigationDirection expected) {
        assert (update.emitted_direction == expected);
    }

    private void test_face_button_mapping () {
        assert (ControllerInputPolicy.get_face_button_action (
            ControllerConfirmButton.SOUTH,
            ControllerFaceButton.SOUTH
        ) == ControllerFaceButtonAction.ACTIVATE);
        assert (ControllerInputPolicy.get_face_button_action (
            ControllerConfirmButton.SOUTH,
            ControllerFaceButton.EAST
        ) == ControllerFaceButtonAction.DISMISS);
        assert (ControllerInputPolicy.get_face_button_action (
            ControllerConfirmButton.EAST,
            ControllerFaceButton.EAST
        ) == ControllerFaceButtonAction.ACTIVATE);
        assert (ControllerInputPolicy.get_face_button_action (
            ControllerConfirmButton.EAST,
            ControllerFaceButton.SOUTH
        ) == ControllerFaceButtonAction.DISMISS);
    }

    private void test_confirm_enum_contract () {
        assert ((int) ControllerConfirmButton.SOUTH == 0);
        assert ((int) ControllerConfirmButton.EAST == 1);
    }

    private void test_axis_normalization () {
        assert (ControllerInputPolicy.normalize_axis (0) == 0);
        assert (ControllerInputPolicy.normalize_axis (32767) == 1);
        assert (ControllerInputPolicy.normalize_axis (-32768) == -1);
        assert_cmpfloat_with_epsilon (
            ControllerInputPolicy.normalize_axis (16384),
            16384.0 / 32767.0,
            0.000001
        );
        assert_cmpfloat_with_epsilon (
            ControllerInputPolicy.normalize_axis (-16384),
            -0.5,
            0.000001
        );
    }

    private void test_left_stick_engagement_and_release () {
        var policy = new ControllerInputPolicy ();

        assert_direction (policy.update_left_axis (1, true, axis_value (0.54)), ControllerNavigationDirection.NONE);
        var engaged = policy.update_left_axis (1, true, axis_value (0.56));
        assert_direction (engaged, ControllerNavigationDirection.RIGHT);
        assert (engaged.repeat_changed);
        assert (policy.has_repeat);

        assert_direction (policy.update_left_axis (1, true, axis_value (0.80)), ControllerNavigationDirection.NONE);
        assert_direction (policy.update_left_axis (1, true, axis_value (0.36)), ControllerNavigationDirection.NONE);
        var released = policy.update_left_axis (1, true, axis_value (0.34));
        assert_direction (released, ControllerNavigationDirection.NONE);
        assert (released.repeat_changed);
        assert (!policy.has_repeat);

        assert_direction (policy.update_left_axis (1, true, axis_value (0.70)), ControllerNavigationDirection.RIGHT);
    }

    private void test_left_stick_diagonal_hysteresis () {
        var horizontal = new ControllerInputPolicy ();
        horizontal.update_left_axis (1, false, axis_value (0.60));
        assert_direction (
            horizontal.update_left_axis (1, true, axis_value (0.80)),
            ControllerNavigationDirection.RIGHT
        );

        var vertical = new ControllerInputPolicy ();
        vertical.update_left_axis (1, true, axis_value (0.60));
        assert_direction (
            vertical.update_left_axis (1, false, axis_value (-0.80)),
            ControllerNavigationDirection.UP
        );

        var stable = new ControllerInputPolicy ();
        assert_direction (
            stable.update_left_axis (1, true, axis_value (0.70)),
            ControllerNavigationDirection.RIGHT
        );
        assert_direction (
            stable.update_left_axis (1, false, axis_value (0.72)),
            ControllerNavigationDirection.NONE
        );
        assert_direction (
            stable.update_left_axis (1, true, axis_value (0.71)),
            ControllerNavigationDirection.NONE
        );
        var dominance_change = stable.update_left_axis (1, false, axis_value (-0.90));
        assert_direction (dominance_change, ControllerNavigationDirection.UP);
        assert (dominance_change.repeat_changed);
    }

    private void test_right_stick_scroll_policy () {
        var policy = new ControllerInputPolicy ();

        assert (!policy.update_right_axis (1, axis_value (0.24)));
        assert (policy.scroll_intent == 0);
        assert (policy.update_right_axis (1, axis_value (0.50)));
        assert_cmpfloat_with_epsilon (policy.scroll_intent, 0.50, 0.0001);
        assert (!policy.has_repeat);
        assert (!policy.update_right_axis (1, axis_value (-0.75)));
        assert_cmpfloat_with_epsilon (policy.scroll_intent, -0.75, 0.0001);
        assert (!policy.has_repeat);
        assert (!policy.update_right_axis (1, axis_value (0.10)));
        assert (policy.scroll_intent == 0);
    }

    private void test_active_device_ownership () {
        var policy = new ControllerInputPolicy ();

        assert (policy.note_button_press (1));
        assert (policy.active_device_id == 1);
        assert (!policy.update_left_axis (2, true, axis_value (0.10)).ownership_changed);
        assert (policy.active_device_id == 1);

        var takeover = policy.update_left_axis (2, true, axis_value (0.70));
        assert (takeover.ownership_changed);
        assert (policy.active_device_id == 2);
        assert (policy.has_repeat);

        policy.update_left_axis (1, true, 0);
        assert (policy.active_device_id == 2);
        assert (policy.has_repeat);

        assert (policy.update_right_axis (3, axis_value (0.70)));
        assert (policy.active_device_id == 3);
        assert (!policy.has_repeat);
        policy.update_right_axis (2, 0);
        assert (policy.active_device_id == 3);
        assert_cmpfloat_with_epsilon (policy.scroll_intent, 0.70, 0.0001);

        assert (policy.disconnect_device (3));
        assert (!policy.has_active_device);
        assert (policy.scroll_intent == 0);
        assert (!policy.disconnect_device (2));
    }

    private void test_button_claim_suppresses_held_axes () {
        var held_axes = new ControllerInputPolicy ();
        assert_direction (
            held_axes.update_left_axis (2, true, axis_value (0.70)),
            ControllerNavigationDirection.RIGHT
        );
        assert (held_axes.update_right_axis (2, axis_value (0.70)) == false);
        assert (held_axes.note_button_press (1));
        assert (held_axes.note_button_press (2));
        assert_direction (
            held_axes.update_left_axis (2, true, axis_value (0.80)),
            ControllerNavigationDirection.NONE
        );
        held_axes.update_right_axis (2, axis_value (0.80));
        assert (held_axes.scroll_intent == 0);

        held_axes.update_left_axis (2, true, axis_value (0.20));
        held_axes.update_right_axis (2, axis_value (0.20));
        assert_direction (
            held_axes.update_left_axis (2, true, axis_value (-0.70)),
            ControllerNavigationDirection.LEFT
        );
        held_axes.update_right_axis (2, axis_value (-0.70));
        assert_cmpfloat_with_epsilon (held_axes.scroll_intent, -0.70, 0.0001);
    }

    private void test_repeat_identity_and_resets () {
        var policy = new ControllerInputPolicy ();
        policy.note_button_press (1);

        assert (policy.begin_repeat (
            1,
            ControllerNavigationDirection.DOWN,
            ControllerNavigationSource.DPAD
        ));
        assert (policy.repeat_direction == ControllerNavigationDirection.DOWN);
        assert (!policy.release_repeat (
            2,
            ControllerNavigationDirection.DOWN,
            ControllerNavigationSource.DPAD
        ));
        assert (!policy.release_repeat (
            1,
            ControllerNavigationDirection.DOWN,
            ControllerNavigationSource.LEFT_STICK
        ));
        assert (policy.has_repeat);

        assert (policy.begin_repeat (
            1,
            ControllerNavigationDirection.DOWN,
            ControllerNavigationSource.LEFT_STICK
        ));
        assert (policy.repeat_direction == ControllerNavigationDirection.DOWN);
        assert (policy.repeat_source == ControllerNavigationSource.LEFT_STICK);

        assert (policy.begin_repeat (
            1,
            ControllerNavigationDirection.RIGHT,
            ControllerNavigationSource.LEFT_STICK
        ));
        assert (policy.repeat_direction == ControllerNavigationDirection.RIGHT);
        assert (policy.repeat_source == ControllerNavigationSource.LEFT_STICK);

        assert (policy.note_button_press (2));
        assert (!policy.has_repeat);
        assert (policy.begin_repeat (
            2,
            ControllerNavigationDirection.UP,
            ControllerNavigationSource.DPAD
        ));
        policy.surface_changed ();
        assert (!policy.has_repeat);
    }

    private void test_surface_change_requires_neutral () {
        var policy = new ControllerInputPolicy ();
        assert_direction (
            policy.update_left_axis (1, false, axis_value (0.70)),
            ControllerNavigationDirection.DOWN
        );
        policy.surface_changed ();

        assert_direction (
            policy.update_left_axis (1, false, axis_value (0.80)),
            ControllerNavigationDirection.NONE
        );

        policy.update_left_axis (1, false, axis_value (0.20));
        assert_direction (
            policy.update_left_axis (1, false, axis_value (-0.70)),
            ControllerNavigationDirection.UP
        );
    }

    private void test_surface_change_suppresses_scroll_until_neutral () {
        var policy = new ControllerInputPolicy ();
        policy.update_right_axis (1, axis_value (0.70));
        assert_cmpfloat_with_epsilon (policy.scroll_intent, 0.70, 0.0001);
        policy.surface_changed ();
        assert (policy.scroll_intent == 0);
        policy.update_right_axis (1, axis_value (0.80));
        assert (policy.scroll_intent == 0);
        policy.update_right_axis (1, axis_value (0.20));
        assert (policy.scroll_intent == 0);
        policy.update_right_axis (1, axis_value (-0.70));
        assert_cmpfloat_with_epsilon (policy.scroll_intent, -0.70, 0.0001);
    }

    public void register_tests () {
        Test.add_func ("/controller-input/face-button-mapping", test_face_button_mapping);
        Test.add_func ("/controller-input/confirm-enum-contract", test_confirm_enum_contract);
        Test.add_func ("/controller-input/axis-normalization", test_axis_normalization);
        Test.add_func ("/controller-input/left-stick-engagement", test_left_stick_engagement_and_release);
        Test.add_func ("/controller-input/left-stick-diagonal", test_left_stick_diagonal_hysteresis);
        Test.add_func ("/controller-input/right-stick-scroll", test_right_stick_scroll_policy);
        Test.add_func ("/controller-input/active-device", test_active_device_ownership);
        Test.add_func ("/controller-input/button-claim-held-axes", test_button_claim_suppresses_held_axes);
        Test.add_func ("/controller-input/repeat-identity", test_repeat_identity_and_resets);
        Test.add_func ("/controller-input/surface-neutral", test_surface_change_requires_neutral);
        Test.add_func ("/controller-input/surface-scroll-neutral", test_surface_change_suppresses_scroll_until_neutral);
    }
}
