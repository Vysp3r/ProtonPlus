namespace AppTests.LaunchCommandTest {
    using GLib;
    using ProtonPlus.Widgets.Games.LaunchOptionsEditor;

    public void register_tests () {
        Test.add_func ("/launch-command/environment-only", test_environment_only);
        Test.add_func ("/launch-command/multiple-environments", test_multiple_environments);
        Test.add_func ("/launch-command/game-arguments-only", test_game_arguments_only);
        Test.add_func ("/launch-command/arguments-preserve-placeholder", test_arguments_preserve_placeholder);
        Test.add_func ("/launch-command/environment-and-game-arguments", test_environment_and_game_arguments);
        Test.add_func ("/launch-command/prefix-wrappers", test_prefix_wrappers);
        Test.add_func ("/launch-command/delimited-wrapper", test_delimited_wrapper);
        Test.add_func ("/launch-command/nested-wrappers", test_nested_wrappers);
        Test.add_func ("/launch-command/environment-nested-wrappers-and-argument", test_environment_nested_wrappers_and_argument);
        Test.add_func ("/launch-command/scopebuddy-shaped-plan", test_scopebuddy_shaped_plan);
        Test.add_func ("/launch-command/shell-safe-segments-remain-raw", test_shell_safe_segments_remain_raw);
        Test.add_func ("/launch-command/validation", test_validation);
        Test.add_func ("/launch-command/wrapper-priority-order", test_wrapper_priority_order);
        Test.add_func ("/launch-command/equal-priorities-are-rejected", test_equal_priorities_are_rejected);
    }

    private LaunchCommandBuildResult build (LaunchCommandPlan plan) {
        return new LaunchCommandBuilder ().build (plan);
    }

    private void assert_line (LaunchCommandPlan plan, string expected) {
        var result = build (plan);
        assert (result.is_valid);
        assert (result.errors.size == 0);
        assert (result.launch_line == expected);
        assert (count_placeholder (result.segments) <= 1);
    }

    private int count_placeholder (Gee.List<string> segments) {
        var count = 0;
        foreach (var segment in segments) {
            if (segment == "%command%")
                count++;
        }
        return count;
    }

    private void test_environment_only () {
        assert_line (new LaunchCommandPlan ({ new LaunchEnvironmentAssignment ("PROTON_LOG", "PROTON_LOG=1") }), "PROTON_LOG=1 %command%");
    }

    private void test_multiple_environments () {
        assert_line (new LaunchCommandPlan ({
            new LaunchEnvironmentAssignment ("PROTON_LOG", "PROTON_LOG=1"),
            new LaunchEnvironmentAssignment ("DXVK_LOG_LEVEL", "DXVK_LOG_LEVEL=none")
        }), "PROTON_LOG=1 DXVK_LOG_LEVEL=none %command%");
    }

    private void test_game_arguments_only () {
        assert_line (new LaunchCommandPlan ({}, {}, { "-console" }), "-console");
    }

    private void test_arguments_preserve_placeholder () {
        assert_line (new LaunchCommandPlan ({}, {}, { "-console" }, true), "%command% -console");
    }

    private void test_environment_and_game_arguments () {
        assert_line (new LaunchCommandPlan ({
            new LaunchEnvironmentAssignment ("PROTON_LOG", "PROTON_LOG=1"),
            new LaunchEnvironmentAssignment ("DXVK_LOG_LEVEL", "DXVK_LOG_LEVEL=none")
        }, {}, { "-dx11", "-skip-launcher" }), "PROTON_LOG=1 DXVK_LOG_LEVEL=none %command% -dx11 -skip-launcher");
    }

    private void test_prefix_wrappers () {
        assert_line (new LaunchCommandPlan ({}, {
            new LaunchWrapperInvocation ("mangohud", { "mangohud" }, {}, null, 10),
            new LaunchWrapperInvocation ("gamemode", { "gamemoderun" }, {}, null, 20)
        }), "mangohud gamemoderun %command%");
    }

    private void test_delimited_wrapper () {
        assert_line (new LaunchCommandPlan ({}, {
            new LaunchWrapperInvocation ("gamescope", { "gamescope" }, { "-f", "-r", "60" }, "--", 10)
        }), "gamescope -f -r 60 -- %command%");
    }

    private void test_nested_wrappers () {
        assert_line (new LaunchCommandPlan ({}, {
            new LaunchWrapperInvocation ("gamescope", { "gamescope" }, { "-f" }, "--", 20),
            new LaunchWrapperInvocation ("gamemode", { "gamemoderun" }, {}, null, 10)
        }), "gamemoderun gamescope -f -- %command%");
    }

    private void test_environment_nested_wrappers_and_argument () {
        assert_line (new LaunchCommandPlan ({
            new LaunchEnvironmentAssignment ("PROTON_LOG", "PROTON_LOG=1")
        }, {
            new LaunchWrapperInvocation ("gamescope", { "gamescope" }, { "-f" }, "--", 20),
            new LaunchWrapperInvocation ("gamemode", { "gamemoderun" }, {}, null, 10)
        }, { "-skip-launcher" }), "PROTON_LOG=1 gamemoderun gamescope -f -- %command% -skip-launcher");
    }

    private void test_scopebuddy_shaped_plan () {
        assert_line (new LaunchCommandPlan ({
            new LaunchEnvironmentAssignment ("SCB_AUTO_RES", "SCB_AUTO_RES=1"),
            new LaunchEnvironmentAssignment ("SCB_AUTO_HDR", "SCB_AUTO_HDR=1")
        }, {
            new LaunchWrapperInvocation ("scb", { "scb" }, { "-f", "-r", "60" }, "--", 10)
        }, { "-skip-launcher" }), "SCB_AUTO_RES=1 SCB_AUTO_HDR=1 scb -f -r 60 -- %command% -skip-launcher");
    }

    private void test_shell_safe_segments_remain_raw () {
        assert_line (new LaunchCommandPlan ({
            new LaunchEnvironmentAssignment ("GAME_NAME", "GAME_NAME=\"hello world\"")
        }, {
            new LaunchWrapperInvocation ("wrapper", { "wrapper" }, { "--display=\"HDMI A-1\"" }, "--", 10)
        }, { "--title=\"quoted game argument\"" }), "GAME_NAME=\"hello world\" wrapper --display=\"HDMI A-1\" -- %command% --title=\"quoted game argument\"");
    }

    private void test_validation () {
        var duplicate = build (new LaunchCommandPlan ({
            new LaunchEnvironmentAssignment ("PROTON_LOG", "PROTON_LOG=1"),
            new LaunchEnvironmentAssignment ("PROTON_LOG", "PROTON_LOG=0")
        }));
        assert (!duplicate.is_valid);
        assert (duplicate.errors.size > 0);

        var placeholder_in_environment = build (new LaunchCommandPlan ({
            new LaunchEnvironmentAssignment ("PROTON_LOG", "PROTON_LOG=%command%")
        }));
        assert (!placeholder_in_environment.is_valid);

        var placeholder_in_wrapper_argument = build (new LaunchCommandPlan ({}, {
            new LaunchWrapperInvocation ("wrapper", { "wrapper" }, { "%command%" }, null, 10)
        }));
        assert (!placeholder_in_wrapper_argument.is_valid);

        var placeholder_in_wrapper_executable = build (new LaunchCommandPlan ({}, {
            new LaunchWrapperInvocation ("wrapper", { "%command%" }, {}, null, 10)
        }));
        assert (!placeholder_in_wrapper_executable.is_valid);

        var placeholder_in_game_argument = build (new LaunchCommandPlan ({}, {}, { "%command%" }));
        assert (!placeholder_in_game_argument.is_valid);

        var empty_wrapper = build (new LaunchCommandPlan ({}, {
            new LaunchWrapperInvocation ("empty", {})
        }));
        assert (!empty_wrapper.is_valid);
        assert (empty_wrapper.launch_line == "");
        assert (empty_wrapper.segments.size == 0);

        var empty_executable_token = build (new LaunchCommandPlan ({}, {
            new LaunchWrapperInvocation ("empty-token", { " " })
        }));
        assert (!empty_executable_token.is_valid);
    }

    private void test_wrapper_priority_order () {
        assert_line (new LaunchCommandPlan ({}, {
            new LaunchWrapperInvocation ("inner", { "inner" }, {}, null, 30),
            new LaunchWrapperInvocation ("outer", { "outer" }, {}, null, 10)
        }), "outer inner %command%");
    }

    private void test_equal_priorities_are_rejected () {
        var result = build (new LaunchCommandPlan ({}, {
            new LaunchWrapperInvocation ("first", { "first" }, {}, null, 10),
            new LaunchWrapperInvocation ("second", { "second" }, {}, null, 10)
        }));
        assert (!result.is_valid);
        assert (result.errors.size > 0);
    }
}
