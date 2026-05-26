namespace ProtonPlus.Widgets.Components {
    using Adw;
    using Gtk;

    public class LaunchOptionCustomPairs : Gtk.Box {
        public signal void changed ();

        public string @value {
            owned get { return get_formatted_value (); }
            set { set_initial_value (value); }
        }

        private Adw.PreferencesGroup group;
        private Adw.SwitchRow master_switch;
        private Gtk.ListBox items_list;
        private Gtk.Frame list_frame;
        private Adw.EntryRow add_custom_row;

        private string[] options_display;
        private string[] options_values;
        private HashTable<string, string>? item_tooltips;
        private HashTable<string, Adw.ComboRow> rows_map;
        private bool is_updating = false;
        private string? separator;
        public string? environment_variable_prefix { get; set; }
        public string? environment_variable { get; set; }

        public LaunchOptionCustomPairs (
            string group_title,
            string group_description,
            string switch_title,
            string switch_subtitle,
            string[] predefined_keys,
            string[] options_display,
            string[] options_values,
            HashTable<string, string>? tooltips = null,
            string? separator = ",",
            string? environment_variable = null
        ) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12);

            this.options_display = options_display;
            this.options_values = options_values;
            this.rows_map = new HashTable<string, Adw.ComboRow> (str_hash, str_equal);
            this.item_tooltips = tooltips;
            this.separator = separator;
            this.environment_variable = environment_variable;
            this.environment_variable_prefix = environment_variable != null ? environment_variable + "=" : null;
            group = new Adw.PreferencesGroup ();
            group.title = group_title;
            group.description = group_description;
            this.append (group);

            master_switch = new Adw.SwitchRow ();
            master_switch.title = switch_title;
            master_switch.subtitle = switch_subtitle;
            group.add (master_switch);

            items_list = new Gtk.ListBox ();
            items_list.get_style_context ().add_class ("boxed-list");
            items_list.margin_top = 6;
            items_list.selection_mode = Gtk.SelectionMode.NONE;
            
            list_frame = new Gtk.Frame (null);
            list_frame.set_child (items_list);
            list_frame.margin_bottom = 12;
            group.add (list_frame);

            foreach (string key in predefined_keys) {
                create_item_row (key, "");
            }

            add_custom_row = new Adw.EntryRow ();
            add_custom_row.title = _("Add custom item (Type name and press Enter)...");
            add_custom_row.activates_default = true;

            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_button.get_style_context ().add_class ("flat");
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

            items_list.append (add_custom_row);

            list_frame.visible = master_switch.active;
            
            master_switch.notify["active"].connect (() => {
                bool active = master_switch.active;
                list_frame.visible = active;
                
                if (active) {
                    rows_map.foreach ((key, row) => {
                        row.queue_resize ();
                    });
                }
                
                trigger_changed ();
            });
        }

        private void create_item_row (string key_name, string initial_value) {
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
            row.notify["selected"].connect (() => { trigger_changed (); });

            if (this.item_tooltips != null && this.item_tooltips.contains (normalized_key)) {
                string description = this.item_tooltips.lookup (normalized_key);
                row.subtitle = description;
            }

            rows_map.insert (normalized_key, row);
            
            items_list.insert (row, (int) rows_map.size () - 1);
            
            row.show ();
        }

        private void on_custom_item_added () {
            string custom_key = add_custom_row.text.strip ().down ();
            
            if (custom_key != "" && !rows_map.contains (custom_key)) {
                string default_val = options_values.length > 1 ? options_values[1] : "";
                
                create_item_row (custom_key, default_val);
                add_custom_row.text = "";
                
                trigger_changed ();
            } else {
                add_custom_row.text = "";
            }
        }

        private void set_initial_value (string raw_value) {
            if (is_updating) return;
            is_updating = true;

            if (raw_value == null || raw_value == "") {
                master_switch.active = false;
                list_frame.visible = false;
                rows_map.foreach ((key, row) => { row.selected = 0; });
                is_updating = false;
                return;
            }

            master_switch.active = true;
            list_frame.visible = true;

            bool is_flag_list = (options_values.length > 1 && options_values[1] == "1");
            string[] parts = raw_value.split (this.separator);
            foreach (string part in parts) {
                string clean_part = part.strip ().down ();
                if (clean_part == "") continue;

                string[] kv = clean_part.split ("=");
                string key = "";
                string val = "";

                if (kv.length == 2) {
                    key = kv[0].strip ();
                    val = kv[1].strip ();
                } else if (is_flag_list) {
                    key = clean_part;
                    val = "1";
                }

                if (key != "") {
                    if (!rows_map.contains (key)) {
                        create_item_row (key, val);
                    } else {
                        var row = rows_map.lookup (key);
                        for (uint i = 0; i < options_values.length; i++) {
                            if (options_values[i] == val) {
                                row.selected = i;
                                break;
                            }
                        }
                    }
                }
            }
            is_updating = false;
        }

        private owned string get_formatted_value () {
            if (!master_switch.active) return "";

            string[] final_parts = {};
            bool is_flag_list = (options_values.length > 1 && options_values[1] == "1");
            rows_map.foreach ((key, combo_row) => {
                uint selected = combo_row.selected;
                string val = options_values[selected];
                if (val != "") {
                    if (is_flag_list) {
                        final_parts += combo_row.title;
                    } else {
                        final_parts += @"$key=$val";
                    }
                }
            });

            return string.joinv (this.separator, final_parts);
        }

        private void trigger_changed () {
            if (!is_updating) this.changed ();
        }
    }
}