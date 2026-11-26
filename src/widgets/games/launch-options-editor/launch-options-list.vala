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
        public static string build_command_preview_markup (string command, bool dark = false) {
            if (command == "")
                return Markup.escape_text (_("No launch options configured yet."));

            string[] colors = dark
                ? new string[] { "#79c0ff", "#ff938a", "#7ee787", "#d2a8ff", "#e3b341", "#56d4dd" }
                : new string[] { "#0550ae", "#a40e26", "#116329", "#6639ba", "#7d4e00", "#00646e" };
            var markup = new StringBuilder ("<tt>");
            var offset = 0;
            var color_index = 0;
            foreach (var token in new LaunchOptionShellTokenizer ().tokenize (command)) {
                var start = command.index_of (token.raw, offset);
                markup.append (Markup.escape_text (command.substring (offset, start - offset)));
                markup.append_printf ("<span foreground='%s'>%s</span>", colors[color_index], Markup.escape_text (token.raw));
                offset = start + token.raw.length;
                color_index = (color_index + 1) % colors.length;
            }
            markup.append (Markup.escape_text (command.substring (offset)));
            markup.append ("</tt>");
            return markup.str;
        }

        public static string build_labeled_command_preview_markup (string[] labels, string[] commands, bool dark = false) {
            assert (labels.length == commands.length);
            var markup = new StringBuilder ();
            for (var index = 0; index < commands.length; index++) {
                if (index > 0)
                    markup.append ("\n\n");
                markup.append ("<b>%s</b>\n".printf (Markup.escape_text (labels[index])));
                markup.append (build_command_preview_markup (commands[index], dark));
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

        internal bool load_from_parse_result (LaunchCommandParseResult parsed, owned LaunchOptionCatalog? catalog = null) {
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
            foreach (var occurrence in parsed.occurrences) {
                if (occurrence.is_legacy
                    || !(occurrence.environment_key in LaunchOptionCatalog.build_environment_keys (occurrence.option_id)))
                    continue;
                if (catalog == null)
                    catalog = new LaunchOptionCatalog ();
                var key = catalog.lookup (occurrence.option_id).semantics.environment_key;
                tokens[occurrence.token_indexes[0]] = key + "=" + occurrence.environment_value;
            }
            foreach (var option in this._options) {
                var wrapper = option as Wrappers.Base;
                if (wrapper != null)
                    wrapper.load_from_parse_result (parsed, tokens, consumed);
                else if (option is LaunchOptionEnvironmentField)
                    ((LaunchOptionEnvironmentField) option).load_from_parse_result (parsed);
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
