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
        public bool has_unquoted_glob { get; construct; }

        public LaunchOptionShellToken (string raw, string value, bool is_opaque = false, bool has_unquoted_glob = false) {
            Object (raw: raw, value: value, is_opaque: is_opaque, has_unquoted_glob: has_unquoted_glob);
        }
    }

    internal class LaunchCustomWrapperInput {
        public const string OPTION_ID = "custom-wrapper";

        public static string? read (string input, out string executable) {
            executable = "";
            var words = new LaunchOptionShellTokenizer ().tokenize (input);
            if (words.size == 0)
                return null;

            if ((words.size == 1 || (words.size == 2 && words[1].raw == "%command%"))
                && is_literal_path (words[0]) && !input.contains ("\n") && !input.contains ("\r")) {
                executable = words[0].raw;
                return null;
            }

            return _("Enter one executable path, with quotes around spaces. You can include %command% at the end.");
        }

        public static bool is_literal_path (LaunchOptionShellToken token) {
            return !token.is_opaque && !token.raw.contains ("%command%")
                && !token.value.contains ("%command%") && !token.value.contains ("\n")
                && !token.value.contains ("\r") && !token.has_unquoted_glob
                && (token.value.has_prefix ("/") || token.value.has_prefix ("./") || token.value.has_prefix ("../"))
                && !token.value.has_suffix ("/");
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
                var unquoted_glob = false;

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
                    if (character == '*' || character == '?' || character == '[')
                        unquoted_glob = true;

                    value.append_c (character);
                    index++;
                }

                tokens.add (new LaunchOptionShellToken (
                    input.substring (start, index - start),
                    value.str,
                    opaque,
                    unquoted_glob
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
