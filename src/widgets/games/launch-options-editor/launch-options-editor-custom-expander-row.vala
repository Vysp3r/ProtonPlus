namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;
using Gtk;

    public class CustomExpanderRow : Adw.ExpanderRow {
        public new signal void changed ();

        protected string[] options_display;
        protected string[] options_values;
        protected HashTable<string, string>? item_tooltips;
        protected HashTable<string, Adw.ComboRow> rows_map;

        private Adw.EntryRow add_custom_row;

        public bool is_advanced { get; set; default = false; }

        public CustomExpanderRow (
                string switch_title,
                string switch_subtitle,
                string[] options_display,
                string[] options_values,
                HashTable<string, string>? tooltips = null
        ) {
            Object (
                    title: switch_title,
                    subtitle: switch_subtitle,
                    show_enable_switch: true
            );

            this.options_display = options_display;
            this.options_values = options_values;
            this.rows_map = new HashTable<string, Adw.ComboRow> (str_hash, str_equal);
            this.item_tooltips = tooltips;

            add_custom_row = new Adw.EntryRow ();
            add_custom_row.title = _ ("Add custom item (Type name and press Enter)...");
            add_custom_row.activates_default = true;

            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_button.add_css_class ("flat");
            add_button.valign = Gtk.Align.CENTER;
            add_button.clicked.connect (on_custom_item_added);
            add_custom_row.add_suffix (add_button);

            var key_controller = new Gtk.EventControllerKey ();
            key_controller.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            key_controller.key_pressed.connect ((keyval, keycode, state) => {
                if (keyval == (uint) Gdk.Key.Return || keyval == (uint) Gdk.Key.KP_Enter) {
                    on_custom_item_added ();
                    return true;
                }
                return false;
            });
            add_custom_row.add_controller (key_controller);

            this.notify["enable-expansion"].connect (() => {
                this.trigger_changed_if_ready ();
            });
        }

        public void init_predefined_keys (string[] predefined_keys) {
            if (predefined_keys == null) return;
            foreach (string key in predefined_keys) {
                create_item_row (key, "");
            }

            this.add_row (add_custom_row);
        }

        protected void create_item_row (string key_name, string initial_value) {
            string normalized_key = key_name.strip ().down ();
            if (rows_map.contains (normalized_key)) return;

            var row = new Adw.ComboRow ();
            row.title = normalized_key;
            row.model = new Gtk.StringList (options_display);

            uint selected_idx = 0;
            for (uint i = 0; i < options_values.length; i++) {
                if (options_values[i] == initial_value) {
                    selected_idx = i;
                    break;
                }
            }
            row.selected = selected_idx;
            row.notify["selected"].connect (() => { this.trigger_changed_if_ready (); });

            if (this.item_tooltips != null && this.item_tooltips.contains (normalized_key)) {
                row.subtitle = this.item_tooltips.lookup (normalized_key);
            }

            rows_map.insert (normalized_key, row);
            this.add_row (row);
            row.show ();
        }

        private void on_custom_item_added () {
            string custom_key = add_custom_row.text.strip ().down ();

            if (custom_key != "" && !rows_map.contains (custom_key)) {
                string default_val = options_values.length > 1 ? options_values[1] : "";

                this.remove (add_custom_row);
                create_item_row (custom_key, default_val);
                this.add_row (add_custom_row);

                add_custom_row.text = "";
                this.trigger_changed_if_ready ();
            } else {
                add_custom_row.text = "";
            }
        }

        protected void force_add_custom_row (string key, string val) {
            this.remove (add_custom_row);
            create_item_row (key, val);
            this.add_row (add_custom_row);
        }

        protected virtual void trigger_changed_if_ready () {
            this.changed ();
        }

        public virtual bool is_active () {
            return this.enable_expansion; 
        }
    }
}