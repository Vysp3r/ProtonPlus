namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    class LaunchOptionArgumentRow : Adw.EntryRow {
        public signal void value_applied ();
        public signal void remove_requested ();

        string committed_text;
        public int source_index { get; construct; }
        Gtk.Button apply_button;

        public LaunchOptionArgumentRow (string value = "", int source_index = -1) {
            Object (title: _("Argument"), source_index: source_index);
            committed_text = value;
            text = value;
            set_tooltip_text (_("One exact shell argument. Quotes and escapes are preserved."));

            apply_button = new Gtk.Button.from_icon_name ("object-select-symbolic") {
                valign = Gtk.Align.CENTER,
                css_classes = { "flat" }
            };
            apply_button.set_tooltip_text (_("Apply argument edit"));
            apply_button.clicked.connect (apply_pending_text);
            add_suffix (apply_button);

            var remove_button = new Gtk.Button.from_icon_name ("user-trash-symbolic") {
                valign = Gtk.Align.CENTER,
                css_classes = { "flat" }
            };
            remove_button.set_tooltip_text (_("Remove argument"));
            remove_button.clicked.connect (() => remove_requested ());
            add_suffix (remove_button);

            var keys = new Gtk.EventControllerKey ();
            keys.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            keys.key_pressed.connect ((keyval, keycode, state) => {
                if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                    apply_pending_text ();
                    return true;
                }
                return false;
            });
            add_controller (keys);
            activate.connect (apply_pending_text);
            changed.connect (refresh_apply_state);
            refresh_apply_state ();
        }

        public string get_committed_text () {
            return committed_text;
        }

        void apply_pending_text () {
            if (text == committed_text)
                return;
            committed_text = text;
            refresh_apply_state ();
            value_applied ();
        }

        void refresh_apply_state () {
            apply_button.sensitive = text != committed_text;
        }
    }

    public class LaunchOptionArgumentList : Adw.ExpanderRow, ILaunchOption {
        public new signal void changed ();

        public LaunchLineType line_type { get; set; default = LaunchLineType.ARGUMENT; }
        public bool is_advanced { get; set; default = true; }

        Gee.ArrayList<LaunchOptionArgumentRow> rows;
        Adw.ActionRow add_action_row;
        bool refreshing;
        string loaded_source = "";

        public LaunchOptionArgumentList (string title, string subtitle) {
            Object (title: title, subtitle: subtitle, expanded: false);
            set_tooltip_text (subtitle);
            rows = new Gee.ArrayList<LaunchOptionArgumentRow> ();

            add_action_row = new Adw.ActionRow () {
                title = _("Add custom argument"),
                subtitle = _("Add one argument per list entry.")
            };
            add_action_row.set_tooltip_text (add_action_row.subtitle);
            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic") {
                valign = Gtk.Align.CENTER,
                css_classes = { "flat" }
            };
            add_button.set_tooltip_text (add_action_row.title);
            add_button.clicked.connect (add_empty_argument);
            add_action_row.add_suffix (add_button);
            add_action_row.add_css_class ("property");
            add_action_row.visible = true;
            add_action_row_to_end ();
        }

        public void load_from_parse_result (LaunchCommandParseResult parsed) {
            refreshing = true;
            loaded_source = parsed.original_input;
            remove_all_rows ();
            var indexes = parsed.get_custom_game_argument_indexes ();
            foreach (var index in indexes)
                append_argument (parsed.tokens[index].raw, index);
            expanded = rows.size > 0;
            refreshing = false;
        }

        public string[] get_raw_arguments () {
            var values = new Gee.ArrayList<string> ();
            foreach (var row in rows) {
                var value = row.get_committed_text ();
                if (value != "")
                    values.add (value);
            }
            return values.to_array ();
        }

        public int[] get_source_indexes () {
            var indexes = new Gee.ArrayList<int> ();
            foreach (var row in rows) {
                if (row.get_committed_text () != "")
                    indexes.add (row.source_index);
            }
            return indexes.to_array ();
        }

        public string get_loaded_source () {
            return loaded_source;
        }

        public string? get_validation_diagnostic () {
            foreach (var value in get_raw_arguments ()) {
                var tokens = new LaunchOptionShellTokenizer ().tokenize (value);
                if (tokens.size != 1 || tokens[0].raw != value)
                    return _("Each custom game argument must be one complete shell argument.");
                if (value.contains ("%command%"))
                    return _("Custom game arguments cannot contain %command%.");
            }
            return null;
        }

        void add_empty_argument () {
            remove (add_action_row);
            var row = append_argument ("", -1);
            add_action_row_to_end ();
            expanded = true;
            row.grab_focus ();
        }

        LaunchOptionArgumentRow append_argument (string value, int source_index) {
            var row = new LaunchOptionArgumentRow (value, source_index);
            row.value_applied.connect (() => {
                if (row.get_committed_text () == "")
                    remove_argument (row);
                else if (!refreshing)
                    changed ();
            });
            row.remove_requested.connect (() => remove_argument (row));
            rows.add (row);
            add_row (row);
            return row;
        }

        void remove_argument (LaunchOptionArgumentRow row) {
            var had_value = row.get_committed_text () != "";
            remove (row);
            rows.remove (row);
            if (had_value && !refreshing)
                changed ();
        }

        void remove_all_rows () {
            foreach (var row in rows)
                remove (row);
            rows.clear ();
        }

        void add_action_row_to_end () {
            add_row (add_action_row);
        }

        public void add_child (ILaunchOption child) {}
        public void parse_tokens (string[] tokens, bool[] consumed) {}

        public void clear () {
            var had_arguments = is_active ();
            refreshing = true;
            remove_all_rows ();
            refreshing = false;
            if (had_arguments)
                changed ();
        }

        public void append_command_segments (Gee.LinkedList<string> segments) {
            foreach (var argument in get_raw_arguments ())
                segments.add (argument);
        }

        public bool is_active () {
            return get_raw_arguments ().length > 0;
        }
    }
}
