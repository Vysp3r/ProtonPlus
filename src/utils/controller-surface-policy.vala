namespace ProtonPlus.Utils {
    public enum ControllerSurfaceKind {
        WINDOW,
        DIALOG,
        POPOVER
    }

    public class ControllerSurface : Object {
        public ControllerSurfaceKind kind { get; private set; }
        public bool opener_valid { get; set; default = false; }

        public ControllerSurface (ControllerSurfaceKind kind) {
            this.kind = kind;
        }
    }

    public class ControllerSurfaceRemoval : Object {
        public bool was_active { get; private set; }
        public bool restore_opener { get; private set; }
        public ControllerSurface active_surface { get; private set; }

        public ControllerSurfaceRemoval (bool was_active, bool restore_opener,
            ControllerSurface active_surface) {
            this.was_active = was_active;
            this.restore_opener = restore_opener;
            this.active_surface = active_surface;
        }
    }

    /* Display-independent ordering and dismissal policy. GTK ownership and
     * focus operations stay in ControllerManager. */
    public class ControllerSurfacePolicy : Object {
        private ControllerSurface window_surface;
        private Gee.ArrayList<ControllerSurface> surfaces = new Gee.ArrayList<ControllerSurface> ();

        public ControllerSurfacePolicy (ControllerSurface window_surface) {
            this.window_surface = window_surface;
            surfaces.add (window_surface);
        }

        public int size {
            get { return surfaces.size; }
        }

        public ControllerSurface active_surface {
            owned get { return surfaces[surfaces.size - 1]; }
        }

        public ControllerSurface? dismissable_surface {
            owned get {
                var active = active_surface;
                return active.kind == ControllerSurfaceKind.WINDOW ? null : active;
            }
        }

        public void present (ControllerSurface surface) {
            if (surface == window_surface)
                return;

            surfaces.remove (surface);
            surfaces.add (surface);
        }

        public ControllerSurfaceRemoval remove (ControllerSurface surface) {
            var was_active = surface == active_surface;
            if (surface != window_surface)
                surfaces.remove (surface);

            return new ControllerSurfaceRemoval (
                was_active,
                was_active && surface.kind == ControllerSurfaceKind.POPOVER && surface.opener_valid,
                active_surface
            );
        }

        public void reset () {
            surfaces.clear ();
            surfaces.add (window_surface);
        }
    }

    public interface ControllerHostAdapter : Object {
        public abstract bool is_controller_window (Object candidate);
        public abstract Object? get_root (Object candidate);
    }

    public class ControllerWindowResolver : Object {
        public static Object? resolve (Object? parent, ControllerHostAdapter adapter) {
            if (parent == null)
                return null;
            if (adapter.is_controller_window (parent))
                return parent;

            var root = adapter.get_root (parent);
            if (root != null && adapter.is_controller_window (root))
                return root;
            return null;
        }
    }
}
