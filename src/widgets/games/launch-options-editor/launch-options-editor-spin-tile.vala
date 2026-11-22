namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;

    class LaunchOptionSpinTile : ActionRow, ILaunchOption {
        public Gtk.Switch toggle { get; private set; }
        public Gtk.Entry value_entry { get; private set; }
        Gtk.Box value_box;
        public signal void draft_changed ();

        int lower_value;
        int upper_value;
        int default_value;
        public bool is_advanced { get; set; default = false; }
        public LaunchLineType line_type { get; set; }
        private Gee.List<ILaunchOption> _children;
        private string env_prefix;

        public LaunchOptionSpinTile (string title, string subtitle, string value_label, double lower, double upper, int default_value, string env_prefix) {
            Object (title: title, subtitle: subtitle);
            this._children = new Gee.ArrayList<ILaunchOption> ();
            this.env_prefix = env_prefix;
            subtitle_lines = 0;
            this.set_tooltip_text (subtitle);

            lower_value = (int) lower;
            upper_value = (int) upper;
            this.default_value = default_value;

            value_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            value_box.set_valign (Gtk.Align.CENTER);

            var value_caption = new Gtk.Label (value_label);
            value_caption.set_xalign (0);
            value_caption.add_css_class ("dim-label");

            value_entry = new Gtk.Entry ();
            Utils.TextInputMetadataPolicy.apply (value_entry, Utils.TextInputFieldKind.DIGITS);
            value_entry.set_width_chars (5);
            value_entry.set_max_width_chars (5);
            value_entry.set_halign (Gtk.Align.START);
            value_entry.set_text (default_value.to_string ());
            value_entry.set_tooltip_text (subtitle);

            value_box.append (value_caption);
            value_box.append (value_entry);

            toggle = new Gtk.Switch ();
            toggle.set_valign (Gtk.Align.CENTER);
            toggle.set_tooltip_text (subtitle);

            add_suffix (value_box);
            add_suffix (toggle);
            activatable_widget = toggle;

            value_entry.changed.connect (value_changed);
            toggle.notify["active"].connect (value_changed);
            refresh_value_state ();
        }

        public void set_value (int value) {
            value_entry.set_text (value.to_string ());
        }

        public bool try_get_value (out int value) {
            return int.try_parse (value_entry.text.strip (), out value)
                && value >= lower_value && value <= upper_value;
        }

        public string? get_validation_diagnostic () {
            int value = 0;
            return is_active () && !try_get_value (out value)
                ? _("Enter a whole number from %d to %d.").printf (lower_value, upper_value)
                : null;
        }

        void value_changed () {
            refresh_value_state ();
            draft_changed ();
        }

        void refresh_value_state () {
            value_box.visible = is_active ();
            var diagnostic = get_validation_diagnostic ();
            if (diagnostic == null)
                value_entry.remove_css_class ("error");
            else
                value_entry.add_css_class ("error");
            value_entry.update_property (Gtk.AccessibleProperty.DESCRIPTION, diagnostic ?? "", -1);
        }

        public void clear () {
            this.toggle.set_active (false);
            this.set_value (this.default_value);

            foreach (var child in this._children) {
                child.clear ();
            }
        }

        public bool is_active () {
            return this.toggle.get_active ();
        }

        public void parse_tokens (string[] tokens, bool[] consumed) {
            for (int i = 0; i < tokens.length; i++) {
                if (consumed[i])
                    continue;

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
            int value = 0;
            if (is_active () && try_get_value (out value)) {
                segments.add ("%s%d".printf (this.env_prefix, value));

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
