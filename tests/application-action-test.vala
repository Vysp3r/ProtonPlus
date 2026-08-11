namespace AppTests.ApplicationActionTest {
    public void register_tests () {
        Test.add_func (
            "/application/actions-and-accelerators",
            test_actions_and_accelerators
        );
        Test.add_func (
            "/application/shortcut-reference-actions",
            test_shortcut_reference_actions
        );
    }

    private void test_actions_and_accelerators () {
        var application = new ProtonPlus.Widgets.Application ();

        assert (application.lookup_action ("preferences") != null);
        assert (application.lookup_action ("help") != null);
        assert (application.lookup_action ("quit") != null);

        var actions = new string[] {
            "app.preferences",
            "app.help",
            "app.quit",
            "win.search",
            "win.show-help-overlay",
            "win.navigate-back"
        };
        var expected = new string[] {
            "<Control>comma",
            "F1",
            "<Control>q",
            "<Control>f",
            "<Control>question",
            "<Alt>Left"
        };
        var accelerators = new Gee.HashSet<string> ();

        for (var i = 0; i < actions.length; i++) {
            var assigned = application.get_accels_for_action (actions[i]);
            assert_cmpuint (assigned.length, CompareOperator.EQ, 1);
            assert_cmpstr (assigned[0], CompareOperator.EQ, expected[i]);
            assert (!accelerators.contains (assigned[0]));
            accelerators.add (assigned[0]);
        }
    }

    private void test_shortcut_reference_actions () {
        try {
            var data = resources_lookup_data (
                "/com/vysp3r/ProtonPlus/gtk/help-overlay.ui",
                ResourceLookupFlags.NONE
            );
            var contents = ProtonPlus.Utils.Parser.data_to_string (
                data.get_data ()
            );
            foreach (var action in new string[] {
                "app.preferences",
                "app.help",
                "app.quit",
                "win.search",
                "win.show-help-overlay",
                "win.navigate-back"
            }) {
                assert (contents.contains (action));
            }
        } catch (Error e) {
            assert_not_reached ();
        }
    }
}
