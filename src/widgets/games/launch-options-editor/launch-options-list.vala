namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

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

    public class LaunchOptionsList : Object {
        private Gee.List<ILaunchOption> _options;
        private Gee.ArrayList<LaunchOptionShellToken> parsed_tokens;
        private Gee.ArrayList<LaunchOptionShellToken> loaded_tokens;
        private Gee.HashMap<LaunchOptionShellToken, ILaunchOption> token_owners;
        private Gee.HashMap<ILaunchOption, string> initial_option_serializations;
        private string loaded_launch_options;
        private bool loaded_source_is_pristine;

        public LaunchOptionsList () {
            this._options = new Gee.ArrayList<ILaunchOption> ();
            this.parsed_tokens = new Gee.ArrayList<LaunchOptionShellToken> ();
            this.loaded_tokens = new Gee.ArrayList<LaunchOptionShellToken> ();
            this.token_owners = new Gee.HashMap<LaunchOptionShellToken, ILaunchOption> ();
            this.initial_option_serializations = new Gee.HashMap<ILaunchOption, string> ();
            this.loaded_launch_options = "";
            this.loaded_source_is_pristine = false;
        }

        public void add (ILaunchOption option) {
            this._options.add (option);
        }

        public string build_preview_markup () {
            var segments = get_segments ();
            return build_command_preview_markup (string.joinv (" ", segments.to_array ()));
        }

        /* Display markup only. The exact command is still produced
         * exclusively by LaunchCommandWriter before reaching this formatter. */
        public static string build_command_preview_markup (string command) {
            var tokens = new LaunchOptionShellTokenizer ().tokenize (command);
            if (tokens.size == 0)
                return Markup.escape_text (_("No launch options configured yet."));

            string[] preview_colors = {
                "#79c0ff",
                "#ff938a",
                "#7ee787",
                "#d2a8ff",
                "#e3b341",
                "#56d4dd"
            };
            var markup = new StringBuilder ();
            markup.append ("<tt>");

            for (var index = 0; index < tokens.size; index++) {
                if (index > 0)
                    markup.append (" ");

                var escaped_segment = Markup.escape_text (tokens[index].raw);
                markup.append ("<span foreground='%s'>%s</span>".printf (preview_colors[index % preview_colors.length], escaped_segment));
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

        public bool has_preview_content () {
            return get_segments ().size > 0;
        }

        /* Deprecated compatibility-only round trip helper.  It is retained
         * for parser characterization; production persistence must consume
         * LaunchCommandWriteResult.launch_line. */
        public string to_launch_line () {
            if (this.loaded_source_is_pristine)
                return this.loaded_launch_options;
            return string.joinv (" ", get_segments ().to_array ());
        }

        /* Legacy control-token rendering remains private to parsing and
         * presentation. Persistence must use LaunchCommandWriteResult. */
        private Gee.LinkedList<string> get_segments () {
            if (this.loaded_source_is_pristine)
                return get_loaded_raw_segments ();

            if (this.loaded_tokens.size > 0)
                return get_source_ordered_segments ();

            var segments = new Gee.LinkedList<string> ();

            foreach (var option in get_environments ()) {
                option.append_command_segments (segments);
            }

            foreach (var option in get_wrappers ()) {
                option.append_command_segments (segments);
            }

            foreach (var option in get_commands ()) {
                option.append_command_segments (segments);
            }

            foreach (var option in get_arguments ()) {
                option.append_command_segments (segments);
            }

            foreach (var option in get_additionals ()) {
                option.append_command_segments (segments);
            }

            return segments;
        }

        /*
         * Keep untouched controls exactly where the user put them.  A changed
         * control replaces only its own source span; controls newly enabled in
         * the UI are appended afterwards because they have no source span.
         */
        private Gee.LinkedList<string> get_source_ordered_segments () {
            var segments = new Gee.LinkedList<string> ();
            var replaced_options = new Gee.HashSet<ILaunchOption> ();
            var source_options = new Gee.HashSet<ILaunchOption> ();

            foreach (var token in this.loaded_tokens) {
                var option = this.token_owners.get (token);
                if (option == null) {
                    segments.add (token.raw);
                    continue;
                }

                source_options.add (option);
                var current = serialize_option (option);
                var initial = this.initial_option_serializations.get (option);
                if (current == initial) {
                    segments.add (token.raw);
                } else if (!replaced_options.contains (option)) {
                    append_option_segments (segments, option);
                    replaced_options.add (option);
                }
            }

            foreach (var option in this._options) {
                if (source_options.contains (option))
                    continue;

                var current = serialize_option (option);
                var initial = this.initial_option_serializations.get (option);
                if (current != initial)
                    append_option_segments (segments, option);
            }

            return segments;
        }

        private void append_option_segments (Gee.LinkedList<string> segments, ILaunchOption option) {
            option.append_command_segments (segments);
        }

        private string serialize_option (ILaunchOption option) {
            var segments = new Gee.LinkedList<string> ();
            append_option_segments (segments, option);
            return string.joinv ("\x1f", segments.to_array ());
        }

        private Gee.LinkedList<string> get_loaded_raw_segments () {
            var segments = new Gee.LinkedList<string> ();
            foreach (var token in this.loaded_tokens)
                segments.add (token.raw);
            return segments;
        }

        public void mark_modified () {
            this.loaded_source_is_pristine = false;
        }

        private Gee.List<ILaunchOption> get_options_by_type (LaunchLineType type) {
            var filtered = new Gee.ArrayList<ILaunchOption> ();
            foreach (var option in this._options) {
                if (option.line_type == type) {
                    filtered.add (option);
                }
            }
            return filtered;
        }

        public Gee.List<ILaunchOption> get_additionals () {
            return this.get_options_by_type (LaunchLineType.ADDITIONAL);
        }

        public Gee.List<ILaunchOption> get_environments () {
            return this.get_options_by_type (LaunchLineType.ENVIRONMENT);
        }

        public Gee.List<ILaunchOption> get_wrappers () {
            return this.get_options_by_type (LaunchLineType.WRAPPER);
        }

        public Gee.List<ILaunchOption> get_commands () {
            return this.get_options_by_type (LaunchLineType.COMMAND);
        }

        public Gee.List<ILaunchOption> get_arguments () {
            return this.get_options_by_type (LaunchLineType.ARGUMENT);
        }

        public void clear_all () {
            foreach (var option in this._options) {
                option.clear ();
            }
        }

        public void parse_all_tokens (string[] tokens_pool, bool[] consumed) {
            this.token_owners.clear ();
            foreach (var option in this._options) {
                var consumed_before = new bool[consumed.length];
                for (var index = 0; index < consumed.length; index++)
                    consumed_before[index] = consumed[index];

                option.parse_tokens (tokens_pool, consumed);

                var entry_binding = option as EntryBinding;
                if (entry_binding != null)
                    entry_binding.set_loaded_tokens (get_newly_consumed_raw_tokens (tokens_pool, consumed_before, consumed));

                for (var index = 0; index < tokens_pool.length; index++) {
                    if (!consumed_before[index] && consumed[index] && index < this.parsed_tokens.size)
                        this.token_owners.set (this.parsed_tokens[index], option);
                }
            }

            this.initial_option_serializations.clear ();
            foreach (var option in this._options)
                this.initial_option_serializations.set (option, serialize_option (option));
        }

        private Gee.LinkedList<string> get_newly_consumed_raw_tokens (string[] tokens_pool, bool[] consumed_before, bool[] consumed) {
            var raw_tokens = new Gee.LinkedList<string> ();
            for (var index = 0; index < tokens_pool.length; index++) {
                if (!consumed_before[index] && consumed[index] && index < this.parsed_tokens.size)
                    raw_tokens.add (this.parsed_tokens[index].raw);
            }
            return raw_tokens;
        }

        public Gee.Iterator<ILaunchOption> iterator () {
            return this._options.iterator ();
        }

        public string[] get_launch_option_tokens (string launch_options) {
            this.parsed_tokens.clear ();
            var values = new Gee.ArrayList<string> ();

            foreach (var token in new LaunchOptionShellTokenizer ().tokenize (launch_options)) {
                if (token.is_opaque)
                    continue;
                this.parsed_tokens.add (token);
                values.add (token.value);
            }

            return values.to_array ();
        }

        public bool load_from_string (string launch_options) {
            this.clear_all ();

            prepare_loaded_source (launch_options);
            var tokens = get_loaded_token_values ();
            var consumed = new bool[tokens.length];

            this.parse_all_tokens (tokens, consumed);

            for (var i = 0; i < tokens.length; i++) {
                if (tokens[i] == "%command%") {
                    consumed[i] = true;
                    break;
                }
            }

            foreach (var option in this._options) {
                if (option.is_advanced && option.is_active ()) {
                    this.loaded_source_is_pristine = true;
                    return true;
                }
            }

            this.loaded_source_is_pristine = true;
            return false;
        }

        public bool has_unrecognized_or_opaque_content () {
            foreach (var token in loaded_tokens) {
                if (token.is_opaque)
                    return true;

                var option = token_owners.get (token);
                if (option == null)
                    return token.value != "%command%";

                if (option is EntryBinding)
                    return true;
            }
            return false;
        }

        private void prepare_loaded_source (string launch_options) {
            this.loaded_tokens.clear ();
            this.loaded_tokens.add_all (new LaunchOptionShellTokenizer ().tokenize (launch_options));
            this.loaded_launch_options = launch_options;
            this.loaded_source_is_pristine = false;
        }

        private string[] get_loaded_token_values () {
            this.parsed_tokens.clear ();
            var values = new Gee.ArrayList<string> ();

            foreach (var token in this.loaded_tokens) {
                if (token.is_opaque)
                    continue;
                this.parsed_tokens.add (token);
                values.add (token.value);
            }

            return values.to_array ();
        }
    }
}
