namespace ProtonPlus.LaunchOptions {
    using Gee;

    /* The catalog defines metadata and command semantics shared by the
     * parser, writer, and editor. */
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

    /* Command semantics are independent of the token classifications retained
     * by legacy control adapters. */
    public enum LaunchOptionSemanticKind {
        ENVIRONMENT_ASSIGNMENT,
        PREFIX_WRAPPER,
        DELIMITED_WRAPPER,
        WRAPPER_ARGUMENT,
        GAME_ARGUMENT,
        WRAPPER_SELECTOR,
        COMMAND_BOUNDARY,
        COMPOSITE_DYNAMIC,
        OPAQUE_CONTEXT_DEPENDENT,
        CUSTOM_WRAPPER
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
        DYNAMIC_GAME_ARGUMENTS,
        WRAPPER_SELECTION,
        COMPOSITE_EMISSION,
        RAW_CONTEXT_DEPENDENT,
        DYNAMIC_WRAPPER_EXECUTABLE
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
        MANGOAPP,
        TINKERGAME,
        STEAMTINKERLAUNCH,
        MANGOHUD,
        GAMEMODE,
        GAME_PERFORMANCE,
        OBS_VKCAPTURE,
        LEGACY_PROTON_HDR,
        PROTON_AUTO_HDR_CONTROL,
        PROTON_FSR4,
        PROTON_FSR4_RDNA3,
        PROTON_MLFG,
        PROTON_DXVK_LOW_LATENCY,
        PROTON_VKD3D_LOW_LATENCY,
        LOW_LATENCY_LAYER,
        VULKAN_REFLEX_LAYER,
        VKBASALT,
        PROTON_LOCAL_SHADER_CACHE,
        PROTON_D7VK,
        PROTON_OPTISCALER,
        OBS_GAMECAPTURE,
        AMD_VULKAN_SWITCHER,
        PROTON_DXVK_HDR,
        WINEALSA_CHANNELS,
        WINEALSA_SPATIAL,
        PROTON_ESYNC,
        PROTON_FSYNC,
        PROTON_NTSYNC,
        PROTON_NO_D3D11,
        PROTON_NO_D3D10,
        PROTON_DISABLE_NVAPI,
        PROTON_LOG_DIR,
        DXVK_FRAME_CONFIG,
        DXVK_DEVICE_FILTER,
        DXVK_LOG_PATH,
        DXVK_SHADER_CACHE,
        DXVK_SHADER_CACHE_PATH,
        VKD3D_DEVICE_FILTER,
        VKD3D_DEVICE_INDEX,
        VKD3D_FRAME_RATE,
        VKD3D_LOG_FILE,
        VKD3D_SHADER_CACHE_PATH,
        PROTON_SDL,
        PROTON_WAYLAND,
        PROTON_WOW64,
        PROTON_PIPEWIRE,
        PROTON_SAREK,
        PROTON_FSR4_INDICATOR,
        PROTON_HEVC_DEFAULTS,
        PROTON_TKG_NVAPI,
        PROTON_TKG_WINEDBG,
        PROTON_TKG_PULSE,
        PROTON_TKG_D3D9,
        PROTON_TKG_WINETRICKS,
        PROTON_ANIME_HSR,
        PROTON_ANIME_KURO,
        BOXTRON_SIERRA,
        ROBERTA_COMMAND,
        ROBERTA_SCREEN,
        PROTON_ANIME_RESHADE,
        PROTON_ANIME_RESHADE_PATH,
        PROTON_ANIME_WUWA,
        PROTON_WINELAND_UPSCALER,
        PROTON_ANIME_XXMI,
        PROTON_ANIME_GIMI,
        PROTON_ANIME_SRMI,
        PROTON_ANIME_ZZMI,
        PROTON_ANIME_HIMI,
        PROTON_ANIME_WWMI,
        PROTON_ANIME_EFMI,
        PROTON_ANIME_GI,
        PROTON_ANIME_NTE,
        PROTON_ANIME_NTE_TIMEOUT,
        LUX_CONFIRM,
        LUX_LOGGING,
        LUX_CLOUD,
        ROSEMARY_GLIBC,
        ROSEMARY_TRACE
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

        internal static bool is_rate_flag (string flag) {
            return flag == "-r" || flag == "--framerate-limit";
        }

        internal static bool matches_rate_flag (string flag, string token) {
            return token == flag || (flag == "-r" && token == "--nested-refresh");
        }

