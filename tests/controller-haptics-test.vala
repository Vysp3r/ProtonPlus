namespace AppTests.ControllerHapticsTest {
    using ProtonPlus.Utils;

    private class RecordingHapticSink : Object, ControllerHapticSink {
        public bool supported = true;
        public int support_checks = 0;
        public Gee.ArrayList<int64?> pulse_devices = new Gee.ArrayList<int64?> ();
        public Gee.ArrayList<ControllerHapticPulse> pulses =
            new Gee.ArrayList<ControllerHapticPulse> ();
        public Gee.ArrayList<int64?> stopped_devices = new Gee.ArrayList<int64?> ();

        public bool supports_device (int64 device_id) {
            support_checks++;
            return supported;
        }

        public bool pulse (int64 device_id, ControllerHapticPulse pulse) {
            pulse_devices.add (device_id);
            pulses.add (pulse);
            return true;
        }

        public void stop (int64 device_id) {
            stopped_devices.add (device_id);
        }
    }

    private ControllerHapticFeedback enabled_feedback (RecordingHapticSink sink,
        int64 device_id = 1) {
        var feedback = new ControllerHapticFeedback (sink);
        feedback.set_enabled (true);
        feedback.claim_device (device_id);
        return feedback;
    }

    private void test_disabled_produces_no_pulse () {
        var sink = new RecordingHapticSink ();
        var feedback = new ControllerHapticFeedback (sink);
        feedback.claim_device (1);
        feedback.activation_outcome (
            1, ControllerActivationDecision.ACTIVATE, true, 1000000
        );
        assert (sink.pulses.size == 0);
        assert (sink.support_checks == 0);
    }

    private void test_supported_active_device_profile () {
        var sink = new RecordingHapticSink ();
        var feedback = enabled_feedback (sink);
        feedback.activation_outcome (
            1, ControllerActivationDecision.ACTIVATE, true, 1000000
        );

        assert (sink.pulses.size == 1);
        assert (sink.pulse_devices[0] == 1);
        assert (sink.pulses[0].low_frequency_strength == 7000);
        assert (sink.pulses[0].high_frequency_strength == 12000);
        assert (sink.pulses[0].duration_ms == 55);
    }

    private void test_unsupported_fails_closed () {
        var sink = new RecordingHapticSink () { supported = false };
        var feedback = enabled_feedback (sink);
        feedback.activation_outcome (
            1, ControllerActivationDecision.ACTIVATE, true, 1000000
        );

        assert (sink.support_checks == 1);
        assert (sink.pulses.size == 0);
    }

    private void test_only_active_device_receives_feedback () {
        var sink = new RecordingHapticSink ();
        var feedback = enabled_feedback (sink, 7);
        feedback.activation_outcome (
            8, ControllerActivationDecision.ACTIVATE, true, 1000000
        );
        feedback.activation_outcome (
            7, ControllerActivationDecision.ACTIVATE, true, 1000000
        );

        assert (sink.pulses.size == 1);
        assert (sink.pulse_devices[0] == 7);
    }

    private void test_activation_outcomes_and_text_input () {
        var sink = new RecordingHapticSink ();
        var feedback = enabled_feedback (sink);
        feedback.activation_outcome (
            1, ControllerActivationDecision.ACTIVATE, false, 1000000
        );
        feedback.activation_outcome (
            1, ControllerActivationDecision.FOCUS_TEXT_INPUT, true, 1200000
        );
        assert (sink.pulses.size == 0);

        feedback.activation_outcome (
            1, ControllerActivationDecision.ACTIVATE, true, 1400000
        );
        assert (sink.pulses.size == 1);
    }

    private void test_navigation_outcomes () {
        var sink = new RecordingHapticSink ();
        var feedback = enabled_feedback (sink);
        feedback.navigation_outcome (1, false, 1000000);
        assert (sink.pulses.size == 0);

        // Dismiss, application pop, and shoulder page switch share the same
        // successful semantic outcome and gentle profile.
        feedback.navigation_outcome (1, true, 1200000);
        feedback.navigation_outcome (1, true, 1400000);
        feedback.navigation_outcome (1, true, 1600000);
        assert (sink.pulses.size == 3);
        foreach (var pulse in sink.pulses) {
            assert (pulse.low_frequency_strength == 4500);
            assert (pulse.high_frequency_strength == 7500);
            assert (pulse.duration_ms == 45);
        }
    }

    private void test_boundary_latch_and_release () {
        var sink = new RecordingHapticSink ();
        var feedback = enabled_feedback (sink);
        feedback.direction_outcome (
            1, ControllerNavigationDirection.LEFT, false, 1000000
        );
        feedback.direction_outcome (
            1, ControllerNavigationDirection.LEFT, false, 2000000
        );
        assert (sink.pulses.size == 1);

        feedback.direction_released (1, ControllerNavigationDirection.LEFT);
        feedback.direction_outcome (
            1, ControllerNavigationDirection.LEFT, false, 3000000
        );
        assert (sink.pulses.size == 2);
    }

    private void test_successful_movement_resets_boundary () {
        var sink = new RecordingHapticSink ();
        var feedback = enabled_feedback (sink);
        feedback.direction_outcome (
            1, ControllerNavigationDirection.DOWN, false, 1000000
        );
        feedback.direction_outcome (
            1, ControllerNavigationDirection.DOWN, true, 1200000
        );
        feedback.direction_outcome (
            1, ControllerNavigationDirection.DOWN, false, 1400000
        );
        assert (sink.pulses.size == 2);
    }

    private void test_duplicate_cooldown () {
        var sink = new RecordingHapticSink ();
        var feedback = enabled_feedback (sink);
        feedback.activation_outcome (
            1, ControllerActivationDecision.ACTIVATE, true, 1000000
        );
        feedback.activation_outcome (
            1, ControllerActivationDecision.ACTIVATE, true, 1050000
        );
        feedback.activation_outcome (
            1, ControllerActivationDecision.ACTIVATE, true,
            1000000 + ControllerHapticPolicy.DUPLICATE_COOLDOWN_USEC
        );
        assert (sink.pulses.size == 2);
    }

    private void test_disabling_stops_and_resets () {
        var sink = new RecordingHapticSink ();
        var feedback = enabled_feedback (sink);
        feedback.direction_outcome (
            1, ControllerNavigationDirection.RIGHT, false, 1000000
        );
        feedback.set_enabled (false);
        assert (sink.stopped_devices.size == 1);
        assert (sink.stopped_devices[0] == 1);

        feedback.direction_outcome (
            1, ControllerNavigationDirection.RIGHT, false, 2000000
        );
        assert (sink.pulses.size == 1);
        feedback.set_enabled (true);
        feedback.direction_outcome (
            1, ControllerNavigationDirection.RIGHT, false, 3000000
        );
        assert (sink.pulses.size == 2);
    }

    private void test_disconnect_and_ownership_changes () {
        var sink = new RecordingHapticSink ();
        var feedback = enabled_feedback (sink, 1);
        feedback.activation_outcome (
            1, ControllerActivationDecision.ACTIVATE, true, 1000000
        );

        feedback.claim_device (2);
        feedback.activation_outcome (
            1, ControllerActivationDecision.ACTIVATE, true, 1200000
        );
        feedback.activation_outcome (
            2, ControllerActivationDecision.ACTIVATE, true, 1200000
        );
        feedback.disconnect_device (2);
        feedback.activation_outcome (
            2, ControllerActivationDecision.ACTIVATE, true, 1400000
        );

        assert (sink.pulses.size == 2);
        assert (sink.pulse_devices[0] == 1);
        assert (sink.pulse_devices[1] == 2);
        assert (sink.stopped_devices.size == 2);
        assert (sink.stopped_devices[0] == 1);
        assert (sink.stopped_devices[1] == 2);
    }

    private void test_inactive_window_and_context_reset () {
        var sink = new RecordingHapticSink ();
        var feedback = enabled_feedback (sink);
        feedback.direction_outcome (
            1, ControllerNavigationDirection.UP, false, 1000000
        );
        feedback.context_changed ();
        feedback.direction_outcome (
            1, ControllerNavigationDirection.UP, false, 1200000
        );
        assert (sink.pulses.size == 2);

        feedback.set_input_active (false);
        assert (sink.stopped_devices.size == 1);
        feedback.direction_outcome (
            1, ControllerNavigationDirection.UP, false, 1400000
        );
        assert (sink.pulses.size == 2);
        feedback.set_input_active (true);
        feedback.direction_outcome (
            1, ControllerNavigationDirection.UP, false, 1600000
        );
        assert (sink.pulses.size == 3);
    }

    private void test_profiles_are_bounded_and_short () {
        var policy = new ControllerHapticPolicy ();
        policy.set_enabled (true);
        var activation = policy.pulse_for (
            ControllerHapticEvent.ACTIVATION, ControllerNavigationDirection.NONE, 1000000
        );
        var navigation = policy.pulse_for (
            ControllerHapticEvent.NAVIGATION, ControllerNavigationDirection.NONE, 1200000
        );
        var boundary = policy.pulse_for (
            ControllerHapticEvent.BOUNDARY, ControllerNavigationDirection.UP, 1400000
        );

        assert (activation != null && navigation != null && boundary != null);
        ControllerHapticPulse[] pulses = { (!) activation, (!) navigation, (!) boundary };
        foreach (var pulse in pulses) {
            assert (pulse.low_frequency_strength <= ControllerHapticPolicy.MAX_STRENGTH);
            assert (pulse.high_frequency_strength <= ControllerHapticPolicy.MAX_STRENGTH);
            assert (pulse.duration_ms > 0);
            assert (pulse.duration_ms <= ControllerHapticPolicy.MAX_DURATION_MS);
        }
    }

    public void register_tests () {
        Test.add_func ("/controller-haptics/disabled", test_disabled_produces_no_pulse);
        Test.add_func ("/controller-haptics/supported-active-profile",
            test_supported_active_device_profile);
        Test.add_func ("/controller-haptics/unsupported", test_unsupported_fails_closed);
        Test.add_func ("/controller-haptics/active-device-only",
            test_only_active_device_receives_feedback);
        Test.add_func ("/controller-haptics/activation-and-text-input",
            test_activation_outcomes_and_text_input);
        Test.add_func ("/controller-haptics/navigation-outcomes", test_navigation_outcomes);
        Test.add_func ("/controller-haptics/boundary-latch-release",
            test_boundary_latch_and_release);
        Test.add_func ("/controller-haptics/movement-resets-boundary",
            test_successful_movement_resets_boundary);
        Test.add_func ("/controller-haptics/duplicate-cooldown", test_duplicate_cooldown);
        Test.add_func ("/controller-haptics/disable-stop-reset",
            test_disabling_stops_and_resets);
        Test.add_func ("/controller-haptics/disconnect-and-ownership",
            test_disconnect_and_ownership_changes);
        Test.add_func ("/controller-haptics/inactive-window-and-context-reset",
            test_inactive_window_and_context_reset);
        Test.add_func ("/controller-haptics/bounded-profiles", test_profiles_are_bounded_and_short);
    }
}
