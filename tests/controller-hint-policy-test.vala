namespace AppTests.ControllerHintPolicyTest {
    using GLib;
    using ProtonPlus.Utils;

    private bool contains (ControllerHintKind[] hints, ControllerHintKind expected) {
        foreach (var hint in hints) {
            if (hint == expected)
                return true;
        }
        return false;
    }

    private ControllerHintKind[] hints_for (ControllerHintControlKind control =
        ControllerHintControlKind.DEFAULT, bool back = false, bool switching = false,
        bool popover = false, bool active = true, bool search = false,
        bool filter = false) {
        return ControllerHintPolicy.get_hints (new ControllerHintContext () {
            controller_mode_active = active,
            control_kind = control,
            can_navigate_back = back,
            can_switch_section = switching,
            can_open_search = search,
            can_open_filter = filter,
            has_popover = popover
        });
    }

    private void test_inactive_has_no_hints () {
        assert (hints_for (ControllerHintControlKind.DEFAULT, false, false, false, false).length == 0);
    }

    private void test_back_context () {
        var root = hints_for ();
        var nested = hints_for (ControllerHintControlKind.DEFAULT, true);
        assert (!contains (root, ControllerHintKind.BACK));
        assert (contains (nested, ControllerHintKind.BACK));
    }

    private void test_popover_precedence () {
        var hints = hints_for (ControllerHintControlKind.DEFAULT, true, true, true);
        assert (contains (hints, ControllerHintKind.SELECT));
        assert (contains (hints, ControllerHintKind.CLOSE));
        assert (!contains (hints, ControllerHintKind.BACK));
        assert (!contains (hints, ControllerHintKind.SWITCH_SECTION));
    }

    private void test_dialog_suppresses_global_hints () {
        var hints = ControllerHintPolicy.get_hints (new ControllerHintContext () {
            controller_mode_active = true,
            has_dialog = true,
            can_navigate_back = true,
            can_switch_section = true
        });
        assert (hints.length == 0);

        var editable = ControllerHintPolicy.get_hints (new ControllerHintContext () {
            controller_mode_active = true,
            has_dialog = true,
            control_kind = ControllerHintControlKind.EDITABLE,
            can_navigate_back = true,
            can_switch_section = true
        });
        assert (editable.length == 1);
        assert (contains (editable, ControllerHintKind.TEXT_INPUT));
        assert (!contains (editable, ControllerHintKind.SELECT));
    }

    private void test_control_hints () {
        var horizontal = hints_for (ControllerHintControlKind.HORIZONTAL_RANGE);
        var vertical = hints_for (ControllerHintControlKind.VERTICAL_RANGE);
        var toggle = hints_for (ControllerHintControlKind.TOGGLE);
        var open = hints_for (ControllerHintControlKind.OPEN);
        var editable = hints_for (ControllerHintControlKind.EDITABLE);
        assert (contains (horizontal, ControllerHintKind.ADJUST_HORIZONTAL));
        assert (contains (vertical, ControllerHintKind.ADJUST_VERTICAL));
        assert (contains (toggle, ControllerHintKind.TOGGLE));
        assert (contains (open, ControllerHintKind.OPEN));
        assert (contains (editable, ControllerHintKind.TEXT_INPUT));
        assert (!contains (editable, ControllerHintKind.SELECT));
    }

    private void test_editable_popover_hints () {
        var hints = hints_for (ControllerHintControlKind.EDITABLE, true, true, true);
        assert (contains (hints, ControllerHintKind.TEXT_INPUT));
        assert (contains (hints, ControllerHintKind.CLOSE));
        assert (!contains (hints, ControllerHintKind.SELECT));
    }

    private void test_editable_back_hint () {
        var hints = hints_for (ControllerHintControlKind.EDITABLE, true);
        assert (contains (hints, ControllerHintKind.TEXT_INPUT));
        assert (contains (hints, ControllerHintKind.BACK));
    }

    private void test_switch_capability () {
        assert (!contains (hints_for (), ControllerHintKind.SWITCH_SECTION));
        assert (contains (hints_for (ControllerHintControlKind.DEFAULT, false, true),
            ControllerHintKind.SWITCH_SECTION));
    }

    private void test_page_shortcut_capabilities () {
        var hints = hints_for (
            ControllerHintControlKind.DEFAULT, false, false, false, true, true, true
        );
        assert (contains (hints, ControllerHintKind.SEARCH));
        assert (contains (hints, ControllerHintKind.FILTER));

        var popover = hints_for (
            ControllerHintControlKind.DEFAULT, false, false, true, true, true, true
        );
        assert (!contains (popover, ControllerHintKind.SEARCH));
        assert (!contains (popover, ControllerHintKind.FILTER));
    }

    private void assert_mapping (SDL.Gamepad.GamepadButtonLabel south,
        SDL.Gamepad.GamepadButtonLabel east, SDL.Gamepad.GamepadButtonLabel west,
        SDL.Gamepad.GamepadButtonLabel north, ControllerPhysicalButtonLabel expected_south,
        ControllerPhysicalButtonLabel expected_east, ControllerPhysicalButtonLabel expected_west,
        ControllerPhysicalButtonLabel expected_north) {
        var facts = ControllerPhysicalLabelResolver.from_sdl (south, east, west, north);
        assert (facts.south == expected_south);
        assert (facts.east == expected_east);
        assert (facts.west == expected_west);
        assert (facts.north == expected_north);

        var south_confirm = ControllerPhysicalLabelResolver.map_prompts (
            facts, ControllerConfirmButton.SOUTH
        );
        var east_confirm = ControllerPhysicalLabelResolver.map_prompts (
            facts, ControllerConfirmButton.EAST
        );
        assert (south_confirm.confirm == expected_south);
        assert (south_confirm.back == expected_east);
        assert (east_confirm.confirm == expected_east);
        assert (east_confirm.back == expected_south);
        assert (facts.south == expected_south);
        assert (facts.east == expected_east);
        assert (facts.west == expected_west);
        assert (facts.north == expected_north);
    }

    private void test_south_confirm_mapping () {
        var facts = ControllerPhysicalLabelResolver.from_sdl (
            SDL.Gamepad.GamepadButtonLabel.A, SDL.Gamepad.GamepadButtonLabel.B,
            SDL.Gamepad.GamepadButtonLabel.X, SDL.Gamepad.GamepadButtonLabel.Y
        );
        var prompts = ControllerPhysicalLabelResolver.map_prompts (
            facts, ControllerConfirmButton.SOUTH
        );
        assert (prompts.confirm == ControllerPhysicalButtonLabel.A);
        assert (prompts.back == ControllerPhysicalButtonLabel.B);
    }

    private void test_east_confirm_mapping () {
        var facts = ControllerPhysicalLabelResolver.from_sdl (
            SDL.Gamepad.GamepadButtonLabel.A, SDL.Gamepad.GamepadButtonLabel.B,
            SDL.Gamepad.GamepadButtonLabel.X, SDL.Gamepad.GamepadButtonLabel.Y
        );
        var prompts = ControllerPhysicalLabelResolver.map_prompts (
            facts, ControllerConfirmButton.EAST
        );
        assert (prompts.confirm == ControllerPhysicalButtonLabel.B);
        assert (prompts.back == ControllerPhysicalButtonLabel.A);
        assert (facts.south == ControllerPhysicalButtonLabel.A);
        assert (facts.east == ControllerPhysicalButtonLabel.B);
    }

    private void test_playstation_mapping () {
        assert_mapping (SDL.Gamepad.GamepadButtonLabel.CROSS,
            SDL.Gamepad.GamepadButtonLabel.CIRCLE,
            SDL.Gamepad.GamepadButtonLabel.SQUARE, SDL.Gamepad.GamepadButtonLabel.TRIANGLE,
            ControllerPhysicalButtonLabel.CROSS, ControllerPhysicalButtonLabel.CIRCLE,
            ControllerPhysicalButtonLabel.SQUARE, ControllerPhysicalButtonLabel.TRIANGLE);
    }

    private void test_nintendo_mapping () {
        assert_mapping (SDL.Gamepad.GamepadButtonLabel.B, SDL.Gamepad.GamepadButtonLabel.A,
            SDL.Gamepad.GamepadButtonLabel.Y, SDL.Gamepad.GamepadButtonLabel.X,
            ControllerPhysicalButtonLabel.B, ControllerPhysicalButtonLabel.A,
            ControllerPhysicalButtonLabel.Y, ControllerPhysicalButtonLabel.X);
    }

    private void test_unknown_fallback () {
        assert_mapping (SDL.Gamepad.GamepadButtonLabel.UNKNOWN,
            SDL.Gamepad.GamepadButtonLabel.UNKNOWN,
            SDL.Gamepad.GamepadButtonLabel.UNKNOWN, SDL.Gamepad.GamepadButtonLabel.UNKNOWN,
            ControllerPhysicalButtonLabel.BOTTOM, ControllerPhysicalButtonLabel.RIGHT,
            ControllerPhysicalButtonLabel.LEFT, ControllerPhysicalButtonLabel.TOP);
    }

    public void register_tests () {
        Test.add_func ("/controller-hints/inactive", test_inactive_has_no_hints);
        Test.add_func ("/controller-hints/back-context", test_back_context);
        Test.add_func ("/controller-hints/popover-precedence", test_popover_precedence);
        Test.add_func ("/controller-hints/dialog-suppresses-global", test_dialog_suppresses_global_hints);
        Test.add_func ("/controller-hints/control-kinds", test_control_hints);
        Test.add_func ("/controller-hints/editable-popover", test_editable_popover_hints);
        Test.add_func ("/controller-hints/editable-back", test_editable_back_hint);
        Test.add_func ("/controller-hints/switch-capability", test_switch_capability);
        Test.add_func ("/controller-hints/page-shortcuts", test_page_shortcut_capabilities);
        Test.add_func ("/controller-hints/south-confirm", test_south_confirm_mapping);
        Test.add_func ("/controller-hints/east-confirm", test_east_confirm_mapping);
        Test.add_func ("/controller-hints/playstation", test_playstation_mapping);
        Test.add_func ("/controller-hints/nintendo", test_nintendo_mapping);
        Test.add_func ("/controller-hints/unknown-fallback", test_unknown_fallback);
    }
}
