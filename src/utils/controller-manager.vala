namespace ProtonPlus.Utils {
    public class ControllerManager : Object {
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
        ulong highlight_visible_handler = 0;
        ulong highlight_unmap_handler = 0;
        ulong highlight_destroy_handler = 0;
        uint focus_idle_id = 0;
        Gee.ArrayList<GamepadState> gamepads = new Gee.ArrayList<GamepadState> ();
        Gee.ArrayList<GtkSurface> registered_surfaces = new Gee.ArrayList<GtkSurface> ();
        GtkSurface window_surface;
        ControllerSurfacePolicy surface_policy;
        ControllerInputPolicy input_policy = new ControllerInputPolicy ();
        ControllerNavigationPolicy navigation_policy = new ControllerNavigationPolicy ();
        uint64 surface_generation = 0;
        uint navigation_focus_source_id = 0;
        uint scroll_focus_source_id = 0;

        const double SCROLL_SPEED = 12.0;
        const uint INITIAL_REPEAT_DELAY = 350;
        const uint REPEAT_INTERVAL = 75;

        public ControllerManager (Widgets.Window window) {
            this.window = window;

            window_surface = new GtkSurface (ControllerSurfaceKind.WINDOW, window);
            surface_policy = new ControllerSurfacePolicy (window_surface);

            motion = new Gtk.EventControllerMotion ();
            motion.motion.connect ((x, y) => deactivate_controller_mode ());

            press = new Gtk.GestureClick ();
            press.set_button (0);
            press.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            press.pressed.connect ((n_press, x, y) => deactivate_controller_mode ());

            keys = new Gtk.EventControllerKey ();
            keys.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            keys.key_pressed.connect ((keyval, keycode, state) => {
                deactivate_controller_mode ();
                return false;
            });

            window_active_handler = window.notify["is-active"].connect (() => {
                if (!window.is_active)
                    reset_input_state ();
            });
            window_focus_handler = window.notify["focus-widget"].connect (() => sync_highlight ());
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
            cancel_repeat_timer ();
            invalidate_navigation_deferred ();
            clear_highlight ();
            if (controller_active)
                sync_highlight ();
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
                return GLib.Source.REMOVE;
            });
        }

        bool is_valid_focus_target (Gtk.Widget? widget) {
            return widget != null && widget.get_root () != null && widget.get_mapped () &&
                widget.get_visible () && widget.get_sensitive () && widget.get_focusable ();
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
        }

        void close_gamepad (SDL.Joystick.JoystickID id) {
            var state = find_gamepad (id);
            if (state == null)
                return;

            if (input_policy.disconnect_device (controller_id (state.id)))
                cancel_repeat_timer ();

            gamepads.remove (state);
            SDL.Gamepad.close_gamepad (state.gamepad);
        }

        void close_gamepads () {
            foreach (var state in gamepads)
                SDL.Gamepad.close_gamepad (state.gamepad);

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
            if (!controller_active) {
                controller_active = true;
                window.add_css_class ("controller-active");
            }
            sync_highlight ();
        }

        void deactivate_controller_mode () {
            if (!controller_active)
                return;

            controller_active = false;
            window.remove_css_class ("controller-active");
            clear_highlight ();
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

        void handle_button_down (SDL.Joystick.JoystickID id, SDL.Gamepad.GamepadButton button) {
            var gamepad = find_gamepad (id);
            if (gamepad == null)
                return;

            if (input_policy.note_button_press (controller_id (id)))
                cancel_repeat_timer ();
            activate_controller_mode ();
            switch (button) {
            case DPAD_UP :
            case DPAD_DOWN :
            case DPAD_LEFT :
            case DPAD_RIGHT :
                var direction = direction_for_dpad (button);
                move_focus (direction);
                input_policy.begin_repeat (
                    controller_id (id),
                    direction,
                    ControllerNavigationSource.DPAD
                );
                restart_repeat_timer ();
                break;
            case SOUTH :
            case EAST :
                handle_face_button (button);
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
                switch_tab (-1);
                break;
            case RIGHT_SHOULDER :
                switch_tab (1);
                break;
            default :
                break;
            }
            sync_highlight ();
        }

        void handle_button_up (SDL.Joystick.JoystickID id, SDL.Gamepad.GamepadButton button) {
            var direction = direction_for_dpad (button);
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

        void handle_face_button (SDL.Gamepad.GamepadButton button) {
            var confirm_button = ControllerConfirmButton.SOUTH;
            if (Globals.SETTINGS != null)
                confirm_button = (ControllerConfirmButton) Globals.SETTINGS.get_enum ("controller-confirm-button");

            var face_button = button == SDL.Gamepad.GamepadButton.SOUTH
                ? ControllerFaceButton.SOUTH
                : ControllerFaceButton.EAST;
            if (ControllerInputPolicy.get_face_button_action (confirm_button, face_button) ==
                ControllerFaceButtonAction.ACTIVATE)
                activate_focused ();
            else
                navigate_back ();
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

                move_focus (input_policy.repeat_direction);
                sync_highlight ();
                repeat_timeout_id = GLib.Timeout.add (REPEAT_INTERVAL, () => {
                    if (!can_repeat_navigation ()) {
                        input_policy.cancel_repeat ();
                        repeat_timeout_id = 0;
                        return GLib.Source.REMOVE;
                    }

                    move_focus (input_policy.repeat_direction);
                    sync_highlight ();
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

        bool move_focus (ControllerNavigationDirection direction) {
            var root = get_input_root ();
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
                var update = input_policy.update_left_axis (
                    controller_id (id),
                    axis == SDL.Gamepad.GamepadAxis.LEFTX,
                    raw
                );
                if (update.ownership_changed)
                    cancel_repeat_timer ();
                if (update.emitted_direction != ControllerNavigationDirection.NONE) {
                    activate_controller_mode ();
                    move_focus (update.emitted_direction);
                }
                if (update.repeat_changed)
                    restart_repeat_timer ();
                break;
            case RIGHTY :
                if (input_policy.update_right_axis (controller_id (id), raw))
                    cancel_repeat_timer ();
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
            return get_active_surface ().kind != ControllerSurfaceKind.WINDOW;
        }

        void activate_focused () {
            var focused = get_focused_widget ();
            if (focused == null)
                return;

            string previous_page_id;
            Gtk.Widget? previous_page_root;
            get_active_page_context (out previous_page_id, out previous_page_root);
            save_current_page_focus ();
            var previous_surface_generation = surface_generation;
            focused.activate ();

            string active_page_id;
            Gtk.Widget? active_page_root;
            get_active_page_context (out active_page_id, out active_page_root);
            if (previous_surface_generation == surface_generation &&
                previous_page_id != active_page_id && active_page_root != null)
                schedule_page_focus_restore ();
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

        void dismiss_active_surface () {
            var surface = surface_policy.dismissable_surface as GtkSurface;
            if (surface != null && surface.kind == ControllerSurfaceKind.POPOVER &&
                surface.widget != null) {
                ((Gtk.Popover) surface.widget).popdown ();
                return;
            }

            var focused_popover = find_focused_popover ();
            if (focused_popover != null) {
                focused_popover.popdown ();
                return;
            }

            if (surface != null && surface.widget != null)
                ((Adw.Dialog) surface.widget).close ();
        }

        public void navigate_back () {
            var focused_popover = find_focused_popover ();
            var has_modal = has_active_modal_surface () || focused_popover != null;
            var host = get_active_navigation_host ();
            if (!has_modal)
                save_current_page_focus ();

            var action = navigation_policy.navigate_back (has_modal, host);
            switch (action) {
            case ControllerBackAction.DISMISS_SURFACE:
                dismiss_active_surface ();
                break;
            case ControllerBackAction.NAVIGATE_APPLICATION:
                schedule_page_focus_restore ();
                break;
            default:
                break;
            }
        }

        public void navigate_application_back () {
            if (has_active_modal_surface () || find_focused_popover () != null)
                return;

            save_current_page_focus ();
            var action = navigation_policy.navigate_back (
                false, get_active_navigation_host ()
            );
            if (action == ControllerBackAction.NAVIGATE_APPLICATION)
                schedule_page_focus_restore ();
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

        void switch_tab (int delta) {
            var surface = get_active_surface ();
            if (surface.kind == ControllerSurfaceKind.POPOVER)
                return;

            var host = get_active_navigation_host ();
            save_current_page_focus ();
            if (navigation_policy.switch_page (host, delta))
                schedule_page_focus_restore ();
        }

        ControllerNavigationHost? get_active_navigation_host () {
            var surface = get_active_surface ();
            var host = surface.widget as ControllerNavigationHost;
            if (host != null)
                return host;
            if (surface.kind == ControllerSurfaceKind.WINDOW)
                return window.main_box as ControllerNavigationHost;
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
        }

        void schedule_page_focus_restore () {
            var host = get_active_navigation_host ();
            if (host == null)
                return;

            cancel_navigation_focus_restore ();
            var request = navigation_policy.begin_restore (
                host.get_controller_page_id (), surface_generation
            );
            schedule_page_focus_restore_attempt (request, 0);
        }

        void schedule_page_focus_restore_attempt (ControllerFocusRestoreRequest request,
            int attempt) {
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
                        schedule_page_focus_restore_attempt (request, attempt + 1);
                    return GLib.Source.REMOVE;
                }

                var remembered = navigation_policy.recall_focus (request.page_id) as Gtk.Widget;
                var initial = host.get_controller_initial_focus () as Gtk.Widget;
                var choice = ControllerNavigationPolicy.choose_focus_target (
                    is_valid_page_focus_target (remembered, page_root),
                    is_valid_page_focus_target (initial, page_root)
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
