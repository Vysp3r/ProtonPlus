using ProtonPlus.LaunchOptions;

namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
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
            if (command == "")
                return Markup.escape_text (_("No launch options configured yet."));
            return "<tt>%s</tt>".printf (Markup.escape_text (command));
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
            return load_from_parse_result (new LaunchCommandParser ().parse (launch_options));
        }

        internal bool load_from_parse_result (LaunchCommandParseResult parsed) {
            this.clear_all ();
            var tokens = new string[parsed.tokens.size];
            var consumed = new bool[tokens.length];
            for (var index = 0; index < tokens.length; index++) {
                tokens[index] = parsed.tokens[index].is_opaque ? "" : parsed.tokens[index].value;
                consumed[index] = parsed.tokens[index].is_opaque || index == parsed.custom_wrapper_index;
            }
            if (parsed.command_boundary_indexes.size == 1) {
                foreach (var token in parsed.unrecognized_tokens) {
                    if (token.kind == LaunchCommandUnrecognizedKind.UNKNOWN_TOKEN) {
                        tokens[token.token_index] = "";
                        consumed[token.token_index] = true;
                    }
                }
            }
            foreach (var option in this._options) {
                var wrapper = option as Wrappers.Base;
                if (wrapper != null)
                    wrapper.load_from_parse_result (parsed, tokens, consumed);
                else
                    option.parse_tokens (tokens, consumed);
            }

            foreach (var option in this._options) {
                if (option.is_advanced && option.is_active ())
                    return true;
            }
            return false;
        }
    }
}
