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
}
