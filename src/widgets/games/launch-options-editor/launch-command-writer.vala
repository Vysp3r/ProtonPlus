namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

    /* The writer is intentionally independent of GTK.  It accepts parsed source
     * plus semantic selections and either returns one complete, safe launch line
     * or refuses to make a change. */
    public enum LaunchCommandWriteStatus {
        UNCHANGED_PRISTINE_SOURCE,
        FRESH_MANAGED_OUTPUT,
        SOURCE_PRESERVING_MANAGED_MERGE,
        UNCHANGED_UNMANAGED_SOURCE,
        BLOCKED_UNSAFE_SOURCE,
        BLOCKED_INVALID_SELECTIONS,
        INCOMPLETE_ADAPTER_COVERAGE,
        CAPABILITY_CONTEXT_REQUIRED
    }

    public class LaunchCommandWriteResult : Object {
        public LaunchCommandWriteStatus status { get; construct; }
        public bool writing_allowed { get; construct; }
        public bool requires_persistence { get; construct; }
        public string launch_line { get; construct; }
        public LaunchCommandParseResult parsed { get; construct; }
        public ArrayList<LaunchCommandCompositionDiagnostic> composition_diagnostics { get; private set; }
        public ArrayList<string> writer_diagnostics { get; private set; }
        public ArrayList<string> modified_option_ids { get; private set; }
        public ArrayList<int> preserved_token_spans { get; private set; }
        public ArrayList<int> replaced_token_spans { get; private set; }

        public LaunchCommandWriteResult (LaunchCommandWriteStatus status,
                                         LaunchCommandParseResult parsed,
                                         bool writing_allowed = false,
                                         bool requires_persistence = false,
                                         string launch_line = "") {
            Object (status: status, parsed: parsed, writing_allowed: writing_allowed,
                    requires_persistence: requires_persistence, launch_line: launch_line);
            composition_diagnostics = new ArrayList<LaunchCommandCompositionDiagnostic> ();
            writer_diagnostics = new ArrayList<string> ();
            modified_option_ids = new ArrayList<string> ();
            preserved_token_spans = new ArrayList<int> ();
            replaced_token_spans = new ArrayList<int> ();
        }
    }

    public class LaunchCommandWriteRequest : Object {
        public LaunchCommandParseResult parsed;
        public LaunchCommandSelection[] selections;
        public string[] modified_option_ids;
        public string[] adapter_diagnostics;
        public LaunchCommandCapabilityContext? capabilities;
        public bool explicit_clear;
        public bool retain_placeholder_for_arguments_only;

        public LaunchCommandWriteRequest (LaunchCommandParseResult parsed,
                                          LaunchCommandSelection[] selections,
                                          string[] modified_option_ids = {},
                                          string[] adapter_diagnostics = {},
                                          LaunchCommandCapabilityContext? capabilities = null,
                                          bool explicit_clear = false,
                                          bool retain_placeholder_for_arguments_only = false) {
            Object ();
            this.parsed = parsed;
            this.selections = selections;
            this.modified_option_ids = modified_option_ids;
            this.adapter_diagnostics = adapter_diagnostics;
            this.capabilities = capabilities;
            this.explicit_clear = explicit_clear;
            this.retain_placeholder_for_arguments_only = retain_placeholder_for_arguments_only;
        }
    }

    class CustomArgumentReplacements : Object {
        public HashMap<int, string> anchored { get; private set; }
        public ArrayList<string> additions { get; private set; }

        public CustomArgumentReplacements () {
            anchored = new HashMap<int, string> ();
            additions = new ArrayList<string> ();
        }
    }

    public class LaunchCommandWriter : Object {
        LaunchOptionCatalog catalog;
        LaunchCommandComposer composer;
        LaunchCommandParser parser;
        LaunchOptionCapabilityResolver capability_resolver;

        public LaunchCommandWriter (LaunchOptionCatalog? catalog = null,
                                    LaunchCommandComposer? composer = null,
                                    LaunchCommandParser? parser = null) {
            this.catalog = catalog ?? new LaunchOptionCatalog ();
            this.composer = composer ?? new LaunchCommandComposer (this.catalog);
            this.parser = parser ?? new LaunchCommandParser (this.catalog);
            this.capability_resolver = new LaunchOptionCapabilityResolver (this.catalog);
        }

        public LaunchCommandWriteResult prepare (LaunchCommandWriteRequest request) {
            var changed = new HashSet<string> ();
            foreach (var id in request.modified_option_ids) changed.add (id);

            if (changed.size == 0 && !request.explicit_clear)
                return new LaunchCommandWriteResult (request.parsed.is_structurally_safe
                    ? LaunchCommandWriteStatus.UNCHANGED_PRISTINE_SOURCE
                    : LaunchCommandWriteStatus.UNCHANGED_UNMANAGED_SOURCE,
                    request.parsed, true, false, request.parsed.original_input);

            if (request.adapter_diagnostics.length > 0) {
                var blocked = new LaunchCommandWriteResult (LaunchCommandWriteStatus.INCOMPLETE_ADAPTER_COVERAGE, request.parsed);
                foreach (var diagnostic in request.adapter_diagnostics) blocked.writer_diagnostics.add (diagnostic);
                return blocked;
            }

            if (requires_context (request.selections) && request.capabilities == null) {
                var blocked = new LaunchCommandWriteResult (LaunchCommandWriteStatus.CAPABILITY_CONTEXT_REQUIRED, request.parsed);
                blocked.writer_diagnostics.add ("A runtime capability context is required before launch options can be saved.");
                return blocked;
            }

            if (!request.explicit_clear && !safe_to_merge (request.parsed, changed)) {
                var blocked = new LaunchCommandWriteResult (LaunchCommandWriteStatus.BLOCKED_UNSAFE_SOURCE, request.parsed);
                blocked.writer_diagnostics.add ("Custom shell content cannot be merged safely.");
                return blocked;
            }

            foreach (var selection in request.selections) {
                var metadata = catalog.lookup (selection.option_id);
                if (metadata == null)
                    continue;
                var eligibility = capability_resolver.evaluate_selection (metadata, selection,
                    request.capabilities, false);
                if (!eligibility.may_activate) {
                    var blocked = new LaunchCommandWriteResult (
                        LaunchCommandWriteStatus.BLOCKED_INVALID_SELECTIONS, request.parsed);
                    blocked.writer_diagnostics.add (eligibility.reason);
                    return blocked;
                }
            }

            var composed = composer.compose (new LaunchCommandCompositionRequest (
                request.selections, request.capabilities ?? new LaunchCommandCapabilityContext (),
                request.retain_placeholder_for_arguments_only));
            if (!composed.is_valid) {
                var blocked = new LaunchCommandWriteResult (LaunchCommandWriteStatus.BLOCKED_INVALID_SELECTIONS, request.parsed);
                foreach (var diagnostic in composed.diagnostics) blocked.composition_diagnostics.add (diagnostic);
                return blocked;
            }

            /* Clear is a full-source replacement session, not a one-shot empty
             * return. If the user enables options after clearing, compose the
             * complete new command without merging any old raw content back. */
            if (request.explicit_clear) {
                var replacement = new LaunchCommandWriteResult (
                    LaunchCommandWriteStatus.SOURCE_PRESERVING_MANAGED_MERGE,
                    request.parsed, true,
                    composed.launch_line != request.parsed.original_input,
                    composed.launch_line
                );
                foreach (var id in request.modified_option_ids)
                    replacement.modified_option_ids.add (id);
                foreach (var diagnostic in composed.diagnostics)
                    replacement.composition_diagnostics.add (diagnostic);
                return replacement;
            }

            /* Dynamic custom arguments are merged from their source anchors.
             * Exclude them from the generated semantic skeleton so raw values
             * such as FOO=bar or an unknown wrapper cannot be reclassified and
             * hide otherwise managed game arguments during the second parse. */
            var generated_composition = composer.compose (new LaunchCommandCompositionRequest (
                without_dynamic_game_arguments (request.selections),
                request.capabilities ?? new LaunchCommandCapabilityContext (),
                request.retain_placeholder_for_arguments_only
            ));
            var generated = parser.parse (generated_composition.launch_line);
            var custom_arguments = collect_custom_argument_replacements (
                request.parsed, request.selections, changed
            );
            var launch_line = only_dynamic_game_arguments_changed (changed)
                ? merge_custom_arguments_in_source (request.parsed, custom_arguments)
                : merge (request.parsed, generated, changed, custom_arguments);
            var result = new LaunchCommandWriteResult (
                request.parsed.original_input == "" ? LaunchCommandWriteStatus.FRESH_MANAGED_OUTPUT
                                                     : LaunchCommandWriteStatus.SOURCE_PRESERVING_MANAGED_MERGE,
                request.parsed, true, launch_line != request.parsed.original_input, launch_line);
            foreach (var id in request.modified_option_ids) result.modified_option_ids.add (id);
            foreach (var diagnostic in composed.diagnostics) result.composition_diagnostics.add (diagnostic);
            record_spans (result, request.parsed, changed);
            return result;
        }

        /* Batch editing supplies one logical intent but every Steam game owns
         * its source text.  Keep parsing here so callers cannot accidentally
         * reuse a result prepared for a different game. */
        public LaunchCommandWriteResult prepare_source (string source,
                                                         LaunchCommandSelection[] selections,
                                                         string[] modified_option_ids = {},
                                                         string[] adapter_diagnostics = {},
                                                         LaunchCommandCapabilityContext? capabilities = null,
                                                         bool explicit_clear = false,
                                                         bool retain_placeholder_for_arguments_only = false) {
            var parsed = parser.parse (source);
            if (!explicit_clear && parsed.command_boundary_indexes.size == 1
                && parsed.command_boundary_indexes[0] == 0)
                retain_placeholder_for_arguments_only = true;
            return prepare (new LaunchCommandWriteRequest (parsed, selections,
                modified_option_ids, adapter_diagnostics, capabilities, explicit_clear,
                retain_placeholder_for_arguments_only));
        }

        bool requires_context (LaunchCommandSelection[] selections) {
            foreach (var selection in selections) {
                var metadata = catalog.lookup (selection.option_id);
                if (metadata == null || metadata.semantics == null) continue;
                if (metadata.semantics.get_required_capabilities ().length > 0
                    || (metadata.semantics.kind == LaunchOptionSemanticKind.WRAPPER_SELECTOR
                        && selection.wrapper_id != "")) return true;
            }
            return false;
        }

        LaunchCommandSelection[] without_dynamic_game_arguments (
            LaunchCommandSelection[] selections
        ) {
            var filtered = new ArrayList<LaunchCommandSelection> ();
            foreach (var selection in selections) {
                var metadata = catalog.lookup (selection.option_id);
                if (metadata != null && metadata.semantics != null
                    && metadata.semantics.kind == LaunchOptionSemanticKind.GAME_ARGUMENT
                    && metadata.semantics.emission_mode == LaunchOptionEmissionMode.DYNAMIC_GAME_ARGUMENTS)
                    continue;
                filtered.add (selection);
            }
            return filtered.to_array ();
        }

        bool safe_to_merge (LaunchCommandParseResult parsed, HashSet<string> changed) {
            if (parsed.command_boundary_indexes.size > 1)
                return false;
            var only_custom_arguments_changed = only_dynamic_game_arguments_changed (changed);
            if (only_custom_arguments_changed && has_custom_argument_source (parsed))
                return true;
            for (var index = 0; index < parsed.tokens.size; index++) {
                if (parsed.tokens[index].is_opaque
                    && !parsed.is_preserved_game_argument_index (index))
                    return false;
            }
            foreach (var diagnostic in parsed.diagnostics) {
                if (diagnostic.code == LaunchCommandParseDiagnosticCode.UNSAFE_SHELL_TOKEN
                    && parsed.is_preserved_game_argument_index (diagnostic.token_index))
                    continue;
                if (diagnostic.code != LaunchCommandParseDiagnosticCode.MISSING_COMMAND_BOUNDARY)
                    return false;
                if (parsed.wrappers.size > 0 || has_environment_occurrence (parsed))
                    return false;
            }
            var environment_keys = new HashSet<string> ();
            foreach (var occurrence in parsed.occurrences) {
                if (!is_environment (occurrence)) continue;
                if (environment_keys.contains (occurrence.environment_key)) return false;
                environment_keys.add (occurrence.environment_key);
            }
            foreach (var token in parsed.unrecognized_tokens) {
                if (token.kind != LaunchCommandUnrecognizedKind.UNKNOWN_ENVIRONMENT_ASSIGNMENT) continue;
                var key = environment_key (token.token.value);
                if (key == "" || environment_keys.contains (key)) return false;
                environment_keys.add (key);
            }
            foreach (var token in parsed.unrecognized_tokens) {
                if (token.kind != LaunchCommandUnrecognizedKind.PRESERVED_GAME_COMMAND_CONTENT
                    && token.kind != LaunchCommandUnrecognizedKind.UNKNOWN_ENVIRONMENT_ASSIGNMENT
                    && !parsed.is_custom_game_argument_index (token.token_index))
                    return false;
            }
            foreach (var occurrence in parsed.occurrences) {
                foreach (var index in occurrence.token_indexes) {
                    if (changed.contains (occurrence.option_id)) continue;
                    if (index < 0 || index >= parsed.tokens.size) return false;
                }
            }
            return true;
        }

        bool only_dynamic_game_arguments_changed (HashSet<string> changed) {
            if (changed.size == 0)
                return false;
            foreach (var id in changed) {
                var metadata = catalog.lookup (id);
                if (metadata == null || metadata.semantics == null
                    || metadata.semantics.kind != LaunchOptionSemanticKind.GAME_ARGUMENT
                    || metadata.semantics.emission_mode != LaunchOptionEmissionMode.DYNAMIC_GAME_ARGUMENTS)
                    return false;
            }
            return true;
        }

        bool has_custom_argument_source (LaunchCommandParseResult parsed) {
            for (var index = 0; index < parsed.tokens.size; index++)
                if (parsed.is_custom_game_argument_index (index)) return true;
            return false;
        }

        bool has_environment_occurrence (LaunchCommandParseResult parsed) {
            foreach (var occurrence in parsed.occurrences)
                if (is_environment (occurrence)) return true;
            return false;
        }

        string environment_key (string value) {
            var separator = value.index_of_char ('=');
            return separator > 0 ? value.substring (0, separator) : "";
        }

        CustomArgumentReplacements collect_custom_argument_replacements (
            LaunchCommandParseResult parsed, LaunchCommandSelection[] selections,
            HashSet<string> changed
        ) {
            var replacements = new CustomArgumentReplacements ();
            foreach (var selection in selections) {
                var metadata = catalog.lookup (selection.option_id);
                if (metadata == null || metadata.semantics == null
                    || metadata.semantics.kind != LaunchOptionSemanticKind.GAME_ARGUMENT
                    || metadata.semantics.emission_mode != LaunchOptionEmissionMode.DYNAMIC_GAME_ARGUMENTS
                    || !changed.contains (selection.option_id))
                    continue;
                var values = selection.get_values ();
                for (var position = 0; position < values.length; position++) {
                    var raw = selection.values_are_serialized
                        ? values[position] : LaunchCommandComposer.shell_word (values[position]);
                    var anchors_match_source = selection.value_source_identity == ""
                        || selection.value_source_identity == parsed.original_input;
                    var source_index = anchors_match_source
                        ? selection.get_value_source_index (position) : -1;
                    if (source_index >= 0)
                        replacements.anchored.set (source_index, raw);
                    else
                        replacements.additions.add (raw);
                }
            }
            return replacements;
        }

        string merge_custom_arguments_in_source (
            LaunchCommandParseResult source, CustomArgumentReplacements replacements
        ) {
            var output = new ArrayList<string> ();
            for (var index = 0; index < source.tokens.size; index++) {
                if (!source.is_custom_game_argument_index (index)) {
                    output.add (source.tokens[index].raw);
                    continue;
                }
                if (replacements.anchored.has_key (index))
                    output.add (replacements.anchored.get (index));
            }
            foreach (var addition in replacements.additions)
                output.add (addition);
            return string.joinv (" ", output.to_array ());
        }

        string merge (LaunchCommandParseResult source, LaunchCommandParseResult generated,
                      HashSet<string> changed, CustomArgumentReplacements custom_arguments) {
            var source_boundary = source.command_boundary_indexes.size == 1
                ? source.command_boundary_indexes[0] : -1;
            var generated_boundary = generated.command_boundary_indexes.size == 1
                ? generated.command_boundary_indexes[0] : -1;
            var output = new ArrayList<string> ();
            var emitted = new HashSet<string> ();
            var replace_unrecognized_arguments = has_changed_dynamic_game_arguments (changed);

            /* Keep unrecognized environment assignments in their source order
             * and apply source-anchored custom edits without normalizing them. */
            for (var index = 0; index < source.tokens.size; index++) {
                if (source_boundary < 0) break;
                if (source_boundary >= 0 && index >= source_boundary) break;
                var occurrence = occurrence_at (source, index);
                if (occurrence != null && output_role_at (source, index) == Region.ENVIRONMENT
                    && !changed.contains (occurrence.option_id))
                    output.add (source.tokens[index].raw);
                else if (unrecognized_environment_at (source, index))
                    append_source_custom_argument (
                        output, source, index, custom_arguments, replace_unrecognized_arguments
                    );
            }
            append_generated_region (output, generated, 0, generated_boundary, changed, emitted, Region.ENVIRONMENT);

            /* A safe, unrecognized pre-command word may be a user-provided
             * wrapper such as `game-performance`. It is editable through the
             * custom-argument list, so keep it source-anchored while managed
             * environments and wrappers are changed around it. */
            if (source_boundary >= 0) {
                for (var index = 0; index < source_boundary; index++) {
                    if (!source.is_custom_game_argument_index (index)
                        || unrecognized_environment_at (source, index)
                        || is_wrapper_token_at (source, index))
                        continue;
                    append_source_custom_argument (
                        output, source, index, custom_arguments, replace_unrecognized_arguments
                    );
                }
            }

            bool rebuild_wrappers = has_changed_wrapper (changed);
            if (!rebuild_wrappers) {
                for (var index = 0; index < source.tokens.size; index++) {
                    if (source_boundary >= 0 && index >= source_boundary) break;
                    if (!is_wrapper_token_at (source, index)) continue;
                    if (source.is_custom_game_argument_index (index))
                        append_source_custom_argument (
                            output, source, index, custom_arguments, replace_unrecognized_arguments
                        );
                    else
                        output.add (source.tokens[index].raw);
                }
            } else {
                append_merged_wrappers (
                    output, source, generated, changed, emitted,
                    custom_arguments, replace_unrecognized_arguments
                );
            }

            bool needs_boundary = output.size > 0 || generated_boundary >= 0
                || (source_boundary == 0 && !has_changed_game_arguments (changed));
            if (needs_boundary) output.add ("%command%");

            for (var index = source_boundary >= 0 ? source_boundary + 1 : 0;
                 index < source.tokens.size; index++) {
                var occurrence = occurrence_at (source, index);
                if (replace_unrecognized_arguments && source.is_custom_game_argument_index (index)) {
                    append_source_custom_argument (
                        output, source, index, custom_arguments, true
                    );
                    continue;
                }
                if ((occurrence == null || occurrence.semantic_kind == LaunchOptionSemanticKind.GAME_ARGUMENT)
                    && (occurrence == null || !changed.contains (occurrence.option_id)))
                    output.add (source.tokens[index].raw);
            }
            append_generated_region (output, generated, generated_boundary + 1, generated.tokens.size,
                changed, emitted, Region.GAME_ARGUMENT);
            if (replace_unrecognized_arguments) {
                foreach (var addition in custom_arguments.additions)
                    output.add (addition);
            }
            return string.joinv (" ", output.to_array ());
        }

        void append_source_custom_argument (
            ArrayList<string> output, LaunchCommandParseResult source, int index,
            CustomArgumentReplacements replacements, bool replace
        ) {
            if (!replace)
                output.add (source.tokens[index].raw);
            else if (replacements.anchored.has_key (index))
                output.add (replacements.anchored.get (index));
        }

        enum Region { ENVIRONMENT, WRAPPER, GAME_ARGUMENT }

        void append_generated_region (ArrayList<string> output, LaunchCommandParseResult generated,
                                      int start, int end, HashSet<string> changed,
                                      HashSet<string> emitted, Region region, bool include_all = false) {
            if (start < 0) start = 0;
            for (var index = start; index < end; index++) {
                var occurrence = occurrence_at (generated, index);
                if (output_role_at (generated, index) != region)
                    continue;
                if (include_all && region == Region.WRAPPER) {
                    /* Ownership is structural, not option-kind based.  A
                     * composite option may produce both an environment token
                     * and a wrapper argument, but each source index has one
                     * role and therefore one output region. */
                    output.add (generated.tokens[index].raw);
                    emitted.add ("token:%d".printf (index));
                    continue;
                }
                if (occurrence == null) continue;
                if (!include_all && !changed.contains (occurrence.option_id)) continue;
                var key = "token:%d".printf (index);
                if (emitted.contains (key)) continue;
                output.add (generated.tokens[index].raw);
                emitted.add (key);
            }
        }

        Region output_role_at (LaunchCommandParseResult parsed, int index) {
            var occurrence = occurrence_at (parsed, index);
            if (occurrence != null) {
                if (occurrence.semantic_kind == LaunchOptionSemanticKind.GAME_ARGUMENT)
                    return Region.GAME_ARGUMENT;
                if (occurrence.semantic_kind == LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT)
                    return Region.ENVIRONMENT;
            }
            var boundary = parsed.command_boundary_indexes.size == 1
                ? parsed.command_boundary_indexes[0] : -1;
            if (boundary >= 0 && index > boundary)
                return Region.GAME_ARGUMENT;
            if (is_wrapper_token_at (parsed, index))
                return Region.WRAPPER;
            return Region.ENVIRONMENT;
        }

        void append_merged_wrappers (ArrayList<string> output, LaunchCommandParseResult source,
                                     LaunchCommandParseResult generated, HashSet<string> changed,
                                     HashSet<string> emitted,
                                     CustomArgumentReplacements custom_arguments,
                                     bool replace_custom_arguments) {
            /* The catalog is ordered by nesting priority.  Select one raw
             * invocation for each wrapper identity: unchanged source first,
             * otherwise the generated replacement.  This keeps independent
             * wrappers and their unknown arguments while replacing only the
             * changed backend or wrapper. */
            foreach (var definition in catalog.get_wrappers ()) {
                var source_invocation = wrapper_invocation (source, definition.id);
                var generated_invocation = wrapper_invocation (generated, definition.id);
                if (source_invocation != null && !wrapper_changed (definition.id, changed)) {
                    append_wrapper_tokens (
                        output, source, source_invocation, emitted,
                        custom_arguments, replace_custom_arguments
                    );
                } else if (generated_invocation != null) {
                    append_wrapper_tokens (
                        output, generated, generated_invocation, emitted,
                        custom_arguments, false
                    );
                }
            }
        }

        LaunchCommandWrapperInvocation? wrapper_invocation (LaunchCommandParseResult parsed, string id) {
            foreach (var invocation in parsed.wrappers)
                if (invocation.wrapper_id == id)
                    return invocation;
            return null;
        }

        void append_wrapper_tokens (ArrayList<string> output, LaunchCommandParseResult parsed,
                                    LaunchCommandWrapperInvocation invocation, HashSet<string> emitted,
                                    CustomArgumentReplacements custom_arguments,
                                    bool replace_custom_arguments) {
            var indexes = new ArrayList<int> ();
            foreach (var index in invocation.executable_indexes) indexes.add (index);
            foreach (var index in invocation.argument_indexes) indexes.add (index);
            if (invocation.delimiter_index >= 0) indexes.add (invocation.delimiter_index);
            indexes.sort ((first, second) => first - second);
            foreach (var index in indexes) {
                var key = "wrapper:%s:%d".printf (parsed.original_input, index);
                if (!emitted.contains (key)) {
                    if (parsed.is_custom_game_argument_index (index))
                        append_source_custom_argument (
                            output, parsed, index, custom_arguments, replace_custom_arguments
                        );
                    else
                        output.add (parsed.tokens[index].raw);
                    emitted.add (key);
                }
            }
        }

        bool wrapper_changed (string wrapper_id, HashSet<string> changed) {
            foreach (var id in changed) {
                var metadata = catalog.lookup (id);
                if (metadata == null || metadata.semantics == null)
                    continue;
                var semantics = metadata.semantics;
                if (semantics.wrapper_id == wrapper_id)
                    return true;
                if (semantics.kind == LaunchOptionSemanticKind.WRAPPER_SELECTOR
                    && contains (semantics.selectable_wrapper_ids, wrapper_id))
                    return true;
            }
            return false;
        }

        bool contains (string[] values, string candidate) {
            foreach (var value in values)
                if (value == candidate) return true;
            return false;
        }

        bool is_environment (LaunchCommandOptionOccurrence occurrence) {
            return occurrence.semantic_kind == LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT;
        }

        bool has_changed_wrapper (HashSet<string> changed) {
            foreach (var id in changed) {
                var metadata = catalog.lookup (id);
                if (metadata == null || metadata.semantics == null) continue;
                var kind = metadata.semantics.kind;
                if (kind == LaunchOptionSemanticKind.PREFIX_WRAPPER || kind == LaunchOptionSemanticKind.DELIMITED_WRAPPER
                    || kind == LaunchOptionSemanticKind.WRAPPER_SELECTOR || kind == LaunchOptionSemanticKind.WRAPPER_ARGUMENT
                    || metadata.semantics.wrapper_id != "") return true;
            }
            return false;
        }

        bool has_changed_game_arguments (HashSet<string> changed) {
            foreach (var id in changed) {
                var metadata = catalog.lookup (id);
                if (metadata != null && metadata.semantics != null
                    && metadata.semantics.kind == LaunchOptionSemanticKind.GAME_ARGUMENT) return true;
            }
            return false;
        }

        bool has_changed_dynamic_game_arguments (HashSet<string> changed) {
            foreach (var id in changed) {
                var metadata = catalog.lookup (id);
                if (metadata != null && metadata.semantics != null
                    && metadata.semantics.kind == LaunchOptionSemanticKind.GAME_ARGUMENT
                    && metadata.semantics.emission_mode == LaunchOptionEmissionMode.DYNAMIC_GAME_ARGUMENTS)
                    return true;
            }
            return false;
        }

        LaunchCommandOptionOccurrence? occurrence_at (LaunchCommandParseResult parsed, int index) {
            foreach (var occurrence in parsed.occurrences)
                foreach (var owned in occurrence.token_indexes)
                    if (owned == index) return occurrence;
            return null;
        }

        bool unrecognized_environment_at (LaunchCommandParseResult parsed, int index) {
            foreach (var token in parsed.unrecognized_tokens)
                if (token.token_index == index
                    && token.kind == LaunchCommandUnrecognizedKind.UNKNOWN_ENVIRONMENT_ASSIGNMENT) return true;
            return false;
        }

        bool is_wrapper_token_at (LaunchCommandParseResult parsed, int index) {
            foreach (var wrapper in parsed.wrappers) {
                foreach (var executable in wrapper.executable_indexes)
                    if (executable == index) return true;
                if (wrapper.delimiter_index == index) return true;
                foreach (var argument in wrapper.argument_indexes)
                    if (argument == index) return true;
            }
            return false;
        }

        void record_spans (LaunchCommandWriteResult result, LaunchCommandParseResult parsed,
                           HashSet<string> changed) {
            for (var index = 0; index < parsed.tokens.size; index++) {
                var occurrence = occurrence_at (parsed, index);
                if (occurrence != null && changed.contains (occurrence.option_id))
                    result.replaced_token_spans.add (index);
                else result.preserved_token_spans.add (index);
            }
        }
    }
}
