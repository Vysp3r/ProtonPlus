namespace AppTests.ControllerSurfacePolicyTest {
    using GLib;
    using ProtonPlus.Utils;

    private class FakeHost : Object {
        public bool is_window;
        public FakeHost? root;

        public FakeHost (bool is_window = false, FakeHost? root = null) {
            this.is_window = is_window;
            this.root = root;
        }
    }

    private class FakeHostAdapter : Object, ControllerHostAdapter {
        public bool is_controller_window (Object candidate) {
            return ((FakeHost) candidate).is_window;
        }

        public Object? get_root (Object candidate) {
            return ((FakeHost) candidate).root;
        }
    }

    private void test_resolves_window_from_child_root () {
        var window = new FakeHost (true);
        var child = new FakeHost (false, window);
        var adapter = new FakeHostAdapter ();

        assert (ControllerWindowResolver.resolve (child, adapter) == window);
        assert (ControllerWindowResolver.resolve (window, adapter) == window);
        assert (ControllerWindowResolver.resolve (new FakeHost (), adapter) == null);
        assert (ControllerWindowResolver.resolve (null, adapter) == null);
    }

    private void test_popover_registration_waits_for_mapping () {
        assert (!ControllerSurfacePolicy.can_register_popover (false, false));
        assert (!ControllerSurfacePolicy.can_register_popover (true, false));
        assert (!ControllerSurfacePolicy.can_register_popover (false, true));
        assert (ControllerSurfacePolicy.can_register_popover (true, true));
    }

    private void test_scroll_focus_requires_overflow () {
        assert (!ControllerSurfacePolicy.scroll_container_needs_focus (0.0, 0.0));
        assert (!ControllerSurfacePolicy.scroll_container_needs_focus (100.0, 100.0));
        assert (!ControllerSurfacePolicy.scroll_container_needs_focus (100.5, 100.0));
        assert (ControllerSurfacePolicy.scroll_container_needs_focus (101.0, 100.0));
    }

    private void test_repeated_registration_moves_without_duplicates () {
        var window = new ControllerSurface (ControllerSurfaceKind.WINDOW);
        var dialog = new ControllerSurface (ControllerSurfaceKind.DIALOG);
        var other_dialog = new ControllerSurface (ControllerSurfaceKind.DIALOG);
        var policy = new ControllerSurfacePolicy (window);

        policy.present (dialog);
        policy.present (other_dialog);
        policy.present (dialog);

        assert (policy.size == 3);
        assert (policy.active_surface == dialog);
    }

    private void test_nested_surface_order_and_closing () {
        var window = new ControllerSurface (ControllerSurfaceKind.WINDOW);
        var dialog = new ControllerSurface (ControllerSurfaceKind.DIALOG);
        var popover = new ControllerSurface (ControllerSurfaceKind.POPOVER);
        var policy = new ControllerSurfacePolicy (window);

        policy.present (dialog);
        policy.present (popover);
        assert (policy.active_surface == popover);
        assert (policy.dismissable_surface == popover);

        var popover_removal = policy.remove (popover);
        assert (popover_removal.was_active);
        assert (popover_removal.active_surface == dialog);
        assert (policy.dismissable_surface == dialog);

        var dialog_removal = policy.remove (dialog);
        assert (dialog_removal.was_active);
        assert (dialog_removal.active_surface == window);
        assert (policy.dismissable_surface == null);
    }

    private void test_removing_non_top_surface_preserves_owner () {
        var window = new ControllerSurface (ControllerSurfaceKind.WINDOW);
        var dialog = new ControllerSurface (ControllerSurfaceKind.DIALOG);
        var popover = new ControllerSurface (ControllerSurfaceKind.POPOVER);
        var policy = new ControllerSurfacePolicy (window);
        policy.present (dialog);
        policy.present (popover);

        var removal = policy.remove (dialog);
        assert (!removal.was_active);
        assert (removal.active_surface == popover);
        assert (policy.active_surface == popover);
    }

    private void test_opener_restoration_requires_active_valid_popover () {
        var window = new ControllerSurface (ControllerSurfaceKind.WINDOW);
        var first = new ControllerSurface (ControllerSurfaceKind.POPOVER);
        var newer = new ControllerSurface (ControllerSurfaceKind.POPOVER);
        var policy = new ControllerSurfacePolicy (window);

        first.opener_valid = true;
        policy.present (first);
        policy.present (newer);
        assert (!policy.remove (first).restore_opener);

        newer.opener_valid = false;
        assert (!policy.remove (newer).restore_opener);

        first.opener_valid = true;
        policy.present (first);
        assert (policy.remove (first).restore_opener);
    }

    public void register_tests () {
        Test.add_func ("/controller-surfaces/window-resolution", test_resolves_window_from_child_root);
        Test.add_func ("/controller-surfaces/popover-registration-ready", test_popover_registration_waits_for_mapping);
        Test.add_func ("/controller-surfaces/scroll-focus-overflow", test_scroll_focus_requires_overflow);
        Test.add_func ("/controller-surfaces/repeated-registration", test_repeated_registration_moves_without_duplicates);
        Test.add_func ("/controller-surfaces/nested-order-and-closing", test_nested_surface_order_and_closing);
        Test.add_func ("/controller-surfaces/non-top-removal", test_removing_non_top_surface_preserves_owner);
        Test.add_func ("/controller-surfaces/opener-restoration", test_opener_restoration_requires_active_valid_popover);
    }
}
