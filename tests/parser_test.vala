namespace AppTests.ParserTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/parser/length-aware-byte-conversion", test_length_aware_byte_conversion);
        Test.add_func ("/vdf/text-parser-replaces-key-and-value", test_vdf_document_replacements);
        Test.add_func ("/launch-options/shell-words-preserve-quoting", test_launch_option_shell_words);
        Test.add_func ("/launch-options/opaque-shell-spans", test_opaque_shell_spans);
        Test.add_func ("/launch-options/command-preview-markup", test_launch_option_command_preview_markup);
        Test.add_func ("/launch-options/catalog-metadata-and-search", test_launch_option_catalog_metadata_and_search);
        Test.add_func ("/launch-options/catalog-semantic-definitions", test_launch_option_catalog_semantic_definitions);
        Test.add_func ("/launch-options/catalog-semantic-validation", test_launch_option_catalog_semantic_validation);
        Test.add_func ("/launch-options/catalog-source-backed-support", test_launch_option_catalog_source_backed_support);
        Test.add_func ("/launch-options/catalog-active-options-survive-filters", test_launch_option_catalog_active_options_survive_filters);
        Test.add_func ("/launch-options/presentation-parent-visibility", test_launch_option_presentation_parent_visibility);
        Test.add_func ("/launch-options/launch-backend-chrome", test_launch_backend_chrome_visibility);
        Test.add_func ("/launch-options/changing-one-control-preserves-unrelated-raw-tokens", test_launch_option_single_control_edit_preserves_raw_tokens);
        Test.add_func ("/launch-options/category-order-does-not-affect-serialization", test_launch_option_category_order_does_not_affect_serialization);
        Test.add_func ("/system/gpu-vendor-from-pci-devices", test_gpu_vendor_from_pci_devices);
    }

    private void test_length_aware_byte_conversion () {
        uint8 data[4];
        data[0] = 't';
        data[1] = 'e';
        data[2] = 's';
        data[3] = 't';

        assert (ProtonPlus.Utils.Parser.data_to_string (data) == "test");
    }

    private void test_vdf_document_replacements () {
        string content = "\"compat_tools\" // tools\n{\n\t\"Old Name\" // internal name\n\t{\n\t\t\"display_name\"    \"Old Name\"\n\t}\n}\n";
        var document = ProtonPlus.Utils.VDF.VdfParser.parse_document (content);
        assert (document != null);

        var compat_tools = document.root.get_child ("compat_tools");
        assert (compat_tools != null);
        assert (compat_tools.children.size == 1);

        var tool = compat_tools.children.get (0);
        var renamed_content = document.replace_key (tool, "New Name");
        assert (renamed_content == "\"compat_tools\" // tools\n{\n\t\"New Name\" // internal name\n\t{\n\t\t\"display_name\"    \"Old Name\"\n\t}\n}\n");

        document = ProtonPlus.Utils.VDF.VdfParser.parse_document (renamed_content);
        assert (document != null);
        compat_tools = document.root.get_child ("compat_tools");
        assert (compat_tools != null);
        tool = compat_tools.children.get (0);
        var display_name = tool.get_child ("display_name");
        assert (display_name != null);

        var rewritten_content = document.replace_value (display_name, "New Name");
        assert (rewritten_content == "\"compat_tools\" // tools\n{\n\t\"New Name\" // internal name\n\t{\n\t\t\"display_name\"    \"New Name\"\n\t}\n}\n");
    }

    private void test_launch_option_shell_words () {
        var options = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionsList ();
        string source = "VAR=\"hello world\" gamescope -- %command% -windowed";

        var tokens = options.get_launch_option_tokens (source);

        assert (tokens.length == 5);
        assert (tokens[0] == "VAR=hello world");
        assert (tokens[3] == "%command%");
        options.load_from_string (source);
        assert (options.to_launch_line () == source);
        options.mark_modified ();
        assert (options.to_launch_line () == source);
    }

    private void test_opaque_shell_spans () {
        var tokenizer = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionShellTokenizer ();
        var tokens = tokenizer.tokenize ("VAR=1 $(unsafe) %command%");

        assert (tokens.size == 3);
        assert (!tokens[0].is_opaque);
        assert (tokens[1].is_opaque);
        assert (tokens[1].raw == "$(unsafe)");

        var options = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionsList ();
        string source = "VAR=1 $(unsafe) %command%";
        options.load_from_string (source);
        assert (options.to_launch_line () == source);
        options.mark_modified ();
        assert (options.to_launch_line () == source);
    }

    private void test_launch_option_command_preview_markup () {
        var markup = ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionsList
            .build_command_preview_markup ("VAR=\"hello world\" %command% <unsafe>");

        assert (markup.contains ("<tt>"));
        assert (markup.contains ("foreground='#79c0ff'"));
        assert (markup.contains ("foreground='#ff938a'"));
        assert (markup.contains ("VAR=&quot;hello world&quot;"));
        assert (markup.contains ("&lt;unsafe&gt;"));

        var labeled = ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionsList
            .build_labeled_command_preview_markup (
                { "Game <One>", "Game Two" },
                { "PROTON_LOG=1 %command%", "-console" }
            );
        assert (labeled.contains ("<b>Game &lt;One&gt;</b>"));
        assert (labeled.contains ("PROTON_LOG=1"));
        assert (labeled.contains ("-console"));
    }

    private void test_launch_option_catalog_metadata_and_search () {
        var catalog = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCatalog ();
        assert (catalog.is_valid ());

        var first_order = catalog.get_ordered ();
        var second_order = catalog.get_ordered ();
        assert (first_order.size == second_order.size);
        for (var index = 0; index < first_order.size; index++) {
            assert (first_order[index].id != "");
            assert (first_order[index].category >= ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PERFORMANCE);
            assert (first_order[index].category <= ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.DIAGNOSTICS);
            assert (first_order[index].id == second_order[index].id);
        }

        assert (catalog.search ("MangoHud").size > 0);
        assert (catalog.search ("temperatures").size > 0);
        assert (catalog.search ("WINEALSA_SPACIAL").size > 0);
        assert (catalog.search ("upload_hvv").size > 0);

        var winealsa = catalog.search ("WINEALSA_SPACIAL")[0];
        assert (winealsa.category == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.INPUT_AUDIO);
        assert (catalog.should_display (
            winealsa,
            ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.PERFORMANCE,
            "WINEALSA_SPACIAL",
            false
        ));
    }

    private void test_launch_option_catalog_semantic_definitions () {
        var catalog = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCatalog ();
        assert (catalog.validate ().size == 0);
        foreach (var entry in catalog.get_ordered ())
            assert (entry.semantics != null);

        var proton_log = catalog.lookup ("proton-debug-log");
        assert (proton_log != null);
        assert (proton_log.semantics.kind == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT);
        assert (proton_log.semantics.placeholder_policy == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchPlaceholderPolicy.REQUIRED);
        assert (proton_log.semantics.environment_key == "PROTON_LOG");
        assert (proton_log.semantics.fixed_tokens[0] == "PROTON_LOG=1");

        var dxvk_limit = catalog.lookup ("dxvk-frame-limit");
        assert (dxvk_limit.semantics.support == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSupport.UNSUPPORTED);
        assert (!dxvk_limit.semantics.managed_emission);

        assert (catalog.lookup ("performance-overlay").semantics.wrapper_id == "mangohud");
        assert (catalog.lookup ("gamemode").semantics.wrapper_id == "gamemode");
        assert (catalog.lookup ("game-performance").semantics.wrapper_id == "game-performance");
        assert (catalog.lookup_wrapper ("mangohud").delimiter == null);
        assert (catalog.lookup_wrapper ("gamemode").delimiter == null);
        assert (catalog.lookup_wrapper ("game-performance").delimiter == null);
        assert (catalog.lookup_wrapper ("gamescope").delimiter == "--");
        assert (catalog.lookup_wrapper ("scopebuddy").delimiter == "--");
        assert (catalog.lookup_wrapper ("gamescope").mutual_exclusion_group == "launch-backend");
        assert (catalog.lookup_wrapper ("scopebuddy").mutual_exclusion_group == "launch-backend");
        assert (catalog.get_wrappers ()[0].nesting_priority <= catalog.get_wrappers ()[1].nesting_priority);

        var gamescope_fullscreen = catalog.lookup ("gamescope-fullscreen");
        var scopebuddy_limit = catalog.lookup ("scopebuddy-frame-limit");
        assert (gamescope_fullscreen.semantics.wrapper_id == "gamescope");
        assert (scopebuddy_limit.semantics.wrapper_id == "scopebuddy");
        assert (gamescope_fullscreen.semantics.placeholder_policy == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchPlaceholderPolicy.INHERITED_FROM_WRAPPER);
        assert (scopebuddy_limit.semantics.placeholder_policy == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchPlaceholderPolicy.INHERITED_FROM_WRAPPER);

        var backend = catalog.lookup ("launch-backend");
        assert (backend.semantics.kind == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.WRAPPER_SELECTOR);
        assert (backend.semantics.selectable_wrapper_ids[0] == "gamescope");
        assert (backend.semantics.selectable_wrapper_ids[1] == "scopebuddy");

        var scopebuddy_resolution = catalog.lookup ("scopebuddy-resolution");
        assert (scopebuddy_resolution.semantics.kind == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.COMPOSITE_DYNAMIC);
        assert (scopebuddy_resolution.semantics.emission_mode == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionEmissionMode.COMPOSITE_EMISSION);
        assert (scopebuddy_resolution.semantics.get_composite_outputs ()[0].environment_key == "SCB_AUTO_RES");
        assert (scopebuddy_resolution.semantics.get_composite_outputs ()[1].wrapper_id == "scopebuddy");

        var developer_console = catalog.lookup ("developer-console");
        assert (developer_console.semantics.kind == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.GAME_ARGUMENT);
        assert (developer_console.semantics.placeholder_policy == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchPlaceholderPolicy.OPTIONAL);
        assert (catalog.lookup ("renderer-vulkan").semantics.conflict_group == "renderer-selection");
        assert (catalog.lookup ("renderer-dx11").semantics.conflict_group == "renderer-selection");
        assert (catalog.lookup ("renderer-dx12").semantics.conflict_group == "renderer-selection");
        assert (catalog.lookup ("amd-fsr4").semantics.conflict_group == "amd-fsr4-upgrade");
        assert (catalog.lookup ("amd-fsr4-rdna3").semantics.conflict_group == "amd-fsr4-upgrade");
        assert (contains (catalog.lookup ("amd-fsr4").semantics.conflicts, "amd-reflex-dxgi-spoof"));
        assert (contains (catalog.lookup ("dxvk-no-hdr").semantics.conflicts, "dxvk-hdr"));
        assert (contains (catalog.lookup ("dxvk-no-hdr").semantics.conflicts, "proton-hdr"));
        assert (contains (catalog.lookup ("amd-mlfg").semantics.conflicts, "cachyos-vkd3d-low-latency"));
        assert (contains (catalog.lookup ("cachyos-vulkan-reflex").semantics.dependencies, "cachyos-vulkan-low-latency"));
        assert (contains (catalog.lookup ("amd-mlfg-rdna3-workaround").semantics.dependencies, "amd-mlfg"));

        var command_entries = 0;
        foreach (var entry in catalog.get_ordered ()) {
            if (entry.semantics.kind == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.COMMAND_BOUNDARY)
                command_entries++;
        }
        assert (command_entries == 1);
        assert (catalog.lookup ("steam-command").semantics.legacy_manual_representation);
        assert (catalog.lookup ("raw-launch-options").semantics.kind == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.OPAQUE_CONTEXT_DEPENDENT);
        assert (catalog.lookup ("custom-game-arguments").semantics.kind == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.GAME_ARGUMENT);
        assert (catalog.lookup ("custom-game-arguments").semantics.emission_mode == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionEmissionMode.DYNAMIC_GAME_ARGUMENTS);
    }

    private void test_launch_option_catalog_semantic_validation () {
        var definitions = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionMetadata[] {
            semantic_fixture ("missing-semantics", ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType.ENVIRONMENT, null),
            semantic_fixture ("missing-wrapper", ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType.WRAPPER_ARGUMENT,
                new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemantics (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.WRAPPER_ARGUMENT, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchPlaceholderPolicy.INHERITED_FROM_WRAPPER, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionEmissionMode.FIXED_TOKENS, "", "missing", { "-f" })),
            semantic_fixture ("missing-dependency", ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType.ENVIRONMENT,
                new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemantics (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchPlaceholderPolicy.REQUIRED, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionEmissionMode.FIXED_TOKENS, "A", "", { "A=1" }, {}, "", {}, { "missing" })),
            semantic_fixture ("missing-conflict", ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType.ARGUMENT,
                new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemantics (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.GAME_ARGUMENT, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchPlaceholderPolicy.OPTIONAL, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionEmissionMode.FIXED_TOKENS, "", "", { "-a" }, {}, "", { "missing" })),
            semantic_fixture ("no-environment-key", ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType.ENVIRONMENT,
                new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemantics (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchPlaceholderPolicy.REQUIRED, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionEmissionMode.FIXED_TOKENS, "", "", { "A=1" })),
            semantic_fixture ("no-fixed-token", ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType.ARGUMENT,
                new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemantics (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.GAME_ARGUMENT, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchPlaceholderPolicy.OPTIONAL, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionEmissionMode.FIXED_TOKENS)),
            semantic_fixture ("embedded-command", ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType.ARGUMENT,
                new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemantics (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.GAME_ARGUMENT, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchPlaceholderPolicy.OPTIONAL, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionEmissionMode.FIXED_TOKENS, "", "", { "before-%command%" })),
            semantic_fixture ("legacy-canonical", ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType.ENVIRONMENT,
                new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemantics (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchPlaceholderPolicy.REQUIRED, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionEmissionMode.FIXED_TOKENS, "A", "", { "A=1" }, {}, "", {}, {}, {}, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionApplicability.GENERIC, {}, false, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSupport.VERIFIED_CURRENT, true, { "A=1" })),
            semantic_fixture ("unsupported-managed", ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType.ENVIRONMENT,
                new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemantics (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchPlaceholderPolicy.REQUIRED, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionEmissionMode.FIXED_TOKENS, "B", "", { "B=1" }, {}, "", {}, {}, {}, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionApplicability.GENERIC, {}, false, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSupport.UNSUPPORTED, true))
        };
        var wrappers = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchWrapperDefinition[] {
            new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchWrapperDefinition ("duplicate", { "first" }),
            new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchWrapperDefinition ("duplicate", { "second" })
        };
        var catalog = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCatalog.with_definitions (definitions, wrappers);
        var diagnostics = catalog.validate ();
        assert (diagnostics_contain (diagnostics, "no semantic definition"));
        assert (diagnostics_contain (diagnostics, "unknown wrapper"));
        assert (diagnostics_contain (diagnostics, "unknown dependency"));
        assert (diagnostics_contain (diagnostics, "unknown conflict"));
        assert (diagnostics_contain (diagnostics, "requires an environment key"));
        assert (diagnostics_contain (diagnostics, "requires tokens"));
        assert (diagnostics_contain (diagnostics, "outside a command boundary"));
        assert (diagnostics_contain (diagnostics, "treats canonical token"));
        assert (diagnostics_contain (diagnostics, "Unsupported or legacy option"));
        assert (diagnostics_contain (diagnostics, "cannot claim generic applicability"));
        assert (diagnostics_contain (diagnostics, "Duplicate wrapper ID"));
    }

    private void test_launch_option_catalog_source_backed_support () {
        var catalog = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCatalog ();
        assert (catalog.is_valid ());

        foreach (var entry in catalog.get_ordered ()) {
            assert (entry.semantics != null);
            assert (entry.semantics.support >= ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSupport.VERIFIED_CURRENT);
            assert (entry.semantics.support <= ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSupport.UNKNOWN_UNVERIFIED);
            if (entry.semantics.support == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSupport.UNSUPPORTED)
                assert (!entry.semantics.managed_emission);
        }

        assert_semantics (
            catalog.lookup ("ntsync-mode").semantics, "PROTON_NO_NTSYNC", "PROTON_NO_NTSYNC=1", "PROTON_USE_NTSYNC=0"
        );
        assert_semantics (
            catalog.lookup ("dll-overrides").semantics, "WINEDLLOVERRIDES", null, "DLL_OVERRIDES"
        );
        assert_semantics (
            catalog.lookup ("amd-vulkan-driver").semantics, "AMD_VULKAN_ICD", null, "AMD_ICD"
        );
        assert_semantics (
            catalog.lookup ("vkd3d-log-level").semantics, "VKD3D_DEBUG", null, "VKD3D_LOG_LEVEL"
        );

        var shader_cache = catalog.lookup ("amd-shader-cache").semantics;
        assert (shader_cache.fixed_tokens.length == 1);
        assert (shader_cache.fixed_tokens[0] == "MESA_SHADER_CACHE_DISABLE=1");
        assert (shader_cache.get_composite_outputs ().length == 0);

        string[] unsupported_ids = { "dxvk-frame-limit", "vkd3d-shader-cache", "vkd3d-gpuva" };
        foreach (var id in unsupported_ids) {
            var semantics = catalog.lookup (id).semantics;
            assert (semantics.support == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSupport.UNSUPPORTED);
            assert (!semantics.managed_emission);
            assert (semantics.environment_key == "");
        }

        var dxvk_async = catalog.lookup ("dxvk-async").semantics;
        assert (dxvk_async.support == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSupport.VARIANT_SPECIFIC);
        assert (dxvk_async.applicability == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionApplicability.COMPONENT_SPECIFIC);
        assert (catalog.lookup ("nvidia-nvapi").semantics.support == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSupport.LEGACY_DEPRECATED);
        assert (catalog.lookup ("dxvk-hdr").semantics.fixed_tokens[0] == "DXVK_HDR=1");
        assert (catalog.lookup ("proton-hdr").semantics.get_required_capabilities ()[0]
            == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCapability.LEGACY_PROTON_HDR);
        assert (catalog.lookup ("amd-fsr4").semantics.get_required_capabilities ()[1]
            == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCapability.PROTON_FSR4);
        assert (catalog.lookup ("amd-fsr4-rdna3").semantics.get_required_capabilities ()[1]
            == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCapability.PROTON_FSR4_RDNA3);
        assert (catalog.lookup ("cachyos-vkd3d-low-latency").semantics.fixed_tokens[0]
            == "PROTON_VKD3D_LOWLATENCY=1");

        var config = catalog.lookup ("vkd3d-config").semantics;
        assert (contains (config.selectable_values, "force_host_cached"));
        assert (!contains (config.selectable_values, "force_host_cache"));
        assert (!contains (config.selectable_values, "shader_cache"));
        assert (contains (config.legacy_tokens, "force_host_cache"));

        assert (contains (catalog.lookup ("amd-radv-perftest").semantics.selectable_values, "nggc"));
        assert (contains (catalog.lookup ("amd-radv-debug").semantics.selectable_values, "hang"));
        assert (contains (catalog.lookup ("amd-aco-debug").semantics.selectable_values, "force-waitcnt"));

        foreach (var entry in catalog.get_ordered ()) {
            foreach (var token in entry.semantics.fixed_tokens)
                assert (!token.contains ("%command%"));
        }
        assert (catalog.lookup ("steam-command").semantics.kind == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemanticKind.COMMAND_BOUNDARY);
    }

    private void assert_semantics (
        ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemantics semantics,
        string key, string? fixed_token, string legacy_token
    ) {
        assert (semantics.environment_key == key);
        if (fixed_token != null) {
            assert (semantics.fixed_tokens.length == 1);
            assert (semantics.fixed_tokens[0] == fixed_token);
        } else {
            assert (semantics.fixed_tokens.length == 0);
        }
        assert (contains (semantics.legacy_tokens, legacy_token));
    }

    private bool contains (string[] values, string expected) {
        foreach (var value in values) {
            if (value == expected)
                return true;
        }
        return false;
    }

    private ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionMetadata semantic_fixture (
        string id,
        ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType serialization_type,
        ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionSemantics? semantics
    ) {
        return new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionMetadata (
            id, id, id, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.DIAGNOSTICS,
            "", 0, false, ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionExpertise.STANDARD,
            "", "", {}, {}, {}, serialization_type, 0, semantics
        );
    }

    private bool diagnostics_contain (Gee.List<string> diagnostics, string fragment) {
        foreach (var diagnostic in diagnostics) {
            if (diagnostic.contains (fragment))
                return true;
        }
        return false;
    }

    private void test_launch_option_catalog_active_options_survive_filters () {
        var catalog = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCatalog ();
        var nvidia_option = catalog.lookup ("nvidia-nvapi");
        assert (nvidia_option != null);

        assert (catalog.should_display (
            nvidia_option,
            ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.QUICK,
            "AMD",
            true
        ));
        assert (!catalog.should_display (
            nvidia_option,
            ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.QUICK,
            "AMD",
            false
        ));
    }

    private void test_launch_option_presentation_parent_visibility () {
        var catalog = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCatalog ();
        var presentations = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionPresentationRegistry (catalog);
        var performance = new TestLaunchOption ("mangohud");
        var graphics = new TestLaunchOption ("DXVK_FRAME_RATE=");
        var proton = new TestLaunchOption ("PROTON_USE_WINED3D=1");
        var gamescope = new TestLaunchOption ("-r");

        presentations.register ("performance-overlay", null, performance);
        presentations.register ("dxvk-frame-limit", null, graphics);
        presentations.register ("wined3d", null, proton);
        presentations.register ("gamescope-frame-limit", null, gamescope, false);

        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.QUICK, "");
        assert (presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PERFORMANCE));
        assert (presentations.has_registered_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PERFORMANCE));
        assert (!presentations.has_registered_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.INPUT_AUDIO));
        assert (!presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PROTON));
        assert (!presentations.has_visible_in_subsection (
            ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.GRAPHICS, "DXVK"
        ));

        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.ACTIVE, "");
        assert (!presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PERFORMANCE));
        performance.active = true;
        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.ACTIVE, "");
        assert (presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PERFORMANCE));
        assert (!presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.GRAPHICS));

        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.ALL, "Gamescope");
        assert (!presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.GRAPHICS));
        assert (presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.DISPLAY));
        assert (presentations.has_visible_in_subsection (
            ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.DISPLAY, "Gamescope"
        ));

        proton.active = true;
        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.PERFORMANCE, "");
        assert (presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PERFORMANCE));
        assert (presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PROTON));
        assert (!presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.GRAPHICS));

        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.ALL, "");
        assert (!presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.INPUT_AUDIO));
        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.QUICK, "");
        assert (!presentations.has_visible_in_subsection (
            ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.GRAPHICS, "DXVK"
        ));
    }

    private void test_launch_backend_chrome_visibility () {
        assert (!ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups.WrapperGroup.should_show_backend_chrome (
            false, false, false
        ));
        assert (ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups.WrapperGroup.should_show_backend_chrome (
            true, false, false
        ));
        assert (ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups.WrapperGroup.should_show_backend_chrome (
            false, true, false
        ));
        assert (ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups.WrapperGroup.should_show_backend_chrome (
            false, false, true
        ));

        assert (!ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups.WrapperGroup.should_show_backend_group (
            true, false
        ));
        assert (ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups.WrapperGroup.should_show_backend_group (
            true, true
        ));
    }

    private void test_launch_option_single_control_edit_preserves_raw_tokens () {
        var options = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionsList ();
        var proton_log = new TestLaunchOption ("PROTON_LOG=1");
        options.add (proton_log);

        string source = "VAR=\"hello world\" PROTON_LOG=1 %command% $(unsafe) -windowed";
        options.load_from_string (source);
        assert (proton_log.active);

        proton_log.active = false;
        options.mark_modified ();
        assert (options.to_launch_line () == "VAR=\"hello world\" %command% $(unsafe) -windowed");
    }

    private void test_launch_option_category_order_does_not_affect_serialization () {
        var options = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionsList ();
        string source = "VAR=\"hello world\" %command% $(unsafe) -windowed";
        options.load_from_string (source);

        var catalog = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCatalog ();
        catalog.get_ordered ();
        catalog.search ("gamescope");

        options.mark_modified ();
        assert (options.to_launch_line () == source);
    }

    private class TestLaunchOption : Object, ProtonPlus.Widgets.Games.LaunchOptionsEditor.ILaunchOption {
        public ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType line_type { get; set; default = ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType.ENVIRONMENT; }
        public bool is_advanced { get; set; default = false; }
        public bool active { get; set; default = false; }
        string token;

        public TestLaunchOption (string token) {
            this.token = token;
        }

        public void add_child (ProtonPlus.Widgets.Games.LaunchOptionsEditor.ILaunchOption child) {
        }

        public void parse_tokens (string[] tokens, bool[] consumed) {
            for (var index = 0; index < tokens.length; index++) {
                if (!consumed[index] && tokens[index] == token) {
                    active = true;
                    consumed[index] = true;
                    return;
                }
            }
        }

        public void clear () {
            active = false;
        }

        public void append_command_segments (Gee.LinkedList<string> segments) {
            if (active)
                segments.add (token);
        }

        public bool is_active () {
            return active;
        }
    }

    private void test_gpu_vendor_from_pci_devices () {
        var pci_devices = "00:00.0 Host bridge [0600]: Intel Corporation Device [8086:7d41]\n"
                          + "00:02.0 VGA compatible controller [0300]: Intel Corporation Device [8086:a7a0]\n"
                          + "01:00.0 Audio device [0403]: NVIDIA Corporation Device [10de:22ba]";

        assert (ProtonPlus.Utils.System.get_gpu_vendor_from_pci_devices (pci_devices)
                == ProtonPlus.Utils.GpuVendor.INTEL);
        assert (ProtonPlus.Utils.System.get_gpu_vendor_from_pci_devices (
            "01:00.0 3D controller [0302]: NVIDIA Corporation Device [10de:28a0]"
        ) == ProtonPlus.Utils.GpuVendor.NVIDIA);
        assert (ProtonPlus.Utils.System.get_gpu_vendor_from_pci_devices (
            "0c:00.0 Display controller [0380]: Advanced Micro Devices, Inc. [AMD/ATI] Device [1002:73bf]"
        ) == ProtonPlus.Utils.GpuVendor.AMD);
        assert (ProtonPlus.Utils.System.get_gpu_vendor_from_pci_devices (
            "00:14.0 USB controller [0c03]: Intel Corporation Device [8086:7a60]"
        ) == ProtonPlus.Utils.GpuVendor.UNKNOWN);
    }
}
