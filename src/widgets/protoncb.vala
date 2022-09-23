using ProtonPlus.Models;
using Gtk;

namespace ProtonPlus.Widgets {
    public class ProtonComboBox : Widget {
        ComboBox cb;

        construct {
            var layout = new BinLayout();
            set_layout_manager(layout);

            cb = new ComboBox();
            cb.set_parent(this);
        }

        protected override void dispose() {
            cb.unparent();
        }

        // Model must be composited of two columns. The first column is the text to be displayed and the second is the object
        public ProtonComboBox(Gtk.ListStore model) {
            CellRendererText cellrenderertext = new CellRendererText();
            cb.set_model(model);
            cb.pack_start(cellrenderertext, true);
            cb.add_attribute(cellrenderertext, "text", 0);
            cb.set_active(0);
        }

        public GLib.Value GetCurrentObject() {
            var model = cb.get_model();
            TreeIter iter;
            cb.get_active_iter(out iter);
            GLib.Value object_value;
            model.get_value(iter, 1, out object_value);
            return object_value;
        }

        public ComboBox GetChild() {
            return cb;
        }
    }
}
