namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;

    class LaunchOptionResolutionField : Adw.ActionRow {
        public Gtk.Switch toggle { get; private set; }
        public Gtk.DropDown dropdown { get; private set; }
        public Gtk.Entry width_entry { get; private set; }
        public Gtk.Entry height_entry { get; private set; }
        public Gtk.Button apply_button { get; private set; }
        Gtk.Box custom_box;
        public signal void value_applied ();
        Gee.LinkedList<LaunchOptionResolutionChoice> choices;
        int committed_width;
        int committed_height;

        public LaunchOptionResolutionField (string title, string subtitle, bool include_auto = false) {
            committed_width = 3840;
            committed_height = 2160;

            choices = new Gee.LinkedList<LaunchOptionResolutionChoice> ();
            choices.add (new LaunchOptionResolutionChoice ("3840 x 2160", 3840, 2160));
            choices.add (new LaunchOptionResolutionChoice ("2560 x 1440", 2560, 1440));
            choices.add (new LaunchOptionResolutionChoice ("1920 x 1080", 1920, 1080));
            choices.add (new LaunchOptionResolutionChoice ("1600 x 900", 1600, 900));
            choices.add (new LaunchOptionResolutionChoice ("1280 x 720", 1280, 720));
            if (include_auto)
            choices.add (new LaunchOptionResolutionChoice (_ ("Auto detect"), 0, 0, true));
            choices.add (new LaunchOptionResolutionChoice (_ ("Custom"), 0, 0, false, true));

            var labels = new string[choices.size];
            for (var index = 0; index < choices.size; index++) {
                labels[index] = choices[index].label;
            }

            Gtk.PropertyExpression expression = new Gtk.PropertyExpression (typeof (Gtk.StringObject), null, "string");
            dropdown = new Gtk.DropDown (new Gtk.StringList (labels), expression);
            dropdown.set_valign (Gtk.Align.CENTER);

            toggle = new Gtk.Switch ();
            toggle.set_valign (Gtk.Align.CENTER);

            width_entry = new Gtk.Entry ();
            width_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
            width_entry.set_width_chars (5);
            width_entry.set_max_width_chars (5);
            width_entry.set_text (committed_width.to_string ());
            width_entry.activate.connect (apply_pending_resolution);

            var separator_label = new Gtk.Label ("x");
            separator_label.add_css_class ("dim-label");

            height_entry = new Gtk.Entry ();
            height_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
            height_entry.set_width_chars (5);
            height_entry.set_max_width_chars (5);
            height_entry.set_text (committed_height.to_string ());
            height_entry.activate.connect (apply_pending_resolution);

            apply_button = new Gtk.Button.with_label (_ ("Set"));
            apply_button.set_tooltip_text (_ ("Apply the custom resolution"));
            apply_button.clicked.connect (apply_pending_resolution);

            custom_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            custom_box.set_valign (Gtk.Align.CENTER);
            custom_box.append (width_entry);
            custom_box.append (separator_label);
            custom_box.append (height_entry);
            custom_box.append (apply_button);

            this.title = title;
            this.subtitle = subtitle;
            add_suffix (custom_box);
            add_suffix (dropdown);
            add_suffix (toggle);
            activatable_widget = toggle;

            toggle.notify["active"].connect (refresh_options_visibility);
            dropdown.notify["selected"].connect (refresh_custom_visibility);
            width_entry.changed.connect (refresh_custom_state);
            height_entry.changed.connect (refresh_custom_state);
            refresh_options_visibility ();
        }

        public void reset () {
            toggle.set_active (false);
            dropdown.set_selected (0);
            committed_width = 3840;
            committed_height = 2160;
            width_entry.set_text (committed_width.to_string ());
            height_entry.set_text (committed_height.to_string ());
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

                committed_width = width;
                committed_height = height;
                width_entry.set_text (committed_width.to_string ());
                height_entry.set_text (committed_height.to_string ());
                toggle.set_active (true);
                dropdown.set_selected ((uint) index);
                refresh_options_visibility ();
                return;
            }
        }

        public bool is_default () {
            return !toggle.get_active ();
        }

        public bool is_auto () {
            return toggle.get_active () && get_selected_choice ().is_auto;
        }

        public bool has_resolution () {
            if (!toggle.get_active ())
            return false;

            return get_selected_choice ().is_custom || get_selected_choice ().width > 0 || get_selected_choice ().height > 0;
        }

        public void get_resolution (out int width, out int height) {
            var selected_choice = get_selected_choice ();
            if (selected_choice.is_custom) {
                width = committed_width;
                height = committed_height;
            } else {
                width = selected_choice.width;
                height = selected_choice.height;
            }
        }

        LaunchOptionResolutionChoice get_selected_choice () {
            return choices[(int) dropdown.get_selected ()];
        }

        void refresh_options_visibility () {
            var is_active = toggle.get_active ();
            dropdown.set_visible (is_active);
            dropdown.set_sensitive (is_active);
            refresh_custom_visibility ();
        }

        void refresh_custom_visibility () {
            custom_box.set_visible (toggle.get_active () && get_selected_choice ().is_custom);
            refresh_custom_state ();
        }

        void apply_pending_resolution () {
            int pending_width;
            int pending_height;
            if (!get_pending_resolution (out pending_width, out pending_height))
            return;

            committed_width = pending_width;
            committed_height = pending_height;
            width_entry.set_text (committed_width.to_string ());
            height_entry.set_text (committed_height.to_string ());
            refresh_custom_state ();
            value_applied ();
        }

        bool get_pending_resolution (out int width, out int height) {
            width = committed_width;
            height = committed_height;

            var width_text = width_entry.get_text ().strip ();
            var height_text = height_entry.get_text ().strip ();
            if (width_text == "" || height_text == "")
            return false;

            if (!int.try_parse (width_text, out width) || !int.try_parse (height_text, out height))
            return false;

            return width >= 320 && width <= 7680 && height >= 240 && height <= 4320;
        }

        void refresh_custom_state () {
            var is_custom = toggle.get_active () && get_selected_choice ().is_custom;
            width_entry.set_sensitive (is_custom);
            height_entry.set_sensitive (is_custom);

            int pending_width;
            int pending_height;
            var has_pending_resolution = get_pending_resolution (out pending_width, out pending_height);
            apply_button.set_sensitive (is_custom && has_pending_resolution && (pending_width != committed_width || pending_height != committed_height));
        }
    }
}