namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;
    using Gtk;

    public class CustomExpanderRow : Adw.ExpanderRow {
        public new signal void changed ();

        protected string[] options_display;
        protected string[] options_values;
        protected HashTable<string, string>? item_tooltips;
        protected HashTable<string, Adw.ComboRow> rows_map;
        protected Gee.ArrayList<string> row_order;
        Gee.HashSet<string> predefined_keys;

        private Adw.EntryRow add_custom_row;
        private Gtk.Label custom_feedback_label;
        private Gtk.ListBoxRow custom_feedback_row;
        private bool allow_custom;

        public bool is_advanced { get; set; default = false; }
        Gtk.EventControllerKey key_controller;

        public CustomExpanderRow (string switch_title,
            string switch_subtitle,
            string[] options_display,
            string[] options_values,
            HashTable<string, string>? tooltips = null, bool allow_custom = true) {
            Object (
                    title : switch_title,
                    subtitle : switch_subtitle
            );

            this.options_display = options_display;
            this.options_values = options_values;
            this.rows_map = new HashTable<string, Adw.ComboRow> (str_hash, str_equal);
            this.row_order = new Gee.ArrayList<string> ();
            this.predefined_keys = new Gee.HashSet<string> ();
            this.item_tooltips = tooltips;
            this.allow_custom = allow_custom;
            this.set_tooltip_text (switch_subtitle);

            add_custom_row = new Adw.EntryRow ();
            add_custom_row.title = _("Custom DLL name");
            Utils.TextInputMetadataPolicy.apply (
                add_custom_row, Utils.TextInputFieldKind.PATH_OR_IDENTIFIER
            );
            add_custom_row.set_tooltip_text (_("Add the DLL to choose a different override mode."));
            custom_feedback_label = LaunchOptionInputFeedback.create_label ();
            custom_feedback_row = new Gtk.ListBoxRow () {
                child = custom_feedback_label,
                activatable = false,
                selectable = false,
                focusable = false,
                visible = false
            };
            add_custom_row.changed.connect (refresh_custom_input);

            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_button.add_css_class ("flat");
            add_button.valign = Gtk.Align.CENTER;
            add_button.set_tooltip_text (_("Add DLL"));
            add_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Add DLL"), -1
            );
            add_button.clicked.connect (on_custom_item_added);
            add_custom_row.add_suffix (add_button);

            key_controller = new Gtk.EventControllerKey ();
            key_controller.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            key_controller.key_pressed.connect ((keyval, keycode, state) => {
                if (keyval == (uint) Gdk.Key.Return || keyval == (uint) Gdk.Key.KP_Enter) {
                    on_custom_item_added ();
                    return true;
                }
                return false;
            });
            add_custom_row.add_controller (key_controller);
        }

        public void init_predefined_keys (string[] predefined_keys) {
            if (predefined_keys == null)
                return;
            foreach (string key in predefined_keys) {
                this.predefined_keys.add (key.strip ().down ());
                create_item_row (key, "");
            }

            if (allow_custom)
                add_custom_row_to_end ();
        }

        void add_custom_row_to_end () {
            add_row (add_custom_row);
            add_row (custom_feedback_row);
        }

        void remove_custom_row () {
            remove (custom_feedback_row);
            remove (add_custom_row);
        }

        protected void create_item_row (string key_name, string initial_value) {
            string normalized_key = key_name.strip ().down ();
            if (rows_map.contains (normalized_key))
                return;

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
                row.set_tooltip_text (row.subtitle);
            } else {
                row.set_tooltip_text (row.title);
            }

            rows_map.insert (normalized_key, row);
            row_order.add (normalized_key);
            this.add_row (row);
            row.visible = true;
        }

        protected string get_pending_custom_key () {
            return allow_custom ? add_custom_row.text.strip ().down () : "";
        }

        protected string get_default_custom_value () {
            return options_values.length > 1 ? options_values[1] : "";
        }

        public string? get_validation_diagnostic () {
            var key = get_pending_custom_key ();
            if (key == "")
                return null;
            if (rows_map.contains (key))
                return _("This DLL is already listed. Change its override mode above.");
            if (key.contains (";") || key.contains ("=") || key.contains ("%command%"))
                return _("Enter a DLL name without a separator or %command%.");
            return null;
        }

        void refresh_custom_input () {
            var diagnostic = get_validation_diagnostic ();
            LaunchOptionInputFeedback.update (add_custom_row, custom_feedback_label, diagnostic);
            custom_feedback_row.visible = diagnostic != null;
            trigger_changed_if_ready ();
        }

        private void on_custom_item_added () {
            var key = get_pending_custom_key ();
            if (key == "" || get_validation_diagnostic () != null)
                return;

            remove_custom_row ();
            create_item_row (key, get_default_custom_value ());
            add_custom_row_to_end ();
            add_custom_row.set_text ("");
        }

        protected void force_add_custom_row (string key, string val) {
            if (allow_custom)
                remove_custom_row ();
            create_item_row (key, val);
            if (allow_custom)
                add_custom_row_to_end ();
        }

        protected void clear_custom_items () {
            add_custom_row.set_text ("");
            var custom_keys = new Gee.ArrayList<string> ();
            foreach (var key in row_order) {
                if (!predefined_keys.contains (key))
                    custom_keys.add (key);
            }
            foreach (var key in custom_keys) {
                var row = rows_map.lookup (key);
                if (row != null)
                    this.remove (row);
                rows_map.remove (key);
                row_order.remove (key);
            }
        }

        protected virtual void trigger_changed_if_ready () {
            this.changed ();
        }
    }
}