        internal static string? attached_rate_value (string flag, string token) {
            string? value = null;
            if (flag == "-r" && token.has_prefix ("-r") && token.length > 2)
                value = token.substring (2);
            else if (flag == "-r" && token.has_prefix ("--nested-refresh="))
                value = token.substring ("--nested-refresh=".length);
            else if (flag == "--framerate-limit" && token.has_prefix ("--framerate-limit="))
                value = token.substring ("--framerate-limit=".length);
            int number;
            return value != null && int.try_parse (value, out number) ? value : null;
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
        public string value_separator { get; construct; }
        public string implicit_value { get; construct; }
        public string value_pattern { get; construct; }
        public string environment_value_prefix { get; construct; }
        public string disabled_feature_value { get; construct; }
        public LaunchOptionParseShape? parse_shape { get; construct; }
        LaunchOptionCapability[] _required_capabilities;
        public LaunchOptionApplicability applicability { get; construct; }
        LaunchOptionSemanticOutput[] _composite_outputs;
        public bool legacy_manual_representation { get; construct; }

        internal bool is_feature_disabled (string value) {
            return disabled_feature_value != "" && value == disabled_feature_value;
        }

        internal bool accepts_value_format (string value) {
            return value_pattern == "" || Regex.match_simple (value_pattern, value, RegexCompileFlags.RAW);
        }

        internal string? decode_environment_value (owned string value) {
            if (environment_value_prefix != "") {
                var separator = value.index_of_char ('=');
                if (separator < 0 || value.substring (0, separator).strip () != environment_value_prefix)
                    return null;
                value = value.substring (separator + 1).strip ();
            }
            return accepts_value_format (value) ? value : null;
        }

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
            LaunchOptionParseShape? parse_shape = null,
            string value_separator = "",
            string implicit_value = "",
            string value_pattern = "",
            string environment_value_prefix = "",
            string disabled_feature_value = ""
        ) {
            Object (
                kind: kind, placeholder_policy: placeholder_policy,
                implicit_value: implicit_value, value_pattern: value_pattern,
                environment_value_prefix: environment_value_prefix,
                disabled_feature_value: disabled_feature_value,
                emission_mode: emission_mode, environment_key: environment_key,
                wrapper_id: wrapper_id, fixed_tokens: fixed_tokens,
                selectable_wrapper_ids: selectable_wrapper_ids,
                conflict_group: conflict_group, conflicts: conflicts,
                dependencies: dependencies, applicability: applicability,
                legacy_manual_representation: legacy_manual_representation,
                support: support, managed_emission: managed_emission,
                legacy_tokens: legacy_tokens, selectable_values: selectable_values,
                parse_shape: parse_shape, value_separator: value_separator
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
        public bool uses_installed_path { get; construct; }

        public LaunchWrapperDefinition (
            string id, string[] executable_tokens, string[] parse_aliases = {},
            string? delimiter = null, uint nesting_priority = 0,
            string mutual_exclusion_group = "",
            LaunchOptionCapability required_capability = LaunchOptionCapability.STEAM,
            bool uses_installed_path = false
        ) {
            Object (
                id: id, executable_tokens: executable_tokens,
                parse_aliases: parse_aliases, delimiter: delimiter,
                nesting_priority: nesting_priority,
                mutual_exclusion_group: mutual_exclusion_group,
                required_capability: required_capability, uses_installed_path: uses_installed_path
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
                var owner = lookup (canonical_keys.get (semantics.environment_key) ?? "");
                if (!distinct_environment_values (owner?.semantics, semantics))
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

        bool distinct_environment_values (LaunchOptionSemantics? first, LaunchOptionSemantics second) {
            if (first == null)
                return false;
            var patterned = first.environment_value_prefix != "" ? first : second;
            var fixed = patterned == first ? second : first;
            if (patterned.environment_value_prefix == "" || fixed.emission_mode != LaunchOptionEmissionMode.FIXED_TOKENS)
                return false;
            foreach (var token in fixed.fixed_tokens) {
                if (patterned.decode_environment_value (token.substring (fixed.environment_key.length + 1)) != null)
                    return false;
            }
            return true;
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
                    if (!(entry.id in other.semantics.conflicts)
                        && (semantics.conflict_group == "" || semantics.conflict_group != other.semantics.conflict_group))
                        diagnostics.add ("Conflict '%s' declared by '%s' is not reciprocal.".printf (conflict_id, entry.id));
                }
            }
            foreach (var group in groups.keys) {
                if (groups.get (group) < 2)
                    diagnostics.add ("Conflict group '%s' must contain at least two options.".printf (group));
            }
        }

        void add_option (
            string id, string title, string description, LaunchOptionCategory category,
            uint rank, string[] raw_tokens, string[] aliases = {},
            LaunchLineType type = LaunchLineType.ENVIRONMENT, string subsection = "",
            bool quick = false, LaunchOptionExpertise expertise = LaunchOptionExpertise.STANDARD,
            string applicability = "", string[] dependencies = {},
            LaunchOptionSemantics? declared_semantics = null
        ) {
            var semantics = declared_semantics ?? create_semantics (id, type, raw_tokens, dependencies);
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
                "game-performance", { "game-performance" }, {}, null, 25, "",
                LaunchOptionCapability.GAME_PERFORMANCE
            ));
            add_wrapper (new LaunchWrapperDefinition (
                "obs-gamecapture", { "obs-gamecapture" }, {}, null, 40, "",
                LaunchOptionCapability.OBS_GAMECAPTURE
            ));
            add_wrapper (new LaunchWrapperDefinition (
                "gamescope", { "gamescope" }, {}, "--", 30, "launch-backend",
                LaunchOptionCapability.GAMESCOPE
            ));
            add_wrapper (new LaunchWrapperDefinition (
                "scopebuddy", { "scopebuddy" }, { "scb" }, "--", 30, "launch-backend",
                LaunchOptionCapability.SCOPEBUDDY
            ));
            add_wrapper (new LaunchWrapperDefinition (
                "tinkergame", { "tinkergame" }, {}, null, 50, "native-game-wrapper",
                LaunchOptionCapability.TINKERGAME, true
            ));
            add_wrapper (new LaunchWrapperDefinition (
                "steamtinkerlaunch", { "steamtinkerlaunch" }, {}, null, 50, "native-game-wrapper",
                LaunchOptionCapability.STEAMTINKERLAUNCH, true
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
            if (id == "game-performance")
                return wrapper_semantics ("game-performance");
            if (id == "obs-gamecapture")
                return wrapper_semantics (id);
            if (id == "launch-backend" || id == "native-game-wrapper") {
                var native_wrapper = id == "native-game-wrapper";
                return new LaunchOptionSemantics (
                    LaunchOptionSemanticKind.WRAPPER_SELECTOR,
                    LaunchPlaceholderPolicy.REQUIRED,
                    LaunchOptionEmissionMode.WRAPPER_SELECTION,
                    "", "", {}, raw_tokens, id,
                    {}, {}, native_wrapper
                        ? new LaunchOptionCapability[] { LaunchOptionCapability.NATIVE_LINUX }
                        : new LaunchOptionCapability[0], LaunchOptionApplicability.COMPONENT_SPECIFIC,
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
            if (id == LaunchCustomWrapperInput.OPTION_ID) {
                return new LaunchOptionSemantics (
                    LaunchOptionSemanticKind.CUSTOM_WRAPPER,
                    LaunchPlaceholderPolicy.REQUIRED,
                    LaunchOptionEmissionMode.DYNAMIC_WRAPPER_EXECUTABLE,
                    "", "", {}, {}, "", {}, {}, {},
                    LaunchOptionApplicability.GENERIC, {}, false,
                    LaunchOptionSupport.VERIFIED_CURRENT, true
                );
            }
            if (id == "custom-game-arguments") {
                return new LaunchOptionSemantics (
                    LaunchOptionSemanticKind.GAME_ARGUMENT,
                    LaunchPlaceholderPolicy.OPTIONAL,
                    LaunchOptionEmissionMode.DYNAMIC_GAME_ARGUMENTS,
                    "", "", {}, {}, "", {}, {}, {},
                    LaunchOptionApplicability.GENERIC, {}, false,
                    support_for (id), true, {}, {}
                );
            }
            if (id == "raw-launch-options") {
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
                    legacy_tokens_for (id), { "auto" }
                );
            }
            if (is_wrapper_argument (serialization_type)) {
                var shape = wrapper_parse_shape_for (id, raw_tokens);
                bool dynamic_value = shape == null || shape.get_value_arities ()[0] > 0;
                string wrapper_id = id.has_prefix ("gamescope-") ? "gamescope" : "scopebuddy";
                var capabilities = id == "gamescope-mangoapp"
                    ? new LaunchOptionCapability[] { LaunchOptionCapability.GAMESCOPE, LaunchOptionCapability.MANGOAPP }
                    : new LaunchOptionCapability[] {
                        wrapper_id == "gamescope" ? LaunchOptionCapability.GAMESCOPE : LaunchOptionCapability.SCOPEBUDDY
                    };
                return new LaunchOptionSemantics (
                    LaunchOptionSemanticKind.WRAPPER_ARGUMENT,
                    LaunchPlaceholderPolicy.INHERITED_FROM_WRAPPER,
                    dynamic_value ? LaunchOptionEmissionMode.DYNAMIC_WRAPPER_ARGUMENT : LaunchOptionEmissionMode.FIXED_TOKENS,
                    "", wrapper_id, dynamic_value ? new string[0] : raw_tokens, {}, "", {}, backend_dependencies (dependencies),
                    capabilities,
                    LaunchOptionApplicability.COMPONENT_SPECIFIC, {}, false,
                    support_for (id), is_managed_emission (id), legacy_tokens_for (id), selectable_values_for (id),
                    shape
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
                    conflict_group_for (id), conflicts_for (id),
                    scopebuddy_owner (id) != "" ? backend_dependencies (dependencies) : dependencies,
                    capabilities_for (id), applicability_for (id), {}, false,
                    support_for (id), is_managed_emission (id), legacy_tokens_for (id), selectable_values_for (id),
                    null, dynamic_environment_separator_for (id),
                    id == "dxvk-log-level" ? "none" : implicit_environment_value (id),
                    "", "", id == "amd-fsr4" || id == "amd-mlfg" ? "0" : ""
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
                "", wrapper_id, {}, {}, "", conflicts_for (wrapper_id), {}, { definition.required_capability },
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
                case "gamescope-force-grab-cursor":
                case "gamescope-hdr-itm":
                case "gamescope-mangoapp":
                    return new LaunchOptionParseShape (raw_tokens, { 0 });
                case "gamescope-resolution":
                case "gamescope-internal-resolution":
                    return new LaunchOptionParseShape (raw_tokens, { 1, 1 });
                case "gamescope-frame-limit":
                case "scopebuddy-frame-limit":
                    return new LaunchOptionParseShape ({ "-r" }, { 1 });
                case "gamescope-fps-limit":
                case "scopebuddy-fps-limit":
                case "gamescope-scaler":
                case "gamescope-filter":
                case "gamescope-sharpness":
                case "gamescope-prefer-output":
                case "gamescope-display-index":
                case "gamescope-hide-cursor-delay":
                case "gamescope-hdr-sdr-nits":
                case "gamescope-hdr-itm-sdr-nits":
                case "gamescope-hdr-itm-target-nits":
                    return new LaunchOptionParseShape (raw_tokens, { 1 });
                default:
                    return null;
            }
        }

        string dynamic_environment_separator_for (string id) {
            switch (id) {
                case "vkd3d-config":
                case "amd-radv-perftest":
                case "amd-radv-debug":
                case "amd-aco-debug":
                    return ",";
                default:
                    return "";
            }
        }

        string implicit_environment_value (string id) {
            switch (id) {
                case "amd-fsr4":
                case "amd-mlfg":
                case "optiscaler":
                case "native-wayland":
                case "wow64":
                case "prefer-sdl":
                case "wined3d":
                case "proton-debug-log":
                case "large-address-aware":
                    return "1";
                default:
                    return "";
            }
        }

        bool is_dynamic_environment (string id) {
            switch (id) {
                case "scopebuddy-profile":
                case "scopebuddy-app-id":
                case "scopebuddy-environment-only":
                case "scopebuddy-auto-refresh":
                case "scopebuddy-auto-frame-limit":
                case "scopebuddy-append-mode":
                case "scopebuddy-debug":
                    return true;
                case "amd-fsr4":
                case "amd-mlfg":
                case "optiscaler":
                case "native-wayland":
                case "wow64":
                case "prefer-sdl":
                case "wined3d":
                case "proton-debug-log":
                case "large-address-aware":
                case "dxvk-log-level":
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
                case "high-process-priority":
                    return true;
                default:
                    return false;
            }
        }

        internal static string[] build_environment_keys (string id) {
            switch (id) {
                case "prefer-sdl": return { "PROTON_PREFER_SDL", "PROTON_USE_SDL" };
                case "d7vk": return { "PROTON_USE_D7VK", "PROTON_D7VK_DDRAW" };
                case "proton-hdr": return { "PROTON_ENABLE_HDR", "PROTON_USE_HDR" };
                case "winealsa-spatial": return { "WINEALSA_SPATIAL", "WINEALSA_SPACIAL" };
                default: return {};
            }
        }

        string[] legacy_tokens_for (string id) {
            switch (id) {
                case "d7vk":
                case "proton-hdr":
                case "winealsa-spatial": return build_environment_keys (id);
                case "ntsync-mode": return { "PROTON_USE_NTSYNC=0" };
                case "dll-overrides": return { "DLL_OVERRIDES" };
                case "amd-vulkan-driver": return { "AMD_ICD" };
                case "vkd3d-log-level": return { "VKD3D_LOG_LEVEL" };
                case "amd-shader-cache": return { "MESA_SHADER_CACHE_DISABLE=0" };
                case "dxvk-hdr": return { "DXVK_HDR" };
                case "dxvk-no-hdr": return { "DXVK_NO_HDR" };
                case "amd-fsr4-rdna3": return { "PROTON_FSR4_RDNA3_UPGRADE" };
                case "dxvk-frame-limit": return { "DXVK_FRAME_RATE=" };
                case "dxvk-async": return { "DXVK_ASYNC=1" };
                case "vkd3d-shader-cache": return { "VKD3D_SHADER_CACHE=1" };
                case "vkd3d-gpuva": return { "VKD3D_GPUVA=1" };
                case "vkd3d-config": return { "force_host_cache", "shader_cache", "upload_hvv", "gpuva", "stable_power_state", "dxr10", "dxr11" };
                case "nvidia-nvapi": return { "PROTON_ENABLE_NVAPI=1" };
                case "high-process-priority": return { "PROTON_PRIORITY_HIGH=1" };
                default: return {};
            }
        }

        string[] selectable_values_for (string id) {
            switch (id) {
                case "scopebuddy-environment-only":
                case "scopebuddy-auto-refresh":
                case "scopebuddy-auto-frame-limit":
                case "scopebuddy-append-mode":
                case "scopebuddy-debug":
                    return { "0", "1" };
                case "gamescope-scaler": return { "auto", "integer", "fit", "fill", "stretch" };
                case "gamescope-filter": return { "linear", "nearest", "fsr", "nis", "pixel" };
                case "amd-vulkan-driver": return { "RADV", "AMDVLK" };
                case "amd-mlfg":
                case "native-wayland":
                case "wow64":
                case "prefer-sdl":
                case "wined3d":
                case "large-address-aware": return { "0", "1" };
                case "dxvk-log-level": return { "none", "error", "warn", "info", "debug", "trace" };
                case "vkd3d-log-level": return { "none", "err", "warn", "fixme", "info", "trace" };
                case "vkd3d-config":
                case "amd-radv-perftest":
                case "amd-radv-debug":
                case "amd-aco-debug":
                    return LaunchOptionFlags.values (id);
                default: return {};
            }
        }

        LaunchOptionSupport support_for (string id) {
            if (id.has_prefix ("gamescope-") || id.has_prefix ("scopebuddy-") || id == "native-game-wrapper")
                return LaunchOptionSupport.COMPONENT_SPECIFIC;
            switch (id) {
                case "dxvk-frame-limit":
                case "vkd3d-shader-cache":
                case "vkd3d-gpuva":
                    return LaunchOptionSupport.UNSUPPORTED;
                case "dxvk-async":
                    return LaunchOptionSupport.VARIANT_SPECIFIC;
                case "nvidia-nvapi":
                case "high-process-priority":
                    return LaunchOptionSupport.LEGACY_DEPRECATED;
                case "discord-bridge":
                case "nvidia-dlss-updater":
                case "nvidia-dlss-indicator":
                case "nvidia-libraries":
                case "intel-xess":
                    return LaunchOptionSupport.VARIANT_SPECIFIC;
                case "performance-overlay":
                case "mangohud":
                case "mangohud-vulkan":
                case "gamemode":
                case "game-performance":
                case "winealsa-channels":
                case "winealsa-spatial":
                case "obs-gamecapture":
                case "obs-vkcapture":
                case "gamescope":
                case "scopebuddy":
                case "launch-backend":
                case "vkbasalt":
                case "vkd3d-config":
                case "vkd3d-log-level":
                case "dxvk-log-level":
                case "dxvk-hdr":
                case "dxvk-no-hdr":
                case "proton-hdr":
                case "nvidia-hdr-wsi":
                case "amd-fsr4":
                case "amd-fsr4-rdna3":
                case "amd-mlfg":
                case "amd-mlfg-rdna3-workaround":
                case "cachyos-dxvk-low-latency":
                case "cachyos-vkd3d-low-latency":
                case "cachyos-vulkan-low-latency":
                case "cachyos-vulkan-reflex":
                case "cachyos-vulkan-reflex-layer":
                case "amd-reflex-allow-other-drivers":
                case "amd-reflex-dxgi-spoof":
                case "amd-reflex-force-nvapi":
                case "amd-reflex-layer-spoof":
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
                case "d7vk":
                case "optiscaler":
                case "per-game-shader-cache":
                case "native-wayland":
                case "desktop-game-profile":
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
            if (id.has_prefix ("scopebuddy-"))
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

        string conflict_group_for (string id) {
            if (id == "amd-fsr4" || id == "amd-fsr4-rdna3")
                return "amd-fsr4-upgrade";
            return "";
        }

        string[] conflicts_for (string id) {
            switch (id) {
                case "mangohud":
                case "performance-overlay": return { "mangohud-vulkan" };
                case "mangohud-vulkan": return { "performance-overlay" };
                case "gamemode": return { "game-performance" };
                case "game-performance": return { "gamemode" };
                case "amd-anti-lag": return { "cachyos-vulkan-low-latency" };
                case "dxvk-hdr": return { "dxvk-no-hdr" };
                case "proton-hdr": return { "dxvk-no-hdr" };
                case "dxvk-no-hdr": return { "dxvk-hdr", "proton-hdr" };
                case "cachyos-vulkan-low-latency": return { "amd-anti-lag", "amd-fsr4", "amd-fsr4-rdna3" };
                case "cachyos-vkd3d-low-latency": return { "amd-mlfg" };
                case "amd-mlfg": return {
                    "cachyos-vkd3d-low-latency", "amd-reflex-dxgi-spoof",
                    "amd-reflex-force-nvapi", "amd-reflex-layer-spoof"
                };
                case "amd-fsr4":
                case "amd-fsr4-rdna3": return {
                    "cachyos-vulkan-low-latency", "amd-reflex-dxgi-spoof",
                    "amd-reflex-force-nvapi", "amd-reflex-layer-spoof"
                };
                case "amd-reflex-dxgi-spoof": return { "amd-fsr4", "amd-fsr4-rdna3", "amd-mlfg", "dxvk-config-frame-limit" };
                case "amd-reflex-force-nvapi":
                case "amd-reflex-layer-spoof": return { "amd-fsr4", "amd-fsr4-rdna3", "amd-mlfg" };
                default: return {};
            }
        }

        LaunchOptionCapability[] capabilities_for (string id) {
            if (id == "ntsync-mode") return { LaunchOptionCapability.PROTON_NTSYNC };
            if (id == "native-wayland") return { LaunchOptionCapability.PROTON_WAYLAND };
            if (id == "wow64") return { LaunchOptionCapability.PROTON_WOW64 };
            if (id == "prefer-sdl") return { LaunchOptionCapability.PROTON_SDL };
            if (id == "per-game-shader-cache") return { LaunchOptionCapability.PROTON_LOCAL_SHADER_CACHE };
            if (id == "d7vk") return { LaunchOptionCapability.PROTON_D7VK };
            if (id == "optiscaler") return { LaunchOptionCapability.PROTON_OPTISCALER };
            if (id == "vkbasalt") return { LaunchOptionCapability.VKBASALT };
            if (id == "mangohud-vulkan") return { LaunchOptionCapability.MANGOHUD };
            if (id == "obs-vkcapture") return { LaunchOptionCapability.OBS_VKCAPTURE };
            if (id == "amd-vulkan-driver") return { LaunchOptionCapability.AMD, LaunchOptionCapability.AMD_VULKAN_SWITCHER };
            if (id == "winealsa-channels") return { LaunchOptionCapability.WINEALSA_CHANNELS };
            if (id == "winealsa-spatial") return { LaunchOptionCapability.WINEALSA_SPATIAL };
            if (id == "dxvk-hdr") return { LaunchOptionCapability.PROTON_DXVK_HDR };
            if (id == "proton-hdr") return { LaunchOptionCapability.LEGACY_PROTON_HDR };
            if (id == "dxvk-no-hdr") return { LaunchOptionCapability.PROTON_AUTO_HDR_CONTROL };
            if (id == "amd-fsr4") return { LaunchOptionCapability.AMD, LaunchOptionCapability.PROTON_FSR4 };
            if (id == "amd-fsr4-rdna3") return { LaunchOptionCapability.AMD, LaunchOptionCapability.PROTON_FSR4_RDNA3 };
            if (id == "amd-mlfg") return { LaunchOptionCapability.AMD, LaunchOptionCapability.PROTON_MLFG };
            if (id == "amd-mlfg-rdna3-workaround")
                return { LaunchOptionCapability.AMD, LaunchOptionCapability.PROTON_MLFG };
            if (id == "cachyos-dxvk-low-latency") return { LaunchOptionCapability.PROTON_DXVK_LOW_LATENCY };
            if (id == "cachyos-vkd3d-low-latency") return { LaunchOptionCapability.PROTON_VKD3D_LOW_LATENCY };
            if (id == "cachyos-vulkan-reflex-layer")
                return { LaunchOptionCapability.NVIDIA, LaunchOptionCapability.VULKAN_REFLEX_LAYER };
            if (id == "cachyos-vulkan-low-latency" || id == "cachyos-vulkan-reflex"
                || id.has_prefix ("amd-reflex-"))
                return id.has_prefix ("amd-reflex-")
                    ? new LaunchOptionCapability[] { LaunchOptionCapability.AMD, LaunchOptionCapability.LOW_LATENCY_LAYER }
                    : new LaunchOptionCapability[] { LaunchOptionCapability.LOW_LATENCY_LAYER };
            if (id.has_prefix ("amd-")) return { LaunchOptionCapability.AMD };
            if (id.has_prefix ("nvidia-")) return { LaunchOptionCapability.NVIDIA, LaunchOptionCapability.PROTON };
            if (id.has_prefix ("intel-")) return { LaunchOptionCapability.INTEL, LaunchOptionCapability.PROTON };
            if (id.has_prefix ("dxvk-")) return { LaunchOptionCapability.DXVK };
            if (id.has_prefix ("vkd3d-")) return { LaunchOptionCapability.VKD3D_PROTON };
            if (id.has_prefix ("scopebuddy-")) return { LaunchOptionCapability.SCOPEBUDDY };
            if (id == "native-wayland" || id.has_prefix ("proton-") || id == "wined3d" || id == "d7vk" || id == "ntsync-mode" || id == "wow64" || id == "large-address-aware" || id == "writecopy" || id == "vulkan-sync2" || id == "futex-waitv" || id == "optiscaler" || id == "discord-bridge" || id == "prefer-sdl" || id == "bypass-steam-input" || id.has_prefix ("winealsa-")) return { LaunchOptionCapability.PROTON };
            return {};
        }

        LaunchOptionApplicability applicability_for (string id) {
            if (id == "per-game-shader-cache" || id == "d7vk" || id == "optiscaler" || id == "discord-bridge" || id == "winealsa-channels" || id == "winealsa-spatial")
                return LaunchOptionApplicability.VARIANT_SPECIFIC;
            if (id.has_prefix ("amd-") || id.has_prefix ("nvidia-") || id.has_prefix ("intel-") || id.has_prefix ("dxvk-") || id.has_prefix ("vkd3d-") || id.has_prefix ("cachyos-") || id == "vkbasalt" || id.has_prefix ("scopebuddy-") || id == "proton-hdr" || id == "mangohud-vulkan" || id == "obs-vkcapture")
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
            if (semantics.kind == LaunchOptionSemanticKind.GAME_ARGUMENT
                && semantics.emission_mode != LaunchOptionEmissionMode.FIXED_TOKENS
                && semantics.emission_mode != LaunchOptionEmissionMode.DYNAMIC_GAME_ARGUMENTS)
                diagnostics.add ("Game argument '%s' has an incompatible emission mode.".printf (entry.id));
            if (semantics.kind == LaunchOptionSemanticKind.WRAPPER_ARGUMENT) {
                var wrapper = lookup_wrapper (semantics.wrapper_id);
                if (wrapper != null && !(wrapper.required_capability in semantics.get_required_capabilities ()))
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

        void add_gamescope_control (string id, string title, string description, uint rank, string[] tokens) {
            add_option ("gamescope-" + id, title, description, LaunchOptionCategory.DISPLAY,
                rank, tokens, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"));
        }

        void add_scopebuddy_control (string id, string title, string description, uint rank, string token) {
            add_option ("scopebuddy-" + id, title, description, LaunchOptionCategory.DISPLAY,
                rank, { token }, {}, LaunchLineType.ENVIRONMENT, _("ScopeBuddy"));
        }

        void add_runtime_option (
            string id, string key, string title, string description, LaunchOptionCategory category,
            uint rank, LaunchOptionCapability capability, string[] values = {},
            string fixed_value = "", string value_pattern = "", string value_prefix = "",
            string subsection = "", string[] legacy_tokens = {}, string[] conflicts = {},
            string[] dependencies = {}
        ) {
            var tokens = new string[] { key + "=" + fixed_value };
            var semantics = new LaunchOptionSemantics (
                LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT, LaunchPlaceholderPolicy.REQUIRED,
                fixed_value == "" ? LaunchOptionEmissionMode.DYNAMIC_ENVIRONMENT_VALUE : LaunchOptionEmissionMode.FIXED_TOKENS,
                key, "", fixed_value == "" ? new string[0] : tokens, {}, "", conflicts, dependencies,
                { capability }, LaunchOptionApplicability.COMPONENT_SPECIFIC, {}, false,
                LaunchOptionSupport.COMPONENT_SPECIFIC, true, legacy_tokens, values,
                null, "", "", value_pattern, value_prefix
            );
            add_option (id, title, description, category, rank, tokens, {}, LaunchLineType.ENVIRONMENT, subsection,
                false, LaunchOptionExpertise.ADVANCED, "", dependencies, semantics);
        }

        void add_shared_runtime_options () {
            add_runtime_option ("proton-esync", "PROTON_NO_ESYNC", _("Disable ESync"),
                _("Disables eventfd-based synchronization where the build supports it."),
                LaunchOptionCategory.PROTON, 31, LaunchOptionCapability.PROTON_ESYNC, {}, "1");
            add_runtime_option ("proton-fsync", "PROTON_NO_FSYNC", _("Disable FSync"),
                _("Disables futex-based synchronization where the build supports it."),
                LaunchOptionCategory.PROTON, 32, LaunchOptionCapability.PROTON_FSYNC, {}, "1");
            add_runtime_option ("proton-no-d3d11", "PROTON_NO_D3D11", _("Disable Direct3D 11"),
                _("Lets games that support older Direct3D versions fall back from Direct3D 11."),
                LaunchOptionCategory.PROTON, 33, LaunchOptionCapability.PROTON_NO_D3D11, {}, "1");
            add_runtime_option ("proton-no-d3d10", "PROTON_NO_D3D10", _("Disable Direct3D 10"),
                _("Lets games that support older Direct3D versions fall back from Direct3D 10."),
                LaunchOptionCategory.PROTON, 34, LaunchOptionCapability.PROTON_NO_D3D10, {}, "1");
            add_runtime_option ("proton-disable-nvapi", "PROTON_DISABLE_NVAPI", _("Disable NVAPI"),
                _("Turns off Proton’s NVAPI integration for games that have problems with it."),
                LaunchOptionCategory.PROTON, 35, LaunchOptionCapability.PROTON_DISABLE_NVAPI, {}, "1");
            add_runtime_option ("proton-log-directory", "PROTON_LOG_DIR", _("Proton log directory"),
                _("Sets the directory for Proton logs when logging is enabled."),
                LaunchOptionCategory.DIAGNOSTICS, 11, LaunchOptionCapability.PROTON_LOG_DIR);

            add_runtime_option ("dxvk-config-frame-limit", "DXVK_CONFIG", _("DXVK frame limiter"),
                _("Enter an integer FPS limit. Use 0 for default behavior, -1 to disable the limiter, or a lower negative number for a conditional cap."),
                LaunchOptionCategory.GRAPHICS, 31, LaunchOptionCapability.DXVK_FRAME_CONFIG,
                {}, "", """\A-?[0-9]+\z""", "dxvk.maxFrameRate", "", {},
                { "amd-reflex-dxgi-spoof" });
            add_runtime_option ("dxvk-device-filter", "DXVK_FILTER_DEVICE_NAME", _("DXVK GPU name filter"),
                _("Lets DXVK use only Vulkan devices whose names contain this text."),
                LaunchOptionCategory.GRAPHICS, 32, LaunchOptionCapability.DXVK_DEVICE_FILTER);
            add_runtime_option ("dxvk-log-directory", "DXVK_LOG_PATH", _("DXVK log directory"),
                _("Sets where DXVK writes logs. Enter none to suppress log files."),
                LaunchOptionCategory.DIAGNOSTICS, 21, LaunchOptionCapability.DXVK_LOG_PATH);
            add_runtime_option ("dxvk-disable-shader-cache", "DXVK_SHADER_CACHE", _("Disable DXVK shader cache"),
                _("Turns off DXVK’s normally enabled internal shader cache."),
                LaunchOptionCategory.GRAPHICS, 33, LaunchOptionCapability.DXVK_SHADER_CACHE, {}, "0");
            add_runtime_option ("dxvk-shader-cache-directory", "DXVK_SHADER_CACHE_PATH", _("DXVK shader cache directory"),
                _("Sets the directory for DXVK’s internal shader cache."),
                LaunchOptionCategory.GRAPHICS, 34, LaunchOptionCapability.DXVK_SHADER_CACHE_PATH);

            add_runtime_option ("vkd3d-device-filter", "VKD3D_FILTER_DEVICE_NAME", _("VKD3D-Proton GPU name filter"),
                _("Lets VKD3D-Proton use only Vulkan devices whose names contain this text."),
                LaunchOptionCategory.GRAPHICS, 51, LaunchOptionCapability.VKD3D_DEVICE_FILTER);
            add_runtime_option ("vkd3d-device-index", "VKD3D_VULKAN_DEVICE", _("VKD3D-Proton GPU index"),
                _("Selects a Vulkan device by its zero-based index."),
                LaunchOptionCategory.GRAPHICS, 52, LaunchOptionCapability.VKD3D_DEVICE_INDEX,
                {}, "", """\A[0-9]+\z""");
            add_runtime_option ("vkd3d-frame-limit", "VKD3D_FRAME_RATE", _("VKD3D-Proton frame limit"),
                _("Enter a positive FPS limit or 0 to leave the frame rate uncapped."),
                LaunchOptionCategory.GRAPHICS, 53, LaunchOptionCapability.VKD3D_FRAME_RATE,
                {}, "", """\A(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?\z""");
            add_runtime_option ("vkd3d-log-file", "VKD3D_LOG_FILE", _("VKD3D-Proton log file"),
                _("Redirects VKD3D-Proton messages to this file."),
                LaunchOptionCategory.DIAGNOSTICS, 31, LaunchOptionCapability.VKD3D_LOG_FILE);
            add_runtime_option ("vkd3d-shader-cache-path", "VKD3D_SHADER_CACHE_PATH", _("VKD3D-Proton shader cache"),
                _("Enter a cache directory or 0 to disable the default internal cache."),
                LaunchOptionCategory.GRAPHICS, 54, LaunchOptionCapability.VKD3D_SHADER_CACHE_PATH);
        }

        void add_variant_runtime_options () {
            add_runtime_option ("proton-pipewire", "PROTON_USE_PIPEWIRE", _("Wine PipeWire audio"),
                _("Selects the Wine PipeWire audio driver on supported Proton builds."),
                LaunchOptionCategory.INPUT_AUDIO, 60, LaunchOptionCapability.PROTON_PIPEWIRE,
                { "0", "1" });
            add_runtime_option ("proton-sarek", "PROTON_DXVK_SAREK", _("DXVK-Sarek"),
                _("Choose whether to use bundled DXVK-Sarek. Some builds select it automatically for older Vulkan drivers."),
                LaunchOptionCategory.GRAPHICS, 101, LaunchOptionCapability.PROTON_SAREK,
                { "0", "1" });
            add_runtime_option ("proton-fsr4-indicator", "PROTON_FSR4_INDICATOR", _("FSR 4 indicator"),
                _("Displays the build’s FSR 4 status indicator."),
                LaunchOptionCategory.GRAPHICS, 102, LaunchOptionCapability.PROTON_FSR4_INDICATOR,
                {}, "1");
            add_runtime_option ("proton-wineland-upscaler", "PROTON_UPSCALER_UPGRADE", _("Proton-Wineland upscaler upgrades"),
                _("Enables automatic component upgrades for supported upscalers."),
                LaunchOptionCategory.GRAPHICS, 103, LaunchOptionCapability.PROTON_WINELAND_UPSCALER,
                {}, "1");
            add_runtime_option ("proton-hevc-defaults", "PROTON_HEVC_DEFAULTS", _("Proton-HEVC graphics defaults"),
                _("Choose whether Proton-HEVC applies its default WineD3D Vulkan and DXGI settings."),
                LaunchOptionCategory.PROTON, 100, LaunchOptionCapability.PROTON_HEVC_DEFAULTS,
                { "0", "1" });
            add_runtime_option ("proton-hevc-renderer", "WINE_D3D_CONFIG", _("Proton-HEVC WineD3D settings"),
                _("Sets WineD3D configuration for Proton-HEVC. Its default renderer setting is renderer=vulkan."),
                LaunchOptionCategory.PROTON, 101, LaunchOptionCapability.PROTON_HEVC_DEFAULTS);
            add_runtime_option ("proton-tkg-nvapi", "PROTON_NVAPI_DISABLE", _("Proton-Tkg NVAPI"),
                _("Choose whether Proton-Tkg disables NVAPI."),
                LaunchOptionCategory.PROTON, 110, LaunchOptionCapability.PROTON_TKG_NVAPI,
                { "0", "1" });
            add_runtime_option ("proton-tkg-winedbg", "PROTON_WINEDBG_DISABLE", _("Proton-Tkg Wine debugger"),
                _("Choose whether Proton-Tkg disables WineDbg."),
                LaunchOptionCategory.PROTON, 111, LaunchOptionCapability.PROTON_TKG_WINEDBG,
                { "0", "1" });
            add_runtime_option ("proton-tkg-pulse", "PROTON_PULSE_LOWLATENCY", _("Proton-Tkg low-latency audio"),
                _("Choose whether Proton-Tkg applies its PulseAudio latency override."),
                LaunchOptionCategory.PROTON, 112, LaunchOptionCapability.PROTON_TKG_PULSE,
                { "0", "1" });
            add_runtime_option ("proton-tkg-d3d9", "PROTON_USE_CUSTOMD3D9", _("Proton-Tkg custom Direct3D 9"),
                _("Choose whether Proton-Tkg uses its custom Direct3D 9 library."),
                LaunchOptionCategory.PROTON, 113, LaunchOptionCapability.PROTON_TKG_D3D9,
                { "0", "1" });
            add_runtime_option ("proton-tkg-winetricks", "PROTON_WINETRICKS", _("Proton-Tkg Winetricks prompt"),
                _("Choose whether Proton-Tkg offers its Winetricks prompt."),
                LaunchOptionCategory.PROTON, 114, LaunchOptionCapability.PROTON_TKG_WINETRICKS,
                { "0", "1" });
            add_runtime_option ("proton-anime-xxmi", "PROTON_USE_XXMI", _("XXMI model importer"),
                _("Enter 1 for the current release, 0 to disable the importer, or a release version to pin it."),
                LaunchOptionCategory.PROTON, 120, LaunchOptionCapability.PROTON_ANIME_XXMI);
            add_runtime_option ("proton-anime-gimi", "PROTON_USE_GIMI", _("GIMI model importer"),
                _("Enter 1 for the current release, 0 to disable the importer, or a release version to pin it."),
                LaunchOptionCategory.PROTON, 121, LaunchOptionCapability.PROTON_ANIME_GIMI);
            add_runtime_option ("proton-anime-srmi", "PROTON_USE_SRMI", _("SRMI model importer"),
                _("Enter 1 for the current release, 0 to disable the importer, or a release version to pin it."),
                LaunchOptionCategory.PROTON, 122, LaunchOptionCapability.PROTON_ANIME_SRMI);
            add_runtime_option ("proton-anime-zzmi", "PROTON_USE_ZZMI", _("ZZMI model importer"),
                _("Enter 1 for the current release, 0 to disable the importer, or a release version to pin it."),
                LaunchOptionCategory.PROTON, 123, LaunchOptionCapability.PROTON_ANIME_ZZMI);
            add_runtime_option ("proton-anime-himi", "PROTON_USE_HIMI", _("HIMI model importer"),
                _("Enter 1 for the current release, 0 to disable the importer, or a release version to pin it."),
                LaunchOptionCategory.PROTON, 124, LaunchOptionCapability.PROTON_ANIME_HIMI);
            add_runtime_option ("proton-anime-wwmi", "PROTON_USE_WWMI", _("WWMI model importer"),
                _("Enter 1 for the current release, 0 to disable the importer, or a release version to pin it."),
                LaunchOptionCategory.PROTON, 125, LaunchOptionCapability.PROTON_ANIME_WWMI);
            add_runtime_option ("proton-anime-efmi", "PROTON_USE_EFMI", _("EFMI model importer"),
                _("Enter 1 for the current release, 0 to disable the importer, or a release version to pin it."),
                LaunchOptionCategory.PROTON, 126, LaunchOptionCapability.PROTON_ANIME_EFMI);
            add_runtime_option ("proton-anime-reshade", "PROTON_USE_RESHADE", _("ReShade integration"),
                _("Enter 1 for the current release, 0 to turn off ReShade, or a release version to pin it. ReShade and OptiScaler can compete for the same DLL."),
                LaunchOptionCategory.PROTON, 127, LaunchOptionCapability.PROTON_ANIME_RESHADE);
            add_runtime_option ("proton-anime-reshade-path", "PROTON_RESHADE_PATH", _("ReShade directory"),
                _("Enter a host directory or 0 to keep ReShade inside the game’s Wine prefix."),
                LaunchOptionCategory.PROTON, 128, LaunchOptionCapability.PROTON_ANIME_RESHADE_PATH);
            add_runtime_option ("proton-anime-hsr-fps", "PROTON_HSR_FPS", _("Honkai: Star Rail frame limit"),
                _("Enter an FPS limit after launching the game once to create its graphics settings."),
                LaunchOptionCategory.PROTON, 129, LaunchOptionCapability.PROTON_ANIME_HSR,
                {}, "", """\A[1-9][0-9]*\z""");
            add_runtime_option ("proton-anime-gi-fps", "PROTON_GI_FPS", _("Genshin Impact frame limit"),
                _("Enter a positive FPS limit for the supported Genshin Impact executables."),
                LaunchOptionCategory.PROTON, 130, LaunchOptionCapability.PROTON_ANIME_GI,
                {}, "", """\A[1-9][0-9]*\z""");
            add_runtime_option ("proton-anime-kuro", "PROTON_KURO_KEEP_LAUNCHER", _("Keep the Kuro Games launcher open"),
                _("Keeps the Wuthering Waves or Punishing: Gray Raven launcher open after the game starts."),
                LaunchOptionCategory.PROTON, 131, LaunchOptionCapability.PROTON_ANIME_KURO,
                {}, "1");
            add_runtime_option ("proton-anime-nte", "PROTON_NTE_HIDE_LAUNCHER", _("Hide the Neverness to Everness launcher"),
                _("Hides the launcher while waiting for the game to start."),
                LaunchOptionCategory.PROTON, 132, LaunchOptionCapability.PROTON_ANIME_NTE,
                {}, "1");
            add_runtime_option ("proton-anime-nte-timeout", "PROTON_NTE_HIDE_LAUNCHER_TIMEOUT", _("Neverness to Everness launcher timeout"),
                _("Sets how long to wait for the game to start before giving up. Enter seconds, or 0 to wait indefinitely. The default is 300 seconds."),
                LaunchOptionCategory.PROTON, 133, LaunchOptionCapability.PROTON_ANIME_NTE_TIMEOUT,
                {}, "", """\A[0-9]+\z""");
            add_runtime_option ("proton-anime-wuwa-engine", "PROTON_WUWA_ENGINE_VARS", _("Wuthering Waves engine variables"),
                _("Enter comma-separated key=value pairs to write to the game’s engine overrides."),
                LaunchOptionCategory.PROTON, 134, LaunchOptionCapability.PROTON_ANIME_WUWA);

            add_runtime_option ("boxtron-sierra-game", "BOXTRON_SIERRA_GAME", _("Boxtron Sierra game"),
                _("Selects a game in a Sierra collection by its index. The default is 1."),
                LaunchOptionCategory.PROTON, 140, LaunchOptionCapability.BOXTRON_SIERRA,
                {}, "", """\A[1-9][0-9]*\z""", "", "Boxtron", { "SDOS_SIERRA_GAME" });
            add_runtime_option ("roberta-scummvm-command", "LUX_SCUMMVM_CMD", _("Roberta ScummVM command"),
                _("Sets Roberta’s ScummVM executable and any arguments for this game."),
                LaunchOptionCategory.PROTON, 141, LaunchOptionCapability.ROBERTA_COMMAND);
            add_runtime_option ("roberta-screen", "LUX_USE_SCREEN", _("Roberta display"),
                _("Selects the fullscreen display. Enter 0 for the primary display."),
                LaunchOptionCategory.PROTON, 142, LaunchOptionCapability.ROBERTA_SCREEN,
                {}, "", """\A[0-9]+\z""");
            add_runtime_option ("luxtorpeda-confirm", "LUX_DISABLE_DEFAULT_CONFIRM", _("Luxtorpeda default-engine confirmation"),
                _("Choose whether Luxtorpeda asks before starting the default engine."),
                LaunchOptionCategory.PROTON, 143, LaunchOptionCapability.LUX_CONFIRM,
                { "0", "1" });
            add_runtime_option ("luxtorpeda-logging", "LUX_WRITE_LOGGING", _("Luxtorpeda file logging"),
                _("Choose whether Luxtorpeda writes logs to a file."),
                LaunchOptionCategory.PROTON, 144, LaunchOptionCapability.LUX_LOGGING,
                { "0", "1" });
            add_runtime_option ("luxtorpeda-cloud", "LUX_STEAM_CLOUD", _("Luxtorpeda Steam Cloud"),
                _("Enables Steam Cloud for engine packages that support it."),
                LaunchOptionCategory.PROTON, 145, LaunchOptionCapability.LUX_CLOUD,
                {}, "1");
            add_runtime_option ("rosemary-glibc", "ROSEMARY_GLIBC", _("Rosemary glibc"),
                _("Selects the host or bundled glibc loader. Auto lets Rosemary choose the loader."),
                LaunchOptionCategory.PROTON, 146, LaunchOptionCapability.ROSEMARY_GLIBC,
                { "auto", "host", "bundled" });
            add_runtime_option ("rosemary-trace", "ROSEMARY_LAUNCHER_TRACE", _("Rosemary launcher trace"),
                _("Enables the Rosemary launcher’s diagnostic trace."),
                LaunchOptionCategory.PROTON, 147, LaunchOptionCapability.ROSEMARY_TRACE,
                {}, "1", "", "", "", { "ROSEMARY_LAUNCHER_TRACE" });

            add_runtime_option ("mangohud-config", "MANGOHUD_CONFIG", _("MangoHud settings"),
                _("Enter comma-separated MangoHud settings such as fps_limit=60 or position=top-right."),
                LaunchOptionCategory.PERFORMANCE, 70, LaunchOptionCapability.MANGOHUD);
            add_runtime_option ("mangohud-config-file", "MANGOHUD_CONFIGFILE", _("MangoHud configuration file"),
                _("Enter the path to the MangoHud configuration file for this game."),
                LaunchOptionCategory.PERFORMANCE, 71, LaunchOptionCapability.MANGOHUD);
            add_runtime_option ("vkbasalt-config-file", "VKBASALT_CONFIG_FILE", _("vkBasalt configuration file"),
                _("Enter the path to the vkBasalt configuration file for this game."),
                LaunchOptionCategory.PERFORMANCE, 72, LaunchOptionCapability.VKBASALT);
            add_runtime_option ("game-performance-screensaver", "GAME_PERFORMANCE_SCREENSAVER_ON", _("Allow the screensaver during play"),
                _("Allows the screensaver to activate normally during play."),
                LaunchOptionCategory.PERFORMANCE, 73, LaunchOptionCapability.GAME_PERFORMANCE,
                {}, "1", "", "", "", {}, {}, { "game-performance" });
        }

        void add_defaults () {
            add_shared_runtime_options ();
            add_variant_runtime_options ();
            // Performance & monitoring
            add_option ("performance-overlay", _("MangoHud performance overlay"), _("Shows frame rate, hardware usage, and temperatures while you play."), LaunchOptionCategory.PERFORMANCE, 10, { "mangohud" }, { "MangoHud", "performance overlay" }, LaunchLineType.WRAPPER, "", true);
            add_option ("gamemode", _("GameMode"), _("Asks the GameMode service to apply its performance settings while the game runs."), LaunchOptionCategory.PERFORMANCE, 20, { "gamemoderun" }, { "Feral Gamemode", "gamemoderun" }, LaunchLineType.WRAPPER, "", true);
            add_option ("game-performance", _("CachyOS game-performance"), _("Temporarily requests the performance power profile and uses the gaming scheduler profile on supported CachyOS setups."), LaunchOptionCategory.PERFORMANCE, 30, { "game-performance" }, { "CachyOS", "power profile", "sched_ext" }, LaunchLineType.WRAPPER, "", true, LaunchOptionExpertise.STANDARD, _("Requires the game-performance command."));
            add_option ("mangohud-vulkan", _("MangoHud Vulkan environment mode"), _("Shows the MangoHud overlay in Vulkan games. Use the MangoHud wrapper for OpenGL or MangoApp inside Gamescope."), LaunchOptionCategory.PERFORMANCE, 40, { "MANGOHUD=1" }, { "MangoHud", "Vulkan overlay" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED, _("Requires MangoHud."));
            add_option ("obs-vkcapture", _("OBS Vulkan-only capture"), _("Makes Vulkan games available to the Game Capture source in OBS. Flatpak setups need the OBS plugin and Vulkan layer."), LaunchOptionCategory.PERFORMANCE, 50, { "OBS_VKCAPTURE=1" }, { "OBS", "obs-gamecapture", "Vulkan capture" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED, _("Requires obs-vkcapture. NVIDIA needs modesetting and driver 515.43.04 or newer."));
            add_option ("obs-gamecapture", _("OBS game capture wrapper"), _("Makes Vulkan and OpenGL games available to the Game Capture source in OBS."), LaunchOptionCategory.PERFORMANCE, 51, { "obs-gamecapture" }, { "OBS", "OpenGL capture" }, LaunchLineType.WRAPPER, "", false, LaunchOptionExpertise.ADVANCED, _("Requires the obs-gamecapture command."));
            add_option ("high-process-priority", _("High process priority"), _("Keeps the historical high-priority setting from an existing launch command."), LaunchOptionCategory.PERFORMANCE, 60, { "PROTON_PRIORITY_HIGH=1" });
            add_option ("per-game-shader-cache", _("Per-game shader cache"), _("Stores this game’s shaders in a separate cache."), LaunchOptionCategory.PERFORMANCE, 70, { "PROTON_LOCAL_SHADER_CACHE=1" }, { "local shader cache" });

            // Display & launch tools
            add_option ("launch-backend", _("Launch backend"), _("Choose the system default, Gamescope, or ScopeBuddy."), LaunchOptionCategory.DISPLAY, 10, { "gamescope", "scopebuddy" }, { "System default", "Gamescope", "ScopeBuddy" }, LaunchLineType.WRAPPER);
            add_option ("native-wayland", _("Native Wayland"), _("Choose whether to use Wine’s native Wayland driver. Some builds enable it by default."), LaunchOptionCategory.DISPLAY, 20, { "PROTON_ENABLE_WAYLAND=1" }, { "Wayland" });
            add_option ("desktop-game-profile", _("Use desktop game profile"), _("Uses the desktop profile instead of a Steam Deck-specific profile."), LaunchOptionCategory.DISPLAY, 30, { "SteamDeck=0" }, { "Disable Steam Deck Mode", "Steam Deck" });
            add_option ("vkbasalt", _("vkBasalt visual effects"), _("Applies post-processing effects such as sharpening and color adjustments to Vulkan games."), LaunchOptionCategory.DISPLAY, 40, { "ENABLE_VKBASALT=1" }, { "VKBasalt" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("dxvk-hdr", _("DXVK HDR"), _("Exposes HDR10 to supported games through DXVK. Some Proton builds already detect HDR automatically."), LaunchOptionCategory.DISPLAY, 50, { "DXVK_HDR=1" }, { "HDR", "dxgi.enableHDR" }, LaunchLineType.ENVIRONMENT, "", true, LaunchOptionExpertise.ADVANCED, _("Requires an HDR-capable display, compositor, and compatible driver."));
            add_option ("proton-hdr", _("Legacy custom-Proton HDR"), _("Requests HDR through the legacy Proton HDR switch."), LaunchOptionCategory.DISPLAY, 55, { "PROTON_ENABLE_HDR=1" }, { "HDR", "Proton-GE" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED, _("Requires a Proton build that supports PROTON_ENABLE_HDR."));
            add_option ("dxvk-no-hdr", _("Disable custom-Proton automatic HDR"), _("Stops supported Proton builds from automatically exposing HDR through DXVK."), LaunchOptionCategory.DISPLAY, 56, { "DXVK_NO_HDR=1" }, { "HDR opt-out", "Proton-CachyOS" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED, _("Requires a Proton build that supports DXVK_NO_HDR."));
            add_option ("nvidia-hdr-wsi", _("NVIDIA legacy HDR WSI"), _("Enables the legacy Vulkan HDR layer for NVIDIA proprietary drivers older than 595."), LaunchOptionCategory.DISPLAY, 57, { "ENABLE_HDR_WSI=1" }, { "HDR WSI", "NVIDIA 595" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("gamescope-fullscreen", _("Fullscreen"), _("Starts the Gamescope window in fullscreen."), LaunchOptionCategory.DISPLAY, 60, { "-f" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.STANDARD);
            add_option ("gamescope-resolution", _("Output resolution"), _("Sets the size of the image Gamescope outputs, in pixels."), LaunchOptionCategory.DISPLAY, 70, { "-W", "-H" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.STANDARD);
            add_option ("gamescope-hdr", _("HDR"), _("Enables HDR output on a compatible display and compositor."), LaunchOptionCategory.DISPLAY, 80, { "--hdr-enabled" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), true, LaunchOptionExpertise.STANDARD);
            add_option ("gamescope-vrr", _("Variable refresh rate"), _("Enables adaptive sync on a supported display so its refresh rate can follow the game’s frame rate."), LaunchOptionCategory.DISPLAY, 90, { "--adaptive-sync" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.STANDARD);
            add_option ("gamescope-frame-limit", _("Nested refresh rate"), _("Sets the refresh rate reported to the game, in Hz."), LaunchOptionCategory.DISPLAY, 100, { "-r" }, { "Frame limit" }, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), true, LaunchOptionExpertise.STANDARD);
            add_option ("gamescope-fps-limit", _("Frame limit"), _("Caps the game’s frame rate using a divisor of the nested refresh rate."), LaunchOptionCategory.DISPLAY, 101, { "--framerate-limit" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.STANDARD);
            add_gamescope_control ("internal-resolution", _("Internal resolution"), _("Sets the resolution seen by the game."), 102, { "-w", "-h" });
            add_gamescope_control ("scaler", _("Scaling mode"), _("Controls how the game image fits the output."), 103, { "-S" });
            add_gamescope_control ("filter", _("Scaling filter"), _("Chooses the filter used to resize the game image."), 104, { "-F" });
            add_gamescope_control ("sharpness", _("Scaling sharpness"), _("Sets filter sharpness from 0 (maximum) to 20 (minimum)."), 105, { "--sharpness" });
            add_gamescope_control ("prefer-output", _("Preferred output connectors"), _("Enter a comma-separated list of connectors for embedded mode, in order of preference."), 106, { "-O" });
            add_gamescope_control ("display-index", _("Nested display index"), _("Forces Gamescope to open on this display in nested mode."), 107, { "--display-index" });
            add_gamescope_control ("force-grab-cursor", _("Force relative mouse mode"), _("Keeps relative mouse mode active when the cursor is visible."), 108, { "--force-grab-cursor" });
            add_gamescope_control ("hide-cursor-delay", _("Hide cursor delay"), _("Sets how long the cursor stays visible after mouse movement, in milliseconds."), 109, { "-C" });
            add_gamescope_control ("hdr-sdr-nits", _("SDR content brightness"), _("Sets the luminance of SDR content in nits during HDR output."), 111, { "--hdr-sdr-content-nits" });
            add_gamescope_control ("hdr-itm", _("Inverse tone mapping"), _("Maps SDR input to HDR output."), 112, { "--hdr-itm-enabled" });
            add_gamescope_control ("hdr-itm-sdr-nits", _("Tone mapping input brightness"), _("Sets the SDR input luminance for inverse tone mapping, in nits."), 113, { "--hdr-itm-sdr-nits" });
            add_gamescope_control ("hdr-itm-target-nits", _("Tone mapping target brightness"), _("Sets the HDR target luminance for inverse tone mapping, in nits."), 114, { "--hdr-itm-target-nits" });
            add_gamescope_control ("mangoapp", _("MangoApp"), _("Shows the MangoHud performance overlay through Gamescope. Requires the mangoapp executable."), 115, { "--mangoapp" });
            add_option ("gamescope-arguments", _("Additional Gamescope arguments"), _("Passes additional flags to Gamescope."), LaunchOptionCategory.DISPLAY, 110, { "gamescope" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.ADVANCED);
            add_option ("scopebuddy-fullscreen", _("Fullscreen"), _("Starts the Gamescope window in fullscreen."), LaunchOptionCategory.DISPLAY, 120, { "-f" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.STANDARD);
            add_option ("scopebuddy-resolution", _("Output resolution"), _("Detects the display resolution automatically or uses the output size you enter."), LaunchOptionCategory.DISPLAY, 130, { "SCB_AUTO_RES=1", "-W", "-H" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.STANDARD);
            add_option ("scopebuddy-auto-hdr", _("Automatic HDR"), _("Turns on Gamescope HDR when ScopeBuddy detects display support."), LaunchOptionCategory.DISPLAY, 140, { "SCB_AUTO_HDR=1" }, {}, LaunchLineType.ENVIRONMENT, _("ScopeBuddy"), true, LaunchOptionExpertise.STANDARD);
            add_option ("scopebuddy-auto-vrr", _("Automatic variable refresh rate"), _("Turns on Gamescope adaptive sync when ScopeBuddy detects display support."), LaunchOptionCategory.DISPLAY, 150, { "SCB_AUTO_VRR=1" }, {}, LaunchLineType.ENVIRONMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.STANDARD);
            add_option ("scopebuddy-frame-limit", _("Nested refresh rate"), _("Sets the refresh rate reported to the game, in Hz."), LaunchOptionCategory.DISPLAY, 160, { "-r" }, { "Frame limit" }, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), true, LaunchOptionExpertise.STANDARD);
            add_option ("scopebuddy-fps-limit", _("Frame limit"), _("Caps the game’s frame rate using a divisor of the nested refresh rate."), LaunchOptionCategory.DISPLAY, 161, { "--framerate-limit" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.STANDARD);
            add_scopebuddy_control ("profile", _("Configuration profile"), _("Enter a profile filename from the ScopeBuddy configuration directory, such as scb.conf."), 162, "SCB_CONF");
            add_scopebuddy_control ("app-id", _("Application config ID"), _("Overrides automatic detection and selects a matching file in ScopeBuddy’s AppID directory."), 163, "SCB_APPID");
            add_scopebuddy_control ("environment-only", _("Environment-only mode"), _("Loads the ScopeBuddy configuration and starts the game directly. Gamescope arguments and display settings are ignored."), 164, "SCB_NOSCOPE");
            add_scopebuddy_control ("auto-refresh", _("Automatic refresh rate"), _("Sets the nested refresh rate from the display’s current mode."), 165, "SCB_AUTO_REFRESH");
            add_scopebuddy_control ("auto-frame-limit", _("Automatic frame limit"), _("Sets Gamescope’s frame limit from the detected display refresh rate."), 166, "SCB_AUTO_FRAME_LIMIT");
            add_scopebuddy_control ("append-mode", _("Config argument merge"), _("Append mode places profile arguments first and launch arguments last. Fallback mode uses the profile arguments when the launch has no Gamescope arguments."), 167, "SCB_APPENDMODE");
            add_scopebuddy_control ("debug", _("Log launch command"), _("Writes the resolved launch command to scopebuddy.log in the ScopeBuddy configuration directory."), 168, "SCB_DEBUG");
            add_option ("scopebuddy-arguments", _("Additional ScopeBuddy arguments"), _("Passes additional flags through ScopeBuddy to Gamescope."), LaunchOptionCategory.DISPLAY, 170, { "scopebuddy", "scb" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.ADVANCED);

            // Proton & Wine compatibility
            add_option ("wined3d", _("WineD3D fallback"), _("Uses WineD3D for Direct3D 9–11. Standard Proton uses WineD3D’s OpenGL renderer."), LaunchOptionCategory.PROTON, 10, { "PROTON_USE_WINED3D=1" }, { "WineD3D" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("d7vk", _("D7VK for older Direct3D games"), _("Uses a Vulkan renderer for supported DirectDraw and early Direct3D games."), LaunchOptionCategory.PROTON, 20, { "PROTON_USE_D7VK=1" }, { "D7VK" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires a Proton build with D7VK."));
            add_option ("ntsync-mode", _("Disable NTSync"), _("Disables NTSync and lets Proton choose a fallback."), LaunchOptionCategory.PROTON, 30, { "PROTON_USE_NTSYNC=0" }, { "Use FSync" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("large-address-aware", _("Large address awareness for 32-bit games"), _("Lets 32-bit games address more memory. Proton normally enables it."), LaunchOptionCategory.PROTON, 40, { "PROTON_FORCE_LARGE_ADDRESS_AWARE=1" });
            add_option ("wow64", _("WoW64 mode"), _("Selects the build’s alternative Wine mode for running 32-bit Windows games on a 64-bit system."), LaunchOptionCategory.PROTON, 50, { "PROTON_USE_WOW64=1" }, { "Use WoW64" });
            add_option ("writecopy", _("Write-copy memory workaround"), _("Simulates Windows write-copy memory protection for applications that depend on it."), LaunchOptionCategory.PROTON, 60, { "WINE_SIMULATE_WRITECOPY=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("vulkan-sync2", _("Vulkan synchronization 2"), _("Lets Wine use the newer Vulkan synchronization API when supported."), LaunchOptionCategory.PROTON, 70, { "WINE_VK_USE_SYNC2=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("futex-waitv", _("Futex waitv synchronization"), _("Lets Wine wait on multiple futexes in a single system call when the kernel supports it."), LaunchOptionCategory.PROTON, 80, { "WINE_SYNC_USE_FUTEX_WAITV=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("optiscaler", _("OptiScaler integration"), _("Enter 1 for the build’s default OptiScaler release, 0 to disable it, or a version supported by the build."), LaunchOptionCategory.PROTON, 90, { "PROTON_USE_OPTISCALER=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires a Proton build with OptiScaler integration."));
            add_option ("discord-bridge", _("Discord bridge"), _("Lets games running in Proton update your Discord Rich Presence."), LaunchOptionCategory.PROTON, 100, { "PROTON_DISCORD_BRIDGE=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires a Proton build with the Discord RPC bridge."));
            add_option ("dll-overrides", _("Wine DLL overrides"), _("Choose whether Wine loads the Windows or Wine-provided version of each DLL, or disables it."), LaunchOptionCategory.PROTON, 110, { "DLL_OVERRIDES" }, { "mscoree", "dxgi", "wined3d" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);

            // Graphics translation
            add_option ("dxvk-frame-limit", _("DXVK frame limit"), _("Caps the frame rate on DXVK builds that read the legacy DXVK_FRAME_RATE setting."), LaunchOptionCategory.GRAPHICS, 10, { "DXVK_FRAME_RATE=" }, {}, LaunchLineType.ENVIRONMENT, _("DXVK"));
            add_option ("dxvk-async", _("Asynchronous pipeline compilation"), _("Compiles graphics pipelines in the background on DXVK builds with async patches."), LaunchOptionCategory.GRAPHICS, 20, { "DXVK_ASYNC=1" }, { "DXVK Async" }, LaunchLineType.ENVIRONMENT, _("DXVK"), false, LaunchOptionExpertise.EXPERIMENTAL);
            add_option ("vkd3d-shader-cache", _("Legacy VKD3D shader cache"), _("Keeps the legacy VKD3D_SHADER_CACHE setting from an existing launch command."), LaunchOptionCategory.GRAPHICS, 30, { "VKD3D_SHADER_CACHE=1" }, {}, LaunchLineType.ENVIRONMENT, _("VKD3D-Proton"));
            add_option ("vkd3d-gpuva", _("Legacy VKD3D GPU virtual addressing"), _("Keeps the legacy VKD3D_GPUVA setting from an existing launch command."), LaunchOptionCategory.GRAPHICS, 40, { "VKD3D_GPUVA=1" }, {}, LaunchLineType.ENVIRONMENT, _("VKD3D-Proton"), false, LaunchOptionExpertise.ADVANCED);
            add_option ("vkd3d-config", _("VKD3D compatibility settings"), _("Selects VKD3D-Proton flags for graphics compatibility and performance."), LaunchOptionCategory.GRAPHICS, 50, { "VKD3D_CONFIG", "shader_cache", "force_host_cache", "upload_hvv", "no_upload_hvv", "gpuva", "stable_power_state" }, { "VKD3D Proton Configurations" }, LaunchLineType.ENVIRONMENT, _("VKD3D-Proton"), false, LaunchOptionExpertise.ADVANCED);
            add_option ("cachyos-dxvk-low-latency", _("Proton-CachyOS DXVK low latency"), _("Uses low-latency frame pacing in Direct3D 9–11 games."), LaunchOptionCategory.GRAPHICS, 60, { "PROTON_DXVK_LOWLATENCY=1" }, { "DX11", "low latency", "CachyOS" }, LaunchLineType.ENVIRONMENT, _("Proton-CachyOS"), false, LaunchOptionExpertise.EXPERIMENTAL, _("Requires a compatible Proton-CachyOS build."));
            add_option ("cachyos-vkd3d-low-latency", _("Proton-CachyOS DX12 low latency"), _("Reduces input lag in Direct3D 12 games with Reflex markers or waitable swapchains. Supports AMD and NVIDIA GPUs with frame generation off."), LaunchOptionCategory.GRAPHICS, 70, { "PROTON_VKD3D_LOWLATENCY=1" }, { "DX12", "Reflex", "waitable swapchain", "CachyOS" }, LaunchLineType.ENVIRONMENT, _("Proton-CachyOS"), false, LaunchOptionExpertise.EXPERIMENTAL, _("Requires a compatible Proton-CachyOS build."));
            add_option ("cachyos-vulkan-low-latency", _("Vulkan Anti-Lag 2 layer"), _("Exposes Anti-Lag 2 to Vulkan games that support it."), LaunchOptionCategory.GRAPHICS, 80, { "LOW_LATENCY_LAYER=1" }, { "Vulkan", "Anti-Lag 2", "CachyOS", "GE-Proton", "Proton-GE" }, LaunchLineType.ENVIRONMENT, _("Vulkan low latency"), false, LaunchOptionExpertise.EXPERIMENTAL, _("Requires a Proton build with the Vulkan low-latency layer."));
            add_option ("cachyos-vulkan-reflex", _("Use Reflex in the Vulkan low-latency layer"), _("Exposes Vulkan Reflex to games that support it."), LaunchOptionCategory.GRAPHICS, 90, { "LOW_LATENCY_LAYER_REFLEX=1" }, { "Vulkan", "Reflex", "VK_NV_low_latency2", "CachyOS", "GE-Proton", "Proton-GE" }, LaunchLineType.ENVIRONMENT, _("Vulkan low latency"), false, LaunchOptionExpertise.EXPERIMENTAL, "", { "cachyos-vulkan-low-latency" });
            add_option ("cachyos-vulkan-reflex-layer", _("NVIDIA Reflex Vulkan layer"), _("Exposes NVIDIA Reflex to native Vulkan games that use VK_NV_low_latency2."), LaunchOptionCategory.GRAPHICS, 100, { "DXVK_NVAPI_VKREFLEX=1" }, { "Vulkan", "NVIDIA Reflex", "CachyOS", "GE-Proton", "Proton-GE" }, LaunchLineType.ENVIRONMENT, _("Vulkan low latency"), false, LaunchOptionExpertise.EXPERIMENTAL, _("Requires an NVIDIA GPU and a Proton build with the DXVK-NVAPI Vulkan Reflex layer."));

            // Hardware & drivers
            add_option ("amd-discrete-gpu", _("Use discrete GPU"), _("Uses the AMD discrete GPU on hybrid systems."), LaunchOptionCategory.HARDWARE, 10, { "DRI_PRIME=1" }, { "Use dGPU" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD);
            add_option ("amd-anti-lag", _("Mesa Anti-Lag"), _("Reduces latency on supported AMD Mesa setups."), LaunchOptionCategory.HARDWARE, 20, { "ENABLE_LAYER_MESA_ANTI_LAG=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD);
            add_option ("amd-fsr4", _("FSR 4 upgrade"), _("Upgrades supported FSR 3.1 games to FSR 4. Enter 1 for the build’s default release, 0 to disable the upgrade, or a supported version."), LaunchOptionCategory.HARDWARE, 30, { "PROTON_FSR4_UPGRADE=1" }, { "FSR 4", "Proton-GE", "Proton-CachyOS", "Proton-EM" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("Requires a compatible Proton build, AMD GPU, and driver."));
            add_option ("amd-fsr4-rdna3", _("Legacy FSR 4 upgrade for RDNA 3"), _("Upgrades supported FSR games on RDNA 3 through the older Proton switch."), LaunchOptionCategory.HARDWARE, 40, { "PROTON_FSR4_RDNA3_UPGRADE=1" }, { "FSR 4", "RDNA3", "legacy" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED, _("Requires a Proton build that supports the legacy RDNA 3 switch."));
            add_option ("amd-mlfg", _("FSR 4 ML frame generation"), _("Enables machine-learning frame generation with supported FSR 4 releases. Some builds enable it automatically with FSR 4."), LaunchOptionCategory.HARDWARE, 50, { "PROTON_MLFG_UPGRADE=1" }, { "MLFG", "machine learning frame generation", "FSR 4" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.EXPERIMENTAL, _("Check your Proton build’s FSR 4 version and GPU requirements."), { "amd-fsr4" });
            add_option ("amd-mlfg-rdna3-workaround", _("RDNA 3 ML frame generation workaround"), _("Applies the shader workaround that some RDNA 3 systems need for ML frame generation."), LaunchOptionCategory.HARDWARE, 55, { "DXIL_SPIRV_CONFIG=wmma_rdna3_workaround" }, { "RDNA3", "MLFG", "WMMA", "DXIL-SPIR-V" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.EXPERIMENTAL, _("Use only on RDNA 3 when ML frame generation needs the workaround."), { "amd-mlfg" });
            add_option ("amd-reflex-allow-other-drivers", _("AMD Reflex preset: allow DXVK-NVAPI"), _("Lets DXVK-NVAPI run on AMD drivers so supported games can expose Reflex."), LaunchOptionCategory.HARDWARE, 60, { "DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1" }, { "AMD", "Reflex", "DXVK-NVAPI" }, LaunchLineType.ENVIRONMENT, _("AMD Reflex compatibility"), false, LaunchOptionExpertise.EXPERIMENTAL, "", { "cachyos-vulkan-reflex" });
            add_option ("amd-reflex-dxgi-spoof", _("AMD Reflex preset: hide AMD GPU"), _("Hides the AMD GPU from DXVK so some games expose Reflex. This can break FSR 4 and ML frame generation."), LaunchOptionCategory.HARDWARE, 70, { "DXVK_CONFIG=dxgi.hideAmdGpu=True" }, { "AMD", "Reflex", "GPU spoof", "DXVK" }, LaunchLineType.ENVIRONMENT, _("AMD Reflex compatibility"), false, LaunchOptionExpertise.EXPERIMENTAL, "", { "cachyos-vulkan-reflex" });
            add_option ("amd-reflex-force-nvapi", _("AMD Reflex preset: force NVAPI"), _("Forces Proton to load NVAPI so games can expose Reflex. This can break FSR 4 and ML frame generation."), LaunchOptionCategory.HARDWARE, 80, { "PROTON_FORCE_NVAPI=1" }, { "AMD", "Reflex", "GPU spoof", "NVAPI" }, LaunchLineType.ENVIRONMENT, _("AMD Reflex compatibility"), false, LaunchOptionExpertise.EXPERIMENTAL, "", { "cachyos-vulkan-reflex" });
            add_option ("amd-reflex-layer-spoof", _("AMD Reflex preset: layer NVIDIA spoof"), _("Makes the Vulkan low-latency layer report an NVIDIA GPU. This can break FSR 4 and ML frame generation."), LaunchOptionCategory.HARDWARE, 90, { "LOW_LATENCY_LAYER_SPOOF_NVIDIA=1" }, { "AMD", "Reflex", "GPU spoof", "NVIDIA" }, LaunchLineType.ENVIRONMENT, _("AMD Reflex compatibility"), false, LaunchOptionExpertise.EXPERIMENTAL, "", { "cachyos-vulkan-reflex" });
            add_option ("amd-hide-apu", _("Treat APU as a discrete GPU"), _("Reports an AMD APU as a discrete GPU for games that mis-detect integrated graphics."), LaunchOptionCategory.HARDWARE, 100, { "PROTON_HIDE_APU=1" }, { "Hide AMD APU" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD);
            add_option ("amd-vulkan-driver", _("Vulkan driver"), _("Selects an AMD Vulkan driver through the installed driver switcher."), LaunchOptionCategory.HARDWARE, 110, { "AMD_VULKAN_ICD" }, { "AMD_ICD" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED);
            add_option ("amd-staging-shm", _("Staging shared memory"), _("Enables shared memory for Wine server requests on builds with the Wine Staging patch."), LaunchOptionCategory.HARDWARE, 120, { "STAGING_SHARED_MEMORY=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD);
            add_option ("amd-glthread", _("Mesa GL threading"), _("Moves Mesa OpenGL command processing to a separate thread."), LaunchOptionCategory.HARDWARE, 130, { "mesa_glthread=true" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED);
            add_option ("amd-shader-cache", _("Mesa shader-cache control"), _("Enables or disables Mesa’s on-disk shader cache."), LaunchOptionCategory.HARDWARE, 140, { "MESA_SHADER_CACHE_DISABLE=0", "MESA_SHADER_CACHE_DISABLE=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED);
            add_option ("amd-radv-perftest", _("Experimental RADV features"), _("Selects experimental performance features for Mesa’s RADV Vulkan driver."), LaunchOptionCategory.HARDWARE, 150, { "RADV_PERFTEST" }, { "AMD RADV Performance Tests" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.EXPERIMENTAL);
            add_option ("amd-radv-debug", _("RADV workarounds and debugging"), _("Selects workarounds and debugging flags for Mesa’s RADV Vulkan driver."), LaunchOptionCategory.HARDWARE, 160, { "RADV_DEBUG" }, { "AMD RADV Debug Options" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED);
            add_option ("amd-aco-debug", _("ACO shader-compiler debugging"), _("Selects debugging flags for Mesa’s AMD shader compiler."), LaunchOptionCategory.HARDWARE, 170, { "ACO_DEBUG" }, { "AMD ACO Debug Options" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED);
            add_option ("nvidia-nvapi", _("NVAPI"), _("Lets games access NVIDIA-specific features such as DLSS."), LaunchOptionCategory.HARDWARE, 200, { "PROTON_ENABLE_NVAPI=1" }, {}, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD);
            add_option ("nvidia-dlss-updater", _("DLSS component updates"), _("Allows NVIDIA’s NGX updater to download newer DLSS components for supported games."), LaunchOptionCategory.HARDWARE, 210, { "PROTON_ENABLE_NGX_UPDATER=1" }, { "Update DLSS components" }, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD);
            add_option ("nvidia-dlss-indicator", _("DLSS indicator"), _("Shows whether DLSS is active while you play."), LaunchOptionCategory.HARDWARE, 220, { "PROTON_DLSS_INDICATOR=1" }, {}, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD);
            add_option ("nvidia-libraries", _("NVIDIA libraries"), _("Enables Proton’s optional NVIDIA libraries."), LaunchOptionCategory.HARDWARE, 230, { "PROTON_NVIDIA_LIBS=1" }, {}, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD);
            add_option ("nvidia-report-amd", _("Report GPU as AMD"), _("Makes the game detect an AMD GPU in place of the NVIDIA GPU."), LaunchOptionCategory.HARDWARE, 240, { "PROTON_HIDE_NVIDIA_GPU=1" }, { "Hide NVIDIA GPU" }, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD);
            add_option ("intel-xess", _("XeSS component upgrade"), _("Replaces the game’s XeSS library with a newer version on supported Proton builds."), LaunchOptionCategory.HARDWARE, 250, { "PROTON_XESS_UPGRADE=1" }, { "XeSS Upgrade" }, LaunchLineType.ENVIRONMENT, _("Intel"), false, LaunchOptionExpertise.STANDARD);

            // Input & audio
            add_option ("prefer-sdl", _("Prefer SDL controller input"), _("Uses SDL for controller input to help games detect some controllers."), LaunchOptionCategory.INPUT_AUDIO, 10, { "PROTON_PREFER_SDL=1" }, { "Prefer SDL controller" });
            add_option ("bypass-steam-input", _("Bypass Steam Input"), _("Disables Steam Input support."), LaunchOptionCategory.INPUT_AUDIO, 20, { "PROTON_NO_STEAMINPUT=1" }, { "Disable Steam Input" });
            add_option ("pulse-latency", _("PulseAudio latency"), _("Sets the requested PulseAudio buffer latency in milliseconds."), LaunchOptionCategory.INPUT_AUDIO, 30, { "PULSE_LATENCY_MSEC=" });
            add_option ("winealsa-channels", _("Wine ALSA output channels"), _("Sets the number of output channels exposed to the game through Wine’s ALSA driver."), LaunchOptionCategory.INPUT_AUDIO, 40, { "WINEALSA_CHANNELS=" }, { "WINEALSA Channels" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires a Proton build with Wine ALSA channel overrides."));
            add_option ("winealsa-spatial", _("Wine ALSA spatial downmix"), _("Applies spatial downmixing to 4-, 6-, or 8-channel Wine ALSA audio."), LaunchOptionCategory.INPUT_AUDIO, 50, { "WINEALSA_SPATIAL=1" }, { "WINEALSA Spatial Audio", "WINEALSA_SPACIAL" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, "", { "winealsa-channels" });

            // Game arguments
            add_option ("skip-launcher", _("Skip launcher"), _("Asks supported games to start directly using -skip-launcher."), LaunchOptionCategory.GAME_ARGUMENTS, 10, { "-skip-launcher" }, {}, LaunchLineType.ARGUMENT, "", true);
            add_option ("renderer-vulkan", _("Vulkan renderer"), _("Asks the game to use Vulkan if it recognizes the -vulkan flag."), LaunchOptionCategory.GAME_ARGUMENTS, 20, { "-vulkan" }, {}, LaunchLineType.ARGUMENT);
            add_option ("renderer-dx11", _("DirectX 11 renderer"), _("Asks the game to use DirectX 11 if it recognizes the -dx11 flag."), LaunchOptionCategory.GAME_ARGUMENTS, 30, { "-dx11" }, {}, LaunchLineType.ARGUMENT);
            add_option ("renderer-dx12", _("DirectX 12 renderer"), _("Asks the game to use DirectX 12 if it recognizes the -dx12 flag."), LaunchOptionCategory.GAME_ARGUMENTS, 40, { "-dx12" }, {}, LaunchLineType.ARGUMENT);
            add_option ("developer-console", _("Developer console"), _("Enables the in-game console in games that recognize the -console flag."), LaunchOptionCategory.GAME_ARGUMENTS, 50, { "-console" }, { "Console" }, LaunchLineType.ARGUMENT);
            add_option ("custom-game-arguments", _("Custom game arguments"), _("Passes additional arguments directly to the game. Enter one argument per entry."), LaunchOptionCategory.GAME_ARGUMENTS, 60, { "custom", "arguments", "unknown" }, {}, LaunchLineType.ADDITIONAL, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("native-game-wrapper", _("Native game wrapper"), _("Runs a native Linux game through an installed TinkerGame or SteamTinkerLaunch executable."), LaunchOptionCategory.GAME_ARGUMENTS, 65, { "tinkergame", "steamtinkerlaunch" }, {}, LaunchLineType.WRAPPER);
            add_option (LaunchCustomWrapperInput.OPTION_ID, _("Custom wrapper"), _("Run an executable or script before the Steam game command."), LaunchOptionCategory.GAME_ARGUMENTS, 70, { "script", "executable", "bgmod", "%command%" }, {}, LaunchLineType.WRAPPER, "", true);

            // Diagnostics & raw command
            add_option ("proton-debug-log", _("Proton debug log"), _("Enter 1 for standard Proton logs, 0 to disable logging, or Wine debug channels for a custom log."), LaunchOptionCategory.DIAGNOSTICS, 10, { "PROTON_LOG=1" }, { "Enable Proton logs" }, LaunchLineType.ENVIRONMENT, "", true);
            add_option ("dxvk-log-level", _("DXVK log level"), _("Sets how much detail DXVK writes to its logs."), LaunchOptionCategory.DIAGNOSTICS, 20, { "DXVK_LOG_LEVEL=none" }, { "Disable DXVK logging" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("vkd3d-log-level", _("VKD3D log level"), _("Sets how much detail VKD3D-Proton writes to its logs."), LaunchOptionCategory.DIAGNOSTICS, 30, { "VKD3D_LOG_LEVEL=" }, { "VKD3D Logging Level" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("steam-command", _("Steam command placeholder (%command%)"), _("Marks where Steam inserts the game's command."), LaunchOptionCategory.DIAGNOSTICS, 40, { "%command%" }, {}, LaunchLineType.COMMAND, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("raw-launch-options", _("Preserved unrecognized launch options"), _("Keeps unrecognized, quoted, and opaque shell content exactly as loaded."), LaunchOptionCategory.DIAGNOSTICS, 50, { "$(unsafe)", "|", "&&", "%command%" }, { "raw", "opaque", "unknown", "custom pair" }, LaunchLineType.ADDITIONAL, "", false, LaunchOptionExpertise.ADVANCED);
        }
    }
}
