namespace ProtonPlus.Utils {
    public enum ControllerNavigationDirection {
        NONE,
        UP,
        DOWN,
        LEFT,
        RIGHT
    }

    public enum ControllerConfirmButton {
        SOUTH = 0,
        EAST = 1
    }

    public enum ControllerFaceButton {
        SOUTH,
        EAST
    }

    public enum ControllerFaceButtonAction {
        ACTIVATE,
        DISMISS
    }

    public enum ControllerNavigationSource {
        DPAD,
        LEFT_STICK
    }

    public class ControllerNavigationUpdate : Object {
        public bool ownership_changed { get; internal set; default = false; }
        public bool repeat_changed { get; internal set; default = false; }
        public ControllerNavigationDirection emitted_direction { get; internal set; default = ControllerNavigationDirection.NONE; }
    }

    /* Display-independent controller semantics. SDL handles, timers, and GTK
     * operations remain in ControllerManager. */
    public class ControllerInputPolicy : Object {
        private class DeviceAxes : Object {
            public int64 id;
            public double left_x = 0;
            public double left_y = 0;
            public double right_y = 0;

            public DeviceAxes (int64 id) {
                this.id = id;
            }
        }

        public const double LEFT_STICK_ENGAGEMENT_THRESHOLD = 0.55;
        public const double LEFT_STICK_RELEASE_THRESHOLD = 0.35;
        public const double RIGHT_STICK_DEADZONE = 0.25;
        public const double DOMINANT_AXIS_MARGIN = 0.10;
        public const int64 NON_CONTROLLER_ECHO_GUARD_US = 200000;

        private Gee.ArrayList<DeviceAxes> devices = new Gee.ArrayList<DeviceAxes> ();
        private bool owns_device = false;
        private int64 owned_device_id = 0;
        private ControllerNavigationDirection analog_direction = ControllerNavigationDirection.NONE;
        private bool analog_suppressed = false;
        private bool scroll_suppressed = false;
        private double owned_scroll_intent = 0;
        private bool repeat_active = false;
        private int64 repeating_device_id = 0;
        private ControllerNavigationDirection repeating_direction = ControllerNavigationDirection.NONE;
        private ControllerNavigationSource repeating_source = ControllerNavigationSource.DPAD;
        private int64 last_controller_activity_us = -1;
        private bool has_pointer_position = false;
        private double pointer_x = 0;
        private double pointer_y = 0;

        public bool has_active_device {
            get { return owns_device; }
        }

        public int64 active_device_id {
            get { return owned_device_id; }
        }

        public double scroll_intent {
            get { return owned_scroll_intent; }
        }

        public bool has_repeat {
            get { return repeat_active; }
        }

        public int64 repeat_device_id {
            get { return repeating_device_id; }
        }

        public ControllerNavigationDirection repeat_direction {
            get { return repeating_direction; }
        }

        public ControllerNavigationSource repeat_source {
            get { return repeating_source; }
        }

        public static double normalize_axis (int16 raw) {
            if (raw < 0)
                return (double) raw / 32768.0;
            if (raw > 0)
                return (double) raw / 32767.0;
            return 0;
        }

        public static ControllerFaceButtonAction get_face_button_action (
            ControllerConfirmButton confirm_button, ControllerFaceButton button) {
            if ((confirm_button == ControllerConfirmButton.SOUTH && button == ControllerFaceButton.SOUTH) ||
                (confirm_button == ControllerConfirmButton.EAST && button == ControllerFaceButton.EAST))
                return ControllerFaceButtonAction.ACTIVATE;
            return ControllerFaceButtonAction.DISMISS;
        }

        public void note_controller_activity (int64 now_us) {
            last_controller_activity_us = now_us;
        }

        /* Some controller mappings mirror SDL actions into GTK key or motion
         * events. Only plausible echoes get the grace period; other keys can
         * claim the input modality immediately. */
        public bool should_accept_keyboard_handoff (bool echo_candidate, int64 now_us) {
            return !echo_candidate || !has_recent_controller_activity (now_us);
        }

        public void note_pointer_position (double x, double y) {
            has_pointer_position = true;
            pointer_x = x;
            pointer_y = y;
        }

        public bool should_accept_pointer_motion_handoff (
            double x, double y, int64 now_us
        ) {
            /* GTK may report motion when animated or relaid-out content moves
             * beneath a stationary pointer. Only physical coordinate changes
             * may claim the input modality. */
            if (!has_pointer_position) {
                note_pointer_position (x, y);
                return false;
            }

            var position_changed = x != pointer_x || y != pointer_y;
            note_pointer_position (x, y);
            return position_changed && !has_recent_controller_activity (now_us);
        }

