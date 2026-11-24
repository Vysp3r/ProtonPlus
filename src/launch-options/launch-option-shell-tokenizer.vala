namespace ProtonPlus.LaunchOptions {
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
}
