using ProtonPlus.LaunchOptions;

namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    class LaunchOptionInputFeedback {
        public static Gtk.Label create_label () {
            return new Gtk.Label ("") {
                xalign = 0,
                wrap = true,
                margin_start = 12,
                margin_end = 12,
                margin_top = 6,
                margin_bottom = 6,
                css_classes = { "error" },
                visible = false
            };
        }

        public static void update (Gtk.Widget field, Gtk.Label label, string? diagnostic) {
            label.label = diagnostic ?? "";
            label.visible = field.visible && diagnostic != null;
            if (diagnostic == null)
                field.remove_css_class ("error");
            else
                field.add_css_class ("error");
            field.update_property (Gtk.AccessibleProperty.DESCRIPTION, diagnostic ?? "", -1);
        }
    }

    class LaunchOptionEntryField : Adw.EntryRow {
        public Gtk.Label validation_label { get; private set; }

        public LaunchOptionEntryField (string title, string subtitle, string placeholder) {
            Object (title: title);
            tooltip_text = subtitle != "" ? subtitle : placeholder;
            Utils.TextInputMetadataPolicy.apply (this, Utils.TextInputFieldKind.COMMAND);
            validation_label = LaunchOptionInputFeedback.create_label ();
            changed.connect (refresh_validation);
            notify["visible"].connect (refresh_validation);
        }

        public string? read_arguments (out string[] arguments) {
            arguments = {};
            var values = new Gee.ArrayList<string> ();
            var words = new LaunchOptionShellTokenizer ().tokenize (text.strip ());
            foreach (var word in words) {
                if (word.raw.contains ("%command%"))
                    return _("Remove %command% from the additional arguments.");
                if (word.is_opaque)
                    return _("Use complete arguments with matching quotes and no shell operators or expansions.");
                values.add (word.raw);
            }
            arguments = values.to_array ();
            return null;
        }

        void refresh_validation () {
            string[] arguments;
            LaunchOptionInputFeedback.update (this, validation_label, read_arguments (out arguments));
        }
    }

    class LaunchCustomWrapperField : Adw.EntryRow, ILaunchOption, ILaunchCommandSelectionSource {
        public LaunchLineType line_type { get; set; default = LaunchLineType.WRAPPER; }
        public bool is_advanced { get; set; }
        public string option_id { get; set; default = LaunchCustomWrapperInput.OPTION_ID; }

        public LaunchCustomWrapperField (LaunchOptionMetadata metadata) {
            Object (title: metadata.title);
            Utils.TextInputMetadataPolicy.apply (this, Utils.TextInputFieldKind.COMMAND);
            var description = metadata.description;
            tooltip_text = description;
            changed.connect (() => {
                var diagnostic = get_diagnostic ();
                if (diagnostic == null)
                    remove_css_class ("error");
                else
                    add_css_class ("error");
                tooltip_text = diagnostic ?? description;
                update_property (Gtk.AccessibleProperty.DESCRIPTION, tooltip_text, -1);
            });
        }

        public void load_from_parse_result (LaunchCommandParseResult parsed) {
            var index = parsed.custom_wrapper_index;
            text = index >= 0 ? parsed.tokens[index].raw : "";
        }

        public LaunchCommandSelection? get_selection () {
            string executable;
            var diagnostic = LaunchCustomWrapperInput.read (text, out executable);
            return diagnostic == null && executable != ""
                ? new LaunchCommandSelection (option_id, { executable }, "", {}, true) : null;
        }

        public string? get_diagnostic () {
            string executable;
            return LaunchCustomWrapperInput.read (text, out executable);
        }

        public string get_invalid_value () { return text; }
        public bool is_active () { return text.strip () != ""; }
        public void clear () { text = ""; }
        public void add_child (ILaunchOption child) {}
        public void parse_tokens (string[] tokens, bool[] consumed) {}
        public void append_command_segments (Gee.LinkedList<string> segments) {}
    }
}