        public bool note_button_press (int64 device_id) {
            ensure_device (device_id);
            return claim_device (device_id, true);
        }

        public bool begin_repeat (int64 device_id, ControllerNavigationDirection direction,
            ControllerNavigationSource source) {
            if (!owns_device || owned_device_id != device_id || direction == ControllerNavigationDirection.NONE)
                return false;

            var changed = !repeat_active || repeating_device_id != device_id ||
                repeating_direction != direction || repeating_source != source;
            repeat_active = true;
            repeating_device_id = device_id;
            repeating_direction = direction;
            repeating_source = source;
            return changed;
        }

        public bool release_repeat (int64 device_id, ControllerNavigationDirection direction,
            ControllerNavigationSource source) {
            if (!repeat_active || repeating_device_id != device_id ||
                repeating_direction != direction || repeating_source != source)
                return false;

            cancel_repeat ();
            return true;
        }

        public void cancel_repeat () {
            repeat_active = false;
            repeating_device_id = 0;
            repeating_direction = ControllerNavigationDirection.NONE;
            repeating_source = ControllerNavigationSource.DPAD;
        }

        public ControllerNavigationUpdate update_left_axis (int64 device_id, bool horizontal, int16 raw) {
            var update = new ControllerNavigationUpdate ();
            var device = ensure_device (device_id);
            var was_engaged = maximum_left_magnitude (device) >= LEFT_STICK_ENGAGEMENT_THRESHOLD;

            if (horizontal)
                device.left_x = normalize_axis (raw);
            else
                device.left_y = normalize_axis (raw);

            var is_engaged = maximum_left_magnitude (device) >= LEFT_STICK_ENGAGEMENT_THRESHOLD;
            if ((!owns_device || owned_device_id != device_id) && !was_engaged && is_engaged)
                update.ownership_changed = claim_device (device_id);

            if (!owns_device || owned_device_id != device_id)
                return update;

            if (analog_suppressed) {
                if (Math.fabs (device.left_x) < LEFT_STICK_RELEASE_THRESHOLD &&
                    Math.fabs (device.left_y) < LEFT_STICK_RELEASE_THRESHOLD)
                    analog_suppressed = false;
                return update;
            }

            var next_direction = choose_latched_direction (device);
            if (next_direction == analog_direction)
                return update;

            var previous_direction = analog_direction;
            analog_direction = next_direction;
            if (next_direction == ControllerNavigationDirection.NONE) {
                update.repeat_changed = release_repeat (
                    device_id,
                    previous_direction,
                    ControllerNavigationSource.LEFT_STICK
                );
                return update;
            }

            update.emitted_direction = next_direction;
            update.repeat_changed = begin_repeat (
                device_id,
                next_direction,
                ControllerNavigationSource.LEFT_STICK
            );
            return update;
        }

        public bool update_right_axis (int64 device_id, int16 raw) {
            var device = ensure_device (device_id);
            var was_outside = Math.fabs (device.right_y) > RIGHT_STICK_DEADZONE;
            device.right_y = normalize_axis (raw);
            var is_outside = Math.fabs (device.right_y) > RIGHT_STICK_DEADZONE;
            var ownership_changed = false;

            if ((!owns_device || owned_device_id != device_id) && !was_outside && is_outside)
                ownership_changed = claim_device (device_id);

            if (owns_device && owned_device_id == device_id) {
                if (scroll_suppressed) {
                    if (!is_outside)
                        scroll_suppressed = false;
                    owned_scroll_intent = 0;
                } else {
                    owned_scroll_intent = is_outside ? device.right_y : 0;
                }
            }
            return ownership_changed;
        }

        public bool disconnect_device (int64 device_id) {
            var device = find_device (device_id);
            if (device != null)
                devices.remove (device);
            if (!owns_device || owned_device_id != device_id)
                return false;

            clear_ownership ();
            return true;
        }

        public void surface_changed () {
            var device = get_owned_device ();
            if (analog_direction != ControllerNavigationDirection.NONE ||
                (device != null && maximum_left_magnitude (device) >= LEFT_STICK_RELEASE_THRESHOLD))
                analog_suppressed = true;
            scroll_suppressed = device != null &&
                Math.fabs (device.right_y) > RIGHT_STICK_DEADZONE;
            analog_direction = ControllerNavigationDirection.NONE;
            owned_scroll_intent = 0;
            cancel_repeat ();
        }

