namespace AppTests.InlineReleaseRequestGuardTest {
    using GLib;
    using ProtonPlus.Widgets.Tools;

    private void test_select_and_clear () {
        var guard = new InlineReleaseRequestGuard ();
        var tool = new Object ();

        var generation = guard.select (tool);
        assert (guard.is_current (tool, generation));

        guard.clear ();
        assert (!guard.is_current (tool, generation));
    }

    private void test_new_selection_invalidates_previous_completion () {
        var guard = new InlineReleaseRequestGuard ();
        var tool_a = new Object ();
        var tool_b = new Object ();

        var generation_a = guard.select (tool_a);
        var generation_b = guard.select (tool_b);

        assert (!guard.is_current (tool_a, generation_a));
        assert (guard.is_current (tool_b, generation_b));
    }

    private void test_reselection_uses_new_generation () {
        var guard = new InlineReleaseRequestGuard ();
        var tool = new Object ();

        var first_generation = guard.select (tool);
        guard.clear ();
        var second_generation = guard.select (tool);

        assert (first_generation != second_generation);
        assert (!guard.is_current (tool, first_generation));
        assert (guard.is_current (tool, second_generation));
    }

    private void test_single_expansion_transition () {
        var state = new InlineReleaseInteractionState ();
        var tool_a = new Object ();
        var tool_b = new Object ();

        assert (state.expand (tool_a) == InlineExpansionTransition.EXPAND);
        assert (state.is_expanded (tool_a));
        assert (state.expand (tool_a) == InlineExpansionTransition.NONE);
        assert (state.expand (tool_b) == InlineExpansionTransition.SWITCH);
        assert (!state.is_expanded (tool_a));
        assert (state.is_expanded (tool_b));
        assert (state.collapse (tool_a) == InlineExpansionTransition.NONE);
        assert (state.collapse (tool_b) == InlineExpansionTransition.COLLAPSE);
        assert (state.expanded_owner == null);
    }

    private void test_filter_uses_only_loaded_expansion_matches () {
        assert (InlineReleaseInteractionState.matches_filter ("proton", "GE-Proton", false, false));
        assert (InlineReleaseInteractionState.matches_filter ("  ", "GE-Proton", false, false));
        assert (InlineReleaseInteractionState.matches_filter ("9-25", "GE-Proton", true, true));
        assert (!InlineReleaseInteractionState.matches_filter ("9-25", "GE-Proton", false, true));
        assert (!InlineReleaseInteractionState.matches_filter ("wine", "GE-Proton", true, false));
    }

    private void test_navigation_restore_is_owner_and_release_scoped () {
        var state = new InlineReleaseInteractionState ();
        var tool_a = new Object ();
        var tool_b = new Object ();
        var release_a = new Object ();
        var release_b = new Object ();
        double position;

        state.remember_navigation (tool_a, release_a, 128.5);
        assert (state.restore_navigation (tool_a, release_a, out position));
        assert (position == 128.5);
        assert (!state.restore_navigation (tool_b, release_a, out position));
        assert (!state.restore_navigation (tool_a, release_b, out position));

        state.clear_navigation (tool_b);
        assert (state.restore_navigation (tool_a, release_a, out position));
        state.clear_navigation (tool_a);
        assert (!state.restore_navigation (tool_a, release_a, out position));
    }

    public void register_tests () {
        Test.add_func ("/inline-release-request/select-and-clear", test_select_and_clear);
        Test.add_func ("/inline-release-request/new-selection-invalidates-previous", test_new_selection_invalidates_previous_completion);
        Test.add_func ("/inline-release-request/reselection-uses-new-generation", test_reselection_uses_new_generation);
        Test.add_func ("/inline-release-request/single-expansion", test_single_expansion_transition);
        Test.add_func ("/inline-release-request/filter-loaded-expansion", test_filter_uses_only_loaded_expansion_matches);
        Test.add_func ("/inline-release-request/navigation-restore", test_navigation_restore_is_owner_and_release_scoped);
    }
}
