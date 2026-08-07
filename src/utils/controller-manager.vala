namespace ProtonPlus.Utils {
    public class ControllerManager : Object {
        public signal void presentation_changed (ControllerPresentationState state);

        private class GamepadState : Object {
            public SDL.Joystick.JoystickID id;
            public SDL.Gamepad.Gamepad gamepad;

            public GamepadState (SDL.Joystick.JoystickID id, SDL.Gamepad.Gamepad gamepad) {
                this.id = id;
                this.gamepad = gamepad;
            }
        }

        private class GtkSurface : ControllerSurface {
            public weak Gtk.Widget? widget;
            public weak Gtk.Widget? opener;
            public weak Gtk.Widget? initial_focus;
            public ulong state_handler = 0;
            public ulong destroy_handler = 0;

            public GtkSurface (ControllerSurfaceKind kind, Gtk.Widget widget,
                Gtk.Widget? opener = null, Gtk.Widget? initial_focus = null) {
                base (kind);
                this.widget = widget;
                this.opener = opener;
                this.initial_focus = initial_focus;
            }
        }

        private class GtkFocusScrollRequest : Object {
            public weak Gtk.Widget? widget;
            public weak Gtk.Widget? page_root;
            public string page_id;
            public uint64 surface_generation;

            public GtkFocusScrollRequest (Gtk.Widget widget, Gtk.Widget page_root,
                string page_id, uint64 surface_generation) {
                this.widget = widget;
                this.page_root = page_root;
                this.page_id = page_id;
                this.surface_generation = surface_generation;
            }
        }

        Widgets.Window window;
        uint timeout_id = 0;
        uint repeat_timeout_id = 0;
        bool sdl_initialized = false;
        bool controller_active = false;
        weak Gtk.Widget? highlighted = null;
        Gtk.EventControllerMotion? motion = null;
        Gtk.GestureClick? press = null;
        Gtk.EventControllerKey? keys = null;
        bool input_controllers_attached = false;
        ulong window_active_handler = 0;
        ulong window_focus_handler = 0;
        ulong confirm_button_changed_handler = 0;
        ulong haptics_enabled_changed_handler = 0;
        ulong highlight_visible_handler = 0;
        ulong highlight_unmap_handler = 0;
        ulong highlight_destroy_handler = 0;
        uint focus_idle_id = 0;
        uint window_inactive_timeout_id = 0;
        Gee.ArrayList<GamepadState> gamepads = new Gee.ArrayList<GamepadState> ();
        Gee.ArrayList<GtkSurface> registered_surfaces = new Gee.ArrayList<GtkSurface> ();
        GtkSurface window_surface;
        ControllerSurfacePolicy surface_policy;
        ControllerInputPolicy input_policy = new ControllerInputPolicy ();
        ControllerNavigationPolicy navigation_policy = new ControllerNavigationPolicy ();
        SdlControllerHapticSink haptic_sink = new SdlControllerHapticSink ();
        ControllerHapticFeedback haptic_feedback;
        uint64 surface_generation = 0;
        uint navigation_focus_source_id = 0;
        uint scroll_focus_source_id = 0;
        weak Gtk.Range? presentation_range = null;
        ulong presentation_range_orientation_handler = 0;

        public ControllerPresentationState presentation_state { get; private set; }

        const double SCROLL_SPEED = 12.0;
        const uint INITIAL_REPEAT_DELAY = 350;
        const uint REPEAT_INTERVAL = 75;
        const uint WINDOW_INACTIVE_DEBOUNCE_MS = 50;

        public ControllerManager (Widgets.Window window) {
            this.window = window;
            haptic_feedback = new ControllerHapticFeedback (haptic_sink);

            var face_labels = ControllerPhysicalLabelResolver.from_sdl (
                SDL.Gamepad.GamepadButtonLabel.UNKNOWN,
                SDL.Gamepad.GamepadButtonLabel.UNKNOWN,
                SDL.Gamepad.GamepadButtonLabel.UNKNOWN,
                SDL.Gamepad.GamepadButtonLabel.UNKNOWN
            );
            presentation_state = new ControllerPresentationState (
                false, {}, face_labels,
                ControllerPhysicalLabelResolver.map_prompts (
                    face_labels, ControllerConfirmButton.SOUTH
                )
            );

            window_surface = new GtkSurface (ControllerSurfaceKind.WINDOW, window);
            surface_policy = new ControllerSurfacePolicy (window_surface);

            motion = new Gtk.EventControllerMotion ();
            motion.enter.connect ((x, y) => input_policy.note_pointer_position (x, y));
            motion.motion.connect ((x, y) => {
                if (input_policy.should_accept_pointer_motion_handoff (
                    x, y, get_monotonic_time ()
                ))
                    yield_to_non_controller_input ();
            });

            press = new Gtk.GestureClick ();
            press.set_button (0);
            press.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            press.pressed.connect ((n_press, x, y) => yield_to_non_controller_input ());

            keys = new Gtk.EventControllerKey ();
            keys.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            keys.key_pressed.connect ((keyval, keycode, state) => {
                if (!input_policy.should_accept_keyboard_handoff (
                    is_controller_echo_key (keyval), get_monotonic_time ()))
                    return true;
                yield_to_non_controller_input ();
                return false;
            });

            window_active_handler = window.notify["is-active"].connect (() => {
                haptic_feedback.set_input_active (window.is_active);
                if (window.is_active)
                    cancel_window_inactive_check ();
                else
                    schedule_window_inactive_check ();
            });
            window_focus_handler = window.notify["focus-widget"].connect (() => {
                sync_highlight ();
                refresh_presentation ();
            });
        }

        public void start () {
            if (timeout_id != 0)
                return;

            if (!SDL.Init.init (SDL.Init.InitFlags.GAMEPAD)) {
                warning ("SDL3 gamepad init FAILED: %s", SDL.Error.get_error ());
                return;
            }

            sdl_initialized = true;
            SDL.Gamepad.set_gamepad_events_enabled (true);
            haptic_feedback.set_input_active (window.is_active);

            if (Globals.SETTINGS != null) {
                confirm_button_changed_handler = Globals.SETTINGS.changed["controller-confirm-button"].connect (
                    refresh_presentation
                );
                haptic_feedback.set_enabled (
                    Globals.SETTINGS.get_boolean ("controller-haptics-enabled")
                );
                haptics_enabled_changed_handler = Globals.SETTINGS.changed["controller-haptics-enabled"].connect (
                    () => haptic_feedback.set_enabled (
                        Globals.SETTINGS.get_boolean ("controller-haptics-enabled")
                    )
                );
            }

            unowned SDL.Joystick.JoystickID[]? ids = SDL.Gamepad.get_gamepads ();
            if (ids != null) {
                foreach (var id in ids)
                    open_gamepad (id);

                SDL.StdInc.free ((void*) ids);
            } else {
                warning ("Unable to enumerate gamepads: %s", SDL.Error.get_error ());
            }

            ((Gtk.Widget) window).add_controller (motion);
            ((Gtk.Widget) window).add_controller (press);
            ((Gtk.Widget) window).add_controller (keys);
            input_controllers_attached = true;

            timeout_id = GLib.Timeout.add (16, poll);
        }

        public void stop () {
            stop_navigation_repeat ();
            haptic_feedback.stop ();

            if (timeout_id != 0) {
                GLib.Source.remove (timeout_id);
                timeout_id = 0;
            }

            if (input_controllers_attached) {
                ((Gtk.Widget) window).remove_controller (motion);
                ((Gtk.Widget) window).remove_controller (press);
                ((Gtk.Widget) window).remove_controller (keys);
            }

            input_controllers_attached = false;
            motion = null;
            press = null;
            keys = null;
            if (focus_idle_id != 0) {
                GLib.Source.remove (focus_idle_id);
                focus_idle_id = 0;
            }
            cancel_window_inactive_check ();
            cancel_navigation_focus_restore ();
            cancel_scroll_to_focus ();
            navigation_policy.invalidate_restores ();
            input_policy.reset ();
            close_gamepads ();
            foreach (var surface in registered_surfaces)
                disconnect_surface (surface);
            registered_surfaces.clear ();
            surface_policy.reset ();
            deactivate_controller_mode ();
            disconnect_presentation_range ();

            if (confirm_button_changed_handler != 0 && Globals.SETTINGS != null) {
                Globals.SETTINGS.disconnect (confirm_button_changed_handler);
                confirm_button_changed_handler = 0;
            }
            if (haptics_enabled_changed_handler != 0 && Globals.SETTINGS != null) {
                Globals.SETTINGS.disconnect (haptics_enabled_changed_handler);
                haptics_enabled_changed_handler = 0;
            }

            if (window_active_handler != 0) {
                window.disconnect (window_active_handler);
                window_active_handler = 0;
            }
            if (window_focus_handler != 0) {
                window.disconnect (window_focus_handler);
                window_focus_handler = 0;
            }

            if (sdl_initialized) {
                SDL.Init.quit_subsystem (SDL.Init.InitFlags.GAMEPAD);
                sdl_initialized = false;
            }
        }

        public void register_dialog (Adw.Dialog dialog) {
            var surface = find_registered_surface (dialog);
            if (surface == null) {
                surface = new GtkSurface (ControllerSurfaceKind.DIALOG, dialog);
                registered_surfaces.add (surface);
                surface.state_handler = dialog.closed.connect (() => unregister_dialog (dialog));
            }

            surface_policy.present (surface);
            surface_changed (surface);
        }

        void unregister_dialog (Adw.Dialog dialog) {
            var surface = find_registered_surface (dialog);
            if (surface == null)
                return;

            remove_surface (surface);
            disconnect_surface (surface);
            registered_surfaces.remove (surface);
        }

        public void register_popover (Gtk.Popover popover, Gtk.Widget? opener,
            Gtk.Widget? initial_focus = null) {
            var surface = find_registered_surface (popover);
            if (surface == null) {
                surface = new GtkSurface (ControllerSurfaceKind.POPOVER, popover, opener, initial_focus);
                registered_surfaces.add (surface);
                surface.state_handler = popover.notify["visible"].connect (() => {
                    if (popover.get_visible ())
                        present_popover (surface);
                    else
                        remove_surface (surface);
                });
                surface.destroy_handler = popover.destroy.connect (() => unregister_popover (surface));
            } else {
                surface.opener = opener;
                surface.initial_focus = initial_focus;
            }

            if (popover.get_visible ())
                present_popover (surface);
        }

        void present_popover (GtkSurface surface) {
            surface_policy.present (surface);
            surface_changed (surface);
            schedule_initial_focus (surface);
        }

        void unregister_popover (GtkSurface surface) {
            remove_surface (surface);
            disconnect_surface (surface);
            registered_surfaces.remove (surface);
        }

        void remove_surface (GtkSurface surface) {
            surface.opener_valid = is_valid_focus_target (surface.opener);
            var removal = surface_policy.remove (surface);
            if (!removal.was_active)
                return;

            input_policy.surface_changed ();
            haptic_feedback.context_changed ();
            cancel_repeat_timer ();
            invalidate_navigation_deferred ();
            clear_highlight ();
            var active = (GtkSurface) removal.active_surface;
            if (removal.restore_opener && surface.opener != null &&
                is_inside_surface (surface.opener, active)) {
                ((!) surface.opener).grab_focus ();
            } else {
                schedule_active_surface_focus ();
            }
            schedule_scroll_to_focus ();
            sync_highlight ();
            refresh_presentation ();
        }

        void disconnect_surface (GtkSurface surface) {
            var widget = surface.widget;
            if (widget != null && surface.state_handler != 0)
                widget.disconnect (surface.state_handler);
            if (widget != null && surface.destroy_handler != 0)
                widget.disconnect (surface.destroy_handler);
            surface.state_handler = 0;
            surface.destroy_handler = 0;
            surface.widget = null;
            surface.opener = null;
            surface.initial_focus = null;
        }

        GtkSurface? find_registered_surface (Gtk.Widget widget) {
            foreach (var surface in registered_surfaces) {
                if (surface.widget == widget)
                    return surface;
            }
            return null;
        }

        void surface_changed (GtkSurface surface) {
            input_policy.surface_changed ();
            haptic_feedback.context_changed ();
            cancel_repeat_timer ();
            invalidate_navigation_deferred ();
            clear_highlight ();
            if (controller_active)
                sync_highlight ();
            refresh_presentation ();
        }

        void schedule_initial_focus (GtkSurface surface) {
            if (focus_idle_id != 0)
                GLib.Source.remove (focus_idle_id);

            focus_idle_id = GLib.Idle.add (() => {
                focus_idle_id = 0;
                if (surface != get_active_surface () || surface.widget == null ||
                    !surface.widget.get_visible () || !surface.widget.get_mapped ())
                    return GLib.Source.REMOVE;

                var focused = get_focused_widget ();
                if (!is_valid_focus_target (focused)) {
                    var initial = surface.initial_focus;
                    if (is_valid_focus_target (initial) && is_inside_surface (initial, surface))
                        ((!) initial).grab_focus ();
                    else
                        surface.widget.child_focus (Gtk.DirectionType.TAB_FORWARD);
                }
                controller_focus_changed ();
                sync_highlight ();
                refresh_presentation ();
                return GLib.Source.REMOVE;
            });
        }

        void focus_active_surface () {
            var surface = get_active_surface ();
            var focused = get_focused_widget ();
            if (focused != null && is_valid_focus_target (focused))
                return;
            if (surface.widget?.child_focus (Gtk.DirectionType.TAB_FORWARD) == true)
                controller_focus_changed ();
        }

        void schedule_active_surface_focus () {
            if (focus_idle_id != 0)
                GLib.Source.remove (focus_idle_id);
            focus_idle_id = GLib.Idle.add (() => {
                focus_idle_id = 0;
                focus_active_surface ();
                sync_highlight ();
                refresh_presentation ();
                return GLib.Source.REMOVE;
            });
        }

        bool is_valid_focus_target (Gtk.Widget? widget) {
            return widget != null && widget.get_root () != null && widget.get_mapped () &&
                widget.is_visible () && widget.is_sensitive () && widget.get_focusable ();
        }

        bool is_inside_surface (Gtk.Widget? widget, GtkSurface surface) {
            if (widget == null || surface.widget == null)
                return false;
            if (surface.kind == ControllerSurfaceKind.WINDOW) {
                if (widget.get_root () != window)
                    return false;
                foreach (var registered in registered_surfaces) {
                    if (registered != window_surface && widget_is_descendant_of (widget, registered.widget))
                        return false;
                }
                return true;
            }

            return widget_is_descendant_of (widget, surface.widget);
        }

        bool widget_is_descendant_of (Gtk.Widget widget, Gtk.Widget? ancestor) {
            if (ancestor == null)
                return false;
            var current = widget;
            while (current != null) {
                if (current == ancestor)
                    return true;
                current = current.get_parent ();
            }
            return false;
        }

        bool poll () {
            SDL.Events.Event event;
            while (SDL.Events.poll_event (out event)) {
                switch (event.type) {
                case SDL.Events.EventType.GAMEPAD_ADDED :
                    open_gamepad (event.gdevice.which);
                    break;
                case SDL.Events.EventType.GAMEPAD_REMOVED :
                    close_gamepad (event.gdevice.which);
                    break;
                case SDL.Events.EventType.GAMEPAD_BUTTON_DOWN :
                    if (window.is_active)
                        handle_button_down (event.gbutton.which, event.gbutton.button);
                    break;
                case SDL.Events.EventType.GAMEPAD_BUTTON_UP :
                    handle_button_up (event.gbutton.which, event.gbutton.button);
                    break;
                case SDL.Events.EventType.GAMEPAD_AXIS_MOTION :
                    if (window.is_active)
                        handle_axis (event.gaxis.which, event.gaxis.axis, event.gaxis.value);
                    break;
                default :
                    break;
                }
            }

            if (!window.is_active) {
                reset_input_state ();
                return GLib.Source.CONTINUE;
            }

            if (input_policy.scroll_intent != 0)
                scroll (input_policy.scroll_intent * SCROLL_SPEED);

            return GLib.Source.CONTINUE;
        }

        void open_gamepad (SDL.Joystick.JoystickID id) {
            if (find_gamepad (id) != null)
                return;

            var gamepad = SDL.Gamepad.open_gamepad (id);
            if (gamepad == null) {
                warning ("Unable to open gamepad: %s", SDL.Error.get_error ());
                return;
            }

            gamepads.add (new GamepadState (id, gamepad));
            haptic_sink.register_device (controller_id (id), gamepad);
        }

        void close_gamepad (SDL.Joystick.JoystickID id) {
            var state = find_gamepad (id);
            if (state == null)
                return;

            haptic_feedback.disconnect_device (controller_id (state.id));
            if (input_policy.disconnect_device (controller_id (state.id))) {
                cancel_repeat_timer ();
                deactivate_controller_mode ();
            }

            haptic_sink.unregister_device (controller_id (state.id));
            gamepads.remove (state);
            SDL.Gamepad.close_gamepad (state.gamepad);
        }

        void close_gamepads () {
            foreach (var state in gamepads) {
                haptic_sink.unregister_device (controller_id (state.id));
                SDL.Gamepad.close_gamepad (state.gamepad);
            }

            gamepads.clear ();
        }

        GamepadState? find_gamepad (SDL.Joystick.JoystickID id) {
            foreach (var state in gamepads) {
                if (state.id == id)
                    return state;
            }

            return null;
        }

        GamepadState? find_gamepad_by_controller_id (int64 id) {
            foreach (var state in gamepads) {
                if (controller_id (state.id) == id)
                    return state;
            }
            return null;
        }

        int64 controller_id (SDL.Joystick.JoystickID id) {
            return (int64) id;
        }

        void activate_controller_mode () {
            input_policy.note_controller_activity (get_monotonic_time ());
            if (!controller_active) {
                controller_active = true;
                window.add_css_class ("controller-active");
            }
            sync_highlight ();
            refresh_presentation ();
        }

        void deactivate_controller_mode () {
            if (!controller_active) {
                refresh_presentation ();
                return;
            }

            controller_active = false;
            window.remove_css_class ("controller-active");
            clear_highlight ();
            refresh_presentation ();
        }

        void schedule_window_inactive_check () {
            cancel_window_inactive_check ();
            window_inactive_timeout_id = GLib.Timeout.add (
                WINDOW_INACTIVE_DEBOUNCE_MS,
                () => {
                    window_inactive_timeout_id = 0;
                    if (!window.is_active) {
                        reset_input_state ();
                        deactivate_controller_mode ();
                    }
                    return GLib.Source.REMOVE;
                }
            );
        }

        void cancel_window_inactive_check () {
            if (window_inactive_timeout_id == 0)
                return;
            GLib.Source.remove (window_inactive_timeout_id);
            window_inactive_timeout_id = 0;
        }

        void yield_to_non_controller_input () {
            input_policy.surface_changed ();
            haptic_feedback.context_changed ();
            cancel_repeat_timer ();
            deactivate_controller_mode ();
        }

        bool is_controller_echo_key (uint keyval) {
            switch (keyval) {
            case Gdk.Key.Up:
            case Gdk.Key.Down:
            case Gdk.Key.Left:
            case Gdk.Key.Right:
            case Gdk.Key.KP_Up:
            case Gdk.Key.KP_Down:
            case Gdk.Key.KP_Left:
            case Gdk.Key.KP_Right:
            case Gdk.Key.Return:
            case Gdk.Key.KP_Enter:
            case Gdk.Key.space:
            case Gdk.Key.Escape:
                return true;
            default:
                return false;
            }
        }

        void update_highlight (Gtk.Widget? widget) {
            if (!controller_active || !is_valid_highlight (widget))
                widget = null;
            if (highlighted == widget)
                return;

            clear_highlight ();
            highlighted = widget;
            if (highlighted == null)
                return;

            ((!) highlighted).add_css_class ("controller-focus");
            highlight_visible_handler = ((!) highlighted).notify["visible"].connect (() => sync_highlight ());
            highlight_unmap_handler = ((!) highlighted).unmap.connect (() => clear_highlight ());
            highlight_destroy_handler = ((!) highlighted).destroy.connect (() => clear_highlight ());
        }

        void clear_highlight () {
            var widget = highlighted;
            if (widget != null) {
                if (highlight_visible_handler != 0)
                    widget.disconnect (highlight_visible_handler);
                if (highlight_unmap_handler != 0)
                    widget.disconnect (highlight_unmap_handler);
                if (highlight_destroy_handler != 0)
                    widget.disconnect (highlight_destroy_handler);
                widget.remove_css_class ("controller-focus");
            }

            highlight_visible_handler = 0;
            highlight_unmap_handler = 0;
            highlight_destroy_handler = 0;
            highlighted = null;
        }

        void sync_highlight () {
            update_highlight (get_focused_widget ());
        }

        bool is_valid_highlight (Gtk.Widget? widget) {
            if (!is_valid_focus_target (widget))
                return false;
            return is_inside_surface (widget, get_active_surface ());
        }

        public void presentation_context_changed () {
            refresh_presentation ();
        }

        void refresh_presentation () {
            var active_gamepad = input_policy.has_active_device
                ? find_gamepad_by_controller_id (input_policy.active_device_id)
                : null;
            var presentation_window_active = window.is_active ||
                window_inactive_timeout_id != 0;
            var presentation_active = controller_active &&
                presentation_window_active && active_gamepad != null;
            var surface = get_active_surface ();
            var focused = get_focused_widget ();
            var control_kind = classify_hint_control (focused, surface);
            var has_popover = surface.kind == ControllerSurfaceKind.POPOVER ||
                find_focused_popover () != null;
            var has_dialog = surface.kind == ControllerSurfaceKind.DIALOG;
            var host = get_active_navigation_host ();
            var shortcuts = host as ControllerPageShortcuts;

            var context = new ControllerHintContext () {
                controller_mode_active = presentation_active,
                has_dialog = has_dialog,
                has_popover = has_popover,
                control_kind = control_kind,
                can_navigate_back = host != null && host.controller_can_navigate_back (),
                can_switch_section = host != null && host.controller_can_switch_page (),
                can_open_search = shortcuts != null &&
                    shortcuts.controller_can_open_search (),
                can_open_filter = shortcuts != null &&
                    shortcuts.controller_can_open_filter ()
            };

            var south_label = SDL.Gamepad.GamepadButtonLabel.UNKNOWN;
            var east_label = SDL.Gamepad.GamepadButtonLabel.UNKNOWN;
            var west_label = SDL.Gamepad.GamepadButtonLabel.UNKNOWN;
            var north_label = SDL.Gamepad.GamepadButtonLabel.UNKNOWN;
            if (active_gamepad != null) {
                south_label = SDL.Gamepad.get_gamepad_button_label (
                    active_gamepad.gamepad, SDL.Gamepad.GamepadButton.SOUTH
                );
                east_label = SDL.Gamepad.get_gamepad_button_label (
                    active_gamepad.gamepad, SDL.Gamepad.GamepadButton.EAST
                );
                west_label = SDL.Gamepad.get_gamepad_button_label (
                    active_gamepad.gamepad, SDL.Gamepad.GamepadButton.WEST
                );
                north_label = SDL.Gamepad.get_gamepad_button_label (
                    active_gamepad.gamepad, SDL.Gamepad.GamepadButton.NORTH
                );
            }
            var face_labels = ControllerPhysicalLabelResolver.from_sdl (
                south_label, east_label, west_label, north_label
            );
            var confirm_button = ControllerConfirmButton.SOUTH;
            if (Globals.SETTINGS != null) {
                confirm_button = (ControllerConfirmButton) Globals.SETTINGS.get_enum (
                    "controller-confirm-button"
                );
            }
            var next = new ControllerPresentationState (
                presentation_active,
                ControllerHintPolicy.get_hints (context),
                face_labels,
                ControllerPhysicalLabelResolver.map_prompts (face_labels, confirm_button)
            );
            if (presentation_state.equal_to (next))
                return;

            presentation_state = next;
            presentation_changed (presentation_state);
        }

        ControllerHintControlKind classify_hint_control (Gtk.Widget? focused,
            GtkSurface surface) {
            var root = get_direction_input_root (focused, surface);
            Gtk.Widget? current = focused;
            Gtk.Range? range = null;
            while (current != null) {
                if (current is Gtk.Range) {
                    range = (Gtk.Range) current;
                    break;
                }
                if (current == root)
                    break;
                current = current.get_parent ();
            }
            sync_presentation_range (range);
            if (range != null) {
                return ((Gtk.Orientable) range).get_orientation () == Gtk.Orientation.HORIZONTAL
                    ? ControllerHintControlKind.HORIZONTAL_RANGE
                    : ControllerHintControlKind.VERTICAL_RANGE;
            }

            var redirected_target = focused == null ? null
                : find_controller_activation_target ((!) focused, root);
            if (redirected_target is Gtk.Switch ||
                redirected_target is Gtk.CheckButton ||
                redirected_target is Gtk.ToggleButton ||
                redirected_target is Adw.SwitchRow)
                return ControllerHintControlKind.TOGGLE;

            current = focused;
            while (current != null) {
                if (current is Gtk.Switch || current is Gtk.CheckButton ||
                    current is Gtk.ToggleButton || current is Adw.SwitchRow)
                    return ControllerHintControlKind.TOGGLE;
                if (current is Gtk.DropDown || current is Gtk.ComboBox ||
                    current is Gtk.MenuButton || current is Adw.ComboRow)
                    return ControllerHintControlKind.OPEN;
                if (current == root)
                    break;
                current = current.get_parent ();
            }
            if (ControllerEditableTargetResolver.resolve (focused, root) != null)
                return ControllerHintControlKind.EDITABLE;
            return ControllerHintControlKind.DEFAULT;
        }

        void sync_presentation_range (Gtk.Range? range) {
            if (presentation_range == range)
                return;
            disconnect_presentation_range ();
            presentation_range = range;
            if (presentation_range != null) {
                presentation_range_orientation_handler = ((!) presentation_range)
                    .notify["orientation"].connect (refresh_presentation);
            }
        }

        void disconnect_presentation_range () {
            var range = presentation_range;
            if (range != null && presentation_range_orientation_handler != 0)
                range.disconnect (presentation_range_orientation_handler);
            presentation_range_orientation_handler = 0;
            presentation_range = null;
        }

        void handle_button_down (SDL.Joystick.JoystickID id, SDL.Gamepad.GamepadButton button) {
            var gamepad = find_gamepad (id);
            if (gamepad == null)
                return;

            var device_id = controller_id (id);
            if (input_policy.note_button_press (device_id)) {
                cancel_repeat_timer ();
                haptic_feedback.claim_device (device_id);
            }
            activate_controller_mode ();
            switch (button) {
            case DPAD_UP :
            case DPAD_DOWN :
            case DPAD_LEFT :
            case DPAD_RIGHT :
                var direction = direction_for_dpad (button);
                handle_controller_direction (device_id, direction);
                input_policy.begin_repeat (
                    device_id,
                    direction,
                    ControllerNavigationSource.DPAD
                );
                restart_repeat_timer ();
                break;
            case SOUTH :
            case EAST :
                handle_face_button (device_id, button);
                break;
            case WEST :
                handle_page_shortcut (device_id, true);
                break;
            case NORTH :
                handle_page_shortcut (device_id, false);
                break;
            case START :
                if (!has_active_modal_surface ())
                    window.open_menu ();
                break;
            case BACK :
                if (!has_active_modal_surface ())
                    window.open_launchers ();
                break;
            case LEFT_SHOULDER :
                haptic_feedback.navigation_outcome (
                    device_id, switch_tab (-1), get_monotonic_time ()
                );
                break;
            case RIGHT_SHOULDER :
                haptic_feedback.navigation_outcome (
                    device_id, switch_tab (1), get_monotonic_time ()
                );
                break;
            default :
                break;
            }
            sync_highlight ();
        }

        void handle_button_up (SDL.Joystick.JoystickID id, SDL.Gamepad.GamepadButton button) {
            var direction = direction_for_dpad (button);
            haptic_feedback.direction_released (controller_id (id), direction);
            if (direction != ControllerNavigationDirection.NONE && input_policy.release_repeat (
                controller_id (id),
                direction,
                ControllerNavigationSource.DPAD
            ))
                cancel_repeat_timer ();
        }

        ControllerNavigationDirection direction_for_dpad (SDL.Gamepad.GamepadButton button) {
            switch (button) {
            case DPAD_UP :
                return ControllerNavigationDirection.UP;
            case DPAD_DOWN :
                return ControllerNavigationDirection.DOWN;
            case DPAD_LEFT :
                return ControllerNavigationDirection.LEFT;
            case DPAD_RIGHT :
                return ControllerNavigationDirection.RIGHT;
            default :
                return ControllerNavigationDirection.NONE;
            }
        }

        void handle_face_button (int64 device_id, SDL.Gamepad.GamepadButton button) {
            var confirm_button = ControllerConfirmButton.SOUTH;
            if (Globals.SETTINGS != null)
                confirm_button = (ControllerConfirmButton) Globals.SETTINGS.get_enum ("controller-confirm-button");

            var face_button = button == SDL.Gamepad.GamepadButton.SOUTH
                ? ControllerFaceButton.SOUTH
                : ControllerFaceButton.EAST;
            if (ControllerInputPolicy.get_face_button_action (confirm_button, face_button) ==
                ControllerFaceButtonAction.ACTIVATE) {
                ControllerActivationDecision decision;
                var succeeded = activate_focused (out decision);
                haptic_feedback.activation_outcome (
                    device_id, decision, succeeded, get_monotonic_time ()
                );
            } else {
                var succeeded = perform_navigate_back ();
                haptic_feedback.navigation_outcome (
                    device_id, succeeded, get_monotonic_time ()
                );
            }
        }

        void handle_page_shortcut (int64 device_id, bool search) {
            var succeeded = false;
            if (!has_active_modal_surface ()) {
                var shortcuts = get_active_navigation_host () as ControllerPageShortcuts;
                if (shortcuts != null) {
                    succeeded = search
                        ? shortcuts.controller_open_search ()
                        : shortcuts.controller_open_filter ();
                }
            }
            haptic_feedback.activation_outcome (
                device_id, ControllerActivationDecision.ACTIVATE,
                succeeded, get_monotonic_time ()
            );
            if (succeeded) {
                save_current_page_focus ();
                schedule_scroll_to_focus ();
                refresh_presentation ();
            }
        }

        void restart_repeat_timer () {
            cancel_repeat_timer ();
            if (!input_policy.has_repeat)
                return;

            repeat_timeout_id = GLib.Timeout.add (INITIAL_REPEAT_DELAY, () => {
                if (!can_repeat_navigation ()) {
                    input_policy.cancel_repeat ();
                    repeat_timeout_id = 0;
                    return GLib.Source.REMOVE;
                }

                handle_controller_direction (
                    input_policy.repeat_device_id, input_policy.repeat_direction
                );
                repeat_timeout_id = GLib.Timeout.add (REPEAT_INTERVAL, () => {
                    if (!can_repeat_navigation ()) {
                        input_policy.cancel_repeat ();
                        repeat_timeout_id = 0;
                        return GLib.Source.REMOVE;
                    }

                    handle_controller_direction (
                        input_policy.repeat_device_id, input_policy.repeat_direction
                    );
                    return GLib.Source.CONTINUE;
                });
                return GLib.Source.REMOVE;
            });
        }

        bool can_repeat_navigation () {
            return window.is_active && input_policy.has_repeat &&
                find_gamepad_by_controller_id (input_policy.repeat_device_id) != null;
        }

        void stop_navigation_repeat () {
            cancel_repeat_timer ();
            input_policy.cancel_repeat ();
        }

        void cancel_repeat_timer () {
            if (repeat_timeout_id != 0) {
                GLib.Source.remove (repeat_timeout_id);
                repeat_timeout_id = 0;
            }
        }

        void handle_controller_direction (int64 device_id,
            ControllerNavigationDirection direction) {
            if (direction == ControllerNavigationDirection.NONE)
                return;

            var surface = get_active_surface ();
            var focused = get_focused_widget ();
            if (focused != null && !is_inside_surface (focused, surface))
                focused = null;

            var root = get_direction_input_root (focused, surface);
            var control = resolve_effective_standard_control (focused, root);
            var range = control as Gtk.Range;
            var control_kind = get_control_kind (range);
            var action = ControllerControlPolicy.get_direction_action (
                control_kind, direction
            );

            bool moved = false;
            var directional_focus = find_directional_focus_ancestor (focused, root);
            if (focused != null && directional_focus != null)
                moved = directional_focus.controller_focus_direction (
                    (!) focused, direction
                );

            if (moved)
                controller_focus_changed ();
            else if (range != null && action != ControllerDirectionAction.MOVE_FOCUS)
                moved = adjust_range (range, action);
            else
                moved = move_focus (root, direction);

            haptic_feedback.direction_outcome (
                device_id, direction, moved, get_monotonic_time ()
            );

            sync_highlight ();
        }

        ControllerDirectionalFocus? find_directional_focus_ancestor (
            Gtk.Widget? focused, Gtk.Widget root
        ) {
            Gtk.Widget? current = focused;
            while (current != null) {
                if (current is ControllerDirectionalFocus)
                    return (ControllerDirectionalFocus) current;
                if (current == root)
                    break;
                current = current.get_parent ();
            }
            return null;
        }

        Gtk.Widget get_direction_input_root (Gtk.Widget? focused, GtkSurface surface) {
            Gtk.Widget? current = focused;
            while (current != null) {
                if (current is Gtk.Popover)
                    return current;
                current = current.get_parent ();
            }
            return surface.widget ?? window;
        }

        Gtk.Widget? resolve_effective_standard_control (Gtk.Widget? focused,
            Gtk.Widget root) {
            Gtk.Widget? current = focused;
            while (current != null) {
                if (current is Gtk.Range)
                    return current;
                if (current == root)
                    break;
                current = current.get_parent ();
            }
            return focused;
        }

        ControllerControlKind get_control_kind (Gtk.Range? range) {
            if (range == null)
                return ControllerControlKind.DEFAULT;
            return ((Gtk.Orientable) range).get_orientation () == Gtk.Orientation.HORIZONTAL
                ? ControllerControlKind.HORIZONTAL_RANGE
                : ControllerControlKind.VERTICAL_RANGE;
        }

        bool adjust_range (Gtk.Range range, ControllerDirectionAction action) {
            var horizontal = ((Gtk.Orientable) range).get_orientation () ==
                Gtk.Orientation.HORIZONTAL;
            Gtk.ScrollType movement;
            if (horizontal)
                movement = action == ControllerDirectionAction.ADJUST_BACKWARD
                    ? Gtk.ScrollType.STEP_LEFT
                    : Gtk.ScrollType.STEP_RIGHT;
            else
                movement = action == ControllerDirectionAction.ADJUST_BACKWARD
                    ? Gtk.ScrollType.STEP_UP
                    : Gtk.ScrollType.STEP_DOWN;

            var previous_value = range.get_value ();
            range.move_slider (movement);
            return range.get_value () != previous_value;
        }

        bool move_focus (Gtk.Widget root, ControllerNavigationDirection direction) {
            bool moved = false;
            switch (direction) {
            case UP :
                moved = root.child_focus (Gtk.DirectionType.UP);
                if (!moved)
                    moved = root.child_focus (Gtk.DirectionType.TAB_BACKWARD);
                break;
            case DOWN :
                moved = root.child_focus (Gtk.DirectionType.DOWN);
                if (!moved)
                    moved = root.child_focus (Gtk.DirectionType.TAB_FORWARD);
                break;
            case LEFT :
                moved = root.child_focus (Gtk.DirectionType.LEFT);
                break;
            case RIGHT :
                moved = root.child_focus (Gtk.DirectionType.RIGHT);
                break;
            default :
                break;
            }
            if (moved)
                controller_focus_changed ();
            return moved;
        }

        void handle_axis (SDL.Joystick.JoystickID id, SDL.Gamepad.GamepadAxis axis, int16 raw) {
            var gamepad = find_gamepad (id);
            if (gamepad == null)
                return;

            switch (axis) {
            case LEFTX :
            case LEFTY :
                var released_direction = input_policy.has_repeat &&
                    input_policy.repeat_device_id == controller_id (id) &&
                    input_policy.repeat_source == ControllerNavigationSource.LEFT_STICK
                    ? input_policy.repeat_direction
                    : ControllerNavigationDirection.NONE;
                var update = input_policy.update_left_axis (
                    controller_id (id),
                    axis == SDL.Gamepad.GamepadAxis.LEFTX,
                    raw
                );
                if (update.ownership_changed) {
                    cancel_repeat_timer ();
                    haptic_feedback.claim_device (controller_id (id));
                }
                if (update.emitted_direction != ControllerNavigationDirection.NONE) {
                    activate_controller_mode ();
                    handle_controller_direction (controller_id (id), update.emitted_direction);
                }
                if (update.emitted_direction == ControllerNavigationDirection.NONE &&
                    update.repeat_changed)
                    haptic_feedback.direction_released (
                        controller_id (id), released_direction
                    );
                if (update.repeat_changed)
                    restart_repeat_timer ();
                break;
            case RIGHTY :
                if (input_policy.update_right_axis (controller_id (id), raw)) {
                    cancel_repeat_timer ();
                    haptic_feedback.claim_device (controller_id (id));
                }
                if (input_policy.has_active_device &&
                    input_policy.active_device_id == controller_id (id) &&
                    input_policy.scroll_intent != 0)
                    activate_controller_mode ();
                break;
            default :
                break;
            }
        }

        void reset_input_state () {
            cancel_repeat_timer ();
            input_policy.reset_transient_input ();
        }

        Gtk.Widget get_input_root () {
            return get_active_surface ().widget ?? window;
        }

        Gtk.Widget? get_focused_widget () {
            var surface = get_active_surface ();
            Gtk.Widget? focused = null;
            if (surface.widget is Adw.Dialog)
                focused = ((Adw.Dialog) surface.widget).get_focus ();
            if (focused == null)
                focused = window.get_focus ();
            return is_inside_surface (focused, surface) ? focused : null;
        }

        GtkSurface get_active_surface () {
            return (GtkSurface) surface_policy.active_surface;
        }

        bool has_active_modal_surface () {
            return get_active_surface ().kind != ControllerSurfaceKind.WINDOW ||
                find_focused_popover () != null;
        }

        bool activate_focused (out ControllerActivationDecision decision) {
            decision = ControllerActivationDecision.ACTIVATE;
            var focused = get_focused_widget ();
            if (focused == null)
                return false;

            var root = get_direction_input_root (focused, get_active_surface ());
            var editable = ControllerEditableTargetResolver.resolve (focused, root);
            decision = ControllerActivationPolicy.for_focused_control (editable != null);
            if (decision == ControllerActivationDecision.FOCUS_TEXT_INPUT) {
                save_current_page_focus ();
                focus_text_input ((!) editable);
                schedule_scroll_to_focus ();
                refresh_presentation ();
                return false;
            }

            string previous_page_id;
            Gtk.Widget? previous_page_root;
            get_active_page_context (out previous_page_id, out previous_page_root);
            save_current_page_focus ();
            var previous_surface_generation = surface_generation;
            var list_view = find_list_view_ancestor (
                focused, get_direction_input_root (focused, get_active_surface ())
            );
            var redirected_target = find_controller_activation_target (focused, root);
            var succeeded = false;
            if (redirected_target != null) {
                succeeded = ((!) redirected_target).activate ();
            } else if (list_view != null) {
                var model = list_view.get_model ();
                var selection = model?.get_selection ();
                if (selection != null && !selection.is_empty ()) {
                    list_view.activate (selection.get_minimum ());
                    succeeded = true;
                }
            } else {
                succeeded = focused.activate ();
            }

            string active_page_id;
            Gtk.Widget? active_page_root;
            get_active_page_context (out active_page_id, out active_page_root);
            if (previous_surface_generation == surface_generation &&
                previous_page_id != active_page_id && active_page_root != null)
                schedule_page_focus_restore ();
            refresh_presentation ();
            return succeeded;
        }

        Gtk.Widget? find_controller_activation_target (
            Gtk.Widget focused, Gtk.Widget root
        ) {
            Gtk.Widget? current = focused;
            while (current != null) {
                if (current is ControllerActivationRedirect)
                    return ((ControllerActivationRedirect) current)
                        .get_controller_activation_target (focused) as Gtk.Widget;
                if (current == root)
                    break;
                current = current.get_parent ();
            }
            return null;
        }

        void focus_text_input (Gtk.Widget target) {
            var focused = get_focused_widget ();
            if (focused != null && widget_is_descendant_of (focused, target))
                return;

            if (target is Adw.EntryRow) {
                ((Adw.EntryRow) target).grab_focus_without_selecting ();
            } else if (target is Gtk.Entry) {
                ((Gtk.Entry) target).grab_focus_without_selecting ();
            } else if (target is Gtk.Editable) {
                var editable_delegate = ((Gtk.Editable) target).get_delegate ();
                if (editable_delegate is Gtk.Text)
                    ((Gtk.Text) editable_delegate).grab_focus_without_selecting ();
                else
                    target.grab_focus ();
            } else {
                target.grab_focus ();
            }
        }

        Gtk.ListView? find_list_view_ancestor (Gtk.Widget focused, Gtk.Widget root) {
            Gtk.Widget? current = focused;
            while (current != null) {
                if (current is Gtk.ListView)
                    return (Gtk.ListView) current;
                if (current == root)
                    break;
                current = current.get_parent ();
            }
            return null;
        }

        void scroll (double delta) {
            var surface = get_active_surface ();
            var root = get_input_root ();
            Gtk.Widget? widget = get_focused_widget ();
            if (widget == null)
                widget = root;

            while (widget != null) {
                if (widget is Gtk.ScrolledWindow) {
                    scroll_adjustment (((Gtk.ScrolledWindow) widget).get_vadjustment (), delta);
                    return;
                }
                if (widget == root)
                    break;
                widget = widget.get_parent ();
            }

            if (surface.kind != ControllerSurfaceKind.WINDOW) {
                var scrolled = find_scrolled_descendant (root);
                if (scrolled != null)
                    scroll_adjustment (scrolled.get_vadjustment (), delta);
            }
        }

        Gtk.ScrolledWindow? find_scrolled_descendant (Gtk.Widget root) {
            var child = root.get_first_child ();
            while (child != null) {
                if (child is Gtk.ScrolledWindow)
                    return (Gtk.ScrolledWindow) child;
                var nested = find_scrolled_descendant (child);
                if (nested != null)
                    return nested;
                child = child.get_next_sibling ();
            }
            return null;
        }

        void scroll_adjustment (Gtk.Adjustment adjustment, double delta) {
            var maximum = adjustment.upper - adjustment.page_size;
            if (maximum < adjustment.lower)
                maximum = adjustment.lower;

            var target = adjustment.value + delta;
            if (target < adjustment.lower)
                target = adjustment.lower;
            if (target > maximum)
                target = maximum;

            adjustment.set_value (target);
        }

        bool dismiss_active_surface () {
            var focused_popover = find_focused_popover ();
            if (focused_popover != null) {
                focused_popover.popdown ();
                return true;
            }

            var surface = surface_policy.dismissable_surface as GtkSurface;
            if (surface != null && surface.kind == ControllerSurfaceKind.POPOVER &&
                surface.widget != null) {
                ((Gtk.Popover) surface.widget).popdown ();
                return true;
            }

            if (surface != null && surface.widget != null) {
                ((Adw.Dialog) surface.widget).close ();
                return true;
            }
            return false;
        }

        public void navigate_back () {
            perform_navigate_back ();
        }

        bool perform_navigate_back () {
            var has_modal = has_active_modal_surface ();
            var host = get_active_navigation_host ();
            if (!has_modal)
                save_current_page_focus ();

            var action = navigation_policy.navigate_back (has_modal, host);
            var succeeded = false;
            switch (action) {
            case ControllerBackAction.DISMISS_SURFACE:
                succeeded = dismiss_active_surface ();
                break;
            case ControllerBackAction.NAVIGATE_APPLICATION:
                schedule_page_focus_restore ();
                succeeded = true;
                break;
            default:
                break;
            }
            refresh_presentation ();
            return succeeded;
        }

        public void navigate_application_back () {
            if (has_active_modal_surface ())
                return;

            save_current_page_focus ();
            var action = navigation_policy.navigate_back (
                false, get_active_navigation_host ()
            );
            if (action == ControllerBackAction.NAVIGATE_APPLICATION)
                schedule_page_focus_restore ();
            refresh_presentation ();
        }

        Gtk.Popover? find_focused_popover () {
            Gtk.Widget? widget = get_focused_widget ();
            while (widget != null) {
                if (widget is Gtk.Popover)
                    return (Gtk.Popover) widget;
                widget = widget.get_parent ();
            }
            return null;
        }

        bool switch_tab (int delta) {
            var surface = get_active_surface ();
            if (surface.kind == ControllerSurfaceKind.POPOVER ||
                find_focused_popover () != null)
                return false;

            var host = get_active_navigation_host ();
            save_current_page_focus ();
            var switched = navigation_policy.switch_page (host, delta);
            if (switched) {
                haptic_feedback.context_changed ();
                schedule_page_focus_restore (
                    host != null &&
                    host.controller_prefers_initial_focus_after_switch ()
                );
            }
            refresh_presentation ();
            return switched;
        }

        ControllerNavigationHost? get_active_navigation_host () {
            var surface = get_active_surface ();
            var host = surface.widget as ControllerNavigationHost;
            if (host != null)
                return host;
            if (surface.kind == ControllerSurfaceKind.WINDOW)
                return window.main_box.get_root () == window &&
                    window.main_box.get_mapped () && window.main_box.get_visible ()
                    ? window.main_box as ControllerNavigationHost
                    : null;
            return null;
        }

        void get_active_page_context (out string page_id, out Gtk.Widget? page_root) {
            var host = get_active_navigation_host ();
            if (host != null) {
                page_id = host.get_controller_page_id ();
                page_root = host.get_controller_page_root () as Gtk.Widget;
                return;
            }

            page_id = "";
            page_root = get_active_surface ().widget;
        }

        void save_current_page_focus () {
            string page_id;
            Gtk.Widget? page_root;
            get_active_page_context (out page_id, out page_root);
            var focused = get_focused_widget ();
            if (page_root != null && is_valid_page_focus_target (focused, page_root))
                navigation_policy.remember_focus (page_id, focused);
        }

        bool is_valid_page_focus_target (Gtk.Widget? widget, Gtk.Widget page_root) {
            return is_valid_focus_target (widget) &&
                widget_is_descendant_of ((!) widget, page_root) &&
                is_inside_surface (widget, get_active_surface ());
        }

        void controller_focus_changed () {
            save_current_page_focus ();
            schedule_scroll_to_focus ();
            refresh_presentation ();
        }

        void schedule_page_focus_restore (bool prefer_initial = false) {
            var host = get_active_navigation_host ();
            if (host == null)
                return;

            cancel_navigation_focus_restore ();
            var request = navigation_policy.begin_restore (
                host.get_controller_page_id (), surface_generation
            );
            schedule_page_focus_restore_attempt (request, 0, prefer_initial);
        }

        void schedule_page_focus_restore_attempt (ControllerFocusRestoreRequest request,
            int attempt, bool prefer_initial) {
            navigation_focus_source_id = GLib.Timeout.add (attempt == 0 ? 1 : 16, () => {
                navigation_focus_source_id = 0;
                var host = get_active_navigation_host ();
                if (host == null || !navigation_policy.can_apply_restore (
                    request, host.get_controller_page_id (), surface_generation
                ))
                    return GLib.Source.REMOVE;

                var page_root = host.get_controller_page_root () as Gtk.Widget;
                if (page_root == null || !page_root.get_visible () ||
                    !page_root.get_mapped () || page_root.get_width () <= 0 ||
                    page_root.get_height () <= 0) {
                    if (attempt < 8)
                        schedule_page_focus_restore_attempt (
                            request, attempt + 1, prefer_initial
                        );
                    return GLib.Source.REMOVE;
                }

                var remembered = navigation_policy.recall_focus (request.page_id) as Gtk.Widget;
                var initial = host.get_controller_initial_focus () as Gtk.Widget;
                var choice = ControllerNavigationPolicy.choose_focus_target (
                    is_valid_page_focus_target (remembered, page_root),
                    is_valid_page_focus_target (initial, page_root),
                    prefer_initial
                );

                bool focused = false;
                switch (choice) {
                case ControllerFocusTargetChoice.REMEMBERED:
                    focused = ((!) remembered).grab_focus ();
                    break;
                case ControllerFocusTargetChoice.INITIAL:
                    focused = ((!) initial).grab_focus ();
                    break;
                case ControllerFocusTargetChoice.TRAVERSE:
                    focused = page_root.child_focus (Gtk.DirectionType.TAB_FORWARD);
                    break;
                }

                if (focused) {
                    save_current_page_focus ();
                    schedule_scroll_to_focus ();
                    sync_highlight ();
                    refresh_presentation ();
                }
                return GLib.Source.REMOVE;
            });
        }

        void cancel_navigation_focus_restore () {
            if (navigation_focus_source_id != 0) {
                GLib.Source.remove (navigation_focus_source_id);
                navigation_focus_source_id = 0;
            }
        }

        void invalidate_navigation_deferred () {
            surface_generation++;
            navigation_policy.invalidate_restores ();
            cancel_navigation_focus_restore ();
            cancel_scroll_to_focus ();
        }

        void schedule_scroll_to_focus () {
            cancel_scroll_to_focus ();
            string page_id;
            Gtk.Widget? page_root;
            get_active_page_context (out page_id, out page_root);
            var focused = get_focused_widget ();
            if (page_root == null || !is_valid_page_focus_target (focused, page_root))
                return;

            var request = new GtkFocusScrollRequest (
                (!) focused, page_root, page_id, surface_generation
            );
            scroll_focus_source_id = GLib.Timeout.add (16, () => {
                scroll_focus_source_id = 0;
                reveal_focused_widget (request);
                return GLib.Source.REMOVE;
            });
        }

        void cancel_scroll_to_focus () {
            if (scroll_focus_source_id != 0) {
                GLib.Source.remove (scroll_focus_source_id);
                scroll_focus_source_id = 0;
            }
        }

        void reveal_focused_widget (GtkFocusScrollRequest request) {
            var widget = request.widget;
            var requested_root = request.page_root;
            if (widget == null || requested_root == null ||
                request.surface_generation != surface_generation)
                return;

            string active_page_id;
            Gtk.Widget? active_page_root;
            get_active_page_context (out active_page_id, out active_page_root);
            if (active_page_root != requested_root || active_page_id != request.page_id ||
                !is_valid_page_focus_target (widget, requested_root))
                return;

            var scrolled = find_nearest_scrolled_ancestor (widget, requested_root);
            var content = scrolled?.get_child ();
            if (scrolled == null || content == null || !scrolled.get_mapped () ||
                !widget_is_descendant_of (scrolled, requested_root))
                return;

            Graphene.Rect bounds;
            if (!widget.compute_bounds (content, out bounds))
                return;

            reveal_adjustment (
                scrolled.get_hadjustment (), bounds.origin.x,
                bounds.origin.x + bounds.size.width
            );
            reveal_adjustment (
                scrolled.get_vadjustment (), bounds.origin.y,
                bounds.origin.y + bounds.size.height
            );
        }

        Gtk.ScrolledWindow? find_nearest_scrolled_ancestor (Gtk.Widget widget,
            Gtk.Widget page_root) {
            Gtk.Widget? current = widget;
            while (current != null) {
                if (current is Gtk.ScrolledWindow)
                    return (Gtk.ScrolledWindow) current;
                if (current == page_root)
                    break;
                current = current.get_parent ();
            }
            return null;
        }

        void reveal_adjustment (Gtk.Adjustment adjustment, double start, double end) {
            const double MARGIN = 12.0;
            var visible_start = adjustment.value;
            var visible_end = visible_start + adjustment.page_size;
            var target = visible_start;

            if (start - MARGIN < visible_start)
                target = start - MARGIN;
            else if (end + MARGIN > visible_end)
                target = end + MARGIN - adjustment.page_size;
            else
                return;

            var maximum = adjustment.upper - adjustment.page_size;
            if (maximum < adjustment.lower)
                maximum = adjustment.lower;
            if (target < adjustment.lower)
                target = adjustment.lower;
            if (target > maximum)
                target = maximum;
            adjustment.set_value (target);
        }
    }
}
