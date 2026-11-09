namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    /*
     * A launch option word has two representations.  `value` is used for
     * matching the controls, while `raw` is the text Steam will receive.  Do
     * not derive the latter from the former: quoting and escaping are part of
     * the command's meaning.
     */
    public class LaunchOptionShellToken : Object {
        public string raw { get; construct; }
        public string value { get; construct; }
        public bool is_opaque { get; construct; }

        public LaunchOptionShellToken (string raw, string value, bool is_opaque = false) {
            Object (raw: raw, value: value, is_opaque: is_opaque);
        }
    }

    /*
     * This deliberately handles shell *words*, not shell evaluation.  Shell
     * operators, expansions and malformed quoted words cannot safely be
     * interpreted by the editor, so they are retained as opaque raw spans.
     */
    public class LaunchOptionShellTokenizer : Object {
        public Gee.ArrayList<LaunchOptionShellToken> tokenize (string input) {
            var tokens = new Gee.ArrayList<LaunchOptionShellToken> ();
            var index = 0;

            while (index < input.length) {
                while (index < input.length && is_whitespace (input[index]))
                    index++;

                if (index >= input.length)
                    break;

                var start = index;
                var value = new StringBuilder ();
                var opaque = false;

                if (input[index] == '#') {
                    // A comment consumes the rest of a shell command line.
                    tokens.add (new LaunchOptionShellToken (input.substring (start), "", true));
                    break;
                }

                while (index < input.length && !is_whitespace (input[index])) {
                    char character = input[index];

                    if (character == '\'') {
                        index++;
                        while (index < input.length && input[index] != '\'') {
                            value.append_c (input[index]);
                            index++;
                        }
                        if (index >= input.length) {
                            opaque = true;
                            break;
                        }
                        index++;
                        continue;
                    }

                    if (character == '"') {
                        index++;
                        var closed = false;
                        while (index < input.length) {
                            character = input[index];
                            if (character == '"') {
                                index++;
                                closed = true;
                                break;
                            }
                            if (character == '$' || character == '`')
                                opaque = true;
                            if (character == '\\') {
                                index++;
                                if (index >= input.length) {
                                    opaque = true;
                                    break;
                                }
                                char escaped = input[index];
                                if (escaped == '"' || escaped == '\\' || escaped == '$' || escaped == '`')
                                    value.append_c (escaped);
                                else {
                                    value.append_c ('\\');
                                    value.append_c (escaped);
                                }
                                index++;
                                continue;
                            }
                            value.append_c (character);
                            index++;
                        }
                        if (!closed) {
                            opaque = true;
                            break;
                        }
                        continue;
                    }

                    if (character == '\\') {
                        index++;
                        if (index >= input.length) {
                            opaque = true;
                            break;
                        }
                        value.append_c (input[index]);
                        index++;
                        continue;
                    }

                    if (character == '$' || character == '`' || is_operator (character))
                        opaque = true;

                    value.append_c (character);
                    index++;
                }

                tokens.add (new LaunchOptionShellToken (
                    input.substring (start, index - start),
                    value.str,
                    opaque
                ));
            }

            return tokens;
        }

        bool is_whitespace (char character) {
            return character == ' ' || character == '\t' || character == '\n' || character == '\r';
        }

        bool is_operator (char character) {
            return character == '|' || character == '&' || character == ';' || character == '('
                   || character == ')' || character == '<' || character == '>';
        }
    }

    // Controls parse source words; LaunchCommandWriter owns command serialization.
    public class LaunchOptionsList : Object {
        private Gee.List<ILaunchOption> _options;

        public LaunchOptionsList () {
            this._options = new Gee.ArrayList<ILaunchOption> ();
        }

        public void add (ILaunchOption option) {
            this._options.add (option);
        }

        /* Display markup only. The exact command is still produced
         * exclusively by LaunchCommandWriter before reaching this formatter. */
        public static string build_command_preview_markup (string command) {
            var tokens = new LaunchOptionShellTokenizer ().tokenize (command);
            if (tokens.size == 0)
                return Markup.escape_text (_("No launch options configured yet."));

            var markup = new StringBuilder ();
            markup.append ("<tt>");

            for (var index = 0; index < tokens.size; index++) {
                if (index > 0)
                    markup.append (" ");

                var escaped_segment = Markup.escape_text (tokens[index].raw);
                markup.append (escaped_segment);
            }

            markup.append ("</tt>");

            return markup.str;
        }

        public static string build_labeled_command_preview_markup (string[] labels, string[] commands) {
            assert (labels.length == commands.length);
            var markup = new StringBuilder ();
            for (var index = 0; index < commands.length; index++) {
                if (index > 0)
                    markup.append ("\n\n");
                markup.append ("<b>%s</b>\n".printf (Markup.escape_text (labels[index])));
                markup.append (build_command_preview_markup (commands[index]));
            }
            return markup.str;
        }

        public void clear_all () {
            foreach (var option in this._options) {
                option.clear ();
            }
        }

        public Gee.Iterator<ILaunchOption> iterator () {
            return this._options.iterator ();
        }

        public string[] get_launch_option_tokens (string launch_options) {
            var values = new Gee.ArrayList<string> ();
            foreach (var token in new LaunchOptionShellTokenizer ().tokenize (launch_options)) {
                if (!token.is_opaque)
                    values.add (token.value);
            }
            return values.to_array ();
        }

        public bool load_from_string (string launch_options) {
            this.clear_all ();
            var tokens = get_launch_option_tokens (launch_options);
            var consumed = new bool[tokens.length];
            foreach (var option in this._options)
                option.parse_tokens (tokens, consumed);

            foreach (var option in this._options) {
                if (option.is_advanced && option.is_active ())
                    return true;
            }
            return false;
        }
    }
}
