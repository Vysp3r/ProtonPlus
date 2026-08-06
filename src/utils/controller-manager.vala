namespace ProtonPlus.Utils {
    public class ControllerManager : Object {
        private class GamepadState : Object {
            public SDL.Joystick.JoystickID id;
            public SDL.Gamepad.Gamepad gamepad;
            public double stick_y = 0;

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
        GamepadState? repeating_gamepad = null;
        SDL.Gamepad.GamepadButton repeating_button = SDL.Gamepad.GamepadButton.INVALID;
        Gee.ArrayList<GamepadState> gamepads = new Gee.ArrayList<GamepadState> ();
        Gee.ArrayList<GtkSurface> registered_surfaces = new Gee.ArrayList<GtkSurface> ();
        GtkSurface window_surface;
        ControllerSurfacePolicy surface_policy;

        const double DEADZONE = 0.25;
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
                    reset_stick_state ();
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
            stop_button_repeat ();

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
            reset_stick_state ();
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

            clear_highlight ();
            var active = (GtkSurface) removal.active_surface;
            if (removal.restore_opener && surface.opener != null &&
                is_inside_surface (surface.opener, active)) {
                ((!) surface.opener).grab_focus ();
            } else {
                schedule_active_surface_focus ();
            }
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
                sync_highlight ();
                return GLib.Source.REMOVE;
            });
        }

        void focus_active_surface () {
            var surface = get_active_surface ();
            var focused = get_focused_widget ();
            if (focused != null && is_valid_focus_target (focused))
                return;
            surface.widget?.child_focus (Gtk.DirectionType.TAB_FORWARD);
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
                reset_stick_state ();
                return GLib.Source.CONTINUE;
            }

            var stick_y = get_scroll_stick_y ();
            if (stick_y != 0)
                scroll (stick_y * SCROLL_SPEED);

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

            if (repeating_gamepad == state)
                stop_button_repeat ();

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

            activate_controller_mode ();
            switch (button) {
            case DPAD_UP :
            case DPAD_DOWN :
            case DPAD_LEFT :
            case DPAD_RIGHT :
                move_focus (button);
                start_button_repeat (gamepad, button);
                break;
            case SOUTH :
                activate_focused ();
                break;
            case EAST :
                dismiss_active_surface ();
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
            if (repeating_gamepad != null && repeating_gamepad.id == id && repeating_button == button)
                stop_button_repeat ();
        }

        void start_button_repeat (GamepadState gamepad, SDL.Gamepad.GamepadButton button) {
            stop_button_repeat ();
            repeating_gamepad = gamepad;
            repeating_button = button;
            repeat_timeout_id = GLib.Timeout.add (INITIAL_REPEAT_DELAY, () => {
                if (!can_repeat_button ()) {
                    clear_button_repeat_state ();
                    return GLib.Source.REMOVE;
                }

                move_focus (repeating_button);
                sync_highlight ();
                repeat_timeout_id = GLib.Timeout.add (REPEAT_INTERVAL, () => {
                    if (!can_repeat_button ()) {
                        clear_button_repeat_state ();
                        return GLib.Source.REMOVE;
                    }

                    move_focus (repeating_button);
                    sync_highlight ();
                    return GLib.Source.CONTINUE;
                });
                return GLib.Source.REMOVE;
            });
        }

        bool can_repeat_button () {
            return window.is_active && repeating_gamepad != null && gamepads.contains (repeating_gamepad);
        }

        void stop_button_repeat () {
            if (repeat_timeout_id != 0)
                GLib.Source.remove (repeat_timeout_id);

            clear_button_repeat_state ();
        }

        void clear_button_repeat_state () {
            repeat_timeout_id = 0;
            repeating_gamepad = null;
            repeating_button = SDL.Gamepad.GamepadButton.INVALID;
        }

        void move_focus (SDL.Gamepad.GamepadButton button) {
            var root = get_input_root ();
            switch (button) {
            case DPAD_UP :
                if (!root.child_focus (Gtk.DirectionType.UP))
                    root.child_focus (Gtk.DirectionType.TAB_BACKWARD);
                break;
            case DPAD_DOWN :
                if (!root.child_focus (Gtk.DirectionType.DOWN))
                    root.child_focus (Gtk.DirectionType.TAB_FORWARD);
                break;
            case DPAD_LEFT :
                root.child_focus (Gtk.DirectionType.LEFT);
                break;
            case DPAD_RIGHT :
                root.child_focus (Gtk.DirectionType.RIGHT);
                break;
            default :
                break;
            }
        }

        void handle_axis (SDL.Joystick.JoystickID id, SDL.Gamepad.GamepadAxis axis, int16 raw) {
            if (axis != SDL.Gamepad.GamepadAxis.LEFTY)
                return;

            var gamepad = find_gamepad (id);
            if (gamepad == null)
                return;

            double value = raw / 32767.0;
            if (value > 1)
                value = 1;
            else if (value < -1)
                value = -1;

            gamepad.stick_y = Math.fabs (value) > DEADZONE ? value : 0;
            if (gamepad.stick_y != 0)
                activate_controller_mode ();
        }

        double get_scroll_stick_y () {
            double value = 0;
            foreach (var gamepad in gamepads) {
                if (Math.fabs (gamepad.stick_y) > Math.fabs (value))
                    value = gamepad.stick_y;
            }

            return value;
        }

        void reset_stick_state () {
            foreach (var gamepad in gamepads)
                gamepad.stick_y = 0;

            stop_button_repeat ();
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
            if (focused != null)
                focused.activate ();
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
            if (surface.kind == ControllerSurfaceKind.DIALOG) {
                var preferences = surface.widget as Widgets.Preferences.PreferencesDialog;
                if (preferences != null)
                    preferences.switch_page (delta);
                return;
            }

            var model = window.main_box.view_stack.pages;
            int count = (int) model.get_n_items ();
            if (count == 0)
                return;

            string? current = window.main_box.view_stack.visible_child_name;
            int current_index = 0;
            for (int i = 0; i < count; i++) {
                var page = (Adw.ViewStackPage) model.get_item ((uint) i);
                if (page.name == current) {
                    current_index = i;
                    break;
                }
            }

            for (int step = 1; step <= count; step++) {
                int index = ((current_index + delta * step) % count + count) % count;
                var page = (Adw.ViewStackPage) model.get_item ((uint) index);
                if (page.visible) {
                    window.main_box.view_stack.visible_child_name = page.name;
                    break;
                }
            }
        }
    }
}
