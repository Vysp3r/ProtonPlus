namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

    public enum LaunchCommandParseDiagnosticCode {
        MISSING_COMMAND_BOUNDARY,
        DUPLICATE_COMMAND_BOUNDARY,
        ENVIRONMENT_AFTER_COMMAND_BOUNDARY,
        WRAPPER_AFTER_COMMAND_BOUNDARY,
        MISSING_WRAPPER_DELIMITER,
        MISPLACED_WRAPPER_DELIMITER,
        EMBEDDED_COMMAND_BOUNDARY,
        UNSAFE_SHELL_TOKEN
    }

    public enum LaunchCommandUnrecognizedKind {
        UNKNOWN_TOKEN,
        UNKNOWN_ENVIRONMENT_ASSIGNMENT,
        PRESERVED_GAME_COMMAND_CONTENT
    }

    public class LaunchCommandParseDiagnostic : Object {
        public LaunchCommandParseDiagnosticCode code { get; construct; }
        public string message { get; construct; }
        public int token_index { get; construct; }

        public LaunchCommandParseDiagnostic (
            LaunchCommandParseDiagnosticCode code, string message, int token_index = -1
        ) {
            Object (code: code, message: message, token_index: token_index);
        }
    }

    public class LaunchCommandOptionOccurrence : Object {
        public string option_id { get; construct; }
        public LaunchOptionSemanticKind semantic_kind { get; construct; }
        public ArrayList<LaunchOptionShellToken> raw_tokens { get; private set; }
        public int[] token_indexes;
        public string normalized_value { get; construct; }
        public bool is_legacy { get; construct; }
        public bool managed_emission { get; construct; }
        public string environment_key { get; construct; }
        public string environment_value { get; construct; }
        public string wrapper_id { get; construct; }

        public LaunchCommandOptionOccurrence (
            string option_id, LaunchOptionSemanticKind semantic_kind,
            ArrayList<LaunchOptionShellToken> raw_tokens, int[] token_indexes,
            string normalized_value = "", bool is_legacy = false,
            bool managed_emission = false, string environment_key = "",
            string environment_value = "", string wrapper_id = ""
        ) {
            Object (
                option_id: option_id, semantic_kind: semantic_kind,
                normalized_value: normalized_value,
                is_legacy: is_legacy, managed_emission: managed_emission,
                environment_key: environment_key, environment_value: environment_value,
                wrapper_id: wrapper_id
            );
            this.raw_tokens = raw_tokens;
            this.token_indexes = token_indexes;
        }
    }

    public class LaunchCommandWrapperInvocation : Object {
        public string wrapper_id { get; construct; }
        public ArrayList<LaunchOptionShellToken> executable_tokens { get; private set; }
        public int[] executable_indexes;
        public bool used_alias { get; construct; }
        public int delimiter_index { get; set; default = -1; }
        public ArrayList<int> argument_indexes { get; private set; }
        public ArrayList<int> unknown_argument_indexes { get; private set; }

        public LaunchCommandWrapperInvocation (
            string wrapper_id, ArrayList<LaunchOptionShellToken> executable_tokens,
            int[] executable_indexes, bool used_alias = false
        ) {
            Object (wrapper_id: wrapper_id, used_alias: used_alias);
            this.executable_tokens = executable_tokens;
            this.executable_indexes = executable_indexes;
            this.argument_indexes = new ArrayList<int> ();
            this.unknown_argument_indexes = new ArrayList<int> ();
        }
    }

    public class LaunchCommandUnrecognizedToken : Object {
        public LaunchOptionShellToken token { get; construct; }
        public int token_index { get; construct; }
        public LaunchCommandUnrecognizedKind kind { get; construct; }

        public LaunchCommandUnrecognizedToken (
            LaunchOptionShellToken token, int token_index, LaunchCommandUnrecognizedKind kind
        ) {
            Object (token: token, token_index: token_index, kind: kind);
        }
    }

    public class LaunchCommandBoundaryOccurrence : Object {
        public LaunchOptionShellToken token { get; construct; }
        public int token_index { get; construct; }

        public LaunchCommandBoundaryOccurrence (LaunchOptionShellToken token, int token_index) {
            Object (token: token, token_index: token_index);
        }
    }

    public class LaunchCommandParseResult : Object {
        public string original_input { get; construct; }
        public ArrayList<LaunchOptionShellToken> tokens { get; private set; }
        public ArrayList<LaunchCommandOptionOccurrence> occurrences { get; private set; }
        public ArrayList<LaunchCommandWrapperInvocation> wrappers { get; private set; }
        public ArrayList<LaunchCommandBoundaryOccurrence> command_boundaries { get; private set; }
        public ArrayList<int> command_boundary_indexes { get; private set; }
        public ArrayList<LaunchCommandUnrecognizedToken> unrecognized_tokens { get; private set; }
        public ArrayList<LaunchOptionShellToken> opaque_tokens { get; private set; }
        public ArrayList<LaunchCommandParseDiagnostic> diagnostics { get; private set; }
        public bool is_structurally_safe { get; set; default = true; }

        public LaunchCommandParseResult (string original_input, ArrayList<LaunchOptionShellToken> tokens) {
            Object (original_input: original_input);
            this.tokens = tokens;
            this.occurrences = new ArrayList<LaunchCommandOptionOccurrence> ();
            this.wrappers = new ArrayList<LaunchCommandWrapperInvocation> ();
            this.command_boundaries = new ArrayList<LaunchCommandBoundaryOccurrence> ();
            this.command_boundary_indexes = new ArrayList<int> ();
            this.unrecognized_tokens = new ArrayList<LaunchCommandUnrecognizedToken> ();
            this.opaque_tokens = new ArrayList<LaunchOptionShellToken> ();
            this.diagnostics = new ArrayList<LaunchCommandParseDiagnostic> ();
        }
    }

    /* A read-only semantic service.  It consumes catalog metadata and shell
     * tokens, never widgets, and never emits a rewritten command line. */
    public class LaunchCommandParser : Object {
        LaunchOptionCatalog catalog;

        public LaunchCommandParser (LaunchOptionCatalog? catalog = null) {
            this.catalog = catalog ?? new LaunchOptionCatalog ();
        }

        public LaunchCommandParseResult parse (string input) {
            var result = new LaunchCommandParseResult (input, new LaunchOptionShellTokenizer ().tokenize (input));
            var boundary = -1;
            var wrapper_consumed = new bool[result.tokens.size];

            for (var index = 0; index < result.tokens.size; index++) {
                var token = result.tokens[index];
                if (token.is_opaque) {
                    result.opaque_tokens.add (token);
                    add_diagnostic (result, LaunchCommandParseDiagnosticCode.UNSAFE_SHELL_TOKEN,
                        "Unsafe or malformed shell content is preserved as opaque.", index);
                    continue;
                }
                if (token.raw == "%command%" && token.value == "%command%") {
                    result.command_boundaries.add (new LaunchCommandBoundaryOccurrence (token, index));
                    result.command_boundary_indexes.add (index);
                    if (boundary < 0)
                        boundary = index;
                } else if (token.value.contains ("%command%")) {
                    add_diagnostic (result, LaunchCommandParseDiagnosticCode.EMBEDDED_COMMAND_BOUNDARY,
                        "The command placeholder must be its own unquoted shell token.", index);
                }
            }

            if (result.command_boundary_indexes.size > 1)
                add_diagnostic (result, LaunchCommandParseDiagnosticCode.DUPLICATE_COMMAND_BOUNDARY,
                    "Launch options contain more than one %command% boundary.");

            var pre_boundary_end = boundary >= 0 ? boundary : result.tokens.size;
            parse_wrappers (result, pre_boundary_end, wrapper_consumed);

            var has_pre_boundary_modifier = has_environment_or_wrapper (result, pre_boundary_end);
            for (var index = 0; index < result.tokens.size; index++) {
                var token = result.tokens[index];
                if (token.is_opaque || index == boundary || is_boundary (result, index))
                    continue;
                if (wrapper_consumed[index])
                    continue;

                bool after_boundary = boundary >= 0 && index > boundary;
                string key;
                string value;
                if (split_environment_assignment (token.value, out key, out value)) {
                    var occurrence = find_environment_occurrence (result, index, key, value);
                    if (occurrence != null)
                        result.occurrences.add (occurrence);
                    else
                        result.unrecognized_tokens.add (new LaunchCommandUnrecognizedToken (
                            token, index, LaunchCommandUnrecognizedKind.UNKNOWN_ENVIRONMENT_ASSIGNMENT));
                    if (after_boundary)
                        add_diagnostic (result, LaunchCommandParseDiagnosticCode.ENVIRONMENT_AFTER_COMMAND_BOUNDARY,
                            "Environment assignments must precede %command%.", index);
                    continue;
                }

                var game_occurrence = find_game_argument_occurrence (result, index);
                if (game_occurrence != null && (after_boundary || (boundary < 0 && !has_pre_boundary_modifier))) {
                    result.occurrences.add (game_occurrence);
                    continue;
                }

                if (after_boundary && (find_wrapper_at (result, index, result.tokens.size) != null
                    || find_wrapper_argument_at (result, index, result.tokens.size, null) != null)) {
                    add_diagnostic (result, LaunchCommandParseDiagnosticCode.WRAPPER_AFTER_COMMAND_BOUNDARY,
                        "Wrapper executables and wrapper arguments must precede %command%.", index);
                }
                /* Without a command boundary or a pre-command modifier, Steam
                 * treats the whole launch-options string as game arguments.
                 * Preserve unknown arguments as such instead of mistaking them
                 * for unsafe content before a command. */
                var arguments_only = boundary < 0 && !has_pre_boundary_modifier;
                result.unrecognized_tokens.add (new LaunchCommandUnrecognizedToken (
                    token, index, after_boundary || arguments_only
                    ? LaunchCommandUnrecognizedKind.PRESERVED_GAME_COMMAND_CONTENT
                    : LaunchCommandUnrecognizedKind.UNKNOWN_TOKEN));
            }

            parse_composites (result, pre_boundary_end);

            if (boundary < 0 && (has_pre_boundary_modifier || result.wrappers.size > 0))
                add_diagnostic (result, LaunchCommandParseDiagnosticCode.MISSING_COMMAND_BOUNDARY,
                    "Environment assignments and wrappers require a %command% boundary.");

            result.occurrences.sort ((first, second) => {
                var first_index = first.token_indexes.length > 0 ? first.token_indexes[0] : -1;
                var second_index = second.token_indexes.length > 0 ? second.token_indexes[0] : -1;
                return first_index - second_index;
            });
            foreach (var occurrence in result.occurrences) {
                if (!occurrence.managed_emission || occurrence.is_legacy)
                    result.is_structurally_safe = false;
            }
            foreach (var token in result.unrecognized_tokens) {
                if (token.kind != LaunchCommandUnrecognizedKind.PRESERVED_GAME_COMMAND_CONTENT)
                    result.is_structurally_safe = false;
            }
            return result;
        }

        void parse_wrappers (LaunchCommandParseResult result, int end, bool[] consumed) {
            var index = 0;
            while (index < end) {
                var matched = find_wrapper_at (result, index, end);
                if (matched == null) {
                    index++;
                    continue;
                }
                var definition = matched.definition;
                var executable_indexes = new ArrayList<int> ();
                var executable_tokens = new ArrayList<LaunchOptionShellToken> ();
                for (var part = 0; part < matched.length; part++) {
                    executable_indexes.add (index + part);
                    executable_tokens.add (result.tokens[index + part]);
                    consumed[index + part] = true;
                }
                var invocation = new LaunchCommandWrapperInvocation (
                    definition.id, executable_tokens, executable_indexes.to_array (), matched.used_alias);
                result.wrappers.add (invocation);
                add_wrapper_occurrence (result, invocation);
                index += matched.length;

                if (definition.delimiter == null)
                    continue;

                bool found_delimiter = false;
                while (index < end) {
                    if (result.tokens[index].value == definition.delimiter) {
                        invocation.delimiter_index = index;
                        consumed[index] = true;
                        index++;
                        found_delimiter = true;
                        break;
                    }
                    var argument = find_wrapper_argument_at (result, index, end, definition.id);
                    if (argument != null) {
                        add_wrapper_argument_occurrence (result, invocation, argument);
                        for (var part = 0; part < argument.length; part++)
                            consumed[index + part] = true;
                        index += argument.length;
                        continue;
                    }
                    invocation.argument_indexes.add (index);
                    invocation.unknown_argument_indexes.add (index);
                    consumed[index] = true;
                    index++;
                }
                if (!found_delimiter)
                    add_diagnostic (result, LaunchCommandParseDiagnosticCode.MISSING_WRAPPER_DELIMITER,
                        "Wrapper '%s' requires '%s' before %%command%%.".printf (definition.id, definition.delimiter), index);
            }

            for (var scan_index = 0; scan_index < end; scan_index++) {
                if (!consumed[scan_index] && result.tokens[scan_index].value == "--")
                    add_diagnostic (result, LaunchCommandParseDiagnosticCode.MISPLACED_WRAPPER_DELIMITER,
                        "A wrapper delimiter is not owned by a delimited wrapper.", scan_index);
            }
        }

        void add_wrapper_occurrence (LaunchCommandParseResult result, LaunchCommandWrapperInvocation invocation) {
            LaunchOptionMetadata? owner = null;
            foreach (var entry in catalog.get_ordered ()) {
                if (entry.semantics == null)
                    continue;
                if (entry.semantics.wrapper_id == invocation.wrapper_id
                    && (entry.semantics.kind == LaunchOptionSemanticKind.PREFIX_WRAPPER
                        || entry.semantics.kind == LaunchOptionSemanticKind.DELIMITED_WRAPPER)) {
                    owner = entry;
                    break;
                }
                if (entry.semantics.kind == LaunchOptionSemanticKind.WRAPPER_SELECTOR
                    && contains (entry.semantics.selectable_wrapper_ids, invocation.wrapper_id))
                    owner = entry;
            }
            if (owner == null)
                return;
            result.occurrences.add (new LaunchCommandOptionOccurrence (
                owner.id, owner.semantics.kind, invocation.executable_tokens, invocation.executable_indexes,
                "", invocation.used_alias, owner.semantics.managed_emission, "", "", invocation.wrapper_id));
        }

        void add_wrapper_argument_occurrence (
            LaunchCommandParseResult result, LaunchCommandWrapperInvocation invocation,
            WrapperArgumentMatch match
        ) {
            var tokens = tokens_for_indexes (result, match.indexes);
            foreach (var source_index in match.indexes)
                invocation.argument_indexes.add (source_index);
            result.occurrences.add (new LaunchCommandOptionOccurrence (
                match.entry.id, match.entry.semantics.kind, tokens, match.indexes,
                normalized_values (result, match.indexes, match.entry.semantics.parse_shape), false,
                match.entry.semantics.managed_emission, "", "", invocation.wrapper_id));
        }

        LaunchCommandOptionOccurrence? find_environment_occurrence (
            LaunchCommandParseResult result, int index, string key, string value
        ) {
            foreach (var entry in catalog.get_ordered ()) {
                var semantics = entry.semantics;
                if (semantics == null)
                    continue;
                bool canonical = semantics.kind == LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT
                    && semantics.environment_key == key && environment_matches_canonical (semantics, result.tokens[index].value);
                bool legacy = environment_matches_legacy (semantics, result.tokens[index].value, key);
                if (!canonical && !legacy)
                    continue;
                return new LaunchCommandOptionOccurrence (
                    entry.id, semantics.kind, tokens_for_indexes (result, { index }), { index }, value,
                    legacy, semantics.managed_emission && !legacy, key, value, semantics.wrapper_id);
            }
            return null;
        }

        bool environment_matches_canonical (LaunchOptionSemantics semantics, string token) {
            if (semantics.emission_mode == LaunchOptionEmissionMode.DYNAMIC_ENVIRONMENT_VALUE)
                return true;
            foreach (var fixed in semantics.fixed_tokens) {
                if (fixed == token)
                    return true;
            }
            return false;
        }

        bool environment_matches_legacy (LaunchOptionSemantics semantics, string token, string key) {
            foreach (var legacy in semantics.legacy_tokens) {
                var separator = legacy.index_of_char ('=');
                if (separator < 0 && key == legacy)
                    return true;
                if (separator >= 0 && legacy.has_suffix ("=") && token.has_prefix (legacy))
                    return true;
                if (legacy == token)
                    return true;
            }
            return false;
        }

        LaunchCommandOptionOccurrence? find_game_argument_occurrence (LaunchCommandParseResult result, int index) {
            foreach (var entry in catalog.get_ordered ()) {
                var semantics = entry.semantics;
                if (semantics == null || semantics.kind != LaunchOptionSemanticKind.GAME_ARGUMENT
                    || semantics.emission_mode != LaunchOptionEmissionMode.FIXED_TOKENS
                    || !matches_tokens (result, index, result.tokens.size, semantics.fixed_tokens))
                    continue;
                var indexes = consecutive_indexes (index, semantics.fixed_tokens.length);
                return new LaunchCommandOptionOccurrence (
                    entry.id, semantics.kind, tokens_for_indexes (result, indexes), indexes, "", false,
                    semantics.managed_emission, "", "", "");
            }
            return null;
        }

        void parse_composites (LaunchCommandParseResult result, int end) {
            foreach (var entry in catalog.get_ordered ()) {
                var semantics = entry.semantics;
                if (semantics == null || semantics.kind != LaunchOptionSemanticKind.COMPOSITE_DYNAMIC)
                    continue;
                var environment_output = find_composite_environment_output (semantics);
                var argument_output = find_composite_argument_output (semantics);
                if (environment_output == null || argument_output == null || argument_output.parse_shape == null)
                    continue;
                var environment_index = find_fixed_token (result, end, environment_output.fixed_tokens);
                if (environment_index < 0)
                    continue;
                bool matched_arguments = false;
                foreach (var invocation in result.wrappers) {
                    if (invocation.wrapper_id != argument_output.wrapper_id)
                        continue;
                    var argument_indexes = match_indexes_in_invocation (result, invocation, argument_output.parse_shape);
                    if (argument_indexes == null)
                        continue;
                    var all_indexes = new ArrayList<int> ();
                    all_indexes.add (environment_index);
                    foreach (var source_index in argument_indexes)
                        all_indexes.add (source_index);
                    all_indexes.sort ((first, second) => first - second);
                    result.occurrences.add (new LaunchCommandOptionOccurrence (
                        entry.id, semantics.kind, tokens_for_indexes (result, all_indexes.to_array ()),
                        all_indexes.to_array (), normalized_values (result, argument_indexes, argument_output.parse_shape),
                        false, semantics.managed_emission, environment_output.environment_key, "", invocation.wrapper_id));
                    remove_unrecognized_indexes (result, all_indexes);
                    foreach (var source_index in argument_indexes)
                        invocation.unknown_argument_indexes.remove (source_index);
                    matched_arguments = true;
                }
                /* A composite may deliberately have an environment-only
                 * automatic mode.  This is declared through the selectable
                 * logical value, rather than a writer-side option exception. */
                bool has_owner_arguments = false;
                foreach (var invocation in result.wrappers) {
                    if (invocation.wrapper_id == semantics.wrapper_id && invocation.argument_indexes.size > 0)
                        has_owner_arguments = true;
                }
                if (!matched_arguments && !has_owner_arguments && contains (semantics.selectable_values, "auto")) {
                    var automatic_indexes = new ArrayList<int> ();
                    automatic_indexes.add (environment_index);
                    result.occurrences.add (new LaunchCommandOptionOccurrence (
                        entry.id, semantics.kind, tokens_for_indexes (result, { environment_index }),
                        { environment_index }, "auto", false, semantics.managed_emission,
                        environment_output.environment_key, "", semantics.wrapper_id));
                    remove_unrecognized_indexes (result, automatic_indexes);
                }
            }
        }

        LaunchOptionSemanticOutput? find_composite_environment_output (LaunchOptionSemantics semantics) {
            foreach (var output in semantics.get_composite_outputs ()) {
                if (output.kind == LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT && output.fixed_tokens.length > 0)
                    return output;
            }
            return null;
        }

        LaunchOptionSemanticOutput? find_composite_argument_output (LaunchOptionSemantics semantics) {
            foreach (var output in semantics.get_composite_outputs ()) {
                if (output.kind == LaunchOptionSemanticKind.WRAPPER_ARGUMENT)
                    return output;
            }
            return null;
        }

        int find_fixed_token (LaunchCommandParseResult result, int end, string[] tokens) {
            for (var index = 0; index < end; index++) {
                if (matches_tokens (result, index, end, tokens))
                    return index;
            }
            return -1;
        }

        int[]? match_indexes_in_invocation (
            LaunchCommandParseResult result, LaunchCommandWrapperInvocation invocation,
            LaunchOptionParseShape shape
        ) {
            for (var position = 0; position < invocation.argument_indexes.size; position++) {
                var indexes = new ArrayList<int> ();
                var cursor = position;
                bool matches = true;
                var arities = shape.get_value_arities ();
                for (var token_index = 0; token_index < shape.tokens.length; token_index++) {
                    if (cursor >= invocation.argument_indexes.size
                        || result.tokens[invocation.argument_indexes[cursor]].value != shape.tokens[token_index]) {
                        matches = false;
                        break;
                    }
                    indexes.add (invocation.argument_indexes[cursor++]);
                    for (var value = 0; value < arities[token_index]; value++) {
                        if (cursor >= invocation.argument_indexes.size) {
                            matches = false;
                            break;
                        }
                        indexes.add (invocation.argument_indexes[cursor++]);
                    }
                    if (!matches)
                        break;
                }
                if (matches)
                    return indexes.to_array ();
            }
            return null;
        }

        void remove_unrecognized_indexes (LaunchCommandParseResult result, ArrayList<int> indexes) {
            for (var position = result.unrecognized_tokens.size - 1; position >= 0; position--) {
                if (indexes.contains (result.unrecognized_tokens[position].token_index))
                    result.unrecognized_tokens.remove_at (position);
            }
        }

        bool has_environment_or_wrapper (LaunchCommandParseResult result, int end) {
            for (var index = 0; index < end; index++) {
                string key;
                string value;
                if (!result.tokens[index].is_opaque
                    && (split_environment_assignment (result.tokens[index].value, out key, out value)
                        || find_wrapper_at (result, index, end) != null))
                    return true;
            }
            return false;
        }

        WrapperMatch? find_wrapper_at (LaunchCommandParseResult result, int index, int end) {
            foreach (var definition in catalog.get_wrappers ()) {
                if (matches_tokens (result, index, end, definition.executable_tokens))
                    return new WrapperMatch (definition, definition.executable_tokens.length, false);
                if (definition.executable_tokens.length == 1) {
                    foreach (var alias in definition.parse_aliases) {
                        if (index < end && !result.tokens[index].is_opaque && result.tokens[index].value == alias)
                            return new WrapperMatch (definition, 1, true);
                    }
                }
            }
            return null;
        }

        WrapperArgumentMatch? find_wrapper_argument_at (
            LaunchCommandParseResult result, int index, int end, string? wrapper_id
        ) {
            foreach (var entry in catalog.get_ordered ()) {
                var semantics = entry.semantics;
                if (semantics == null || semantics.kind != LaunchOptionSemanticKind.WRAPPER_ARGUMENT
                    || semantics.parse_shape == null
                    || (wrapper_id != null && semantics.wrapper_id != wrapper_id))
                    continue;
                var shape = semantics.parse_shape;
                var arities = shape.get_value_arities ();
                if (arities.length != shape.tokens.length)
                    continue;
                var indexes = new ArrayList<int> ();
                var cursor = index;
                bool matches = true;
                for (var part = 0; part < shape.tokens.length; part++) {
                    if (cursor >= end || result.tokens[cursor].is_opaque || result.tokens[cursor].value != shape.tokens[part]) {
                        matches = false;
                        break;
                    }
                    indexes.add (cursor++);
                    for (var value = 0; value < arities[part]; value++) {
                        if (cursor >= end || result.tokens[cursor].is_opaque) {
                            matches = false;
                            break;
                        }
                        indexes.add (cursor++);
                    }
                    if (!matches)
                        break;
                }
                if (matches)
                    return new WrapperArgumentMatch (entry, indexes.to_array ());
            }
            return null;
        }

        bool split_environment_assignment (string token, out string key, out string value) {
            key = "";
            value = "";
            var separator = token.index_of_char ('=');
            if (separator <= 0)
                return false;
            var candidate = token.substring (0, separator);
            if (!is_environment_key (candidate))
                return false;
            key = candidate;
            value = token.substring (separator + 1);
            return true;
        }

        bool is_environment_key (string value) {
            if (value.length == 0 || !((value[0] >= 'A' && value[0] <= 'Z') || (value[0] >= 'a' && value[0] <= 'z') || value[0] == '_'))
                return false;
            for (var index = 1; index < value.length; index++) {
                var character = value[index];
                if (!((character >= 'A' && character <= 'Z') || (character >= 'a' && character <= 'z')
                    || (character >= '0' && character <= '9') || character == '_'))
                    return false;
            }
            return true;
        }

        bool matches_tokens (LaunchCommandParseResult result, int index, int end, string[] expected) {
            if (expected.length == 0 || index + expected.length > end)
                return false;
            for (var part = 0; part < expected.length; part++) {
                if (result.tokens[index + part].is_opaque || result.tokens[index + part].value != expected[part])
                    return false;
            }
            return true;
        }

        bool is_boundary (LaunchCommandParseResult result, int index) {
            return result.command_boundary_indexes.contains (index);
        }

        ArrayList<LaunchOptionShellToken> tokens_for_indexes (LaunchCommandParseResult result, int[] indexes) {
            var values = new ArrayList<LaunchOptionShellToken> ();
            foreach (var index in indexes)
                values.add (result.tokens[index]);
            return values;
        }

        int[] consecutive_indexes (int start, int length) {
            var indexes = new int[length];
            for (var index = 0; index < length; index++)
                indexes[index] = start + index;
            return indexes;
        }

        string normalized_values (LaunchCommandParseResult result, int[] indexes, LaunchOptionParseShape? shape) {
            if (shape == null)
                return "";
            var values = new ArrayList<string> ();
            var arities = shape.get_value_arities ();
            var position = 0;
            foreach (var arity in arities) {
                position++;
                for (var value = 0; value < arity && position < indexes.length; value++)
                    values.add (result.tokens[indexes[position++]].value);
            }
            return string.joinv (",", values.to_array ());
        }

        bool contains (string[] values, string candidate) {
            foreach (var value in values) {
                if (value == candidate)
                    return true;
            }
            return false;
        }

        void add_diagnostic (
            LaunchCommandParseResult result, LaunchCommandParseDiagnosticCode code,
            string message, int token_index = -1
        ) {
            result.diagnostics.add (new LaunchCommandParseDiagnostic (code, message, token_index));
            result.is_structurally_safe = false;
        }
    }

    class WrapperMatch : Object {
        public LaunchWrapperDefinition definition { get; construct; }
        public int length { get; construct; }
        public bool used_alias { get; construct; }

        public WrapperMatch (LaunchWrapperDefinition definition, int length, bool used_alias) {
            Object (definition: definition, length: length, used_alias: used_alias);
        }
    }

    class WrapperArgumentMatch : Object {
        public LaunchOptionMetadata entry { get; construct; }
        public int[] indexes;
        public int length { get { return indexes.length; } }

        public WrapperArgumentMatch (LaunchOptionMetadata entry, int[] indexes) {
            Object (entry: entry);
            this.indexes = indexes;
        }
    }
}
