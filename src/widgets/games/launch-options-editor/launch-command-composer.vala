namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

    /* This is deliberately a UI-free input model. Values are logical values,
     * never preassembled launch-command fragments. */
    public class LaunchCommandSelection : Object {
        public string option_id { get; construct; }
        string[] _values;
        public string wrapper_id { get; construct; }
        string[] _additional_wrapper_arguments;

        public LaunchCommandSelection (
            string option_id, string[] values = {}, string wrapper_id = "",
            string[] additional_wrapper_arguments = {}
        ) {
            Object (option_id: option_id, wrapper_id: wrapper_id);
            _values = values;
            _additional_wrapper_arguments = additional_wrapper_arguments;
        }

        public string[] get_values () { return _values; }
        public string[] get_additional_wrapper_arguments () { return _additional_wrapper_arguments; }
    }

    public class LaunchCommandCapabilityContext : Object {
        LaunchOptionCapability[] _capabilities;

        public LaunchCommandCapabilityContext (LaunchOptionCapability[] capabilities = {}) {
            _capabilities = capabilities;
        }

        public bool has (LaunchOptionCapability capability) {
            foreach (var candidate in _capabilities) {
                if (candidate == capability)
                    return true;
            }
            return false;
        }
    }

    public class LaunchCommandCompositionRequest : Object {
        LaunchCommandSelection[] _selections;
        public LaunchCommandCapabilityContext capabilities { get; construct; }
        public bool retain_placeholder_for_arguments_only { get; construct; }

        public LaunchCommandCompositionRequest (
            LaunchCommandSelection[] selections,
            LaunchCommandCapabilityContext capabilities,
            bool retain_placeholder_for_arguments_only = false
        ) {
            Object (
                capabilities: capabilities,
                retain_placeholder_for_arguments_only: retain_placeholder_for_arguments_only
            );
            _selections = selections;
        }

        public string[] get_selections_ids () {
            var ids = new ArrayList<string> ();
            foreach (var selection in _selections)
                ids.add (selection.option_id);
            return ids.to_array ();
        }

        public LaunchCommandSelection[] get_selections () { return _selections; }
    }

    public enum LaunchCommandCompositionDiagnosticCode {
        UNKNOWN_OPTION_ID,
        DUPLICATE_OPTION_SELECTION,
        OPTION_NOT_ELIGIBLE_FOR_MANAGED_EMISSION,
        MISSING_REQUIRED_CAPABILITY,
        MISSING_DEPENDENCY,
        EXPLICIT_OPTION_CONFLICT,
        CONFLICT_GROUP_COLLISION,
        INVALID_WRAPPER_SELECTION,
        MUTUALLY_EXCLUSIVE_WRAPPERS,
        DUPLICATE_WRAPPER,
        WRAPPER_ARGUMENT_WITHOUT_WRAPPER,
        WRAPPER_ARGUMENT_OWNED_BY_WRONG_WRAPPER,
        MISSING_DYNAMIC_VALUE,
        UNEXPECTED_DYNAMIC_VALUE,
        INVALID_VALUE_COUNT,
        UNSUPPORTED_SELECTABLE_VALUE,
        DUPLICATE_ENVIRONMENT_KEY,
        EMPTY_OR_UNSAFE_ARGUMENT,
        EMBEDDED_COMMAND_PLACEHOLDER,
        INVALID_COMPOSITE_OUTPUT,
        INVALID_CATALOG_DEFINITION,
        UNMANAGED_PARSED_CONTENT,
        WRAPPER_NESTING_VIOLATION
    }

    public class LaunchCommandCompositionDiagnostic : Object {
        public LaunchCommandCompositionDiagnosticCode code { get; construct; }
        public string option_id { get; construct; }
        public string message { get; construct; }

        public LaunchCommandCompositionDiagnostic (
            LaunchCommandCompositionDiagnosticCode code, string option_id, string message
        ) {
            Object (code: code, option_id: option_id, message: message);
        }
    }

    public class LaunchCommandCompositionResult : Object {
        public bool is_valid { get; construct; }
        public Gee.List<LaunchCommandCompositionDiagnostic> diagnostics { get; construct; }
        public LaunchCommandPlan? plan { get; construct; }
        public LaunchCommandBuildResult? build_result { get; construct; }
        public string launch_line { get; construct; }

        public LaunchCommandCompositionResult (
            bool is_valid, Gee.List<LaunchCommandCompositionDiagnostic> diagnostics,
            LaunchCommandPlan? plan = null, LaunchCommandBuildResult? build_result = null
        ) {
            Object (
                is_valid: is_valid, diagnostics: diagnostics, plan: plan,
                build_result: build_result,
                launch_line: is_valid && build_result != null ? build_result.launch_line : ""
            );
        }
    }

    public class LaunchCommandComposer : Object {
        LaunchOptionCatalog catalog;
        LaunchCommandBuilder builder;

        public LaunchCommandComposer (LaunchOptionCatalog? catalog = null, LaunchCommandBuilder? builder = null) {
            this.catalog = catalog ?? new LaunchOptionCatalog ();
            this.builder = builder ?? new LaunchCommandBuilder ();
        }

        public LaunchCommandCompositionResult compose (LaunchCommandCompositionRequest request) {
            var diagnostics = new ArrayList<LaunchCommandCompositionDiagnostic> ();
            foreach (var issue in catalog.validate ())
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.INVALID_CATALOG_DEFINITION, "", issue);
            if (diagnostics.size > 0)
                return invalid (diagnostics);

            var selections = request.get_selections ();
            var selected_ids = new HashSet<string> ();
            var selected_wrappers = new HashMap<string, LaunchWrapperDefinition> ();
            var wrapper_arguments = new HashMap<string, ArrayList<string>> ();
            var environments = new ArrayList<LaunchEnvironmentAssignment> ();
            var game_arguments = new ArrayList<string> ();

            foreach (var selection in selections) {
                var metadata = catalog.lookup (selection.option_id);
                if (metadata == null || metadata.semantics == null) {
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.UNKNOWN_OPTION_ID, selection.option_id,
                        "Unknown launch option '%s'.".printf (selection.option_id));
                    continue;
                }
                var semantics = metadata.semantics;
                if (selected_ids.contains (selection.option_id))
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.DUPLICATE_OPTION_SELECTION, selection.option_id,
                        "Launch option '%s' was selected more than once.".printf (selection.option_id));
                selected_ids.add (selection.option_id);
                if (!semantics.managed_emission || semantics.kind == LaunchOptionSemanticKind.COMMAND_BOUNDARY
                    || semantics.kind == LaunchOptionSemanticKind.OPAQUE_CONTEXT_DEPENDENT) {
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.OPTION_NOT_ELIGIBLE_FOR_MANAGED_EMISSION, selection.option_id,
                        "Launch option '%s' is not eligible for managed emission.".printf (selection.option_id));
                    continue;
                }
                validate_capabilities (diagnostics, selection.option_id, semantics.get_required_capabilities (), request.capabilities);
                if (semantics.kind == LaunchOptionSemanticKind.WRAPPER_SELECTOR) {
                    add_selected_wrapper (diagnostics, selection.option_id, selection.wrapper_id,
                        semantics.selectable_wrapper_ids, request.capabilities, selected_wrappers);
                    append_safe_arguments (diagnostics, selection.option_id, selection.wrapper_id,
                        selection.get_additional_wrapper_arguments (), wrapper_arguments);
                    validate_no_values (diagnostics, selection, semantics);
                } else if (semantics.kind == LaunchOptionSemanticKind.PREFIX_WRAPPER
                           || semantics.kind == LaunchOptionSemanticKind.DELIMITED_WRAPPER) {
                    add_selected_wrapper (diagnostics, selection.option_id, semantics.wrapper_id,
                        { semantics.wrapper_id }, request.capabilities, selected_wrappers);
                    append_safe_arguments (diagnostics, selection.option_id, semantics.wrapper_id,
                        selection.get_additional_wrapper_arguments (), wrapper_arguments);
                    validate_no_values (diagnostics, selection, semantics);
                } else if (semantics.kind == LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT) {
                    append_environment (diagnostics, selection, semantics, environments);
                    validate_no_additional_arguments (diagnostics, selection);
                } else if (semantics.kind == LaunchOptionSemanticKind.WRAPPER_ARGUMENT) {
                    append_wrapper_argument (diagnostics, selection, semantics, wrapper_arguments);
                    validate_no_additional_arguments (diagnostics, selection);
                } else if (semantics.kind == LaunchOptionSemanticKind.GAME_ARGUMENT) {
                    if (semantics.emission_mode == LaunchOptionEmissionMode.DYNAMIC_GAME_ARGUMENTS) {
                        var values = selection.get_values ();
                        if (values.length == 0)
                            add (diagnostics, LaunchCommandCompositionDiagnosticCode.MISSING_DYNAMIC_VALUE,
                                selection.option_id, "Launch option '%s' requires at least one argument.".printf (
                                    selection.option_id));
                        foreach (var value in values) {
                            if (safe (diagnostics, selection.option_id, value))
                                game_arguments.add (shell_word (value));
                        }
                    } else {
                        append_fixed_tokens (diagnostics, selection.option_id,
                            semantics.fixed_tokens, game_arguments);
                        validate_no_values (diagnostics, selection, semantics);
                    }
                    validate_no_additional_arguments (diagnostics, selection);
                } else if (semantics.kind == LaunchOptionSemanticKind.COMPOSITE_DYNAMIC) {
                    append_composite (diagnostics, selection, semantics, environments, wrapper_arguments);
                    validate_no_additional_arguments (diagnostics, selection);
                }
            }

            validate_relationships (diagnostics, selections, selected_ids, selected_wrappers, request.capabilities);
            validate_environment_keys (diagnostics, environments);
            if (diagnostics.size > 0)
                return invalid (diagnostics);

            var wrappers = new ArrayList<LaunchWrapperInvocation> ();
            foreach (var definition in catalog.get_wrappers ()) {
                if (!selected_wrappers.has_key (definition.id))
                    continue;
                string[] arguments = {};
                if (wrapper_arguments.has_key (definition.id)) {
                    var stored_arguments = wrapper_arguments.get (definition.id);
                    if (stored_arguments != null) {
                        arguments = new string[stored_arguments.size];
                        for (var index = 0; index < stored_arguments.size; index++)
                            arguments[index] = stored_arguments[index];
                    }
                }
                wrappers.add (new LaunchWrapperInvocation (definition.id, definition.executable_tokens,
                    arguments, definition.delimiter, (int) definition.nesting_priority));
            }
            var environment_values = new LaunchEnvironmentAssignment[environments.size];
            for (var index = 0; index < environments.size; index++)
                environment_values[index] = environments[index];
            var wrapper_values = new LaunchWrapperInvocation[wrappers.size];
            for (var index = 0; index < wrappers.size; index++)
                wrapper_values[index] = wrappers[index];
            var game_argument_values = new string[game_arguments.size];
            for (var index = 0; index < game_arguments.size; index++)
                game_argument_values[index] = game_arguments[index];
            var plan = new LaunchCommandPlan (environment_values, wrapper_values,
                game_argument_values, request.retain_placeholder_for_arguments_only);
            var build_result = builder.build (plan);
            if (!build_result.is_valid) {
                foreach (var error in build_result.errors)
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.EMPTY_OR_UNSAFE_ARGUMENT, "", error);
                return invalid (diagnostics);
            }
            return new LaunchCommandCompositionResult (true, diagnostics, plan, build_result);
        }

        public Gee.List<LaunchCommandCompositionDiagnostic> validate_parsed (
            LaunchCommandParseResult parsed, LaunchCommandCapabilityContext? capabilities = null
        ) {
            var diagnostics = new ArrayList<LaunchCommandCompositionDiagnostic> ();
            if (!parsed.is_structurally_safe)
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.UNMANAGED_PARSED_CONTENT, "",
                    "Structural parsing found content that cannot be safely managed.");
            var ids = new HashSet<string> ();
            var all_ids = new HashSet<string> ();
            foreach (var occurrence in parsed.occurrences)
                all_ids.add (occurrence.option_id);
            var environment_keys = new HashSet<string> ();
            var conflict_groups = new HashSet<string> ();
            foreach (var occurrence in parsed.occurrences) {
                if (ids.contains (occurrence.option_id))
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.DUPLICATE_OPTION_SELECTION, occurrence.option_id,
                        "Parsed command contains duplicate option '%s'.".printf (occurrence.option_id));
                ids.add (occurrence.option_id);
                if (!occurrence.managed_emission || occurrence.is_legacy)
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.UNMANAGED_PARSED_CONTENT, occurrence.option_id,
                        "Parsed option '%s' cannot be managed.".printf (occurrence.option_id));
                if (occurrence.environment_key != "" && environment_keys.contains (occurrence.environment_key))
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.DUPLICATE_ENVIRONMENT_KEY, occurrence.option_id,
                        "Parsed command contains duplicate environment key '%s'.".printf (occurrence.environment_key));
                environment_keys.add (occurrence.environment_key);
                var metadata = catalog.lookup (occurrence.option_id);
                if (metadata == null || metadata.semantics == null)
                    continue;
                var semantics = metadata.semantics;
                if (capabilities != null)
                    validate_capabilities (diagnostics, occurrence.option_id,
                        semantics.get_required_capabilities (), capabilities);
                foreach (var dependency in semantics.dependencies) {
                    if (!all_ids.contains (dependency))
                        add (diagnostics, LaunchCommandCompositionDiagnosticCode.MISSING_DEPENDENCY, occurrence.option_id,
                            "Parsed option '%s' requires '%s'.".printf (occurrence.option_id, dependency));
                }
                foreach (var conflict in semantics.conflicts) {
                    if (all_ids.contains (conflict))
                        add (diagnostics, LaunchCommandCompositionDiagnosticCode.EXPLICIT_OPTION_CONFLICT, occurrence.option_id,
                            "Parsed option '%s' conflicts with '%s'.".printf (occurrence.option_id, conflict));
                }
                if (semantics.conflict_group != "") {
                    if (conflict_groups.contains (semantics.conflict_group))
                        add (diagnostics, LaunchCommandCompositionDiagnosticCode.CONFLICT_GROUP_COLLISION, occurrence.option_id,
                            "Parsed command has a collision in '%s'.".printf (semantics.conflict_group));
                    conflict_groups.add (semantics.conflict_group);
                }
            }
            var wrapper_ids = new HashSet<string> ();
            var wrapper_groups = new HashSet<string> ();
            var previous_priority = -1;
            foreach (var invocation in parsed.wrappers) {
                var definition = catalog.lookup_wrapper (invocation.wrapper_id);
                if (wrapper_ids.contains (invocation.wrapper_id))
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.DUPLICATE_WRAPPER, invocation.wrapper_id,
                        "Parsed command contains wrapper '%s' more than once.".printf (invocation.wrapper_id));
                wrapper_ids.add (invocation.wrapper_id);
                if (definition != null && capabilities != null && !capabilities.has (definition.required_capability))
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.MISSING_REQUIRED_CAPABILITY, invocation.wrapper_id,
                        "Wrapper '%s' requires an unavailable capability.".printf (invocation.wrapper_id));
                if (definition != null && previous_priority > (int) definition.nesting_priority)
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.WRAPPER_NESTING_VIOLATION, invocation.wrapper_id,
                        "Parsed wrappers are not ordered by declared nesting priority.");
                if (definition != null)
                    previous_priority = (int) definition.nesting_priority;
                if (definition != null && definition.mutual_exclusion_group != "") {
                    if (wrapper_groups.contains (definition.mutual_exclusion_group))
                        add (diagnostics, LaunchCommandCompositionDiagnosticCode.MUTUALLY_EXCLUSIVE_WRAPPERS, invocation.wrapper_id,
                            "Parsed command contains mutually exclusive wrappers.");
                    wrapper_groups.add (definition.mutual_exclusion_group);
                }
            }
            return diagnostics;
        }

        void validate_relationships (
            ArrayList<LaunchCommandCompositionDiagnostic> diagnostics,
            LaunchCommandSelection[] selections, HashSet<string> selected_ids,
            HashMap<string, LaunchWrapperDefinition> selected_wrappers,
            LaunchCommandCapabilityContext capabilities
        ) {
            var groups = new HashSet<string> ();
            foreach (var selection in selections) {
                var metadata = catalog.lookup (selection.option_id);
                if (metadata == null || metadata.semantics == null)
                    continue;
                var semantics = metadata.semantics;
                foreach (var dependency in semantics.dependencies) {
                    if (!selected_ids.contains (dependency))
                        add (diagnostics, LaunchCommandCompositionDiagnosticCode.MISSING_DEPENDENCY, selection.option_id,
                            "Launch option '%s' requires '%s'.".printf (selection.option_id, dependency));
                }
                foreach (var conflict in semantics.conflicts) {
                    if (selected_ids.contains (conflict))
                        add (diagnostics, LaunchCommandCompositionDiagnosticCode.EXPLICIT_OPTION_CONFLICT, selection.option_id,
                            "Launch option '%s' conflicts with '%s'.".printf (selection.option_id, conflict));
                }
                if (semantics.conflict_group != "") {
                    if (groups.contains (semantics.conflict_group))
                        add (diagnostics, LaunchCommandCompositionDiagnosticCode.CONFLICT_GROUP_COLLISION, selection.option_id,
                            "More than one option belongs to conflict group '%s'.".printf (semantics.conflict_group));
                    groups.add (semantics.conflict_group);
                }
                if (semantics.kind == LaunchOptionSemanticKind.WRAPPER_ARGUMENT
                    || semantics.kind == LaunchOptionSemanticKind.COMPOSITE_DYNAMIC
                    || semantics.wrapper_id != "") {
                    string owner = semantics.wrapper_id;
                    if (owner != "" && !selected_wrappers.has_key (owner)) {
                        var code = selected_wrappers.size == 0
                            ? LaunchCommandCompositionDiagnosticCode.WRAPPER_ARGUMENT_WITHOUT_WRAPPER
                            : LaunchCommandCompositionDiagnosticCode.WRAPPER_ARGUMENT_OWNED_BY_WRONG_WRAPPER;
                        add (diagnostics, code, selection.option_id,
                            "Launch option '%s' requires wrapper '%s'.".printf (selection.option_id, owner));
                    }
                }
            }
            var wrapper_groups = new HashSet<string> ();
            foreach (var wrapper in catalog.get_wrappers ()) {
                if (!selected_wrappers.has_key (wrapper.id))
                    continue;
                if (!capabilities.has (wrapper.required_capability))
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.MISSING_REQUIRED_CAPABILITY, wrapper.id,
                        "Wrapper '%s' requires an unavailable capability.".printf (wrapper.id));
                if (wrapper.mutual_exclusion_group != "") {
                    if (wrapper_groups.contains (wrapper.mutual_exclusion_group))
                        add (diagnostics, LaunchCommandCompositionDiagnosticCode.MUTUALLY_EXCLUSIVE_WRAPPERS, wrapper.id,
                            "More than one wrapper belongs to '%s'.".printf (wrapper.mutual_exclusion_group));
                    wrapper_groups.add (wrapper.mutual_exclusion_group);
                }
            }
        }

        void append_environment (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics,
            LaunchCommandSelection selection, LaunchOptionSemantics semantics,
            ArrayList<LaunchEnvironmentAssignment> environments) {
            if (semantics.emission_mode == LaunchOptionEmissionMode.FIXED_TOKENS) {
                validate_no_values (diagnostics, selection, semantics);
                foreach (var token in semantics.fixed_tokens) {
                    if (!safe (diagnostics, selection.option_id, token)) continue;
                    environments.add (new LaunchEnvironmentAssignment (semantics.environment_key, token));
                }
                return;
            }
            var values = selection.get_values ();
            if (values.length == 0) {
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.MISSING_DYNAMIC_VALUE, selection.option_id,
                    "Launch option '%s' requires a value.".printf (selection.option_id)); return;
            }
            if (values.length != 1) {
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.INVALID_VALUE_COUNT, selection.option_id,
                    "Launch option '%s' requires exactly one value.".printf (selection.option_id)); return;
            }
            bool selectable = valid_selectable (diagnostics, selection.option_id, values[0], semantics.selectable_values);
            bool safe_value = safe (diagnostics, selection.option_id, values[0]);
            if (!selectable || !safe_value) return;
            environments.add (new LaunchEnvironmentAssignment (semantics.environment_key,
                "%s=%s".printf (semantics.environment_key, shell_word (values[0]))));
        }

        void append_wrapper_argument (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics,
            LaunchCommandSelection selection, LaunchOptionSemantics semantics,
            HashMap<string, ArrayList<string>> arguments) {
            var output = new ArrayList<string> ();
            if (semantics.emission_mode == LaunchOptionEmissionMode.FIXED_TOKENS) {
                validate_no_values (diagnostics, selection, semantics);
                foreach (var token in semantics.fixed_tokens) output.add (token);
            } else if (semantics.parse_shape != null) {
                append_shape (diagnostics, selection.option_id, selection.get_values (), semantics.parse_shape, output);
            } else {
                foreach (var token in selection.get_values ()) output.add (token);
                if (output.size == 0)
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.MISSING_DYNAMIC_VALUE, selection.option_id,
                        "Launch option '%s' requires at least one argument.".printf (selection.option_id));
            }
            append_arguments_for_wrapper (diagnostics, selection.option_id, semantics.wrapper_id, output, arguments);
        }

        void append_composite (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics,
            LaunchCommandSelection selection, LaunchOptionSemantics semantics,
            ArrayList<LaunchEnvironmentAssignment> environments,
            HashMap<string, ArrayList<string>> arguments) {
            var outputs = semantics.get_composite_outputs ();
            LaunchOptionSemanticOutput? dynamic_output = null;
            var automatic_outputs = new ArrayList<LaunchOptionSemanticOutput> ();
            foreach (var output in outputs) {
                if (output.kind == LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT) {
                    automatic_outputs.add (output);
                } else if (output.kind == LaunchOptionSemanticKind.WRAPPER_ARGUMENT) {
                    dynamic_output = output;
                }
            }
            var values = selection.get_values ();
            /* Composite metadata can declare an automatic form through its
             * selectable value.  That form emits only fixed outputs. */
            if (values.length == 1 && values[0] == "auto" && contains (semantics.selectable_values, "auto")) {
                foreach (var output in automatic_outputs) {
                    foreach (var token in output.fixed_tokens) {
                        if (output.environment_key == "" || !safe (diagnostics, selection.option_id, token))
                            add (diagnostics, LaunchCommandCompositionDiagnosticCode.INVALID_COMPOSITE_OUTPUT, selection.option_id,
                                "Composite option '%s' has an invalid environment output.".printf (selection.option_id));
                        else environments.add (new LaunchEnvironmentAssignment (output.environment_key, token));
                    }
                }
                return;
            }
            if (dynamic_output == null || dynamic_output.parse_shape == null) {
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.INVALID_COMPOSITE_OUTPUT, selection.option_id,
                    "Composite option '%s' has no valid wrapper output.".printf (selection.option_id)); return;
            }
            var tokens = new ArrayList<string> ();
            append_shape (diagnostics, selection.option_id, values, dynamic_output.parse_shape, tokens);
            append_arguments_for_wrapper (diagnostics, selection.option_id, dynamic_output.wrapper_id, tokens, arguments);
        }

        void append_shape (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics, string id,
            string[] values, LaunchOptionParseShape shape, ArrayList<string> output) {
            var arities = shape.get_value_arities ();
            var required = 0;
            foreach (var arity in arities) required += (int) arity;
            if (values.length == 0) {
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.MISSING_DYNAMIC_VALUE, id,
                    "Launch option '%s' requires values.".printf (id)); return;
            }
            if (values.length != required) {
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.INVALID_VALUE_COUNT, id,
                    "Launch option '%s' requires %d values.".printf (id, required)); return;
            }
            var cursor = 0;
            for (var index = 0; index < shape.tokens.length; index++) {
                output.add (shape.tokens[index]);
                for (var count = 0; count < arities[index]; count++) {
                    if (safe (diagnostics, id, values[cursor])) output.add (shell_word (values[cursor]));
                    cursor++;
                }
            }
        }

        void add_selected_wrapper (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics, string option_id,
            string wrapper_id, string[] allowed, LaunchCommandCapabilityContext capabilities,
            HashMap<string, LaunchWrapperDefinition> selected) {
            if (wrapper_id == "" || !contains (allowed, wrapper_id) || catalog.lookup_wrapper (wrapper_id) == null) {
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.INVALID_WRAPPER_SELECTION, option_id,
                    "Launch option '%s' has an invalid wrapper selection.".printf (option_id)); return;
            }
            var definition = catalog.lookup_wrapper (wrapper_id);
            if (selected.has_key (wrapper_id))
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.DUPLICATE_WRAPPER, option_id,
                    "Wrapper '%s' was selected more than once.".printf (wrapper_id));
            selected.set (wrapper_id, definition);
            if (!capabilities.has (definition.required_capability))
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.MISSING_REQUIRED_CAPABILITY, option_id,
                    "Wrapper '%s' requires an unavailable capability.".printf (wrapper_id));
        }

        void append_safe_arguments (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics, string option_id,
            string wrapper_id, string[] tokens, HashMap<string, ArrayList<string>> arguments) {
            if (tokens.length == 0) return;
            if (catalog.lookup_wrapper (wrapper_id) == null) {
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.WRAPPER_ARGUMENT_OWNED_BY_WRONG_WRAPPER, option_id,
                    "Additional wrapper arguments require an owned wrapper."); return;
            }
            var bucket = arguments.has_key (wrapper_id) ? arguments.get (wrapper_id) : new ArrayList<string> ();
            foreach (var token in tokens) if (safe (diagnostics, option_id, token)) bucket.add (shell_word (token));
            arguments.set (wrapper_id, bucket);
        }

        void append_arguments_for_wrapper (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics, string option_id,
            string wrapper_id, ArrayList<string> tokens, HashMap<string, ArrayList<string>> arguments) {
            var bucket = arguments.has_key (wrapper_id) ? arguments.get (wrapper_id) : new ArrayList<string> ();
            foreach (var token in tokens) if (safe (diagnostics, option_id, token)) bucket.add (token);
            arguments.set (wrapper_id, bucket);
        }

        void validate_capabilities (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics, string id,
            LaunchOptionCapability[] required, LaunchCommandCapabilityContext capabilities) {
            foreach (var capability in required) if (!capabilities.has (capability))
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.MISSING_REQUIRED_CAPABILITY, id,
                    "Launch option '%s' requires an unavailable capability.".printf (id));
        }

        void validate_environment_keys (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics,
            ArrayList<LaunchEnvironmentAssignment> environments) {
            var keys = new HashSet<string> ();
            foreach (var environment in environments) {
                if (keys.contains (environment.key))
                    add (diagnostics, LaunchCommandCompositionDiagnosticCode.DUPLICATE_ENVIRONMENT_KEY, environment.key,
                        "Environment key '%s' is emitted more than once.".printf (environment.key));
                keys.add (environment.key);
            }
        }

        void validate_no_values (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics,
            LaunchCommandSelection selection, LaunchOptionSemantics semantics) {
            if (selection.get_values ().length > 0)
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.UNEXPECTED_DYNAMIC_VALUE, selection.option_id,
                    "Launch option '%s' does not accept values.".printf (selection.option_id));
        }
        void validate_no_additional_arguments (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics,
            LaunchCommandSelection selection) {
            if (selection.get_additional_wrapper_arguments ().length > 0)
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.WRAPPER_ARGUMENT_OWNED_BY_WRONG_WRAPPER, selection.option_id,
                    "Launch option '%s' cannot own additional wrapper arguments.".printf (selection.option_id));
        }
        void append_fixed_tokens (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics, string id,
            string[] tokens, ArrayList<string> output) { foreach (var token in tokens) if (safe (diagnostics, id, token)) output.add (token); }
        bool valid_selectable (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics, string id, string value, string[] selectable) {
            if (selectable.length == 0 || contains (selectable, value)) return true;
            add (diagnostics, LaunchCommandCompositionDiagnosticCode.UNSUPPORTED_SELECTABLE_VALUE, id,
                "Value '%s' is not selectable for '%s'.".printf (value, id)); return false;
        }
        bool safe (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics, string id, string token) {
            if (token.contains ("%command%")) {
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.EMBEDDED_COMMAND_PLACEHOLDER, id,
                    "Launch option '%s' must not contain %%command%%.".printf (id)); return false;
            }
            if (token.strip () == "") {
                add (diagnostics, LaunchCommandCompositionDiagnosticCode.EMPTY_OR_UNSAFE_ARGUMENT, id,
                    "Launch option '%s' has an empty argument.".printf (id)); return false;
            }
            return true;
        }
        bool contains (string[] values, string value) { foreach (var candidate in values) if (candidate == value) return true; return false; }
        void add (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics, LaunchCommandCompositionDiagnosticCode code, string id, string message) {
            diagnostics.add (new LaunchCommandCompositionDiagnostic (code, id, message));
        }
        LaunchCommandCompositionResult invalid (ArrayList<LaunchCommandCompositionDiagnostic> diagnostics) {
            return new LaunchCommandCompositionResult (false, diagnostics);
        }

        /* Quotes only when needed, never evaluates a value. Single quoting is
         * POSIX shell-safe and preserves commas, semicolons, spaces and equals. */
        public static string shell_word (string value) {
            if (value == "") return "''";
            bool plain = true;
            for (var index = 0; index < value.length; index++) {
                unichar character = value.get_char (index);
                if (!(character.isalnum () || character == '_' || character == '.' || character == '/' || character == ':' || character == '-' || character == '+')) { plain = false; break; }
            }
            if (plain) return value;
            return "'%s'".printf (value.replace ("'", "'\\\"'\\\"'"));
        }
    }
}
