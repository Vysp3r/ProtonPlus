namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;

    class LaunchOptionSpinTile : ActionRow, ILaunchOption {
        public Gtk.Switch toggle { get; private set; }
        public Gtk.Entry value_entry { get; private set; }
        public Gtk.Button apply_button { get; private set; }
        Gtk.Box value_box;
        public signal void value_applied ();

        int lower_value;
        int upper_value;
        int committed_value;
        public bool is_advanced { get; set; default = false; }
        public LaunchLineType line_type { get; set; }
        private Gee.List<ILaunchOption> _children;
        private string env_prefix;

        public LaunchOptionSpinTile (string title, string subtitle, string value_label, double lower, double upper, int default_value, string env_prefix) {
            Object (title: title, subtitle: subtitle);
            this._children = new Gee.ArrayList<ILaunchOption> ();
            this.env_prefix = env_prefix;
            subtitle_lines = 0;

            lower_value = (int) lower;
            upper_value = (int) upper;
            committed_value = default_value;

            value_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            value_box.set_valign (Gtk.Align.CENTER);

            var value_caption = new Gtk.Label (value_label);
            value_caption.set_xalign (0);
            value_caption.add_css_class ("dim-label");

            value_entry = new Gtk.Entry ();
            value_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
            value_entry.set_width_chars (5);
            value_entry.set_max_width_chars (5);
            value_entry.set_halign (Gtk.Align.START);
            value_entry.set_text (default_value.to_string ());
            value_entry.activate.connect (apply_pending_value);

            apply_button = new Gtk.Button.with_label (_("Set"));
            apply_button.set_tooltip_text (_("Apply the FPS value"));
            apply_button.clicked.connect (apply_pending_value);

            value_box.append (value_caption);
            value_box.append (value_entry);
            value_box.append (apply_button);

            toggle = new Gtk.Switch ();
            toggle.set_valign (Gtk.Align.CENTER);

            add_suffix (value_box);
            add_suffix (toggle);
            activatable_widget = toggle;

            value_entry.changed.connect (refresh_value_state);
            toggle.notify["active"].connect (refresh_value_state);
            refresh_value_state ();
        }

        public int get_value_as_int () {
            return committed_value;
        }

        public void set_value (int value) {
            committed_value = int.max (lower_value, int.min (upper_value, value));
            value_entry.set_text (committed_value.to_string ());
            refresh_value_state ();
        }

        void apply_pending_value () {
            int pending_value;
            if (!get_pending_value (out pending_value))
                return;

            committed_value = pending_value;
            value_entry.set_text (committed_value.to_string ());
            refresh_value_state ();
            value_applied ();
        }

        bool get_pending_value (out int value) {
            value = committed_value;

            var text = value_entry.get_text ().strip ();
            if (text == "")
                return false;

            int parsed_value;
            if (!int.try_parse (text, out parsed_value))
                return false;

            if (parsed_value < lower_value || parsed_value > upper_value)
                return false;

            value = parsed_value;
            return true;
        }

        void refresh_value_state () {
            var is_active = toggle.get_active ();
            value_box.set_visible (is_active);
            value_entry.set_sensitive (is_active);

            int pending_value;
            var has_pending_value = get_pending_value (out pending_value);
            apply_button.set_sensitive (is_active && has_pending_value && pending_value != committed_value);
        }

        public void clear () {
            this.toggle.set_active (false);
            this.set_value (this.committed_value);

            foreach (var child in this._children) {
                child.clear ();
            }
        }

        public bool is_active () {
            return this.toggle.get_active ();
        }

        public void parse_tokens (string[] tokens, bool[] consumed) {
            for (int i = 0; i < tokens.length; i++) {
                if (consumed[i])continue;

                if (tokens[i].has_prefix (this.env_prefix)) {
                    string val_str = tokens[i].replace (this.env_prefix, "");
                    int val_int;
                    if (int.try_parse (val_str, out val_int)) {
                        this.toggle.set_active (true);
                        this.set_value (val_int);
                        consumed[i] = true;
                        break;
                    }
                }
            }
            foreach (var child in this._children) {
                child.parse_tokens (tokens, consumed);
            }
        }

        public void append_command_segments (Gee.LinkedList<string> segments) {
            if (this.toggle.get_active ()) {
                segments.add ("%s%d".printf (this.env_prefix, this.get_value_as_int ()));

                foreach (var child in this._children) {
                    if (child.is_active ()) {
                        child.append_command_segments (segments);
                    }
                }
            }
        }

        public void add_child (ILaunchOption child) {
            this._children.add (child);
        }
    }
}