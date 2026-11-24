namespace ProtonPlus.Utils {
    public enum TextInputFieldKind {
        SEARCH,
        FREE_FORM,
        NUMERIC,
        DIGITS,
        URL,
        SECRET,
        COMMAND,
        PATH_OR_IDENTIFIER
    }

    public class TextInputMetadata : Object {
        public Gtk.InputPurpose purpose { get; private set; }
        public Gtk.InputHints hints { get; private set; }

        public TextInputMetadata (Gtk.InputPurpose purpose, Gtk.InputHints hints) {
            this.purpose = purpose;
            this.hints = hints;
        }

        public bool has_hint (Gtk.InputHints hint) {
            return (hints & hint) != 0;
        }
    }

    /* Semantic metadata only. Applying a policy never reads or writes the
     * field's text, cursor, selection, validation, or persistence state. */
    public class TextInputMetadataPolicy : Object {
        public static TextInputMetadata for_kind (TextInputFieldKind kind) {
            switch (kind) {
            case SEARCH:
                return new TextInputMetadata (
                    Gtk.InputPurpose.FREE_FORM,
                    Gtk.InputHints.NO_SPELLCHECK | Gtk.InputHints.NO_EMOJI
                );
            case FREE_FORM:
                return new TextInputMetadata (
                    Gtk.InputPurpose.FREE_FORM,
                    Gtk.InputHints.NONE
                );
            case NUMERIC:
                return new TextInputMetadata (
                    Gtk.InputPurpose.NUMBER,
                    Gtk.InputHints.NONE
                );
            case DIGITS:
                return new TextInputMetadata (
                    Gtk.InputPurpose.DIGITS,
                    Gtk.InputHints.NONE
                );
            case URL:
                return exact_metadata (Gtk.InputPurpose.URL, false);
            case SECRET:
                return exact_metadata (Gtk.InputPurpose.PASSWORD, true);
            case COMMAND:
                return exact_metadata (Gtk.InputPurpose.TERMINAL, false);
            case PATH_OR_IDENTIFIER:
                return exact_metadata (Gtk.InputPurpose.TERMINAL, false);
            default:
                assert_not_reached ();
            }
        }

        public static void apply (Gtk.Widget widget, TextInputFieldKind kind) {
            var metadata = for_kind (kind);
            if (widget is Adw.EntryRow) {
                var entry_row = (Adw.EntryRow) widget;
                entry_row.set_input_purpose (metadata.purpose);
                entry_row.set_input_hints (metadata.hints);
                if (metadata.has_hint (Gtk.InputHints.NO_EMOJI))
                    entry_row.set_enable_emoji_completion (false);
            } else if (widget is Gtk.SearchEntry) {
                var search_entry = (Gtk.SearchEntry) widget;
                search_entry.set_input_purpose (metadata.purpose);
                search_entry.set_input_hints (metadata.hints);
            } else if (widget is Gtk.Entry) {
                var entry = (Gtk.Entry) widget;
                entry.set_input_purpose (metadata.purpose);
                entry.set_input_hints (metadata.hints);
                if (metadata.has_hint (Gtk.InputHints.NO_EMOJI))
                    entry.enable_emoji_completion = false;
            } else if (widget is Gtk.TextView) {
                var text_view = (Gtk.TextView) widget;
                text_view.set_input_purpose (metadata.purpose);
                text_view.set_input_hints (metadata.hints);
            }
        }

        static TextInputMetadata exact_metadata (Gtk.InputPurpose purpose, bool is_private) {
            var hints = Gtk.InputHints.NO_SPELLCHECK | Gtk.InputHints.NO_EMOJI;
            if (is_private)
                hints |= Gtk.InputHints.PRIVATE;
            return new TextInputMetadata (purpose, hints);
        }
    }

    public enum ControllerActivationDecision {
        ACTIVATE,
        FOCUS_TEXT_INPUT
    }

    public class ControllerActivationPolicy : Object {
        public static ControllerActivationDecision for_focused_control (
            bool has_effective_editable) {
            return has_effective_editable
                ? ControllerActivationDecision.FOCUS_TEXT_INPUT
                : ControllerActivationDecision.ACTIVATE;
        }
    }

    /* Resolve the public editable represented by the focused widget. The
     * first focusable non-editable target is a boundary, which keeps suffix
     * buttons inside entry rows on the ordinary activation path. */
    public class ControllerEditableTargetResolver : Object {
        public static bool accepts_edits (bool is_text_control, bool editable,
            bool sensitive) {
            return is_text_control && editable && sensitive;
        }

        public static Gtk.Widget? resolve (Gtk.Widget? focused, Gtk.Widget root) {
            Gtk.Widget? current = focused;
            Gtk.Widget? delegate_candidate = null;
            while (current != null) {
                bool is_editable = current is Gtk.Editable;
                bool is_text_view = current is Gtk.TextView;
                if (is_editable || is_text_view) {
                    bool editable = is_editable
                        ? ((Gtk.Editable) current).get_editable ()
                        : ((Gtk.TextView) current).get_editable ();
                    if (!accepts_edits (true, editable, current.is_sensitive ()))
                        return null;

                    if (current is Adw.EntryRow || current is Gtk.Entry ||
                        current is Gtk.SearchEntry || current is Gtk.TextView)
                        return current;
                    if (delegate_candidate == null)
                        delegate_candidate = current;
                } else if (delegate_candidate == null && current.get_focusable ()) {
                    return null;
                }

                if (current == root)
                    break;
                current = current.get_parent ();
            }
            return delegate_candidate;
        }
    }
}
