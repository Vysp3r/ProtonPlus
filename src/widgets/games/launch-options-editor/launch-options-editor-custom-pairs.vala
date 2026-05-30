namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;
using Gtk;

    public class LaunchOptionCustomPairs : CustomExpanderRow, ILaunchOption {

        public string @value {
            owned get { return get_formatted_value (); }
            set { set_initial_value (value); }
        }

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
            base (switch_title, switch_subtitle, options_display, options_values, tooltips);

            this.separator = separator != null ? separator : ",";
            this.environment_variable = environment_variable;
            this.environment_variable_prefix = environment_variable != null ? environment_variable + "=" : null;
            this.is_updating = false;
            this.init_predefined_keys (predefined_keys);

        }

        private void set_initial_value (string raw_value) {
            if (is_updating) return;
            is_updating = true;

            if (this.separator == null) {
                this.separator = ",";
            }

            if (raw_value == null || raw_value == "") {
                this.enable_expansion = false;
                if (rows_map != null) {
                    foreach (var row in rows_map.get_values ()) {
                        if (row != null) {
                            row.selected = 0;
                        }
                    }
                }
                is_updating = false;
                return;
            }

            this.enable_expansion = true;

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
                        force_add_custom_row (key, val);
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

        private string get_formatted_value () {
            if (!this.enable_expansion) return "";

            string[] final_parts = {};
            bool is_flag_list = (options_values.length > 1 && options_values[1] == "1");
            if (rows_map != null) {
                foreach (string key in rows_map.get_keys ()) {
                    var combo_row = rows_map.lookup (key);
                    if (combo_row == null) continue;

                    uint selected = combo_row.selected;
                    string val = options_values[selected];
                    if (val != "") {
                        if (is_flag_list) {
                            final_parts += combo_row.title;
                        } else {
                            final_parts += @"$key=$val";
                        }
                    }
                }
            }

            return string.joinv (this.separator, final_parts);
        }

        protected override void trigger_changed_if_ready () {
            if (!is_updating) this.changed ();
        }

        public void parse_tokens(string[] tokens, bool[] consumed) {
            string raw = "";
            for (int i = 0; i < tokens.length; i++) {
                if (consumed[i]) {
                    continue;
                }

                if (tokens[i].has_prefix (this.environment_variable_prefix)) {
                    raw = tokens[i].substring (this.environment_variable_prefix.length);
                    consumed[i] = true;
                    break;
                }
            }

            this.value = raw;
        }

        public void clear () {
            this.value = "";
        }

        public virtual void append_command_segments (Gee.LinkedList<string> segments) {
            string val = this.value;
            if (val != "") {
                segments.add (this.environment_variable_prefix + val);
            }
        }
    }
}