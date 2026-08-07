namespace ProtonPlus.Utils {
    public enum ControllerHapticEvent {
        ACTIVATION,
        NAVIGATION,
        BOUNDARY
    }

    public class ControllerHapticPulse : Object {
        public uint16 low_frequency_strength { get; private set; }
        public uint16 high_frequency_strength { get; private set; }
        public uint32 duration_ms { get; private set; }

        public ControllerHapticPulse (uint16 low_frequency_strength,
            uint16 high_frequency_strength, uint32 duration_ms) {
            this.low_frequency_strength = low_frequency_strength;
            this.high_frequency_strength = high_frequency_strength;
            this.duration_ms = duration_ms;
        }
    }

    public interface ControllerHapticSink : Object {
        public abstract bool supports_device (int64 device_id);
        public abstract bool pulse (int64 device_id, ControllerHapticPulse pulse);
        public abstract void stop (int64 device_id);
    }

    /* UI- and hardware-independent pulse selection, cooldown, and boundary
     * latching. Timestamps are supplied by the caller for deterministic tests. */
    public class ControllerHapticPolicy : Object {
        public const int64 DUPLICATE_COOLDOWN_USEC = 120 * 1000;
        public const uint16 MAX_STRENGTH = 12000;
        public const uint32 MAX_DURATION_MS = 60;

        private bool enabled = false;
        private bool boundary_latched = false;
        private ControllerNavigationDirection boundary_direction =
            ControllerNavigationDirection.NONE;
        private bool has_last_pulse = false;
        private ControllerHapticEvent last_event = ControllerHapticEvent.ACTIVATION;
        private int64 last_pulse_time_usec = 0;

        public void set_enabled (bool enabled) {
            if (this.enabled == enabled)
                return;
            this.enabled = enabled;
            reset_session ();
        }

        public ControllerHapticPulse? pulse_for (ControllerHapticEvent event,
            ControllerNavigationDirection direction, int64 now_usec) {
            if (!enabled)
                return null;

            if (event == ControllerHapticEvent.BOUNDARY) {
                if (direction == ControllerNavigationDirection.NONE)
                    return null;
                if (boundary_latched && boundary_direction == direction)
                    return null;
                boundary_latched = true;
                boundary_direction = direction;
            }

            if (has_last_pulse && last_event == event &&
                now_usec >= last_pulse_time_usec &&
                now_usec - last_pulse_time_usec < DUPLICATE_COOLDOWN_USEC)
                return null;

            has_last_pulse = true;
            last_event = event;
            last_pulse_time_usec = now_usec;

            switch (event) {
            case ACTIVATION:
                return new ControllerHapticPulse (7000, 12000, 55);
            case NAVIGATION:
                return new ControllerHapticPulse (4500, 7500, 45);
            case BOUNDARY:
                return new ControllerHapticPulse (10500, 2500, 35);
            default:
                return null;
            }
        }

        public void direction_released (ControllerNavigationDirection direction) {
            if (boundary_latched && boundary_direction == direction)
                reset_boundary ();
        }

        public void reset_boundary () {
            boundary_latched = false;
            boundary_direction = ControllerNavigationDirection.NONE;
        }

        public void reset_session () {
            reset_boundary ();
            has_last_pulse = false;
            last_event = ControllerHapticEvent.ACTIVATION;
            last_pulse_time_usec = 0;
        }
    }

    /* Owns semantic outcome gating and ensures that a sink only sees calls for
     * the current ControllerInputPolicy owner. */
    public class ControllerHapticFeedback : Object {
        private ControllerHapticSink sink;
        private ControllerHapticPolicy policy;
        private bool has_active_device = false;
        private int64 active_device_id = 0;
        private bool input_active = true;

        public ControllerHapticFeedback (ControllerHapticSink sink,
            ControllerHapticPolicy? policy = null) {
            this.sink = sink;
            this.policy = policy ?? new ControllerHapticPolicy ();
        }

        public void set_enabled (bool enabled) {
            if (!enabled && has_active_device)
                sink.stop (active_device_id);
            policy.set_enabled (enabled);
        }

        public void claim_device (int64 device_id) {
            if (has_active_device && active_device_id == device_id)
                return;
            if (has_active_device)
                sink.stop (active_device_id);
            has_active_device = true;
            active_device_id = device_id;
            policy.reset_session ();
        }

        public void disconnect_device (int64 device_id) {
            if (!has_active_device || active_device_id != device_id)
                return;
            sink.stop (active_device_id);
            has_active_device = false;
            active_device_id = 0;
            policy.reset_session ();
        }

        public void stop () {
            if (has_active_device)
                sink.stop (active_device_id);
            has_active_device = false;
            active_device_id = 0;
            policy.reset_session ();
        }

        public void set_input_active (bool active) {
            if (input_active == active)
                return;
            input_active = active;
            if (!active && has_active_device)
                sink.stop (active_device_id);
            policy.reset_session ();
        }

        public void context_changed () {
            policy.reset_boundary ();
        }

        public void direction_released (int64 device_id,
            ControllerNavigationDirection direction) {
            if (is_active_device (device_id))
                policy.direction_released (direction);
        }

        public void direction_outcome (int64 device_id,
            ControllerNavigationDirection direction, bool moved, int64 now_usec) {
            if (!is_active_device (device_id))
                return;
            if (moved) {
                policy.reset_boundary ();
                return;
            }
            emit (ControllerHapticEvent.BOUNDARY, direction, now_usec);
        }

        public void activation_outcome (int64 device_id,
            ControllerActivationDecision decision, bool succeeded, int64 now_usec) {
            if (!is_active_device (device_id) || !succeeded ||
                decision != ControllerActivationDecision.ACTIVATE)
                return;
            policy.reset_boundary ();
            emit (ControllerHapticEvent.ACTIVATION,
                ControllerNavigationDirection.NONE, now_usec);
        }

        public void navigation_outcome (int64 device_id, bool succeeded,
            int64 now_usec) {
            if (!is_active_device (device_id) || !succeeded)
                return;
            policy.reset_boundary ();
            emit (ControllerHapticEvent.NAVIGATION,
                ControllerNavigationDirection.NONE, now_usec);
        }

        private bool is_active_device (int64 device_id) {
            return input_active && has_active_device && active_device_id == device_id;
        }

        private void emit (ControllerHapticEvent event,
            ControllerNavigationDirection direction, int64 now_usec) {
            var pulse = policy.pulse_for (event, direction, now_usec);
            if (pulse == null || !sink.supports_device (active_device_id))
                return;
            sink.pulse (active_device_id, (!) pulse);
        }
    }

    public class SdlControllerHapticSink : Object, ControllerHapticSink {
        private class Device : Object {
            public int64 id;
            public SDL.Gamepad.Gamepad gamepad;
            public bool capability_checked = false;
            public bool rumble_supported = false;
            public bool diagnostic_reported = false;

            public Device (int64 id, SDL.Gamepad.Gamepad gamepad) {
                this.id = id;
                this.gamepad = gamepad;
            }
        }

        private Gee.HashMap<int64?, Device> devices = new Gee.HashMap<int64?, Device> ();

        public void register_device (int64 device_id, SDL.Gamepad.Gamepad gamepad) {
            devices[device_id] = new Device (device_id, gamepad);
        }

        public void unregister_device (int64 device_id) {
            devices.unset (device_id);
        }

        public bool supports_device (int64 device_id) {
            var device = devices[device_id];
            if (device == null)
                return false;
            if (device.capability_checked)
                return device.rumble_supported;

            device.capability_checked = true;
            var properties = SDL.Gamepad.get_gamepad_properties (device.gamepad);
            if ((uint32) properties == 0) {
                report_failure_once (device, "Unable to inspect controller rumble support");
                return false;
            }
            device.rumble_supported = SDL.Properties.get_boolean_property (
                properties, SDL.Gamepad.PropGamepad.CAP_RUMBLE_BOOLEAN, false
            );
            return device.rumble_supported;
        }

        public bool pulse (int64 device_id, ControllerHapticPulse pulse) {
            var device = devices[device_id];
            if (device == null || !supports_device (device_id))
                return false;
            if (SDL.Gamepad.rumble_gamepad (device.gamepad,
                pulse.low_frequency_strength, pulse.high_frequency_strength,
                pulse.duration_ms))
                return true;

            device.rumble_supported = false;
            report_failure_once (device, "Controller rumble failed");
            return false;
        }

        public void stop (int64 device_id) {
            var device = devices[device_id];
            if (device == null || !device.capability_checked || !device.rumble_supported)
                return;
            if (!SDL.Gamepad.rumble_gamepad (device.gamepad, 0, 0, 0)) {
                device.rumble_supported = false;
                report_failure_once (device, "Stopping controller rumble failed");
            }
        }

        private void report_failure_once (Device device, string message) {
            if (device.diagnostic_reported)
                return;
            device.diagnostic_reported = true;
            warning ("%s for device %" + int64.FORMAT + ": %s",
                message, device.id, SDL.Error.get_error ());
        }
    }
}
