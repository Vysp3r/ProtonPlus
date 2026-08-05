namespace AppTests.LaunchCommandComposerTest {
    using GLib;
    using ProtonPlus.Widgets.Games.LaunchOptionsEditor;

    public void register_tests () {
        Test.add_func ("/launch-command-composer/environment-and-shell-values", test_environment_and_shell_values);
        Test.add_func ("/launch-command-composer/arguments-boundary", test_arguments_boundary);
        Test.add_func ("/launch-command-composer/wrappers-and-composite", test_wrappers_and_composite);
        Test.add_func ("/launch-command-composer/invalid-combinations", test_invalid_combinations);
        Test.add_func ("/launch-command-composer/capabilities-and-values", test_capabilities_and_values);
        Test.add_func ("/launch-command-composer/current-custom-proton-options", test_current_custom_proton_options);
        Test.add_func ("/launch-command-composer/current-option-conflicts", test_current_option_conflicts);
        Test.add_func ("/launch-command-composer/parsed-validation", test_parsed_validation);
    }

    private LaunchCommandCapabilityContext capabilities (LaunchOptionCapability[] values) {
        return new LaunchCommandCapabilityContext (values);
    }

    private LaunchCommandCompositionResult compose (
        LaunchCommandSelection[] selections, LaunchOptionCapability[] values = {}, bool preserve = false
    ) {
        return new LaunchCommandComposer ().compose (new LaunchCommandCompositionRequest (
            selections, capabilities (values), preserve
        ));
    }

    private void assert_code (LaunchCommandCompositionResult result, LaunchCommandCompositionDiagnosticCode code) {
        foreach (var diagnostic in result.diagnostics) if (diagnostic.code == code) return;
        assert_not_reached ();
    }

    private void test_environment_and_shell_values () {
        assert (new LaunchOptionCatalog ().is_valid ());
        var basic = compose ({ new LaunchCommandSelection ("proton-debug-log") }, { LaunchOptionCapability.PROTON });
        assert (basic.is_valid);
        assert (basic.plan != null);
        assert (basic.launch_line == "PROTON_LOG=1 %command%");

        var shell = compose ({ new LaunchCommandSelection ("dll-overrides", { "d3d11=n;dxgi=n,b" }) }, { LaunchOptionCapability.PROTON });
        assert (shell.is_valid);
        assert (shell.launch_line == "WINEDLLOVERRIDES='d3d11=n;dxgi=n,b' %command%");
        assert (count_placeholder (shell.launch_line) == 1);
    }

    private void test_arguments_boundary () {
        var normal = compose ({ new LaunchCommandSelection ("developer-console") });
        assert (normal.is_valid);
        assert (normal.launch_line == "-console");
        var preserved = compose ({ new LaunchCommandSelection ("developer-console") }, {}, true);
        assert (preserved.is_valid);
        assert (preserved.launch_line == "%command% -console");

        var custom = compose ({
            new LaunchCommandSelection ("custom-game-arguments", { "--profile", "hello world" })
        });
        assert (custom.is_valid);
        assert (custom.launch_line == "--profile 'hello world'");

        var serialized = compose ({
            new LaunchCommandSelection ("custom-game-arguments",
                { "--profile=\"Exact spelling\"", "$(opaque)" }, "", {}, true)
        });
        assert (serialized.is_valid);
        assert (serialized.launch_line == "--profile=\"Exact spelling\" $(opaque)");

        var multiple = compose ({
            new LaunchCommandSelection ("custom-game-arguments", { "two arguments" }, "", {}, true)
        });
        assert (!multiple.is_valid);
        assert_code (multiple, LaunchCommandCompositionDiagnosticCode.EMPTY_OR_UNSAFE_ARGUMENT);

        var unsafe = compose ({
            new LaunchCommandSelection ("custom-game-arguments", { "%command%" })
        });
        assert (!unsafe.is_valid);
        assert_code (unsafe, LaunchCommandCompositionDiagnosticCode.EMBEDDED_COMMAND_PLACEHOLDER);
    }

    private void test_wrappers_and_composite () {
        var gamescope = compose ({
            new LaunchCommandSelection ("performance-overlay"),
            new LaunchCommandSelection ("launch-backend", {}, "gamescope"),
            new LaunchCommandSelection ("gamescope-fullscreen"),
            new LaunchCommandSelection ("gamescope-frame-limit", { "60" }),
            new LaunchCommandSelection ("skip-launcher")
        }, { LaunchOptionCapability.MANGOHUD, LaunchOptionCapability.GAMESCOPE });
        assert (gamescope.is_valid);
        assert (gamescope.launch_line == "mangohud gamescope -f -r 60 -- %command% -skip-launcher");
        assert (count_placeholder (gamescope.launch_line) == 1);

        var scopebuddy = compose ({
            new LaunchCommandSelection ("launch-backend", {}, "scopebuddy"),
            new LaunchCommandSelection ("scopebuddy-resolution", { "1920", "1080" }),
            new LaunchCommandSelection ("scopebuddy-auto-hdr")
        }, { LaunchOptionCapability.SCOPEBUDDY });
        assert (scopebuddy.is_valid);
        assert (scopebuddy.launch_line == "SCB_AUTO_HDR=1 scopebuddy -W 1920 -H 1080 -- %command%");
    }

    private void test_invalid_combinations () {
        var unsupported = compose ({ new LaunchCommandSelection ("nvidia-nvapi") }, { LaunchOptionCapability.NVIDIA, LaunchOptionCapability.PROTON });
        assert (!unsupported.is_valid);
        assert_code (unsupported, LaunchCommandCompositionDiagnosticCode.OPTION_NOT_ELIGIBLE_FOR_MANAGED_EMISSION);

        var unknown = compose ({ new LaunchCommandSelection ("unknown") });
        assert (!unknown.is_valid);
        assert_code (unknown, LaunchCommandCompositionDiagnosticCode.UNKNOWN_OPTION_ID);

        var opaque = compose ({ new LaunchCommandSelection ("raw-launch-options") });
        assert (!opaque.is_valid);
        assert_code (opaque, LaunchCommandCompositionDiagnosticCode.OPTION_NOT_ELIGIBLE_FOR_MANAGED_EMISSION);

        var duplicate = compose ({ new LaunchCommandSelection ("developer-console"), new LaunchCommandSelection ("developer-console") });
        assert (!duplicate.is_valid);
        assert_code (duplicate, LaunchCommandCompositionDiagnosticCode.DUPLICATE_OPTION_SELECTION);

        var missing_wrapper = compose ({ new LaunchCommandSelection ("gamescope-frame-limit", { "60" }) }, { LaunchOptionCapability.GAMESCOPE });
        assert (!missing_wrapper.is_valid);
        assert_code (missing_wrapper, LaunchCommandCompositionDiagnosticCode.MISSING_DEPENDENCY);
        assert_code (missing_wrapper, LaunchCommandCompositionDiagnosticCode.WRAPPER_ARGUMENT_WITHOUT_WRAPPER);

        var wrong_wrapper = compose ({
            new LaunchCommandSelection ("launch-backend", {}, "gamescope"),
            new LaunchCommandSelection ("scopebuddy-frame-limit", { "60" })
        }, { LaunchOptionCapability.GAMESCOPE, LaunchOptionCapability.SCOPEBUDDY });
        assert (!wrong_wrapper.is_valid);
        assert_code (wrong_wrapper, LaunchCommandCompositionDiagnosticCode.WRAPPER_ARGUMENT_OWNED_BY_WRONG_WRAPPER);

        var conflict = compose ({ new LaunchCommandSelection ("renderer-dx11"), new LaunchCommandSelection ("renderer-dx12") });
        assert (!conflict.is_valid);
        assert_code (conflict, LaunchCommandCompositionDiagnosticCode.CONFLICT_GROUP_COLLISION);

        var fsr4 = compose ({ new LaunchCommandSelection ("amd-fsr4"), new LaunchCommandSelection ("amd-fsr4-rdna3") }, { LaunchOptionCapability.AMD });
        assert (!fsr4.is_valid);
        assert_code (fsr4, LaunchCommandCompositionDiagnosticCode.CONFLICT_GROUP_COLLISION);

        var unsafe = compose ({ new LaunchCommandSelection ("vkd3d-log-level", { "%command%" }) }, { LaunchOptionCapability.VKD3D_PROTON });
        assert (!unsafe.is_valid);
        assert_code (unsafe, LaunchCommandCompositionDiagnosticCode.EMBEDDED_COMMAND_PLACEHOLDER);
    }

    private void test_capabilities_and_values () {
        var empty_context = compose ({ new LaunchCommandSelection ("proton-debug-log") });
        assert (!empty_context.is_valid);
        assert_code (empty_context, LaunchCommandCompositionDiagnosticCode.MISSING_REQUIRED_CAPABILITY);

        var invalid_value = compose ({ new LaunchCommandSelection ("vkd3d-log-level", { "invalid" }) }, { LaunchOptionCapability.VKD3D_PROTON });
        assert (!invalid_value.is_valid);
        assert_code (invalid_value, LaunchCommandCompositionDiagnosticCode.UNSUPPORTED_SELECTABLE_VALUE);

        var bad_count = compose ({ new LaunchCommandSelection ("gamescope-resolution", { "1920" }) }, { LaunchOptionCapability.GAMESCOPE });
        assert (!bad_count.is_valid);
        assert_code (bad_count, LaunchCommandCompositionDiagnosticCode.INVALID_VALUE_COUNT);
    }

    private void test_current_custom_proton_options () {
        var game_performance = compose ({ new LaunchCommandSelection ("game-performance") }, {
            LaunchOptionCapability.GAME_PERFORMANCE
        });
        assert (game_performance.is_valid);
        assert (game_performance.launch_line == "game-performance %command%");

        var capture = compose ({
            new LaunchCommandSelection ("mangohud-vulkan"),
            new LaunchCommandSelection ("obs-vkcapture")
        }, { LaunchOptionCapability.MANGOHUD, LaunchOptionCapability.OBS_VKCAPTURE });
        assert (capture.is_valid);
        assert (capture.launch_line == "MANGOHUD=1 OBS_VKCAPTURE=1 %command%");

        var low_latency = compose ({
            new LaunchCommandSelection ("cachyos-vulkan-low-latency"),
            new LaunchCommandSelection ("cachyos-vulkan-reflex"),
            new LaunchCommandSelection ("amd-reflex-allow-other-drivers")
        }, { LaunchOptionCapability.AMD, LaunchOptionCapability.LOW_LATENCY_LAYER });
        assert (low_latency.is_valid);
        assert (low_latency.launch_line == "LOW_LATENCY_LAYER=1 LOW_LATENCY_LAYER_REFLEX=1 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 %command%");

        var mlfg = compose ({
            new LaunchCommandSelection ("amd-fsr4"),
            new LaunchCommandSelection ("amd-mlfg"),
            new LaunchCommandSelection ("amd-mlfg-rdna3-workaround")
        }, {
            LaunchOptionCapability.AMD, LaunchOptionCapability.PROTON_FSR4,
            LaunchOptionCapability.PROTON_MLFG
        });
        assert (mlfg.is_valid);
        assert (mlfg.launch_line == "PROTON_FSR4_UPGRADE=1 PROTON_MLFG_UPGRADE=1 DXIL_SPIRV_CONFIG=wmma_rdna3_workaround %command%");
    }

    private void test_current_option_conflicts () {
        var performance = compose ({
            new LaunchCommandSelection ("gamemode"),
            new LaunchCommandSelection ("game-performance")
        }, { LaunchOptionCapability.GAMEMODE, LaunchOptionCapability.GAME_PERFORMANCE });
        assert (!performance.is_valid);
        assert_code (performance, LaunchCommandCompositionDiagnosticCode.EXPLICIT_OPTION_CONFLICT);

        var overlays = compose ({
            new LaunchCommandSelection ("performance-overlay"),
            new LaunchCommandSelection ("mangohud-vulkan")
        }, { LaunchOptionCapability.MANGOHUD });
        assert (!overlays.is_valid);
        assert_code (overlays, LaunchCommandCompositionDiagnosticCode.EXPLICIT_OPTION_CONFLICT);

        var hdr = compose ({
            new LaunchCommandSelection ("dxvk-hdr"),
            new LaunchCommandSelection ("dxvk-no-hdr")
        }, { LaunchOptionCapability.DXVK, LaunchOptionCapability.PROTON_AUTO_HDR_CONTROL });
        assert (!hdr.is_valid);
        assert_code (hdr, LaunchCommandCompositionDiagnosticCode.EXPLICIT_OPTION_CONFLICT);

        var spoof_fsr = compose ({
            new LaunchCommandSelection ("cachyos-vulkan-low-latency"),
            new LaunchCommandSelection ("cachyos-vulkan-reflex"),
            new LaunchCommandSelection ("amd-reflex-dxgi-spoof"),
            new LaunchCommandSelection ("amd-fsr4")
        }, {
            LaunchOptionCapability.AMD, LaunchOptionCapability.LOW_LATENCY_LAYER,
            LaunchOptionCapability.PROTON_FSR4
        });
        assert (!spoof_fsr.is_valid);
        assert_code (spoof_fsr, LaunchCommandCompositionDiagnosticCode.EXPLICIT_OPTION_CONFLICT);

        var dx12_frame_generation = compose ({
            new LaunchCommandSelection ("amd-fsr4"),
            new LaunchCommandSelection ("amd-mlfg"),
            new LaunchCommandSelection ("cachyos-vkd3d-low-latency")
        }, {
            LaunchOptionCapability.AMD, LaunchOptionCapability.PROTON_FSR4,
            LaunchOptionCapability.PROTON_MLFG,
            LaunchOptionCapability.PROTON_VKD3D_LOW_LATENCY
        });
        assert (!dx12_frame_generation.is_valid);
        assert_code (dx12_frame_generation, LaunchCommandCompositionDiagnosticCode.EXPLICIT_OPTION_CONFLICT);
    }

    private void test_parsed_validation () {
        var parser = new LaunchCommandParser ();
        var diagnostics = new LaunchCommandComposer ().validate_parsed (
            parser.parse ("PROTON_LOG=1 PROTON_LOG=1 %command%"), capabilities ({ LaunchOptionCapability.PROTON })
        );
        var found = false;
        foreach (var diagnostic in diagnostics) if (diagnostic.code == LaunchCommandCompositionDiagnosticCode.DUPLICATE_OPTION_SELECTION) found = true;
        assert (found);
    }

    private int count_placeholder (string value) {
        var count = 0;
        var offset = 0;
        while ((offset = value.index_of ("%command%", offset)) >= 0) { count++; offset += 9; }
        return count;
    }
}
