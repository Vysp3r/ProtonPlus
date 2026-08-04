namespace AppTests.LaunchCommandParserTest {
    using GLib;
    using ProtonPlus.Widgets.Games.LaunchOptionsEditor;

    public void register_tests () {
        Test.add_func ("/launch-command-parser/empty-and-arguments", test_empty_and_arguments);
        Test.add_func ("/launch-command-parser/environment-canonical-and-legacy", test_environment_canonical_and_legacy);
        Test.add_func ("/launch-command-parser/wrappers-and-delimiters", test_wrappers_and_delimiters);
        Test.add_func ("/launch-command-parser/scopebuddy-composite", test_scopebuddy_composite);
        Test.add_func ("/launch-command-parser/structural-diagnostics", test_structural_diagnostics);
        Test.add_func ("/launch-command-parser/raw-preservation", test_raw_preservation);
        Test.add_func ("/launch-command-parser/custom-argument-import", test_custom_argument_import);
        Test.add_func ("/launch-command-parser/catalog-parse-validation", test_catalog_parse_validation);
    }

    private LaunchCommandParseResult parse (string input) {
        return new LaunchCommandParser ().parse (input);
    }

    private void test_empty_and_arguments () {
        var empty = parse ("");
        assert (empty.tokens.size == 0);
        assert (empty.is_structurally_safe);

        var arguments = parse ("-console");
        assert (arguments.occurrences.size == 1);
        assert (arguments.occurrences[0].option_id == "developer-console");
        assert (arguments.command_boundary_indexes.size == 0);
        assert (arguments.diagnostics.size == 0);

        var boundary = parse ("%command% -console");
        assert (boundary.command_boundary_indexes.size == 1);
        assert (boundary.command_boundary_indexes[0] == 0);
        assert (boundary.command_boundaries[0].token.raw == "%command%");
        assert (boundary.occurrences[0].option_id == "developer-console");
    }

    private void test_environment_canonical_and_legacy () {
        var result = parse ("PROTON_LOG=1 WINEDLLOVERRIDES=\"d3d11=n;dxgi=n,b\" PROTON_NO_NTSYNC=1 PROTON_USE_NTSYNC=0 AMD_VULKAN_ICD=RADV AMD_ICD=AMDVLK VKD3D_DEBUG=warn VKD3D_LOG_LEVEL=warn DXVK_ASYNC=1 VKD3D_SHADER_CACHE=1 %command%");
        assert (result.occurrences.size == 10);
        assert (result.occurrences[0].option_id == "proton-debug-log");
        assert (result.occurrences[1].environment_value == "d3d11=n;dxgi=n,b");
        assert (!result.occurrences[2].is_legacy);
        assert (result.occurrences[3].option_id == "ntsync-mode");
        assert (result.occurrences[3].is_legacy);
        assert (!result.occurrences[3].managed_emission);
        assert (!result.occurrences[4].is_legacy);
        assert (result.occurrences[5].is_legacy);
        assert (!result.occurrences[6].is_legacy);
        assert (result.occurrences[7].is_legacy);
        assert (result.occurrences[8].option_id == "dxvk-async");
        assert (!result.occurrences[8].managed_emission);
        assert (result.occurrences[9].option_id == "vkd3d-shader-cache");
        assert (!result.occurrences[9].managed_emission);

        var unknown = parse ("UNKNOWN_VALUE=one %command%");
        assert (unknown.unrecognized_tokens.size == 1);
        assert (unknown.unrecognized_tokens[0].kind == LaunchCommandUnrecognizedKind.UNKNOWN_ENVIRONMENT_ASSIGNMENT);
    }

    private void test_wrappers_and_delimiters () {
        var result = parse ("PROTON_LOG=1 mangohud gamemoderun gamescope -f -r 60 -- %command% -skip-launcher");
        assert (result.wrappers.size == 3);
        assert (result.wrappers[0].wrapper_id == "mangohud");
        assert (result.wrappers[1].wrapper_id == "gamemode");
        assert (result.wrappers[2].wrapper_id == "gamescope");
        assert (result.wrappers[2].delimiter_index == 7);
        assert (has_occurrence (result, "gamescope-fullscreen"));
        assert (has_occurrence (result, "gamescope-frame-limit"));
        assert (has_occurrence (result, "skip-launcher"));

        var alias = parse ("scb -- %command%");
        assert (alias.wrappers.size == 1);
        assert (alias.wrappers[0].wrapper_id == "scopebuddy");
        assert (alias.wrappers[0].used_alias);

        var current = parse (
            "DXVK_NO_HDR=1 PROTON_FSR4_UPGRADE=1 LOW_LATENCY_LAYER=1 "
            + "game-performance %command%"
        );
        assert (current.wrappers.size == 1);
        assert (current.wrappers[0].wrapper_id == "game-performance");
        assert (has_occurrence (current, "dxvk-no-hdr"));
        assert (has_occurrence (current, "amd-fsr4"));
        assert (has_occurrence (current, "cachyos-vulkan-low-latency"));

        var missing = parse ("gamescope -f %command%");
        assert (has_diagnostic (missing, LaunchCommandParseDiagnosticCode.MISSING_WRAPPER_DELIMITER));
        var unknown = parse ("gamescope --unknown -- %command%");
        assert (unknown.wrappers[0].unknown_argument_indexes.size == 1);
    }

    private void test_scopebuddy_composite () {
        var result = parse ("SCB_AUTO_RES=1 scb -W 1920 -H 1080 -- %command%");
        var composite = find_occurrence (result, "scopebuddy-resolution");
        assert (composite != null);
        assert (composite.raw_tokens.size == 5);
        assert (composite.normalized_value == "1920,1080");
        assert (composite.wrapper_id == "scopebuddy");

        var partial = parse ("SCB_AUTO_RES=1 scb -W 1920 -- %command%");
        assert (find_occurrence (partial, "scopebuddy-resolution") == null);
    }

    private void test_structural_diagnostics () {
        assert (has_diagnostic (parse ("PROTON_LOG=1"), LaunchCommandParseDiagnosticCode.MISSING_COMMAND_BOUNDARY));
        assert (has_diagnostic (parse ("mangohud"), LaunchCommandParseDiagnosticCode.MISSING_COMMAND_BOUNDARY));
        assert (has_diagnostic (parse ("%command% %command%"), LaunchCommandParseDiagnosticCode.DUPLICATE_COMMAND_BOUNDARY));
        var post_boundary = parse ("%command% PROTON_LOG=1 gamescope");
        assert (post_boundary.diagnostics.size == 0);
        assert (post_boundary.get_custom_game_arguments ().size == 2);
        assert (has_diagnostic (parse ("before%command%"), LaunchCommandParseDiagnosticCode.EMBEDDED_COMMAND_BOUNDARY));
        assert (has_diagnostic (parse ("$(unsafe) %command%"), LaunchCommandParseDiagnosticCode.UNSAFE_SHELL_TOKEN));
        assert (has_diagnostic (parse ("VAR=\"unterminated %command%"), LaunchCommandParseDiagnosticCode.UNSAFE_SHELL_TOKEN));
        var unknown = parse ("unknown-before %command% unknown-after");
        assert (unknown.unrecognized_tokens[0].kind == LaunchCommandUnrecognizedKind.UNKNOWN_TOKEN);
        assert (unknown.unrecognized_tokens[1].kind == LaunchCommandUnrecognizedKind.PRESERVED_GAME_COMMAND_CONTENT);

        var arguments_only = parse ("--old 'old value'");
        assert (arguments_only.is_structurally_safe);
        assert (arguments_only.unrecognized_tokens.size == 2);
        assert (arguments_only.unrecognized_tokens[0].kind == LaunchCommandUnrecognizedKind.PRESERVED_GAME_COMMAND_CONTENT);
        assert (arguments_only.unrecognized_tokens[1].kind == LaunchCommandUnrecognizedKind.PRESERVED_GAME_COMMAND_CONTENT);
    }

    private void test_raw_preservation () {
        var result = parse ("WINEDLLOVERRIDES=\"d3d11=n;dxgi=n,b\" gamescope -r 60 -- %command% --title=\"Quoted game argument\"");
        assert (result.tokens.size == 7);
        assert (result.tokens[0].raw == "WINEDLLOVERRIDES=\"d3d11=n;dxgi=n,b\"");
        assert (result.tokens[6].raw == "--title=\"Quoted game argument\"");
        var overrides = find_occurrence (result, "dll-overrides");
        assert (overrides != null);
        assert (overrides.token_indexes[0] == 0);
        assert (result.unrecognized_tokens[0].kind == LaunchCommandUnrecognizedKind.PRESERVED_GAME_COMMAND_CONTENT);
    }

    private void test_custom_argument_import () {
        var result = parse (
            "PROTON_LOG=1 %command% --title=\"Exact spelling\" -console $(opaque) FOO=bar"
        );
        var arguments = result.get_custom_game_arguments ();
        var indexes = result.get_custom_game_argument_indexes ();
        assert (arguments.size == 3);
        assert (indexes.length == 3);
        assert (arguments[0].raw == "--title=\"Exact spelling\"");
        assert (arguments[1].raw == "$(opaque)");
        assert (arguments[2].raw == "FOO=bar");
        assert (indexes[0] < indexes[1]);
        assert (find_occurrence (result, "developer-console") != null);

        var arguments_only = parse ("--first 'two words'").get_custom_game_arguments ();
        assert (arguments_only.size == 2);
        assert (arguments_only[0].raw == "--first");
        assert (arguments_only[1].raw == "'two words'");

        var grouped = parse (
            "custom-wrapper gamescope --unknown-wrapper-value -- %command% --game-value"
        ).get_custom_game_arguments ();
        assert (grouped.size == 3);
        assert (grouped[0].raw == "custom-wrapper");
        assert (grouped[1].raw == "--unknown-wrapper-value");
        assert (grouped[2].raw == "--game-value");
    }

    private void test_catalog_parse_validation () {
        var invalid = new LaunchOptionSemantics (
            LaunchOptionSemanticKind.WRAPPER_ARGUMENT,
            LaunchPlaceholderPolicy.INHERITED_FROM_WRAPPER,
            LaunchOptionEmissionMode.FIXED_TOKENS, "", "missing", { "-x" },
            {}, "", {}, {}, {}, LaunchOptionApplicability.COMPONENT_SPECIFIC,
            {}, false, LaunchOptionSupport.VERIFIED_CURRENT, true, {}, {},
            new LaunchOptionParseShape ({ "" }, { 0, 1 })
        );
        var entry = new LaunchOptionMetadata (
            "invalid-parse", "", "", LaunchOptionCategory.DISPLAY, "", 0, false,
            LaunchOptionExpertise.STANDARD, "", "", {}, {}, {}, LaunchLineType.WRAPPER_ARGUMENT, 0, invalid
        );
        var other = new LaunchOptionMetadata (
            "ambiguous-parse", "", "", LaunchOptionCategory.DISPLAY, "", 1, false,
            LaunchOptionExpertise.STANDARD, "", "", {}, {}, {}, LaunchLineType.WRAPPER_ARGUMENT, 1,
            new LaunchOptionSemantics (
                LaunchOptionSemanticKind.WRAPPER_ARGUMENT,
                LaunchPlaceholderPolicy.INHERITED_FROM_WRAPPER,
                LaunchOptionEmissionMode.FIXED_TOKENS, "", "missing", { "-x" },
                {}, "", {}, {}, {}, LaunchOptionApplicability.COMPONENT_SPECIFIC,
                {}, false, LaunchOptionSupport.VERIFIED_CURRENT, true, {}, {},
                new LaunchOptionParseShape ({ "" }, { 0, 1 })
            )
        );
        var catalog = new LaunchOptionCatalog.with_definitions ({ entry, other }, {});
        var diagnostics = catalog.validate ();
        assert (diagnostics_contain (diagnostics, "invalid value arity"));
        assert (diagnostics_contain (diagnostics, "empty flag"));
        assert (diagnostics_contain (diagnostics, "unknown wrapper"));
        assert (diagnostics_contain (diagnostics, "ambiguous ownership"));
    }

    private bool has_occurrence (LaunchCommandParseResult result, string id) {
        return find_occurrence (result, id) != null;
    }

    private LaunchCommandOptionOccurrence? find_occurrence (LaunchCommandParseResult result, string id) {
        foreach (var occurrence in result.occurrences) {
            if (occurrence.option_id == id)
                return occurrence;
        }
        return null;
    }

    private bool has_diagnostic (LaunchCommandParseResult result, LaunchCommandParseDiagnosticCode code) {
        foreach (var diagnostic in result.diagnostics) {
            if (diagnostic.code == code)
                return true;
        }
        return false;
    }

    private bool diagnostics_contain (Gee.List<string> diagnostics, string text) {
        foreach (var diagnostic in diagnostics) {
            if (diagnostic.contains (text))
                return true;
        }
        return false;
    }
}
