using ProtonPlus.LaunchOptions;

namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    class LaunchOptionArgumentRow : Adw.EntryRow {
        public signal void remove_requested ();

        string original_text;
        public int source_index { get; construct; }
        public Gtk.Label validation_label { get; private set; }
        public Gtk.ListBoxRow validation_row { get; private set; }

        public LaunchOptionArgumentRow (string value = "", int source_index = -1) {
            Object (title: _("Argument"), source_index: source_index);
            original_text = value;
            text = value;
            Utils.TextInputMetadataPolicy.apply (this, Utils.TextInputFieldKind.COMMAND);
            set_tooltip_text (_("One exact shell argument. Quotes and escapes are preserved."));

            var remove_button = new Gtk.Button.from_icon_name ("user-trash-symbolic") {
                valign = Gtk.Align.CENTER,
                css_classes = { "flat" }
            };
            remove_button.set_tooltip_text (_("Remove argument"));
            remove_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Remove argument"), -1
            );
            remove_button.clicked.connect (() => remove_requested ());
            add_suffix (remove_button);

            validation_label = LaunchOptionInputFeedback.create_label ();
            validation_row = new Gtk.ListBoxRow () {
                child = validation_label,
                activatable = false,
                selectable = false,
                focusable = false,
                visible = false
            };
            changed.connect (refresh_validation);
        }

        public string? get_validation_diagnostic () {
            // Imported shell content can be left in place or removed.
            if (text == "" || (source_index >= 0 && text == original_text))
                return null;
            if (text.contains ("%command%"))
                return _("Remove %command% from this argument.");
            var tokens = new LaunchOptionShellTokenizer ().tokenize (text);
            if (tokens.size != 1 || tokens[0].raw != text || tokens[0].is_opaque)
                return _("Enter one complete argument. Use quotes around spaces and close all quotes.");
            return null;
        }

        void refresh_validation () {
            var diagnostic = get_validation_diagnostic ();
            LaunchOptionInputFeedback.update (this, validation_label, diagnostic);
            validation_row.visible = diagnostic != null;
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
            add_action_row.set_focusable (false);
            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic") {
                valign = Gtk.Align.CENTER,
                css_classes = { "flat" }
            };
            add_button.set_tooltip_text (add_action_row.title);
            add_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Add custom argument"), -1
            );
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
                var value = row.text;
                if (value != "")
                    values.add (value);
            }
            return values.to_array ();
        }

        public int[] get_source_indexes () {
            var indexes = new Gee.ArrayList<int> ();
            foreach (var row in rows) {
                if (row.text != "")
                    indexes.add (row.source_index);
            }
            return indexes.to_array ();
        }

        public string get_loaded_source () {
            return loaded_source;
        }

        public string? get_validation_diagnostic () {
            foreach (var row in rows) {
                var diagnostic = row.get_validation_diagnostic ();
                if (diagnostic != null)
                    return diagnostic;
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
            row.changed.connect (() => {
                if (!refreshing)
                    changed ();
            });
            row.remove_requested.connect (() => remove_argument (row));
            rows.add (row);
            add_row (row);
            add_row (row.validation_row);
            return row;
        }

        void remove_argument (LaunchOptionArgumentRow row) {
            var had_value = row.text != "";
            remove (row.validation_row);
            remove (row);
            rows.remove (row);
            if (had_value && !refreshing)
                changed ();
        }

        void remove_all_rows () {
            foreach (var row in rows) {
                remove (row.validation_row);
                remove (row);
            }
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
