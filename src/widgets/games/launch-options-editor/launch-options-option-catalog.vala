namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

    /* Presentation metadata only. LaunchOptionsList remains the owner of
     * shell-safe parsing, source order, and serialized command output. */
    public enum LaunchOptionCategory {
        PERFORMANCE,
        DISPLAY,
        PROTON,
        GRAPHICS,
        HARDWARE,
        INPUT_AUDIO,
        GAME_ARGUMENTS,
        DIAGNOSTICS
    }

    public enum LaunchOptionView {
        QUICK,
        ACTIVE,
        ALL,
        PERFORMANCE,
        DISPLAY,
        PROTON,
        GRAPHICS,
        HARDWARE,
        INPUT_AUDIO,
        GAME_ARGUMENTS,
        DIAGNOSTICS
    }

    public enum LaunchOptionExpertise {
        STANDARD,
        ADVANCED,
        EXPERIMENTAL
    }

    /* Command semantics are deliberately separate from LaunchLineType, which
     * remains the legacy serialization detail used by the current editor. */
    public enum LaunchOptionSemanticKind {
        ENVIRONMENT_ASSIGNMENT,
        PREFIX_WRAPPER,
        DELIMITED_WRAPPER,
        WRAPPER_ARGUMENT,
        GAME_ARGUMENT,
        WRAPPER_SELECTOR,
        COMMAND_BOUNDARY,
        COMPOSITE_DYNAMIC,
        OPAQUE_CONTEXT_DEPENDENT
    }

    public enum LaunchPlaceholderPolicy {
        REQUIRED,
        OPTIONAL,
        INHERITED_FROM_WRAPPER,
        BUILDER_MANAGED_COMMAND_BOUNDARY,
        CONTEXT_DEPENDENT_RAW
    }

    public enum LaunchOptionEmissionMode {
        FIXED_TOKENS,
        DYNAMIC_ENVIRONMENT_VALUE,
        DYNAMIC_WRAPPER_ARGUMENT,
        WRAPPER_SELECTION,
        COMPOSITE_EMISSION,
        RAW_CONTEXT_DEPENDENT
    }

    public enum LaunchOptionApplicability {
        GENERIC,
        COMPONENT_SPECIFIC,
        VARIANT_SPECIFIC,
        UNKNOWN
    }

    /* Applicability says where an option may apply. Support says how much
     * current, primary-source evidence we have for managing its emission. */
    public enum LaunchOptionSupport {
        VERIFIED_CURRENT,
        COMPONENT_SPECIFIC,
        VARIANT_SPECIFIC,
        LEGACY_DEPRECATED,
        UNSUPPORTED,
        UNKNOWN_UNVERIFIED
    }

    public enum LaunchOptionCapability {
        STEAM,
        PROTON,
        NATIVE_LINUX,
        STEAM_SHORTCUT,
        UMU_COMPATIBLE_PROTON,
        MESA,
        DXVK,
        VKD3D_PROTON,
        WINE_STAGING_CUSTOM_WINE,
        GE_CUSTOM_PROTON,
        AMD,
        NVIDIA,
        INTEL,
        GAMESCOPE,
        SCOPEBUDDY,
        MANGOHUD,
        GAMEMODE,
        VKBASALT
    }

    public class LaunchOptionSemanticOutput : Object {
        public LaunchOptionSemanticKind kind { get; construct; }
        public LaunchOptionEmissionMode emission_mode { get; construct; }
        public string environment_key { get; construct; }
        public string wrapper_id { get; construct; }
        public string[] fixed_tokens { get; construct; }
        public LaunchOptionParseShape? parse_shape { get; construct; }

        public LaunchOptionSemanticOutput (
            LaunchOptionSemanticKind kind,
            LaunchOptionEmissionMode emission_mode,
            string environment_key = "",
            string wrapper_id = "",
            string[] fixed_tokens = {}, LaunchOptionParseShape? parse_shape = null
        ) {
            Object (
                kind: kind, emission_mode: emission_mode,
                environment_key: environment_key, wrapper_id: wrapper_id,
                fixed_tokens: fixed_tokens, parse_shape: parse_shape
            );
        }
    }

    /* Parsing metadata intentionally describes token shape, rather than a
     * widget or option-name convention.  Each entry in value_arities belongs
     * to the token at the same position and says how many following words it
     * consumes. */
    public class LaunchOptionParseShape : Object {
        public string[] tokens { get; construct; }
        uint[] _value_arities;

        public LaunchOptionParseShape (string[] tokens, uint[] value_arities = {}) {
            Object (tokens: tokens);
            this._value_arities = value_arities;
        }

        public uint[] get_value_arities () {
            return _value_arities;
        }
    }

    public class LaunchOptionSemantics : Object {
        public LaunchOptionSemanticKind kind { get; construct; }
        public LaunchPlaceholderPolicy placeholder_policy { get; construct; }
        public LaunchOptionEmissionMode emission_mode { get; construct; }
        public string environment_key { get; construct; }
        public string wrapper_id { get; construct; }
        public string[] fixed_tokens { get; construct; }
        public string[] selectable_wrapper_ids { get; construct; }
        public string conflict_group { get; construct; }
        public string[] conflicts { get; construct; }
        public string[] dependencies { get; construct; }
        public LaunchOptionSupport support { get; construct; }
        public bool managed_emission { get; construct; }
        public string[] legacy_tokens { get; construct; }
        public string[] selectable_values { get; construct; }
        public LaunchOptionParseShape? parse_shape { get; construct; }
        LaunchOptionCapability[] _required_capabilities;
        public LaunchOptionApplicability applicability { get; construct; }
        LaunchOptionSemanticOutput[] _composite_outputs;
        public bool legacy_manual_representation { get; construct; }

        public LaunchOptionSemantics (
            LaunchOptionSemanticKind kind,
            LaunchPlaceholderPolicy placeholder_policy,
            LaunchOptionEmissionMode emission_mode,
            string environment_key = "",
            string wrapper_id = "",
            string[] fixed_tokens = {},
            string[] selectable_wrapper_ids = {},
            string conflict_group = "",
            string[] conflicts = {},
            string[] dependencies = {},
            LaunchOptionCapability[] required_capabilities = {},
            LaunchOptionApplicability applicability = LaunchOptionApplicability.GENERIC,
            LaunchOptionSemanticOutput[] composite_outputs = {},
            bool legacy_manual_representation = false,
            LaunchOptionSupport support = LaunchOptionSupport.UNKNOWN_UNVERIFIED,
            bool managed_emission = false,
            string[] legacy_tokens = {},
            string[] selectable_values = {},
            LaunchOptionParseShape? parse_shape = null
        ) {
            Object (
                kind: kind, placeholder_policy: placeholder_policy,
                emission_mode: emission_mode, environment_key: environment_key,
                wrapper_id: wrapper_id, fixed_tokens: fixed_tokens,
                selectable_wrapper_ids: selectable_wrapper_ids,
                conflict_group: conflict_group, conflicts: conflicts,
                dependencies: dependencies, applicability: applicability,
                legacy_manual_representation: legacy_manual_representation,
                support: support, managed_emission: managed_emission,
                legacy_tokens: legacy_tokens, selectable_values: selectable_values,
                parse_shape: parse_shape
            );
            this._required_capabilities = required_capabilities;
            this._composite_outputs = composite_outputs;
        }

        public LaunchOptionCapability[] get_required_capabilities () {
            return _required_capabilities;
        }

        public LaunchOptionSemanticOutput[] get_composite_outputs () {
            return _composite_outputs;
        }
    }

    public class LaunchWrapperDefinition : Object {
        public string id { get; construct; }
        public string[] executable_tokens { get; construct; }
        public string[] parse_aliases { get; construct; }
        public string? delimiter { get; construct; }
        public uint nesting_priority { get; construct; }
        public string mutual_exclusion_group { get; construct; }
        public LaunchOptionCapability required_capability { get; construct; }

        public LaunchWrapperDefinition (
            string id, string[] executable_tokens, string[] parse_aliases = {},
            string? delimiter = null, uint nesting_priority = 0,
            string mutual_exclusion_group = "",
            LaunchOptionCapability required_capability = LaunchOptionCapability.STEAM
        ) {
            Object (
                id: id, executable_tokens: executable_tokens,
                parse_aliases: parse_aliases, delimiter: delimiter,
                nesting_priority: nesting_priority,
                mutual_exclusion_group: mutual_exclusion_group,
                required_capability: required_capability
            );
        }
    }

    public class LaunchOptionMetadata : Object {
        public string id { get; construct; }
        public string title { get; construct; }
        public string description { get; construct; }
        public LaunchOptionCategory category { get; construct; }
        public string subsection { get; construct; }
        public uint display_rank { get; construct; }
        public bool quick_setting { get; construct; }
        public LaunchOptionExpertise expertise { get; construct; }
        public string applicability { get; construct; }
        public string unavailable_reason { get; construct; }
        public string[] dependencies { get; construct; }
        public string[] aliases { get; construct; }
        public string[] raw_tokens { get; construct; }
        public LaunchLineType serialization_type { get; construct; }
        public uint command_order_rank { get; construct; }
        public LaunchOptionSemantics? semantics { get; construct; }

        public LaunchOptionMetadata (
            string id, string title, string description, LaunchOptionCategory category,
            string subsection, uint display_rank, bool quick_setting,
            LaunchOptionExpertise expertise, string applicability,
            string unavailable_reason, string[] dependencies, string[] aliases,
            string[] raw_tokens, LaunchLineType serialization_type,
            uint command_order_rank, LaunchOptionSemantics? semantics
        ) {
            Object (
                id: id, title: title, description: description, category: category,
                subsection: subsection, display_rank: display_rank,
                quick_setting: quick_setting, expertise: expertise,
                applicability: applicability, unavailable_reason: unavailable_reason,
                dependencies: dependencies, aliases: aliases, raw_tokens: raw_tokens,
                serialization_type: serialization_type,
                command_order_rank: command_order_rank, semantics: semantics
            );
        }

        public bool matches_search (string query) {
            var normalized = query.strip ().down ();
            if (normalized == "")
                return true;
            if (matches (title, normalized) || matches (description, normalized)
                || matches (subsection, normalized)
                || matches (LaunchOptionCatalog.category_title (category), normalized)
                || matches (applicability, normalized))
                return true;
            foreach (var alias in aliases) {
                if (matches (alias, normalized))
                    return true;
            }
            foreach (var token in raw_tokens) {
                if (matches (token, normalized))
                    return true;
            }
            return false;
        }

        bool matches (string text, string query) {
            return text.down ().contains (query);
        }
    }

    public class LaunchOptionCatalog : Object {
        Gee.ArrayList<LaunchOptionMetadata> entries;
        Gee.HashMap<string, LaunchOptionMetadata> by_id;
        Gee.ArrayList<LaunchWrapperDefinition> wrappers;
        Gee.HashMap<string, LaunchWrapperDefinition> wrappers_by_id;

        public LaunchOptionCatalog () {
            entries = new Gee.ArrayList<LaunchOptionMetadata> ();
            by_id = new Gee.HashMap<string, LaunchOptionMetadata> ();
            wrappers = new Gee.ArrayList<LaunchWrapperDefinition> ();
            wrappers_by_id = new Gee.HashMap<string, LaunchWrapperDefinition> ();
            add_wrapper_defaults ();
            add_defaults ();
        }

        /* Test-only construction keeps validation fixtures small and does not
         * expose mutation of the production catalog. */
        public LaunchOptionCatalog.with_definitions (
            LaunchOptionMetadata[] definitions,
            LaunchWrapperDefinition[] wrapper_definitions
        ) {
            entries = new Gee.ArrayList<LaunchOptionMetadata> ();
            by_id = new Gee.HashMap<string, LaunchOptionMetadata> ();
            wrappers = new Gee.ArrayList<LaunchWrapperDefinition> ();
            wrappers_by_id = new Gee.HashMap<string, LaunchWrapperDefinition> ();
            foreach (var definition in definitions) {
                entries.add (definition);
                by_id.set (definition.id, definition);
            }
            foreach (var definition in wrapper_definitions) {
                wrappers.add (definition);
                wrappers_by_id.set (definition.id, definition);
            }
        }

        public static string category_title (LaunchOptionCategory category) {
            switch (category) {
                case LaunchOptionCategory.PERFORMANCE: return _("Performance & monitoring");
                case LaunchOptionCategory.DISPLAY: return _("Display & launch tools");
                case LaunchOptionCategory.PROTON: return _("Proton & Wine compatibility");
                case LaunchOptionCategory.GRAPHICS: return _("Graphics translation");
                case LaunchOptionCategory.HARDWARE: return _("Hardware & drivers");
                case LaunchOptionCategory.INPUT_AUDIO: return _("Input & audio");
                case LaunchOptionCategory.GAME_ARGUMENTS: return _("Game arguments");
                case LaunchOptionCategory.DIAGNOSTICS: return _("Diagnostics & raw command");
                default: assert_not_reached ();
            }
        }

        public static LaunchOptionView category_view (LaunchOptionCategory category) {
            return (LaunchOptionView) ((int) category + (int) LaunchOptionView.PERFORMANCE);
        }

        public LaunchOptionMetadata? lookup (string id) {
            return by_id.get (id);
        }

        public LaunchWrapperDefinition? lookup_wrapper (string id) {
            return wrappers_by_id.get (id);
        }

        public Gee.List<LaunchWrapperDefinition> get_wrappers () {
            var ordered = new Gee.ArrayList<LaunchWrapperDefinition> ();
            foreach (var wrapper in wrappers)
                ordered.add (wrapper);
            ordered.sort ((first, second) => {
                if (first.nesting_priority != second.nesting_priority)
                    return (int) first.nesting_priority - (int) second.nesting_priority;
                return strcmp (first.id, second.id);
            });
            return ordered;
        }

        public Gee.List<LaunchOptionMetadata> get_ordered () {
            var ordered = new Gee.ArrayList<LaunchOptionMetadata> ();
            foreach (var entry in entries)
                ordered.add (entry);
            ordered.sort ((a, b) => {
                if (a.category != b.category)
                    return (int) a.category - (int) b.category;
                if (a.display_rank != b.display_rank)
                    return (int) a.display_rank - (int) b.display_rank;
                return strcmp (a.id, b.id);
            });
            return ordered;
        }

        public Gee.List<LaunchOptionMetadata> search (string query) {
            var results = new Gee.ArrayList<LaunchOptionMetadata> ();
            foreach (var entry in get_ordered ()) {
                if (entry.matches_search (query))
                    results.add (entry);
            }
            return results;
        }

        public bool should_display (LaunchOptionMetadata metadata, LaunchOptionView view, string query, bool active) {
            if (active)
                return true;
            if (query.strip () != "")
                return metadata.matches_search (query);
            if (view == LaunchOptionView.ALL)
                return true;
            if (view == LaunchOptionView.QUICK)
                return metadata.quick_setting;
            if (view == LaunchOptionView.ACTIVE)
                return false;
            return category_view (metadata.category) == view;
        }

        public bool is_valid () {
            return validate ().size == 0;
        }

        public Gee.List<string> validate () {
            var diagnostics = new Gee.ArrayList<string> ();
            var ids = new Gee.HashSet<string> ();
            var canonical_keys = new Gee.HashMap<string, string> ();
            var legacy_keys = new Gee.HashMap<string, string> ();
            var command_boundaries = 0;
            foreach (var entry in entries) {
                if (entry.id.strip () == "")
                    diagnostics.add ("Option IDs must not be empty.");
                else if (ids.contains (entry.id))
                    diagnostics.add ("Duplicate option ID: %s".printf (entry.id));
                ids.add (entry.id);
                validate_option_semantics (entry, diagnostics);
                var semantics = entry.semantics;
                if (semantics == null)
                    continue;
                if (semantics.kind == LaunchOptionSemanticKind.COMMAND_BOUNDARY)
                    command_boundaries++;
                register_environment_key (canonical_keys, semantics.environment_key, entry.id, "canonical", diagnostics);
                foreach (var token in semantics.legacy_tokens)
                    register_environment_key (legacy_keys, token_key (token), entry.id, "legacy", diagnostics);
            }

            foreach (var key in canonical_keys.keys) {
                if (legacy_keys.has_key (key) && canonical_keys.get (key) != legacy_keys.get (key))
                    diagnostics.add ("Environment key '%s' is canonical for '%s' and legacy for unrelated option '%s'.".printf (key, canonical_keys.get (key), legacy_keys.get (key)));
            }
            validate_parse_shape_ownership (diagnostics);
            validate_conflict_consistency (diagnostics);
            if (command_boundaries != 1)
                diagnostics.add ("Catalog requires exactly one legacy command boundary (found %d).".printf (command_boundaries));

            var wrapper_ids = new Gee.HashSet<string> ();
            var wrapper_priorities = new Gee.HashMap<uint, LaunchWrapperDefinition> ();
            foreach (var wrapper in wrappers) {
                if (wrapper.id.strip () == "")
                    diagnostics.add ("Wrapper IDs must not be empty.");
                else if (wrapper_ids.contains (wrapper.id))
                    diagnostics.add ("Duplicate wrapper ID: %s".printf (wrapper.id));
                wrapper_ids.add (wrapper.id);
                if (wrapper.executable_tokens.length == 0)
                    diagnostics.add ("Wrapper '%s' requires executable tokens.".printf (wrapper.id));
                foreach (var token in wrapper.executable_tokens) {
                    if (token.strip () == "")
                        diagnostics.add ("Wrapper '%s' has an empty executable token.".printf (wrapper.id));
                    if (token.contains ("%command%"))
                        diagnostics.add ("Wrapper '%s' executable tokens must not contain %%command%%.".printf (wrapper.id));
                }
                if (wrapper.delimiter != null && (wrapper.delimiter.strip () == "" || wrapper.delimiter.contains ("%command%")))
                    diagnostics.add ("Wrapper '%s' has an invalid delimiter.".printf (wrapper.id));
                if (wrapper_priorities.has_key (wrapper.nesting_priority)) {
                    var other = wrapper_priorities.get (wrapper.nesting_priority);
                    if (other.mutual_exclusion_group == "" || other.mutual_exclusion_group != wrapper.mutual_exclusion_group)
                        diagnostics.add ("Wrapper nesting priority %u is ambiguous.".printf (wrapper.nesting_priority));
                } else {
                    wrapper_priorities.set (wrapper.nesting_priority, wrapper);
                }
            }
            return diagnostics;
        }

        void register_environment_key (
            Gee.HashMap<string, string> owners, string key, string option_id,
            string role, Gee.List<string> diagnostics
        ) {
            if (key.strip () == "")
                return;
            if (owners.has_key (key) && owners.get (key) != option_id)
                diagnostics.add ("Environment key '%s' has multiple %s owners: '%s' and '%s'.".printf (key, role, owners.get (key), option_id));
            else
                owners.set (key, option_id);
        }

        void validate_parse_shape_ownership (Gee.List<string> diagnostics) {
            foreach (var entry in entries) {
                var semantics = entry.semantics;
                if (semantics == null || semantics.kind != LaunchOptionSemanticKind.WRAPPER_ARGUMENT
                    || semantics.parse_shape == null)
                    continue;
                foreach (var other in entries) {
                    if (entry == other || other.semantics == null
                        || other.semantics.kind != LaunchOptionSemanticKind.WRAPPER_ARGUMENT
                        || other.semantics.parse_shape == null
                        || semantics.wrapper_id != other.semantics.wrapper_id)
                        continue;
                    if (same_parse_shape (semantics.parse_shape, other.semantics.parse_shape)
                        && strcmp (entry.id, other.id) < 0)
                        diagnostics.add ("Wrapper parse shape '%s' has ambiguous ownership between '%s' and '%s'.".printf (semantics.wrapper_id, entry.id, other.id));
                }
            }
        }

        bool same_parse_shape (LaunchOptionParseShape first, LaunchOptionParseShape second) {
            if (first.tokens.length != second.tokens.length)
                return false;
            var first_arities = first.get_value_arities ();
            var second_arities = second.get_value_arities ();
            if (first_arities.length != second_arities.length)
                return false;
            for (var index = 0; index < first.tokens.length; index++) {
                if (first.tokens[index] != second.tokens[index]
                    || first_arities[index] != second_arities[index])
                    return false;
            }
            return true;
        }

        string token_key (string token) {
            var separator = token.index_of_char ('=');
            return separator >= 0 ? token.substring (0, separator) : token;
        }

        void validate_conflict_consistency (Gee.List<string> diagnostics) {
            var groups = new Gee.HashMap<string, uint> ();
            foreach (var entry in entries) {
                var semantics = entry.semantics;
                if (semantics == null)
                    continue;
                if (semantics.conflict_group != ""
                    && semantics.kind != LaunchOptionSemanticKind.WRAPPER_SELECTOR) {
                    var count = groups.has_key (semantics.conflict_group) ? groups.get (semantics.conflict_group) : 0;
                    groups.set (semantics.conflict_group, count + 1);
                }
                foreach (var conflict_id in semantics.conflicts) {
                    var other = lookup (conflict_id);
                    if (other == null || other.semantics == null)
                        continue;
                    if (!contains_id (other.semantics.conflicts, entry.id)
                        && (semantics.conflict_group == "" || semantics.conflict_group != other.semantics.conflict_group))
                        diagnostics.add ("Conflict '%s' declared by '%s' is not reciprocal.".printf (conflict_id, entry.id));
                }
            }
            foreach (var group in groups.keys) {
                if (groups.get (group) < 2)
                    diagnostics.add ("Conflict group '%s' must contain at least two options.".printf (group));
            }
        }

        bool contains_id (string[] values, string id) {
            foreach (var value in values) {
                if (value == id)
                    return true;
            }
            return false;
        }

        void add_option (
            string id, string title, string description, LaunchOptionCategory category,
            uint rank, string[] raw_tokens, string[] aliases = {},
            LaunchLineType type = LaunchLineType.ENVIRONMENT, string subsection = "",
            bool quick = false, LaunchOptionExpertise expertise = LaunchOptionExpertise.STANDARD,
            string applicability = "", string[] dependencies = {}
        ) {
            var semantics = create_semantics (id, type, raw_tokens, dependencies);
            var entry = new LaunchOptionMetadata (
                id, title, description, category, subsection, rank, quick, expertise,
                applicability, "", dependencies, aliases, raw_tokens, type, rank, semantics
            );
            assert (!by_id.has_key (id));
            entries.add (entry);
            by_id.set (id, entry);
        }

        void add_wrapper_defaults () {
            add_wrapper (new LaunchWrapperDefinition (
                "mangohud", { "mangohud" }, {}, null, 10, "",
                LaunchOptionCapability.MANGOHUD
            ));
            add_wrapper (new LaunchWrapperDefinition (
                "gamemode", { "gamemoderun" }, {}, null, 20, "",
                LaunchOptionCapability.GAMEMODE
            ));
            add_wrapper (new LaunchWrapperDefinition (
                "gamescope", { "gamescope" }, {}, "--", 30, "launch-backend",
                LaunchOptionCapability.GAMESCOPE
            ));
            add_wrapper (new LaunchWrapperDefinition (
                "scopebuddy", { "scopebuddy" }, { "scb" }, "--", 30, "launch-backend",
                LaunchOptionCapability.SCOPEBUDDY
            ));
        }

        void add_wrapper (LaunchWrapperDefinition definition) {
            wrappers.add (definition);
            wrappers_by_id.set (definition.id, definition);
        }

        LaunchOptionSemantics create_semantics (
            string id, LaunchLineType serialization_type, string[] raw_tokens,
            string[] dependencies
        ) {
            if (id == "performance-overlay")
                return wrapper_semantics ("mangohud");
            if (id == "gamemode")
                return wrapper_semantics ("gamemode");
            if (id == "launch-backend") {
                return new LaunchOptionSemantics (
                    LaunchOptionSemanticKind.WRAPPER_SELECTOR,
                    LaunchPlaceholderPolicy.REQUIRED,
                    LaunchOptionEmissionMode.WRAPPER_SELECTION,
                    "", "", {}, { "gamescope", "scopebuddy" }, "launch-backend",
                    {}, {}, {}, LaunchOptionApplicability.COMPONENT_SPECIFIC,
                    {}, false, LaunchOptionSupport.COMPONENT_SPECIFIC, true
                );
            }
            if (id == "steam-command") {
                return new LaunchOptionSemantics (
                    LaunchOptionSemanticKind.COMMAND_BOUNDARY,
                    LaunchPlaceholderPolicy.BUILDER_MANAGED_COMMAND_BOUNDARY,
                    LaunchOptionEmissionMode.RAW_CONTEXT_DEPENDENT,
                    "", "", {}, {}, "", {}, {}, {},
                    LaunchOptionApplicability.GENERIC, {}, true,
                    support_for (id), false, {}, {}
                );
            }
            if (id == "raw-launch-options" || id == "custom-game-arguments") {
                return new LaunchOptionSemantics (
                    LaunchOptionSemanticKind.OPAQUE_CONTEXT_DEPENDENT,
                    LaunchPlaceholderPolicy.CONTEXT_DEPENDENT_RAW,
                    LaunchOptionEmissionMode.RAW_CONTEXT_DEPENDENT,
                    "", "", {}, {}, "", {}, {}, {},
                    LaunchOptionApplicability.UNKNOWN, {}, false,
                    support_for (id), false, legacy_tokens_for (id), {}
                );
            }
            if (id == "scopebuddy-resolution") {
                return new LaunchOptionSemantics (
                    LaunchOptionSemanticKind.COMPOSITE_DYNAMIC,
                    LaunchPlaceholderPolicy.INHERITED_FROM_WRAPPER,
                    LaunchOptionEmissionMode.COMPOSITE_EMISSION,
                    "", "scopebuddy", {}, {}, "", {}, backend_dependencies (dependencies),
                    { LaunchOptionCapability.SCOPEBUDDY }, LaunchOptionApplicability.COMPONENT_SPECIFIC, {
                        new LaunchOptionSemanticOutput (
                            LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT,
                            LaunchOptionEmissionMode.FIXED_TOKENS,
                            "SCB_AUTO_RES", "", { "SCB_AUTO_RES=1" }
                        ),
                        new LaunchOptionSemanticOutput (
                            LaunchOptionSemanticKind.WRAPPER_ARGUMENT,
                            LaunchOptionEmissionMode.DYNAMIC_WRAPPER_ARGUMENT,
                            "", "scopebuddy", { "-W", "-H" },
                            new LaunchOptionParseShape ({ "-W", "-H" }, { 1, 1 })
                        )
                    }, false, support_for (id), is_managed_emission (id),
                    legacy_tokens_for (id), selectable_values_for (id)
                );
            }
            if (is_wrapper_argument (serialization_type)) {
                bool dynamic_value = id.has_suffix ("resolution")
                               || id.has_suffix ("frame-limit")
                               || id.has_suffix ("arguments");
                string wrapper_id = id.has_prefix ("gamescope-") ? "gamescope" : "scopebuddy";
                return new LaunchOptionSemantics (
                    LaunchOptionSemanticKind.WRAPPER_ARGUMENT,
                    LaunchPlaceholderPolicy.INHERITED_FROM_WRAPPER,
                    dynamic_value ? LaunchOptionEmissionMode.DYNAMIC_WRAPPER_ARGUMENT : LaunchOptionEmissionMode.FIXED_TOKENS,
                    "", wrapper_id, dynamic_value ? new string[0] : raw_tokens, {}, "", {}, backend_dependencies (dependencies),
                    { wrapper_id == "gamescope" ? LaunchOptionCapability.GAMESCOPE : LaunchOptionCapability.SCOPEBUDDY },
                    LaunchOptionApplicability.COMPONENT_SPECIFIC, {}, false,
                    support_for (id), is_managed_emission (id), legacy_tokens_for (id), selectable_values_for (id),
                    wrapper_parse_shape_for (id, raw_tokens)
                );
            }
            if (serialization_type == LaunchLineType.ARGUMENT) {
                return new LaunchOptionSemantics (
                    LaunchOptionSemanticKind.GAME_ARGUMENT,
                    LaunchPlaceholderPolicy.OPTIONAL,
                    LaunchOptionEmissionMode.FIXED_TOKENS,
                    "", "", raw_tokens, {}, renderer_conflict_group (id), {}, {}, {},
                    LaunchOptionApplicability.GENERIC, {}, false,
                    support_for (id), is_managed_emission (id), legacy_tokens_for (id), selectable_values_for (id)
                );
            }
            if (serialization_type == LaunchLineType.ENVIRONMENT) {
                if (has_no_canonical_emission (id)) {
                    return new LaunchOptionSemantics (
                        LaunchOptionSemanticKind.OPAQUE_CONTEXT_DEPENDENT,
                        LaunchPlaceholderPolicy.CONTEXT_DEPENDENT_RAW,
                        LaunchOptionEmissionMode.RAW_CONTEXT_DEPENDENT,
                        "", "", {}, {}, "", {}, {}, capabilities_for (id), applicability_for (id), {}, false,
                        support_for (id), false, legacy_tokens_for (id), selectable_values_for (id)
                    );
                }
                bool dynamic_value = is_dynamic_environment (id);
                string key = canonical_environment_key_for (id, raw_tokens);
                var fixed_tokens = canonical_fixed_tokens_for (id, raw_tokens);
                return new LaunchOptionSemantics (
                    LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT,
                    LaunchPlaceholderPolicy.REQUIRED,
                    dynamic_value ? LaunchOptionEmissionMode.DYNAMIC_ENVIRONMENT_VALUE : LaunchOptionEmissionMode.FIXED_TOKENS,
                    key, scopebuddy_owner (id), dynamic_value ? new string[0] : fixed_tokens, {},
                    id == "amd-fsr4" || id == "amd-fsr4-rdna3" ? "amd-fsr4-upgrade" : "", {},
                    scopebuddy_owner (id) != "" ? backend_dependencies (dependencies) : dependencies,
                    capabilities_for (id), applicability_for (id), {}, false,
                    support_for (id), is_managed_emission (id), legacy_tokens_for (id), selectable_values_for (id)
                );
            }

            /* ADDITIONAL is intentionally opaque unless a specific branch above
             * can describe its output without guessing about user input. */
            return new LaunchOptionSemantics (
                LaunchOptionSemanticKind.OPAQUE_CONTEXT_DEPENDENT,
                LaunchPlaceholderPolicy.CONTEXT_DEPENDENT_RAW,
                LaunchOptionEmissionMode.RAW_CONTEXT_DEPENDENT,
                "", "", {}, {}, "", {}, {}, {}, LaunchOptionApplicability.UNKNOWN, {}, false,
                support_for (id), false, legacy_tokens_for (id), selectable_values_for (id)
            );
        }

        LaunchOptionSemantics wrapper_semantics (string wrapper_id) {
            var definition = lookup_wrapper (wrapper_id);
            return new LaunchOptionSemantics (
                definition.delimiter == null ? LaunchOptionSemanticKind.PREFIX_WRAPPER : LaunchOptionSemanticKind.DELIMITED_WRAPPER,
                LaunchPlaceholderPolicy.REQUIRED,
                LaunchOptionEmissionMode.WRAPPER_SELECTION,
                "", wrapper_id, {}, {}, "", {}, {}, { definition.required_capability },
                LaunchOptionApplicability.COMPONENT_SPECIFIC, {}, false,
                support_for (wrapper_id), true, {}, {}
            );
        }

        bool is_wrapper_argument (LaunchLineType serialization_type) {
            return serialization_type == LaunchLineType.WRAPPER_ARGUMENT;
        }

        /* These are catalog declarations.  The parser consumes only this
         * shape and never branches on an option ID or a widget type. */
        LaunchOptionParseShape? wrapper_parse_shape_for (string id, string[] raw_tokens) {
            switch (id) {
                case "gamescope-fullscreen":
                case "gamescope-hdr":
                case "gamescope-vrr":
                case "scopebuddy-fullscreen":
                    return new LaunchOptionParseShape (raw_tokens, { 0 });
                case "gamescope-resolution":
                    return new LaunchOptionParseShape ({ "-W", "-H" }, { 1, 1 });
                case "gamescope-frame-limit":
                case "scopebuddy-frame-limit":
                    return new LaunchOptionParseShape ({ "-r" }, { 1 });
                default:
                    return null;
            }
        }

        bool is_dynamic_environment (string id) {
            switch (id) {
                case "dxvk-frame-limit":
                case "pulse-latency":
                case "winealsa-channels":
                case "vkd3d-log-level":
                case "dll-overrides":
                case "vkd3d-config":
                case "amd-vulkan-driver":
                case "amd-radv-perftest":
                case "amd-radv-debug":
                case "amd-aco-debug":
                    return true;
                default:
                    return false;
            }
        }

        string canonical_environment_key_for (string id, string[] raw_tokens) {
            switch (id) {
                case "ntsync-mode": return "PROTON_NO_NTSYNC";
                case "dll-overrides": return "WINEDLLOVERRIDES";
                case "amd-vulkan-driver": return "AMD_VULKAN_ICD";
                case "vkd3d-log-level": return "VKD3D_DEBUG";
                default: break;
            }
            foreach (var token in raw_tokens) {
                var separator = token.index_of_char ('=');
                if (separator >= 0)
                    return token.substring (0, separator);
            }
            if (raw_tokens.length > 0)
                return raw_tokens[0];
            return "";
        }

        string[] canonical_fixed_tokens_for (string id, string[] raw_tokens) {
            if (id == "ntsync-mode") return { "PROTON_NO_NTSYNC=1" };
            if (id == "amd-shader-cache") return { "MESA_SHADER_CACHE_DISABLE=1" };
            return raw_tokens;
        }

        bool has_no_canonical_emission (string id) {
            switch (id) {
                /* Current upstream DXVK uses dxvk.conf configuration keys;
                 * DXVK_ASYNC is a patched-DXVK convention. VKD3D-Proton
                 * documents neither of the historical variables below. */
                case "dxvk-frame-limit":
                case "dxvk-async":
                case "vkd3d-shader-cache":
                case "vkd3d-gpuva":
                case "nvidia-nvapi":
                    return true;
                default:
                    return false;
            }
        }

        string[] legacy_tokens_for (string id) {
            switch (id) {
                case "ntsync-mode": return { "PROTON_USE_NTSYNC=0" };
                case "dll-overrides": return { "DLL_OVERRIDES" };
                case "amd-vulkan-driver": return { "AMD_ICD" };
                case "vkd3d-log-level": return { "VKD3D_LOG_LEVEL" };
                case "amd-shader-cache": return { "MESA_SHADER_CACHE_DISABLE=0" };
                case "dxvk-frame-limit": return { "DXVK_FRAME_RATE=" };
                case "dxvk-async": return { "DXVK_ASYNC=1" };
                case "vkd3d-shader-cache": return { "VKD3D_SHADER_CACHE=1" };
                case "vkd3d-gpuva": return { "VKD3D_GPUVA=1" };
                case "vkd3d-config": return { "force_host_cache", "shader_cache", "upload_hvv", "gpuva", "stable_power_state", "dxr10", "dxr11" };
                case "nvidia-nvapi": return { "PROTON_ENABLE_NVAPI=1" };
                default: return {};
            }
        }

        string[] selectable_values_for (string id) {
            switch (id) {
                case "vkd3d-log-level": return { "none", "err", "warn", "fixme", "info", "trace" };
                case "vkd3d-config": return { "vk_debug", "skip_application_workarounds", "nodxr", "dxr", "dxr12", "force_static_cbv", "single_queue", "no_upload_hvv", "force_host_cached", "no_invariant_position", "pipeline_library_app_cache" };
                case "amd-radv-perftest": return { "cswave32", "dccmsaa", "dmashaders", "gewave32", "localbos", "lowlatencydec", "lowlatencyenc", "nggc", "nircache", "nogttspill", "nosam", "pswave32", "rtcps" };
                /* RADV_DEBUG and ACO_DEBUG are diagnostic flag lists. Keep
                 * only flags documented by current Mesa, rather than the
                 * historical widget's guessed boolean pairs. */
                case "amd-radv-debug": return { "hang", "syncshaders", "noibs", "nocache", "nodcc", "nogpl", "nooptvariant", "nosam", "novrs", "precompile", "psocachestats" };
                case "amd-aco-debug": return { "validate", "perfinfo", "force-waitcnt", "nosched", "nowave32" };
                default: return {};
            }
        }

        LaunchOptionSupport support_for (string id) {
            switch (id) {
                case "dxvk-frame-limit":
                case "vkd3d-shader-cache":
                case "vkd3d-gpuva":
                    return LaunchOptionSupport.UNSUPPORTED;
                case "dxvk-async":
                    return LaunchOptionSupport.VARIANT_SPECIFIC;
                case "nvidia-nvapi":
                    return LaunchOptionSupport.LEGACY_DEPRECATED;
                case "d7vk":
                case "optiscaler":
                case "discord-bridge":
                case "winealsa-channels":
                case "winealsa-spatial":
                case "amd-fsr4":
                case "amd-fsr4-rdna3":
                case "nvidia-dlss-updater":
                case "nvidia-dlss-indicator":
                case "nvidia-libraries":
                case "intel-xess":
                    return LaunchOptionSupport.VARIANT_SPECIFIC;
                case "performance-overlay":
                case "mangohud":
                case "gamemode":
                case "gamescope":
                case "scopebuddy":
                case "launch-backend":
                case "gamescope-fullscreen":
                case "gamescope-resolution":
                case "gamescope-hdr":
                case "gamescope-vrr":
                case "gamescope-frame-limit":
                case "gamescope-arguments":
                case "scopebuddy-fullscreen":
                case "scopebuddy-resolution":
                case "scopebuddy-auto-hdr":
                case "scopebuddy-auto-vrr":
                case "scopebuddy-frame-limit":
                case "scopebuddy-arguments":
                case "vkbasalt":
                case "vkd3d-config":
                case "vkd3d-log-level":
                case "dxvk-log-level":
                case "amd-discrete-gpu":
                case "amd-anti-lag":
                case "amd-vulkan-driver":
                case "amd-glthread":
                case "amd-shader-cache":
                case "amd-radv-perftest":
                case "amd-radv-debug":
                case "amd-aco-debug":
                    return LaunchOptionSupport.COMPONENT_SPECIFIC;
                case "raw-launch-options":
                case "custom-game-arguments":
                case "high-process-priority":
                case "per-game-shader-cache":
                case "native-wayland":
                case "desktop-game-profile":
                case "proton-hdr":
                case "wow64":
                case "writecopy":
                case "vulkan-sync2":
                case "futex-waitv":
                case "amd-staging-shm":
                case "prefer-sdl":
                case "bypass-steam-input":
                case "pulse-latency":
                case "steam-command":
                case "wined3d":
                case "ntsync-mode":
                case "large-address-aware":
                case "dll-overrides":
                case "proton-debug-log":
                case "nvidia-report-amd":
                case "skip-launcher":
                case "renderer-vulkan":
                case "renderer-dx11":
                case "renderer-dx12":
                case "developer-console":
                    return LaunchOptionSupport.VERIFIED_CURRENT;
                default:
                    /* An ID not named above has no current primary-source
                     * evidence in this phase. It is deliberately not a
                     * generic managed default. */
                    return LaunchOptionSupport.UNKNOWN_UNVERIFIED;
            }
        }

        bool is_managed_emission (string id) {
            var support = support_for (id);
            return support != LaunchOptionSupport.UNSUPPORTED
                   && support != LaunchOptionSupport.UNKNOWN_UNVERIFIED
                   && support != LaunchOptionSupport.LEGACY_DEPRECATED
                   && id != "steam-command";
        }

        string scopebuddy_owner (string id) {
            if (id == "scopebuddy-auto-hdr" || id == "scopebuddy-auto-vrr")
                return "scopebuddy";
            return "";
        }

        string[] backend_dependencies (string[] dependencies) {
            var merged = new Gee.ArrayList<string> ();
            foreach (var dependency in dependencies)
                merged.add (dependency);
            if (!merged.contains ("launch-backend"))
                merged.add ("launch-backend");
            return merged.to_array ();
        }

        string renderer_conflict_group (string id) {
            if (id == "renderer-vulkan" || id == "renderer-dx11" || id == "renderer-dx12")
                return "renderer-selection";
            return "";
        }

        LaunchOptionCapability[] capabilities_for (string id) {
            if (id == "vkbasalt") return { LaunchOptionCapability.VKBASALT };
            if (id.has_prefix ("amd-")) return { LaunchOptionCapability.AMD };
            if (id.has_prefix ("nvidia-")) return { LaunchOptionCapability.NVIDIA, LaunchOptionCapability.PROTON };
            if (id.has_prefix ("intel-")) return { LaunchOptionCapability.INTEL, LaunchOptionCapability.PROTON };
            if (id.has_prefix ("dxvk-")) return { LaunchOptionCapability.DXVK };
            if (id.has_prefix ("vkd3d-")) return { LaunchOptionCapability.VKD3D_PROTON };
            if (id == "scopebuddy-auto-hdr" || id == "scopebuddy-auto-vrr") return { LaunchOptionCapability.SCOPEBUDDY };
            if (id == "native-wayland" || id == "proton-hdr" || id.has_prefix ("proton-") || id == "wined3d" || id == "d7vk" || id == "ntsync-mode" || id == "wow64" || id == "large-address-aware" || id == "writecopy" || id == "vulkan-sync2" || id == "futex-waitv" || id == "optiscaler" || id == "discord-bridge" || id == "prefer-sdl" || id == "bypass-steam-input" || id.has_prefix ("winealsa-")) return { LaunchOptionCapability.PROTON };
            return {};
        }

        LaunchOptionApplicability applicability_for (string id) {
            if (id == "d7vk" || id == "optiscaler" || id == "discord-bridge" || id == "winealsa-channels" || id == "winealsa-spatial")
                return LaunchOptionApplicability.VARIANT_SPECIFIC;
            if (id.has_prefix ("amd-") || id.has_prefix ("nvidia-") || id.has_prefix ("intel-") || id.has_prefix ("dxvk-") || id.has_prefix ("vkd3d-") || id == "vkbasalt" || id.has_prefix ("scopebuddy-"))
                return LaunchOptionApplicability.COMPONENT_SPECIFIC;
            return LaunchOptionApplicability.GENERIC;
        }

        void validate_option_semantics (LaunchOptionMetadata entry, Gee.List<string> diagnostics) {
            var semantics = entry.semantics;
            if (semantics == null) {
                diagnostics.add ("Option '%s' has no semantic definition.".printf (entry.id));
                return;
            }
            foreach (var dependency in semantics.dependencies) {
                if (dependency.strip () == "" || !by_id.has_key (dependency))
                    diagnostics.add ("Option '%s' has an unknown dependency '%s'.".printf (entry.id, dependency));
                if (dependency == entry.id)
                    diagnostics.add ("Option '%s' must not depend on itself.".printf (entry.id));
                var dependency_entry = lookup (dependency);
                if (semantics.managed_emission && dependency_entry != null
                    && dependency_entry.semantics != null
                    && !dependency_entry.semantics.managed_emission)
                    diagnostics.add ("Managed option '%s' depends on unmanaged option '%s'.".printf (entry.id, dependency));
            }
            foreach (var conflict in semantics.conflicts) {
                if (conflict.strip () == "" || !by_id.has_key (conflict))
                    diagnostics.add ("Option '%s' has an unknown conflict '%s'.".printf (entry.id, conflict));
                if (conflict == entry.id)
                    diagnostics.add ("Option '%s' must not conflict with itself.".printf (entry.id));
            }
            if (semantics.kind == LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT && semantics.environment_key.strip () == "")
                diagnostics.add ("Environment option '%s' requires an environment key.".printf (entry.id));
            if (semantics.emission_mode == LaunchOptionEmissionMode.FIXED_TOKENS && semantics.fixed_tokens.length == 0)
                diagnostics.add ("Fixed-emission option '%s' requires tokens.".printf (entry.id));
            if (semantics.kind == LaunchOptionSemanticKind.WRAPPER_ARGUMENT && lookup_wrapper (semantics.wrapper_id) == null)
                diagnostics.add ("Wrapper argument '%s' references an unknown wrapper '%s'.".printf (entry.id, semantics.wrapper_id));
            if (semantics.wrapper_id != "" && lookup_wrapper (semantics.wrapper_id) == null
                && semantics.kind != LaunchOptionSemanticKind.WRAPPER_ARGUMENT)
                diagnostics.add ("Option '%s' references an unknown wrapper '%s'.".printf (entry.id, semantics.wrapper_id));
            if (semantics.kind == LaunchOptionSemanticKind.WRAPPER_SELECTOR) {
                foreach (var wrapper_id in semantics.selectable_wrapper_ids) {
                    if (lookup_wrapper (wrapper_id) == null)
                        diagnostics.add ("Wrapper selector '%s' references an unknown wrapper '%s'.".printf (entry.id, wrapper_id));
                }
            }
            if (semantics.kind == LaunchOptionSemanticKind.COMMAND_BOUNDARY && entry.serialization_type != LaunchLineType.COMMAND)
                diagnostics.add ("Only legacy command entries may be command boundaries ('%s').".printf (entry.id));
            if (semantics.kind != LaunchOptionSemanticKind.COMMAND_BOUNDARY && entry.serialization_type == LaunchLineType.COMMAND)
                diagnostics.add ("Command entry '%s' must be a command boundary.".printf (entry.id));
            if (semantics.kind == LaunchOptionSemanticKind.COMMAND_BOUNDARY && semantics.placeholder_policy != LaunchPlaceholderPolicy.BUILDER_MANAGED_COMMAND_BOUNDARY)
                diagnostics.add ("Command boundary '%s' requires builder-managed placeholder policy.".printf (entry.id));
            if (semantics.kind == LaunchOptionSemanticKind.COMMAND_BOUNDARY && !semantics.legacy_manual_representation)
                diagnostics.add ("Command boundary '%s' must be marked as a legacy manual representation.".printf (entry.id));
            foreach (var token in semantics.fixed_tokens) {
                if (token.strip () == "")
                    diagnostics.add ("Option '%s' has an empty fixed token.".printf (entry.id));
                if (semantics.kind != LaunchOptionSemanticKind.COMMAND_BOUNDARY && token.contains ("%command%"))
                    diagnostics.add ("Option '%s' has %%command%% outside a command boundary.".printf (entry.id));
                if (semantics.kind == LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT
                    && token_key (token) != semantics.environment_key)
                    diagnostics.add ("Fixed environment token '%s' for '%s' does not use declared key '%s'.".printf (token, entry.id, semantics.environment_key));
            }
            foreach (var token in semantics.legacy_tokens) {
                if (token.strip () == "")
                    diagnostics.add ("Option '%s' has an empty legacy token.".printf (entry.id));
                if (token.contains ("%command%"))
                    diagnostics.add ("Option '%s' legacy tokens must not contain %%command%%.".printf (entry.id));
                foreach (var canonical in semantics.fixed_tokens) {
                    if (token == canonical)
                        diagnostics.add ("Option '%s' treats canonical token '%s' as legacy.".printf (entry.id, token));
                }
            }
            if ((semantics.support == LaunchOptionSupport.UNSUPPORTED
                 || semantics.support == LaunchOptionSupport.LEGACY_DEPRECATED)
                && semantics.managed_emission)
                diagnostics.add ("Unsupported or legacy option '%s' must not be managed emission.".printf (entry.id));
            if (semantics.managed_emission && semantics.support == LaunchOptionSupport.UNKNOWN_UNVERIFIED)
                diagnostics.add ("Managed option '%s' has unknown support semantics.".printf (entry.id));
            if (semantics.support == LaunchOptionSupport.UNSUPPORTED
                && semantics.applicability == LaunchOptionApplicability.GENERIC)
                diagnostics.add ("Unsupported option '%s' cannot claim generic applicability.".printf (entry.id));
            if (semantics.kind == LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT && semantics.emission_mode != LaunchOptionEmissionMode.FIXED_TOKENS && semantics.emission_mode != LaunchOptionEmissionMode.DYNAMIC_ENVIRONMENT_VALUE)
                diagnostics.add ("Environment option '%s' has an incompatible emission mode.".printf (entry.id));
            if (semantics.kind == LaunchOptionSemanticKind.WRAPPER_ARGUMENT && semantics.emission_mode != LaunchOptionEmissionMode.FIXED_TOKENS && semantics.emission_mode != LaunchOptionEmissionMode.DYNAMIC_WRAPPER_ARGUMENT)
                diagnostics.add ("Wrapper argument '%s' has an incompatible emission mode.".printf (entry.id));
            if (semantics.kind == LaunchOptionSemanticKind.WRAPPER_ARGUMENT) {
                var wrapper = lookup_wrapper (semantics.wrapper_id);
                if (wrapper != null && !has_capability (semantics.get_required_capabilities (), wrapper.required_capability))
                    diagnostics.add ("Wrapper argument '%s' does not require wrapper capability '%s'.".printf (entry.id, semantics.wrapper_id));
            }
            validate_parse_shape (entry.id, semantics.parse_shape, diagnostics);
            validate_composite_outputs (entry, semantics, diagnostics);
        }

        void validate_parse_shape (
            string owner, LaunchOptionParseShape? shape, Gee.List<string> diagnostics
        ) {
            if (shape == null)
                return;
            var arities = shape.get_value_arities ();
            if (shape.tokens.length == 0)
                diagnostics.add ("Parse shape '%s' requires tokens.".printf (owner));
            if (arities.length != shape.tokens.length)
                diagnostics.add ("Parse shape '%s' has invalid value arity.".printf (owner));
            foreach (var token in shape.tokens) {
                if (token.strip () == "")
                    diagnostics.add ("Parse shape '%s' has an empty flag.".printf (owner));
                if (token.contains ("%command%"))
                    diagnostics.add ("Parse shape '%s' must not contain %%command%%.".printf (owner));
            }
        }

        bool has_capability (LaunchOptionCapability[] capabilities, LaunchOptionCapability capability) {
            foreach (var candidate in capabilities) {
                if (candidate == capability)
                    return true;
            }
            return false;
        }

        void validate_composite_outputs (
            LaunchOptionMetadata entry, LaunchOptionSemantics semantics,
            Gee.List<string> diagnostics
        ) {
            var assignments = new Gee.HashMap<string, string> ();
            foreach (var output in semantics.get_composite_outputs ()) {
                if (output.kind == LaunchOptionSemanticKind.WRAPPER_ARGUMENT
                    && lookup_wrapper (output.wrapper_id) == null)
                    diagnostics.add ("Composite option '%s' references unknown wrapper '%s'.".printf (entry.id, output.wrapper_id));
                validate_parse_shape (entry.id, output.parse_shape, diagnostics);
                if (output.kind != LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT)
                    continue;
                if (output.environment_key.strip () == "") {
                    diagnostics.add ("Composite environment output for '%s' requires a key.".printf (entry.id));
                    continue;
                }
                foreach (var token in output.fixed_tokens) {
                    if (token_key (token) != output.environment_key)
                        diagnostics.add ("Composite token '%s' for '%s' does not use declared key '%s'.".printf (token, entry.id, output.environment_key));
                    if (assignments.has_key (output.environment_key) && assignments.get (output.environment_key) != token)
                        diagnostics.add ("Composite option '%s' emits contradictory assignments for '%s'.".printf (entry.id, output.environment_key));
                    else
                        assignments.set (output.environment_key, token);
                }
            }
        }

        void add_defaults () {
            // Performance & monitoring
            add_option ("performance-overlay", _("MangoHud performance overlay"), _("Shows FPS, CPU/GPU usage, and temperatures in game."), LaunchOptionCategory.PERFORMANCE, 10, { "mangohud" }, { "MangoHud", "performance overlay" }, LaunchLineType.WRAPPER, "", true);
            add_option ("gamemode", _("GameMode"), _("Requests temporary system performance optimizations while the game is running."), LaunchOptionCategory.PERFORMANCE, 20, { "gamemoderun" }, { "Feral Gamemode", "gamemoderun" }, LaunchLineType.WRAPPER, "", true);
            add_option ("high-process-priority", _("High process priority"), _("Gives the game a higher CPU priority."), LaunchOptionCategory.PERFORMANCE, 30, { "PROTON_PRIORITY_HIGH=1" });
            add_option ("per-game-shader-cache", _("Per-game shader cache"), _("Keeps this game's shader cache separate."), LaunchOptionCategory.PERFORMANCE, 40, { "PROTON_LOCAL_SHADER_CACHE=1" }, { "local shader cache" });

            // Display & launch tools
            add_option ("launch-backend", _("Launch backend"), _("Choose the system default, Gamescope, or ScopeBuddy."), LaunchOptionCategory.DISPLAY, 10, { "gamescope", "scopebuddy" }, { "System default", "Gamescope", "ScopeBuddy" }, LaunchLineType.WRAPPER);
            add_option ("native-wayland", _("Native Wayland"), _("Runs the game on Wayland instead of XWayland."), LaunchOptionCategory.DISPLAY, 20, { "PROTON_ENABLE_WAYLAND=1" }, { "Wayland" });
            add_option ("desktop-game-profile", _("Use desktop game profile"), _("Uses the desktop profile instead of a Steam Deck-specific profile."), LaunchOptionCategory.DISPLAY, 30, { "SteamDeck=0" }, { "Disable Steam Deck Mode", "Steam Deck" });
            add_option ("vkbasalt", _("vkBasalt visual effects"), _("Adds visual effects such as sharpening and color adjustments."), LaunchOptionCategory.DISPLAY, 40, { "ENABLE_VKBASALT=1" }, { "VKBasalt" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("proton-hdr", _("HDR through Proton"), _("Outputs HDR colors through Proton when the display supports it."), LaunchOptionCategory.DISPLAY, 50, { "PROTON_ENABLE_HDR=1" }, {}, LaunchLineType.ENVIRONMENT, "", true);
            add_option ("gamescope-fullscreen", _("Fullscreen"), _("Runs the game in a fullscreen Gamescope session."), LaunchOptionCategory.DISPLAY, 60, { "-f" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.STANDARD, _("Requires Gamescope"));
            add_option ("gamescope-resolution", _("Output resolution"), _("Sets the Gamescope output resolution."), LaunchOptionCategory.DISPLAY, 70, { "-W", "-H" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.STANDARD, _("Requires Gamescope"));
            add_option ("gamescope-hdr", _("HDR"), _("Outputs HDR colors through Gamescope."), LaunchOptionCategory.DISPLAY, 80, { "--hdr-enabled" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), true, LaunchOptionExpertise.STANDARD, _("Requires Gamescope"));
            add_option ("gamescope-vrr", _("Variable refresh rate"), _("Matches the display refresh rate to the game's FPS."), LaunchOptionCategory.DISPLAY, 90, { "--adaptive-sync" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.STANDARD, _("Requires Gamescope"));
            add_option ("gamescope-frame-limit", _("Frame limit"), _("Caps the frame rate inside Gamescope."), LaunchOptionCategory.DISPLAY, 100, { "-r" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), true, LaunchOptionExpertise.STANDARD, _("Requires Gamescope"));
            add_option ("gamescope-arguments", _("Additional Gamescope arguments"), _("Keeps extra Gamescope flags such as output selection."), LaunchOptionCategory.DISPLAY, 110, { "gamescope" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.ADVANCED, _("Requires Gamescope"));
            add_option ("scopebuddy-fullscreen", _("Fullscreen"), _("Runs the game in a fullscreen ScopeBuddy session."), LaunchOptionCategory.DISPLAY, 120, { "-f" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.STANDARD, _("Requires ScopeBuddy"));
            add_option ("scopebuddy-resolution", _("Output resolution"), _("Sets the ScopeBuddy output resolution."), LaunchOptionCategory.DISPLAY, 130, { "SCB_W", "SCB_H" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.STANDARD, _("Requires ScopeBuddy"));
            add_option ("scopebuddy-auto-hdr", _("Automatic HDR"), _("Enables HDR automatically when the display supports it."), LaunchOptionCategory.DISPLAY, 140, { "SCB_AUTO_HDR=1" }, {}, LaunchLineType.ENVIRONMENT, _("ScopeBuddy"), true, LaunchOptionExpertise.STANDARD, _("Requires ScopeBuddy"));
            add_option ("scopebuddy-auto-vrr", _("Automatic variable refresh rate"), _("Matches the display refresh rate to the game's FPS."), LaunchOptionCategory.DISPLAY, 150, { "SCB_AUTO_VRR=1" }, {}, LaunchLineType.ENVIRONMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.STANDARD, _("Requires ScopeBuddy"));
            add_option ("scopebuddy-frame-limit", _("Frame limit"), _("Caps the frame rate inside ScopeBuddy."), LaunchOptionCategory.DISPLAY, 160, { "-r" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), true, LaunchOptionExpertise.STANDARD, _("Requires ScopeBuddy"));
            add_option ("scopebuddy-arguments", _("Additional ScopeBuddy arguments"), _("Keeps extra ScopeBuddy flags such as preferred output selection."), LaunchOptionCategory.DISPLAY, 170, { "scopebuddy", "scb" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.ADVANCED, _("Requires ScopeBuddy"));

            // Proton & Wine compatibility
            add_option ("wined3d", _("OpenGL fallback (WineD3D)"), _("Uses OpenGL instead of Vulkan when DXVK causes problems."), LaunchOptionCategory.PROTON, 10, { "PROTON_USE_WINED3D=1" }, { "WineD3D" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("d7vk", _("D7VK for older Direct3D games"), _("Enables D7VK for older Direct3D games."), LaunchOptionCategory.PROTON, 20, { "PROTON_USE_D7VK=1" }, { "D7VK" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires a compatible Proton version"));
            add_option ("ntsync-mode", _("NTSync mode"), _("Uses FSync instead of NTSync for games that need that compatibility mode."), LaunchOptionCategory.PROTON, 30, { "PROTON_USE_NTSYNC=0" }, { "Use FSync" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("large-address-aware", _("Large address awareness for 32-bit games"), _("Lets supported 32-bit games use more than 2GB of memory."), LaunchOptionCategory.PROTON, 40, { "PROTON_FORCE_LARGE_ADDRESS_AWARE=1" });
            add_option ("wow64", _("WoW64 mode"), _("Enables WoW64 support for 32-bit games on 64-bit Proton builds."), LaunchOptionCategory.PROTON, 50, { "PROTON_USE_WOW64=1" }, { "Use WoW64" });
            add_option ("writecopy", _("Write-copy memory workaround"), _("Simulates page write protection for initialization errors."), LaunchOptionCategory.PROTON, 60, { "WINE_SIMULATE_WRITECOPY=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("vulkan-sync2", _("Vulkan synchronization 2"), _("Enables WINE_VK_USE_SYNC2."), LaunchOptionCategory.PROTON, 70, { "WINE_VK_USE_SYNC2=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("futex-waitv", _("Futex waitv synchronization"), _("Enables WINE_SYNC_USE_FUTEX_WAITV."), LaunchOptionCategory.PROTON, 80, { "WINE_SYNC_USE_FUTEX_WAITV=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("optiscaler", _("OptiScaler integration"), _("Enables Proton OptiScaler."), LaunchOptionCategory.PROTON, 90, { "PROTON_USE_OPTISCALER=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires Proton 11-1 or newer"));
            add_option ("discord-bridge", _("Discord bridge"), _("Enables Proton's Discord bridge."), LaunchOptionCategory.PROTON, 100, { "PROTON_DISCORD_BRIDGE=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires Proton 11-1 or newer"));
            add_option ("dll-overrides", _("Wine DLL overrides"), _("Choose builtin or native Windows DLL behavior."), LaunchOptionCategory.PROTON, 110, { "DLL_OVERRIDES" }, { "mscoree", "dxgi", "wined3d" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);

            // Graphics translation
            add_option ("dxvk-frame-limit", _("DXVK frame limit"), _("Caps the frame rate with DXVK's built-in limiter."), LaunchOptionCategory.GRAPHICS, 10, { "DXVK_FRAME_RATE=" }, {}, LaunchLineType.ENVIRONMENT, _("DXVK"));
            add_option ("dxvk-async", _("Asynchronous pipeline compilation"), _("Enables DXVK asynchronous pipeline compilation."), LaunchOptionCategory.GRAPHICS, 20, { "DXVK_ASYNC=1" }, { "DXVK Async" }, LaunchLineType.ENVIRONMENT, _("DXVK"), false, LaunchOptionExpertise.EXPERIMENTAL, _("Requires compatible patched DXVK"));
            add_option ("vkd3d-shader-cache", _("VKD3D shader cache"), _("Enables VKD3D's internal shader cache."), LaunchOptionCategory.GRAPHICS, 30, { "VKD3D_SHADER_CACHE=1" }, {}, LaunchLineType.ENVIRONMENT, _("VKD3D-Proton"));
            add_option ("vkd3d-gpuva", _("VKD3D GPU virtual addressing"), _("Enables VKD3D GPU virtual addressing."), LaunchOptionCategory.GRAPHICS, 40, { "VKD3D_GPUVA=1" }, {}, LaunchLineType.ENVIRONMENT, _("VKD3D-Proton"), false, LaunchOptionExpertise.ADVANCED);
            add_option ("vkd3d-config", _("VKD3D compatibility settings"), _("Configure Direct3D 12 to Vulkan compatibility workarounds."), LaunchOptionCategory.GRAPHICS, 50, { "VKD3D_CONFIG", "shader_cache", "force_host_cache", "upload_hvv", "no_upload_hvv", "gpuva", "stable_power_state" }, { "VKD3D Proton Configurations" }, LaunchLineType.ENVIRONMENT, _("VKD3D-Proton"), false, LaunchOptionExpertise.ADVANCED);

            // Hardware & drivers
            add_option ("amd-discrete-gpu", _("Use discrete GPU"), _("Uses the AMD discrete GPU on hybrid systems."), LaunchOptionCategory.HARDWARE, 10, { "DRI_PRIME=1" }, { "Use dGPU" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("AMD"));
            add_option ("amd-anti-lag", _("Mesa Anti-Lag"), _("Reduces latency on supported AMD Mesa setups."), LaunchOptionCategory.HARDWARE, 20, { "ENABLE_LAYER_MESA_ANTI_LAG=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("AMD"));
            add_option ("amd-fsr4", _("FSR 4 upgrade"), _("Upgrades supported FSR 3.1 games to FSR 4."), LaunchOptionCategory.HARDWARE, 30, { "PROTON_FSR4_UPGRADE=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("AMD"));
            add_option ("amd-fsr4-rdna3", _("FSR 4 RDNA3 upgrade"), _("Optimizes FSR 4 for RDNA3 hardware."), LaunchOptionCategory.HARDWARE, 40, { "PROTON_FSR4_RDNA3_UPGRADE=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("AMD"));
            add_option ("amd-hide-apu", _("Treat APU as a discrete GPU"), _("Reports an AMD APU as a discrete GPU for games that mis-detect integrated graphics."), LaunchOptionCategory.HARDWARE, 50, { "PROTON_HIDE_APU=1" }, { "Hide AMD APU" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("AMD"));
            add_option ("amd-vulkan-driver", _("Vulkan driver"), _("Chooses the AMD Vulkan driver for this game."), LaunchOptionCategory.HARDWARE, 60, { "AMD_ICD" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED, _("AMD"));
            add_option ("amd-staging-shm", _("Staging shared memory"), _("Enables AMD driver shared memory support."), LaunchOptionCategory.HARDWARE, 70, { "STAGING_SHARED_MEMORY=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("AMD"));
            add_option ("amd-glthread", _("Mesa GL threading"), _("Enables Mesa GLThread."), LaunchOptionCategory.HARDWARE, 80, { "mesa_glthread=true" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED, _("AMD"));
            add_option ("amd-shader-cache", _("Mesa shader-cache control"), _("Controls Mesa's shader cache."), LaunchOptionCategory.HARDWARE, 90, { "MESA_SHADER_CACHE_DISABLE=0", "MESA_SHADER_CACHE_DISABLE=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED, _("AMD"));
            add_option ("amd-radv-perftest", _("Experimental RADV features"), _("Tests experimental RADV performance features."), LaunchOptionCategory.HARDWARE, 100, { "RADV_PERFTEST" }, { "AMD RADV Performance Tests" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.EXPERIMENTAL, _("AMD"));
            add_option ("amd-radv-debug", _("RADV workarounds and debugging"), _("Configure RADV compatibility workarounds and debugging."), LaunchOptionCategory.HARDWARE, 110, { "RADV_DEBUG" }, { "AMD RADV Debug Options" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED, _("AMD"));
            add_option ("amd-aco-debug", _("ACO shader-compiler debugging"), _("Configure AMD ACO shader compiler debugging."), LaunchOptionCategory.HARDWARE, 120, { "ACO_DEBUG" }, { "AMD ACO Debug Options" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED, _("AMD"));
            add_option ("nvidia-nvapi", _("NVAPI"), _("Lets games access NVIDIA-specific features such as DLSS."), LaunchOptionCategory.HARDWARE, 130, { "PROTON_ENABLE_NVAPI=1" }, {}, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD, _("NVIDIA"));
            add_option ("nvidia-dlss-updater", _("DLSS component updates"), _("Updates DLSS components for supported games."), LaunchOptionCategory.HARDWARE, 140, { "PROTON_ENABLE_NGX_UPDATER=1" }, { "Update DLSS components" }, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD, _("NVIDIA"));
            add_option ("nvidia-dlss-indicator", _("DLSS indicator"), _("Shows an in-game DLSS status indicator."), LaunchOptionCategory.HARDWARE, 150, { "PROTON_DLSS_INDICATOR=1" }, {}, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD, _("NVIDIA"));
            add_option ("nvidia-libraries", _("NVIDIA libraries"), _("Enables NVIDIA-specific libraries."), LaunchOptionCategory.HARDWARE, 160, { "PROTON_NVIDIA_LIBS=1" }, {}, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD, _("NVIDIA"));
            add_option ("nvidia-report-amd", _("Report GPU as AMD"), _("Reports an NVIDIA GPU as AMD for affected games."), LaunchOptionCategory.HARDWARE, 170, { "PROTON_HIDE_NVIDIA_GPU=1" }, { "Hide NVIDIA GPU" }, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD, _("NVIDIA"));
            add_option ("intel-xess", _("XeSS component upgrade"), _("Updates XeSS in supported games."), LaunchOptionCategory.HARDWARE, 180, { "PROTON_XESS_UPGRADE=1" }, { "XeSS Upgrade" }, LaunchLineType.ENVIRONMENT, _("Intel"), false, LaunchOptionExpertise.STANDARD, _("Intel"));

            // Input & audio
            add_option ("prefer-sdl", _("Prefer SDL controller input"), _("Works around controller detection issues."), LaunchOptionCategory.INPUT_AUDIO, 10, { "PROTON_PREFER_SDL=1" }, { "Prefer SDL controller" });
            add_option ("bypass-steam-input", _("Bypass Steam Input"), _("Disables Steam Input support."), LaunchOptionCategory.INPUT_AUDIO, 20, { "PROTON_NO_STEAMINPUT=1" }, { "Disable Steam Input" });
            add_option ("pulse-latency", _("PulseAudio latency"), _("Sets the PulseAudio latency target."), LaunchOptionCategory.INPUT_AUDIO, 30, { "PULSE_LATENCY_MSEC=" });
            add_option ("winealsa-channels", _("Wine ALSA output channels"), _("Sets the Wine ALSA output channel count."), LaunchOptionCategory.INPUT_AUDIO, 40, { "WINEALSA_CHANNELS=" }, { "WINEALSA Channels" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires Proton 11-1 or newer"));
            add_option ("winealsa-spatial", _("Wine ALSA spatial downmix"), _("Enables Wine ALSA spatial downmix for 4, 6, or 8 channels."), LaunchOptionCategory.INPUT_AUDIO, 50, { "WINEALSA_SPACIAL=1" }, { "WINEALSA Spatial Audio" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires 4, 6, or 8 output channels"), { "winealsa-channels" });

            // Game arguments
            add_option ("skip-launcher", _("Skip launcher"), _("Adds -skip-launcher for games that support it."), LaunchOptionCategory.GAME_ARGUMENTS, 10, { "-skip-launcher" }, {}, LaunchLineType.ARGUMENT, "", true);
            add_option ("renderer-vulkan", _("Vulkan renderer"), _("Adds -vulkan."), LaunchOptionCategory.GAME_ARGUMENTS, 20, { "-vulkan" }, {}, LaunchLineType.ARGUMENT);
            add_option ("renderer-dx11", _("DirectX 11 renderer"), _("Adds -dx11."), LaunchOptionCategory.GAME_ARGUMENTS, 30, { "-dx11" }, {}, LaunchLineType.ARGUMENT);
            add_option ("renderer-dx12", _("DirectX 12 renderer"), _("Adds -dx12."), LaunchOptionCategory.GAME_ARGUMENTS, 40, { "-dx12" }, {}, LaunchLineType.ARGUMENT);
            add_option ("developer-console", _("Developer console"), _("Adds -console when the game supports it."), LaunchOptionCategory.GAME_ARGUMENTS, 50, { "-console" }, { "Console" }, LaunchLineType.ARGUMENT);
            add_option ("custom-game-arguments", _("Custom game arguments"), _("Adds your own game arguments without changing recognized controls."), LaunchOptionCategory.GAME_ARGUMENTS, 60, { "custom", "arguments" }, {}, LaunchLineType.ADDITIONAL, "", false, LaunchOptionExpertise.ADVANCED);

            // Diagnostics & raw command
            add_option ("proton-debug-log", _("Proton debug log"), _("Enables Proton troubleshooting logs."), LaunchOptionCategory.DIAGNOSTICS, 10, { "PROTON_LOG=1" }, { "Enable Proton logs" }, LaunchLineType.ENVIRONMENT, "", true);
            add_option ("dxvk-log-level", _("DXVK log level"), _("Controls DXVK logging."), LaunchOptionCategory.DIAGNOSTICS, 20, { "DXVK_LOG_LEVEL=none" }, { "Disable DXVK logging" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("vkd3d-log-level", _("VKD3D log level"), _("Controls VKD3D troubleshooting logs."), LaunchOptionCategory.DIAGNOSTICS, 30, { "VKD3D_LOG_LEVEL=" }, { "VKD3D Logging Level" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("steam-command", _("Steam command placeholder (%command%)"), _("Marks where Steam inserts the game's command."), LaunchOptionCategory.DIAGNOSTICS, 40, { "%command%" }, {}, LaunchLineType.COMMAND, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("raw-launch-options", _("Preserved unrecognized launch options"), _("Keeps unrecognized, quoted, and opaque shell content exactly as loaded."), LaunchOptionCategory.DIAGNOSTICS, 50, { "$(unsafe)", "|", "&&", "%command%" }, { "raw", "opaque", "unknown", "custom pair" }, LaunchLineType.ADDITIONAL, "", false, LaunchOptionExpertise.ADVANCED);
        }
    }
}