        public void reset_transient_input () {
            foreach (var device in devices) {
                device.left_x = 0;
                device.left_y = 0;
                device.right_y = 0;
            }
            analog_direction = ControllerNavigationDirection.NONE;
            analog_suppressed = false;
            scroll_suppressed = false;
            owned_scroll_intent = 0;
            cancel_repeat ();
            last_controller_activity_us = -1;
            has_pointer_position = false;
        }

        public void reset () {
            devices.clear ();
            clear_ownership ();
            last_controller_activity_us = -1;
            has_pointer_position = false;
        }

        private bool claim_device (int64 device_id, bool suppress_held_axes = false) {
            if (owns_device && owned_device_id == device_id)
                return false;

            var device = ensure_device (device_id);
            owns_device = true;
            owned_device_id = device_id;
            analog_direction = ControllerNavigationDirection.NONE;
            analog_suppressed = suppress_held_axes &&
                maximum_left_magnitude (device) >= LEFT_STICK_RELEASE_THRESHOLD;
            scroll_suppressed = suppress_held_axes &&
                Math.fabs (device.right_y) > RIGHT_STICK_DEADZONE;
            owned_scroll_intent = 0;
            cancel_repeat ();
            return true;
        }

        private void clear_ownership () {
            owns_device = false;
            owned_device_id = 0;
            analog_direction = ControllerNavigationDirection.NONE;
            analog_suppressed = false;
            scroll_suppressed = false;
            owned_scroll_intent = 0;
            cancel_repeat ();
        }

        private bool has_recent_controller_activity (int64 now_us) {
            return last_controller_activity_us >= 0 && now_us >= last_controller_activity_us &&
                now_us - last_controller_activity_us <= NON_CONTROLLER_ECHO_GUARD_US;
        }

        private ControllerNavigationDirection choose_latched_direction (DeviceAxes device) {
            var horizontal_magnitude = Math.fabs (device.left_x);
            var vertical_magnitude = Math.fabs (device.left_y);

            if (analog_direction == ControllerNavigationDirection.LEFT ||
                analog_direction == ControllerNavigationDirection.RIGHT) {
                if (horizontal_magnitude >= LEFT_STICK_RELEASE_THRESHOLD &&
                    !(vertical_magnitude >= LEFT_STICK_ENGAGEMENT_THRESHOLD &&
                      vertical_magnitude > horizontal_magnitude + DOMINANT_AXIS_MARGIN)) {
                    if (device.left_x < 0)
                        return ControllerNavigationDirection.LEFT;
                    if (device.left_x > 0)
                        return ControllerNavigationDirection.RIGHT;
                }
            } else if (analog_direction == ControllerNavigationDirection.UP ||
                       analog_direction == ControllerNavigationDirection.DOWN) {
                if (vertical_magnitude >= LEFT_STICK_RELEASE_THRESHOLD &&
                    !(horizontal_magnitude >= LEFT_STICK_ENGAGEMENT_THRESHOLD &&
                      horizontal_magnitude > vertical_magnitude + DOMINANT_AXIS_MARGIN)) {
                    if (device.left_y < 0)
                        return ControllerNavigationDirection.UP;
                    if (device.left_y > 0)
                        return ControllerNavigationDirection.DOWN;
                }
            }

            if (horizontal_magnitude < LEFT_STICK_ENGAGEMENT_THRESHOLD &&
                vertical_magnitude < LEFT_STICK_ENGAGEMENT_THRESHOLD)
                return ControllerNavigationDirection.NONE;

            if (horizontal_magnitude > vertical_magnitude)
                return device.left_x < 0 ? ControllerNavigationDirection.LEFT : ControllerNavigationDirection.RIGHT;
            return device.left_y < 0 ? ControllerNavigationDirection.UP : ControllerNavigationDirection.DOWN;
        }

        private double maximum_left_magnitude (DeviceAxes device) {
            return double.max (Math.fabs (device.left_x), Math.fabs (device.left_y));
        }

        private DeviceAxes ensure_device (int64 device_id) {
            var device = find_device (device_id);
            if (device == null) {
                device = new DeviceAxes (device_id);
                devices.add (device);
            }
            return (!) device;
        }

        private DeviceAxes? find_device (int64 device_id) {
            foreach (var device in devices) {
                if (device.id == device_id)
                    return device;
            }
            return null;
        }

        private DeviceAxes? get_owned_device () {
            return owns_device ? find_device (owned_device_id) : null;
        }
    }
}
