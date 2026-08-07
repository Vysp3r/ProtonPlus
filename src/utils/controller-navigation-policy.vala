namespace ProtonPlus.Utils {
    public enum ControllerBackAction {
        NONE,
        DISMISS_SURFACE,
        NAVIGATE_APPLICATION
    }

    public enum ControllerFocusTargetChoice {
        REMEMBERED,
        INITIAL,
        TRAVERSE
    }

    /* Page owners implement this narrow contract so ControllerManager does not
     * need to know widget classes or stack child names. */
    public interface ControllerNavigationHost : Object {
        public abstract string get_controller_page_id ();
        public abstract Object? get_controller_page_root ();
        public abstract Object? get_controller_initial_focus ();
        public abstract bool controller_can_navigate_back ();
        public abstract bool controller_can_switch_page ();
        public abstract bool controller_prefers_initial_focus_after_switch ();
        public abstract bool controller_navigate_back ();
        public abstract bool controller_switch_page (int delta);
    }

    /* Composite widgets can provide controller-only directional routes when
     * GTK's geometric focus choice does not match the visible interaction. */
    public interface ControllerDirectionalFocus : Object {
        public abstract bool controller_focus_direction (
            Object focused, ControllerNavigationDirection direction
        );
    }

    /* Composite widgets can redirect controller confirmation to a child while
     * leaving focused action controls to GTK's normal activation path. */
    public interface ControllerActivationRedirect : Object {
        public abstract Object? get_controller_activation_target (Object focused);
    }

    public interface ControllerPageShortcuts : Object {
        public abstract bool controller_can_open_search ();
        public abstract bool controller_can_open_filter ();
        public abstract bool controller_open_search ();
        public abstract bool controller_open_filter ();
    }

    public class ControllerFocusRestoreRequest : Object {
        public uint64 generation { get; private set; }
        public string page_id { get; private set; }
        public uint64 surface_generation { get; private set; }

        public ControllerFocusRestoreRequest (uint64 generation, string page_id,
            uint64 surface_generation) {
            this.generation = generation;
            this.page_id = page_id;
            this.surface_generation = surface_generation;
        }
    }

    private class ControllerFocusHistoryEntry : Object {
        public weak Object? target;

        public ControllerFocusHistoryEntry (Object target) {
            this.target = target;
        }
    }

    /* Display-independent application navigation, focus-history, and stale
     * deferred-work policy. GTK validation and focus operations remain in
     * ControllerManager. */
    public class ControllerNavigationPolicy : Object {
        private Gee.HashMap<string, ControllerFocusHistoryEntry> focus_history =
            new Gee.HashMap<string, ControllerFocusHistoryEntry> ();
        private uint64 restore_generation = 0;

        public ControllerBackAction navigate_back (bool has_modal_surface,
            ControllerNavigationHost? host) {
            if (has_modal_surface)
                return ControllerBackAction.DISMISS_SURFACE;
            if (host != null && host.controller_navigate_back ())
                return ControllerBackAction.NAVIGATE_APPLICATION;
            return ControllerBackAction.NONE;
        }

        public bool switch_page (ControllerNavigationHost? host, int delta) {
            return host != null && host.controller_switch_page (delta);
        }

        public void remember_focus (string page_id, Object? target) {
            if (page_id == "" || target == null)
                return;
            focus_history[page_id] = new ControllerFocusHistoryEntry ((!) target);
        }

        public Object? recall_focus (string page_id) {
            var entry = focus_history[page_id];
            return entry?.target;
        }

        public ControllerFocusRestoreRequest begin_restore (string page_id,
            uint64 surface_generation) {
            restore_generation++;
            return new ControllerFocusRestoreRequest (
                restore_generation, page_id, surface_generation
            );
        }

        public void invalidate_restores () {
            restore_generation++;
        }

        public bool can_apply_restore (ControllerFocusRestoreRequest request,
            string active_page_id, uint64 active_surface_generation) {
            return request.generation == restore_generation &&
                request.page_id == active_page_id &&
                request.surface_generation == active_surface_generation;
        }

        public static ControllerFocusTargetChoice choose_focus_target (
            bool remembered_valid, bool initial_valid,
            bool prefer_initial = false
        ) {
            if (prefer_initial && initial_valid)
                return ControllerFocusTargetChoice.INITIAL;
            if (remembered_valid)
                return ControllerFocusTargetChoice.REMEMBERED;
            if (initial_valid)
                return ControllerFocusTargetChoice.INITIAL;
            return ControllerFocusTargetChoice.TRAVERSE;
        }
    }
}
