namespace AppTests.LaunchCommandComposerTest {
    using GLib;
    using ProtonPlus.Widgets.Games.LaunchOptionsEditor;

    public void register_tests () {
        Test.add_func ("/launch-command-composer/environment-and-shell-values", test_environment_and_shell_values);
        Test.add_func ("/launch-command-composer/arguments-boundary", test_arguments_boundary);
        Test.add_func ("/launch-command-composer/wrappers-and-composite", test_wrappers_and_composite);
        Test.add_func ("/launch-command-composer/invalid-combinations", test_invalid_combinations);
        Test.add_func ("/launch-command-composer/capabilities-and-values", test_capabilities_and_values);
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
