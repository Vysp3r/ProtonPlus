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

    public class LaunchCommandWriter : Object {
        LaunchOptionCatalog catalog;
        LaunchCommandComposer composer;
        LaunchCommandParser parser;

        public LaunchCommandWriter (LaunchOptionCatalog? catalog = null,
                                    LaunchCommandComposer? composer = null,
                                    LaunchCommandParser? parser = null) {
            this.catalog = catalog ?? new LaunchOptionCatalog ();
            this.composer = composer ?? new LaunchCommandComposer (this.catalog);
            this.parser = parser ?? new LaunchCommandParser (this.catalog);
        }

        public LaunchCommandWriteResult prepare (LaunchCommandWriteRequest request) {
            var changed = new HashSet<string> ();
            foreach (var id in request.modified_option_ids) changed.add (id);

            if (changed.size == 0 && !request.explicit_clear)
                return new LaunchCommandWriteResult (request.parsed.is_structurally_safe
                    ? LaunchCommandWriteStatus.UNCHANGED_PRISTINE_SOURCE
                    : LaunchCommandWriteStatus.UNCHANGED_UNMANAGED_SOURCE,
                    request.parsed, true, false, request.parsed.original_input);

            if (request.explicit_clear) {
                var clear = new LaunchCommandWriteResult (LaunchCommandWriteStatus.SOURCE_PRESERVING_MANAGED_MERGE,
                    request.parsed, true, request.parsed.original_input != "", "");
                foreach (var id in request.modified_option_ids) clear.modified_option_ids.add (id);
                return clear;
            }

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

            if (!safe_to_merge (request.parsed, changed)) {
                var blocked = new LaunchCommandWriteResult (LaunchCommandWriteStatus.BLOCKED_UNSAFE_SOURCE, request.parsed);
                blocked.writer_diagnostics.add ("Custom shell content cannot be merged safely.");
                return blocked;
            }

            var composed = composer.compose (new LaunchCommandCompositionRequest (
                request.selections, request.capabilities ?? new LaunchCommandCapabilityContext (),
                request.retain_placeholder_for_arguments_only));
            if (!composed.is_valid) {
                var blocked = new LaunchCommandWriteResult (LaunchCommandWriteStatus.BLOCKED_INVALID_SELECTIONS, request.parsed);
                foreach (var diagnostic in composed.diagnostics) blocked.composition_diagnostics.add (diagnostic);
                return blocked;
            }

            var generated = parser.parse (composed.launch_line);
            var result = new LaunchCommandWriteResult (
                request.parsed.original_input == "" ? LaunchCommandWriteStatus.FRESH_MANAGED_OUTPUT
                                                     : LaunchCommandWriteStatus.SOURCE_PRESERVING_MANAGED_MERGE,
                request.parsed, true, true, merge (request.parsed, generated, changed));
            foreach (var id in request.modified_option_ids) result.modified_option_ids.add (id);
            foreach (var diagnostic in composed.diagnostics) result.composition_diagnostics.add (diagnostic);
            record_spans (result, request.parsed, changed);
            return result;
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

        bool safe_to_merge (LaunchCommandParseResult parsed, HashSet<string> changed) {
            if (parsed.opaque_tokens.size > 0 || parsed.command_boundary_indexes.size > 1)
                return false;
            foreach (var diagnostic in parsed.diagnostics) {
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
                    && token.kind != LaunchCommandUnrecognizedKind.UNKNOWN_ENVIRONMENT_ASSIGNMENT)
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

        bool has_environment_occurrence (LaunchCommandParseResult parsed) {
            foreach (var occurrence in parsed.occurrences)
                if (is_environment (occurrence)) return true;
            return false;
        }

        string environment_key (string value) {
            var separator = value.index_of_char ('=');
            return separator > 0 ? value.substring (0, separator) : "";
        }

        string merge (LaunchCommandParseResult source, LaunchCommandParseResult generated,
                      HashSet<string> changed) {
            if (source.original_input == "") return generated.original_input;

            var source_boundary = source.command_boundary_indexes.size == 1
                ? source.command_boundary_indexes[0] : -1;
            var generated_boundary = generated.command_boundary_indexes.size == 1
                ? generated.command_boundary_indexes[0] : -1;
            var output = new ArrayList<string> ();
            var emitted = new HashSet<string> ();

            /* Environment assignments are the only unrecognised pre-boundary
             * words admitted by the merge.  Keep their raw spelling and order. */
            for (var index = 0; index < source.tokens.size; index++) {
                if (source_boundary >= 0 && index >= source_boundary) break;
                var occurrence = occurrence_at (source, index);
                if (occurrence != null && is_environment (occurrence) && !changed.contains (occurrence.option_id))
                    output.add (source.tokens[index].raw);
                else if (unrecognized_environment_at (source, index))
                    output.add (source.tokens[index].raw);
            }
            append_generated_region (output, generated, 0, generated_boundary, changed, emitted, Region.ENVIRONMENT);

            bool rebuild_wrappers = has_changed_wrapper (changed);
            if (!rebuild_wrappers) {
                for (var index = 0; index < source.tokens.size; index++) {
                    if (source_boundary >= 0 && index >= source_boundary) break;
                    if (is_wrapper_token_at (source, index)) output.add (source.tokens[index].raw);
                }
            } else {
                append_generated_region (output, generated, 0, generated_boundary, changed, emitted, Region.WRAPPER, true);
            }

            bool needs_boundary = output.size > 0 || generated_boundary >= 0
                || (source_boundary == 0 && !has_changed_game_arguments (changed));
            if (needs_boundary) output.add ("%command%");

            for (var index = source_boundary >= 0 ? source_boundary + 1 : 0;
                 index < source.tokens.size; index++) {
                var occurrence = occurrence_at (source, index);
                if ((occurrence == null || occurrence.semantic_kind == LaunchOptionSemanticKind.GAME_ARGUMENT)
                    && (occurrence == null || !changed.contains (occurrence.option_id)))
                    output.add (source.tokens[index].raw);
            }
            append_generated_region (output, generated, generated_boundary + 1, generated.tokens.size,
                changed, emitted, Region.GAME_ARGUMENT);
            return string.joinv (" ", output.to_array ());
        }

        enum Region { ENVIRONMENT, WRAPPER, GAME_ARGUMENT }

        void append_generated_region (ArrayList<string> output, LaunchCommandParseResult generated,
                                      int start, int end, HashSet<string> changed,
                                      HashSet<string> emitted, Region region, bool include_all = false) {
            if (start < 0) start = 0;
            for (var index = start; index < end; index++) {
                var occurrence = occurrence_at (generated, index);
                if (include_all && region == Region.WRAPPER) {
                    if (occurrence == null || !is_environment (occurrence))
                        output.add (generated.tokens[index].raw);
                    continue;
                }
                if (occurrence == null) continue;
                if (!include_all && !changed.contains (occurrence.option_id)) continue;
                if (!belongs_to (occurrence, region)) continue;
                var key = "%s:%d".printf (occurrence.option_id, index);
                if (emitted.contains (key)) continue;
                output.add (generated.tokens[index].raw);
                emitted.add (key);
            }
        }

        bool belongs_to (LaunchCommandOptionOccurrence occurrence, Region region) {
            switch (region) {
            case Region.ENVIRONMENT:
                return is_environment (occurrence) || occurrence.semantic_kind == LaunchOptionSemanticKind.COMPOSITE_DYNAMIC;
            case Region.WRAPPER:
                return occurrence.semantic_kind == LaunchOptionSemanticKind.PREFIX_WRAPPER
                    || occurrence.semantic_kind == LaunchOptionSemanticKind.DELIMITED_WRAPPER
                    || occurrence.semantic_kind == LaunchOptionSemanticKind.WRAPPER_SELECTOR
                    || occurrence.semantic_kind == LaunchOptionSemanticKind.WRAPPER_ARGUMENT
                    || occurrence.semantic_kind == LaunchOptionSemanticKind.COMPOSITE_DYNAMIC;
            case Region.GAME_ARGUMENT:
                return occurrence.semantic_kind == LaunchOptionSemanticKind.GAME_ARGUMENT;
            }
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
