namespace ProtonPlus.Widgets {
    public class ScrollController : Object {
        private Gtk.Adjustment vadjustment;
        private double saved_pos = 0;

        public ScrollController (Gtk.ScrolledWindow window) {
            vadjustment = window.get_vadjustment();

            if (vadjustment == null)
                warning ("ScrollController: vadjustment is null – window not realized?");
        }

        public void save () {
            if (vadjustment == null)
                return;

            saved_pos = vadjustment.get_value();
        }

        public void restore(int delay_ms = 50) {
            if (vadjustment == null)
                return;

            GLib.Timeout.add(delay_ms, () => {
                vadjustment.set_value(saved_pos);
                return false;
            });
        }
    }
}