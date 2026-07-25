using Gee;

namespace ProtonPlus.Utils.VDF {

    /**
     * A parsed VDF key/value entry.  Source positions refer to the original
     * document, which lets callers make small edits without serializing the
     * whole file again.
     */
    public class VdfEntry : GLib.Object {
        public string key { get; private set; }
        public string? value { get; private set; }
        public Gee.ArrayList<VdfEntry> children { get; private set; }
        public int start { get; private set; }
        public int end { get; private set; }
        public int value_start { get; private set; }
        public int value_end { get; private set; }
        public int key_start { get; private set; }
        public int key_end { get; private set; }
        public int closing_brace_start { get; private set; }

        public VdfEntry (string key, int start) {
            this.key = key;
            this.start = start;
            this.end = start;
            this.value_start = -1;
            this.value_end = -1;
            this.key_start = -1;
            this.key_end = -1;
            this.closing_brace_start = -1;
            this.children = new Gee.ArrayList<VdfEntry> ();
        }

        public VdfEntry? get_child (string child_key) {
            foreach (var child in children) {
                if (child.key == child_key) {
                    return child;
                }
            }

            return null;
        }

        internal void set_value_range (string value, int start, int end) {
            this.value = value;
            this.value_start = start;
            this.value_end = end;
            this.end = end;
        }

        internal void set_key_range (int start, int end) {
            this.key_start = start;
            this.key_end = end;
        }

        internal void set_block_end (int closing_brace_start, int end) {
            this.closing_brace_start = closing_brace_start;
            this.end = end;
        }
    }

    public class VdfDocument : GLib.Object {
        public string content { get; private set; }
        public VdfEntry root { get; private set; }

        public VdfDocument (string content, VdfEntry root) {
            this.content = content;
            this.root = root;
        }

        public string replace_value (VdfEntry entry, string value) {
            return content.substring (0, entry.value_start)
                + quote (value)
                + content.substring (entry.value_end);
        }

        public string replace_key (VdfEntry entry, string key) {
            return content.substring (0, entry.key_start)
                + quote (key)
                + content.substring (entry.key_end);
        }

        public string remove_entry (VdfEntry entry) {
            var start = line_start (entry.start);
            var end = entry.end;

            if (end < content.length && content.get_char (end) == '\n') {
                end++;
            }

            return content.substring (0, start) + content.substring (end);
        }

        public string insert_before_closing_brace (VdfEntry entry, string text) {
            var position = line_start (entry.closing_brace_start);
            return content.substring (0, position) + text + content.substring (position);
        }

        public string indentation_of_closing_brace (VdfEntry entry) {
            var line_start = line_start (entry.closing_brace_start);
            return content.substring (line_start, entry.closing_brace_start - line_start);
        }

        private int line_start (int position) {
            var previous_newline = content.substring (0, position).last_index_of ("\n");
            return previous_newline == -1 ? 0 : previous_newline + 1;
        }

        public static string quote (string value) {
            return "\"%s\"".printf (value
                .replace ("\\", "\\\\")
                .replace ("\"", "\\\"")
                .replace ("\n", "\\n")
                .replace ("\r", "\\r")
                .replace ("\t", "\\t"));
        }
    }

    public class VdfParser : GLib.Object {

        public static VdfDocument? parse_document (string vdf_content) {
            var parser = new DocumentParser (vdf_content);
            return parser.parse ();
        }

        private class DocumentParser : GLib.Object {
            private string content;
            private int position = 0;

            public DocumentParser (string content) {
                this.content = content;
            }

            public VdfDocument? parse () {
                var root = new VdfEntry ("", 0);

                if (!parse_entries (root, false)) {
                    return null;
                }

                skip_ignored ();
                if (position != content.length) {
                    return null;
                }

                root.set_block_end (content.length, content.length);
                return new VdfDocument (content, root);
            }

            private bool parse_entries (VdfEntry parent, bool expect_closing_brace) {
                while (true) {
                    skip_ignored ();

                    if (position >= content.length) {
                        return !expect_closing_brace;
                    }

                    if (content.get_char (position) == '}') {
                        if (!expect_closing_brace) {
                            return false;
                        }

                        var closing_brace_start = position;
                        advance ();
                        parent.set_block_end (closing_brace_start, position);
                        return true;
                    }

                    var entry_start = position;
                    string key;
                    int key_start;
                    int key_end;
                    if (!read_quoted (out key, out key_start, out key_end)) {
                        return false;
                    }

                    skip_ignored ();
                    if (position >= content.length) {
                        return false;
                    }

                    var entry = new VdfEntry (key, entry_start);
                    entry.set_key_range (key_start, key_end);
                    if (content.get_char (position) == '{') {
                        advance ();
                        if (!parse_entries (entry, true)) {
                            return false;
                        }
                    } else {
                        string value;
                        int value_start;
                        int value_end;
                        if (!read_quoted (out value, out value_start, out value_end)) {
                            return false;
                        }

                        entry.set_value_range (value, value_start, value_end);
                    }

                    parent.children.add (entry);
                }
            }

            private bool read_quoted (out string value, out int start, out int end) {
                value = "";
                start = -1;
                end = -1;

                if (position >= content.length || content.get_char (position) != '"') {
                    return false;
                }

                start = position;
                advance ();
                var builder = new StringBuilder ();
                var escaped = false;

                while (position < content.length) {
                    var character = content.get_char (position);
                    advance ();
                    if (escaped) {
                        switch (character) {
                            case 'n': builder.append_c ('\n'); break;
                            case 'r': builder.append_c ('\r'); break;
                            case 't': builder.append_c ('\t'); break;
                            default: builder.append_unichar (character); break;
                        }
                        escaped = false;
                    } else if (character == '\\') {
                        escaped = true;
                    } else if (character == '"') {
                        end = position;
                        value = builder.str;
                        return true;
                    } else {
                        builder.append_unichar (character);
                    }
                }

                return false;
            }

            private void skip_ignored () {
                while (position < content.length) {
                    var character = content.get_char (position);
                    if (character == ' ' || character == '\t' || character == '\r' || character == '\n') {
                        advance ();
                    } else if (character == '/' && position + 1 < content.length && content.get_char (position + 1) == '/') {
                        position += 2;
                        while (position < content.length && content.get_char (position) != '\n') {
                            advance ();
                        }
                    } else {
                        return;
                    }
                }
            }

            private void advance () {
                position += content.get_char (position).to_string ().length;
            }
        }
    }
}
