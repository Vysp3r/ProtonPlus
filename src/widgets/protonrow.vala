namespace ProtonPlus.Widgets {
    public class ProtonRow<T> : Gtk.Widget {
        Gtk.Label label;
        T obj;

        construct {
            var layout = new Gtk.BinLayout();
            set_layout_manager(layout);

            label = new Gtk.Label ("a");
            label.set_parent(this);
        }

        protected override void dispose() {
            label.unparent();
        }

        public ProtonRow(string label, T obj) {
            this.label.set_label (label);
            this.obj = obj;
        }

        public T GetCurrentObject() {
            return obj;
        }

        public Gtk.Label GetChild() {
            return label;
        }
    }
}
