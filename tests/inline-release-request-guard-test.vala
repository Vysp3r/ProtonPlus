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

    private void test_presentation_keeps_cached_content_during_refresh () {
        var presentation = InlineReleasePresentation.evaluate (
            InlineReleaseRequestKind.REFRESH, true, true, false
        );
        assert (presentation.view == InlineReleaseView.LIST);
        assert (!presentation.show_error_banner);

        presentation = InlineReleasePresentation.evaluate (
            InlineReleaseRequestKind.REFRESH, false, true, true
        );
        assert (presentation.view == InlineReleaseView.LIST);
        assert (presentation.show_error_banner);

        presentation = InlineReleasePresentation.evaluate (
            InlineReleaseRequestKind.REFRESH, false, true, true, true
        );
        assert (presentation.view == InlineReleaseView.EMPTY);
        assert (presentation.show_error_banner);
    }

    private void test_presentation_initial_loading_empty_and_error () {
        var presentation = InlineReleasePresentation.evaluate (
            InlineReleaseRequestKind.INITIAL, true, false, false
        );
        assert (presentation.view == InlineReleaseView.LOADING);

        presentation = InlineReleasePresentation.evaluate (
            InlineReleaseRequestKind.INITIAL, false, false, false
        );
        assert (presentation.view == InlineReleaseView.EMPTY);

        presentation = InlineReleasePresentation.evaluate (
            InlineReleaseRequestKind.INITIAL, false, false, true
        );
        assert (presentation.view == InlineReleaseView.ERROR);
        assert (!presentation.show_error_banner);

        presentation = InlineReleasePresentation.evaluate (
            InlineReleaseRequestKind.INITIAL, false, true, false
        );
        assert (presentation.view == InlineReleaseView.LIST);
    }

    private void test_presentation_load_more_retry_keeps_content () {
        var presentation = InlineReleasePresentation.evaluate (
            InlineReleaseRequestKind.LOAD_MORE, true, true, false
        );
        assert (presentation.view == InlineReleaseView.LIST);

        presentation = InlineReleasePresentation.evaluate (
            InlineReleaseRequestKind.LOAD_MORE, false, true, true
        );
        assert (presentation.view == InlineReleaseView.LIST);
        assert (presentation.show_error_banner);
    }

    private void test_empty_reason_is_specific () {
        assert (InlineReleasePresentation.empty_reason (
            "proton", Filter.ALL, true
        ) == InlineReleaseEmptyReason.SEARCH);
        assert (InlineReleasePresentation.empty_reason (
            "", Filter.INSTALLED, true
        ) == InlineReleaseEmptyReason.FILTER);
        assert (InlineReleasePresentation.empty_reason (
            "", Filter.ALL, false
        ) == InlineReleaseEmptyReason.UNAVAILABLE);
        assert (InlineReleasePresentation.empty_reason (
            "", Filter.ALL, true
        ) == InlineReleaseEmptyReason.CATALOG);
    }

    private void test_tool_actions_follow_build_selector () {
        assert (
            InlineReleasePresentation.actions_placement (false) ==
            InlineReleaseActionsPlacement.HEADER
        );
        assert (
            InlineReleasePresentation.actions_placement (true) ==
            InlineReleaseActionsPlacement.TOOLBAR
        );
    }

    public void register_tests () {
        Test.add_func ("/inline-release-request/select-and-clear", test_select_and_clear);
        Test.add_func ("/inline-release-request/new-selection-invalidates-previous", test_new_selection_invalidates_previous_completion);
        Test.add_func ("/inline-release-request/reselection-uses-new-generation", test_reselection_uses_new_generation);
        Test.add_func ("/inline-release-request/single-expansion", test_single_expansion_transition);
        Test.add_func ("/inline-release-request/filter-loaded-expansion", test_filter_uses_only_loaded_expansion_matches);
        Test.add_func ("/inline-release-request/navigation-restore", test_navigation_restore_is_owner_and_release_scoped);
        Test.add_func ("/inline-release-request/presentation-cached-refresh", test_presentation_keeps_cached_content_during_refresh);
        Test.add_func ("/inline-release-request/presentation-initial-states", test_presentation_initial_loading_empty_and_error);
        Test.add_func ("/inline-release-request/presentation-load-more-retry", test_presentation_load_more_retry_keeps_content);
        Test.add_func ("/inline-release-request/empty-reason", test_empty_reason_is_specific);
        Test.add_func (
            "/inline-release-request/tool-actions-placement",
            test_tool_actions_follow_build_selector
        );
    }
}
