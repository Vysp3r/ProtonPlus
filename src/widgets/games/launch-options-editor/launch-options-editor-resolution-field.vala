using ProtonPlus.LaunchOptions;

namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;

    class LaunchOptionResolutionField : Adw.ActionRow, ILaunchOption {
        public Gtk.Switch toggle { get; private set; }
        public Gtk.DropDown dropdown { get; private set; }
        public Gtk.Entry width_entry { get; private set; }
        public Gtk.Entry height_entry { get; private set; }
        Gtk.Box custom_box;

        Gee.LinkedList<LaunchOptionResolutionChoice> choices;
        const int MIN_WIDTH = 320;
        const int MAX_WIDTH = 7680;
        const int MIN_HEIGHT = 240;
        const int MAX_HEIGHT = 4320;
        const int DEFAULT_WIDTH = 3840;
        const int DEFAULT_HEIGHT = 2160;

        public bool is_advanced { get; set; default = false; }
        public LaunchLineType line_type { get; set; }
        private Gee.List<ILaunchOption> _children;
        private bool is_scopebuddy;
        public signal void draft_changed ();

        public LaunchOptionResolutionField (string title, string subtitle, bool include_auto = false, bool is_scopebuddy = false) {
            this.is_scopebuddy = is_scopebuddy;
            this._children = new Gee.ArrayList<ILaunchOption> ();

            choices = new Gee.LinkedList<LaunchOptionResolutionChoice> ();
            choices.add (new LaunchOptionResolutionChoice ("3840 x 2160", 3840, 2160));
            choices.add (new LaunchOptionResolutionChoice ("2560 x 1440", 2560, 1440));
            choices.add (new LaunchOptionResolutionChoice ("1920 x 1080", 1920, 1080));
            choices.add (new LaunchOptionResolutionChoice ("1600 x 900", 1600, 900));
            choices.add (new LaunchOptionResolutionChoice ("1280 x 720", 1280, 720));
            if (include_auto)
                choices.add (new LaunchOptionResolutionChoice (_("Auto detect"), 0, 0, true));
            choices.add (new LaunchOptionResolutionChoice (_("Custom"), 0, 0, false, true));

            var labels = new string[choices.size];
            for (var index = 0; index < choices.size; index++) {
                labels[index] = choices[index].label;
            }

            Gtk.PropertyExpression expression = new Gtk.PropertyExpression (typeof (Gtk.StringObject), null, "string");
            dropdown = new Gtk.DropDown (new Gtk.StringList (labels), expression);
            dropdown.set_valign (Gtk.Align.CENTER);
            dropdown.set_tooltip_text (subtitle);

            toggle = new Gtk.Switch ();
            toggle.set_valign (Gtk.Align.CENTER);
            toggle.set_tooltip_text (subtitle);

            width_entry = new Gtk.Entry ();
            Utils.TextInputMetadataPolicy.apply (width_entry, Utils.TextInputFieldKind.DIGITS);
            width_entry.set_width_chars (5);
            width_entry.set_max_width_chars (5);
            width_entry.set_text (DEFAULT_WIDTH.to_string ());
            width_entry.set_tooltip_text (_("Width"));
            width_entry.update_property (Gtk.AccessibleProperty.LABEL, _("Width"), -1);

            var separator_label = new Gtk.Label ("x");
            separator_label.add_css_class ("dim-label");

            height_entry = new Gtk.Entry ();
            Utils.TextInputMetadataPolicy.apply (height_entry, Utils.TextInputFieldKind.DIGITS);
            height_entry.set_width_chars (5);
            height_entry.set_max_width_chars (5);
            height_entry.set_text (DEFAULT_HEIGHT.to_string ());
            height_entry.set_tooltip_text (_("Height"));
            height_entry.update_property (Gtk.AccessibleProperty.LABEL, _("Height"), -1);

            custom_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            custom_box.set_valign (Gtk.Align.CENTER);
            custom_box.append (width_entry);
            custom_box.append (separator_label);
            custom_box.append (height_entry);

            this.title = title;
            this.subtitle = subtitle;
            this.set_tooltip_text (subtitle);
            add_suffix (custom_box);
            add_suffix (dropdown);
            add_suffix (toggle);
            activatable_widget = toggle;

            toggle.notify["active"].connect (value_changed);
            dropdown.notify["selected"].connect (value_changed);
            width_entry.changed.connect (value_changed);
            height_entry.changed.connect (value_changed);

            refresh_options_visibility ();
        }

        public void add_child (ILaunchOption child) {
            this._children.add (child);
        }

        public void clear () {
            this.reset ();

            foreach (var child in this._children) {
                child.clear ();
            }
        }

        public void parse_tokens (string[] tokens, bool[] consumed) {
            if (tokens.length != consumed.length) {
                return;
            }

            if (this.is_scopebuddy) {
                for (int i = 0; i < tokens.length; i++) {
                    if (consumed[i])
                        continue;
                    if (tokens[i] == "SCB_AUTO_RES=1") {
                        this.set_auto ();
                        consumed[i] = true;
                        return;
                    }
                }
            }

            for (int i = 0; i < tokens.length; i++) {
                if (consumed[i])
                    continue;

                if (tokens[i] == "-W" && i + 3 < tokens.length && tokens[i + 2] == "-H") {
                    int width = 0;
                    int height = 0;
                    if (int.try_parse (tokens[i + 1], out width) && int.try_parse (tokens[i + 3], out height)) {
                        this.set_resolution (width, height);
                        consumed[i] = true;
                        consumed[i + 1] = true;
                        consumed[i + 2] = true;
                        consumed[i + 3] = true;
                        break;
                    }
                }
            }

            foreach (var child in this._children) {
                child.parse_tokens (tokens, consumed);
            }
        }

        public void append_command_segments (Gee.LinkedList<string> segments) {
            if (!toggle.get_active ()) {
                return;
            }

            if (this.is_scopebuddy && this.is_auto ()) {
                segments.add ("SCB_AUTO_RES=1");
                return;
            }

            int width, height;
            if (try_get_resolution (out width, out height)) {
                segments.add ("-W %d".printf (width));
                segments.add ("-H %d".printf (height));
            }

            foreach (var child in this._children) {
                if (child.is_active ()) {
                    child.append_command_segments (segments);
                }
            }
        }

        public void reset () {
            toggle.set_active (false);
            dropdown.set_selected (0);
            width_entry.set_text (DEFAULT_WIDTH.to_string ());
            height_entry.set_text (DEFAULT_HEIGHT.to_string ());
            refresh_options_visibility ();
        }

        public void set_auto () {
            for (var index = 0; index < choices.size; index++) {
                if (choices[index].is_auto) {
                    toggle.set_active (true);
                    dropdown.set_selected ((uint) index);
                    refresh_options_visibility ();
                    return;
                }
            }
        }

        public void set_resolution (int width, int height) {
            for (var index = 0; index < choices.size; index++) {
                if (choices[index].width == width && choices[index].height == height && !choices[index].is_custom) {
                    toggle.set_active (true);
                    dropdown.set_selected ((uint) index);
                    refresh_options_visibility ();
                    return;
                }
            }

            for (var index = 0; index < choices.size; index++) {
                if (!choices[index].is_custom)
                    continue;

                width_entry.set_text (width.to_string ());
                height_entry.set_text (height.to_string ());
                toggle.set_active (true);
                dropdown.set_selected ((uint) index);
                refresh_options_visibility ();
                return;
            }
        }

        public bool is_auto () {
            return toggle.get_active () && get_selected_choice ().is_auto;
        }

        public bool try_get_resolution (out int width, out int height) {
            var choice = get_selected_choice ();
            if (!choice.is_custom) {
                width = choice.width;
                height = choice.height;
                return is_active () && !choice.is_auto;
            }

            var valid_width = try_get_dimension (width_entry, MIN_WIDTH, MAX_WIDTH, out width);
            var valid_height = try_get_dimension (height_entry, MIN_HEIGHT, MAX_HEIGHT, out height);
            return is_active () && valid_width && valid_height;
        }

        public string? get_validation_diagnostic () {
            if (!is_active () || !get_selected_choice ().is_custom)
                return null;

            int width, height;
            var valid_width = try_get_dimension (width_entry, MIN_WIDTH, MAX_WIDTH, out width);
            var valid_height = try_get_dimension (height_entry, MIN_HEIGHT, MAX_HEIGHT, out height);
            if (!valid_width && !valid_height)
                return _("Enter a width from %d to %d and a height from %d to %d.").printf (
                    MIN_WIDTH, MAX_WIDTH, MIN_HEIGHT, MAX_HEIGHT);
            if (!valid_width)
                return _("Enter a whole number from %d to %d for width.").printf (MIN_WIDTH, MAX_WIDTH);
            if (!valid_height)
                return _("Enter a whole number from %d to %d for height.").printf (MIN_HEIGHT, MAX_HEIGHT);
            return null;
        }

        LaunchOptionResolutionChoice get_selected_choice () {
            return choices[(int) dropdown.get_selected ()];
        }

        static bool try_get_dimension (Gtk.Entry entry, int lower, int upper, out int dimension) {
            return int.try_parse (entry.text.strip (), out dimension) && dimension >= lower && dimension <= upper;
        }

        void value_changed () {
            refresh_options_visibility ();
            draft_changed ();
        }

        void refresh_options_visibility () {
            var active = is_active ();
            dropdown.visible = active;
            var custom = active && get_selected_choice ().is_custom;
            custom_box.visible = custom;
            int width, height;
            update_dimension_style (width_entry, custom && !try_get_dimension (width_entry, MIN_WIDTH, MAX_WIDTH, out width));
            update_dimension_style (height_entry, custom && !try_get_dimension (height_entry, MIN_HEIGHT, MAX_HEIGHT, out height));
        }

        static void update_dimension_style (Gtk.Entry entry, bool invalid) {
            if (invalid)
                entry.add_css_class ("error");
            else
                entry.remove_css_class ("error");
        }

        public bool is_active () {
            return this.toggle.get_active ();
        }
    }
}
