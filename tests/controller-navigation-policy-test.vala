namespace AppTests.ControllerNavigationPolicyTest {
    using GLib;
    using ProtonPlus.Utils;

    private class FakeNavigationHost : Object, ControllerNavigationHost {
        public string page_id;
        public int back_calls = 0;
        public int switch_calls = 0;
        public Gee.HashMap<string, string> parents = new Gee.HashMap<string, string> ();
        public string[] switch_pages = {};

        public FakeNavigationHost (string page_id) {
            this.page_id = page_id;
        }

        public string get_controller_page_id () {
            return page_id;
        }

        public Object? get_controller_page_root () {
            return null;
        }

        public Object? get_controller_initial_focus () {
            return null;
        }

        public bool controller_navigate_back () {
            back_calls++;
            if (!parents.has_key (page_id))
                return false;
            page_id = parents[page_id];
            return true;
        }

        public bool controller_can_navigate_back () {
            return parents.has_key (page_id);
        }

        public bool controller_can_switch_page () {
            return switch_pages.length >= 2;
        }

        public bool controller_switch_page (int delta) {
            switch_calls++;
            if (switch_pages.length < 2)
                return false;

            int current = 0;
            for (int i = 0; i < switch_pages.length; i++) {
                if (switch_pages[i] == page_id) {
                    current = i;
                    break;
                }
            }
            int next = ((current + delta) % switch_pages.length + switch_pages.length) % switch_pages.length;
            page_id = switch_pages[next];
            return next != current;
        }
    }

    private void test_modal_back_precedence () {
        var policy = new ControllerNavigationPolicy ();
        var host = new FakeNavigationHost ("tools:release");
        host.parents["tools:release"] = "tools:releases";

        assert (policy.navigate_back (true, host) == ControllerBackAction.DISMISS_SURFACE);
        assert (host.back_calls == 0);
        assert (host.page_id == "tools:release");
    }

    private void test_tools_back_transitions () {
        var policy = new ControllerNavigationPolicy ();
        var host = new FakeNavigationHost ("tools:migrate");
        host.parents["tools:migrate"] = "tools:release";
        host.parents["tools:release"] = "tools:releases";
        host.parents["tools:releases"] = "tools:groups";

        assert (policy.navigate_back (false, host) == ControllerBackAction.NAVIGATE_APPLICATION);
        assert (host.page_id == "tools:release");
        assert (policy.navigate_back (false, host) == ControllerBackAction.NAVIGATE_APPLICATION);
        assert (host.page_id == "tools:releases");
        assert (policy.navigate_back (false, host) == ControllerBackAction.NAVIGATE_APPLICATION);
        assert (host.page_id == "tools:groups");
        assert (policy.navigate_back (false, host) == ControllerBackAction.NONE);
        assert (host.page_id == "tools:groups");
    }

    private void test_games_back_and_root_noop () {
        var policy = new ControllerNavigationPolicy ();
        var host = new FakeNavigationHost ("games:mass-edit");
        host.parents["games:mass-edit"] = "games:list";

        assert (policy.navigate_back (false, host) == ControllerBackAction.NAVIGATE_APPLICATION);
        assert (host.page_id == "games:list");
        assert (policy.navigate_back (false, host) == ControllerBackAction.NONE);
        assert (host.back_calls == 2);
    }

    private void test_application_back_never_closes () {
        var policy = new ControllerNavigationPolicy ();
        var host = new FakeNavigationHost ("tools:groups");

        var action = policy.navigate_back (false, host);
        assert (action == ControllerBackAction.NONE);
        assert (host.page_id == "tools:groups");
        assert (host.back_calls == 1);
    }

    private void test_focus_history_isolated_by_page () {
        var policy = new ControllerNavigationPolicy ();
        var tools_target = new Object ();
        var games_target = new Object ();

        policy.remember_focus ("tools:groups", tools_target);
        policy.remember_focus ("games:list", games_target);

        assert (policy.recall_focus ("tools:groups") == tools_target);
        assert (policy.recall_focus ("games:list") == games_target);
        assert (policy.recall_focus ("tools:release") == null);
    }

    private void test_invalid_remembered_target_uses_fallback () {
        assert (ControllerNavigationPolicy.choose_focus_target (true, true) ==
            ControllerFocusTargetChoice.REMEMBERED);
        assert (ControllerNavigationPolicy.choose_focus_target (false, true) ==
            ControllerFocusTargetChoice.INITIAL);
        assert (ControllerNavigationPolicy.choose_focus_target (false, false) ==
            ControllerFocusTargetChoice.TRAVERSE);
    }

    private void test_switch_restores_correct_page () {
        var policy = new ControllerNavigationPolicy ();
        var host = new FakeNavigationHost ("tools:groups");
        host.switch_pages = { "tools:groups", "games:list" };
        var tools_target = new Object ();
        var games_target = new Object ();
        policy.remember_focus ("tools:groups", tools_target);
        policy.remember_focus ("games:list", games_target);

        assert (policy.switch_page (host, 1));
        var games_request = policy.begin_restore (host.get_controller_page_id (), 4);
        assert (games_request.page_id == "games:list");
        assert (policy.recall_focus (games_request.page_id) == games_target);

        assert (policy.switch_page (host, -1));
        var tools_request = policy.begin_restore (host.get_controller_page_id (), 4);
        assert (tools_request.page_id == "tools:groups");
        assert (policy.recall_focus (tools_request.page_id) == tools_target);
    }

    private void test_stale_restore_is_rejected () {
        var policy = new ControllerNavigationPolicy ();
        var stale_page = policy.begin_restore ("tools:groups", 2);
        var current_page = policy.begin_restore ("games:list", 2);

        assert (!policy.can_apply_restore (stale_page, "tools:groups", 2));
        assert (!policy.can_apply_restore (current_page, "tools:groups", 2));
        assert (!policy.can_apply_restore (current_page, "games:list", 3));
        assert (policy.can_apply_restore (current_page, "games:list", 2));

        policy.invalidate_restores ();
        assert (!policy.can_apply_restore (current_page, "games:list", 2));
    }

    public void register_tests () {
        Test.add_func ("/controller-navigation/modal-precedence", test_modal_back_precedence);
        Test.add_func ("/controller-navigation/tools-back", test_tools_back_transitions);
        Test.add_func ("/controller-navigation/games-back-root-noop", test_games_back_and_root_noop);
        Test.add_func ("/controller-navigation/application-back-never-closes", test_application_back_never_closes);
        Test.add_func ("/controller-navigation/focus-history", test_focus_history_isolated_by_page);
        Test.add_func ("/controller-navigation/focus-fallback", test_invalid_remembered_target_uses_fallback);
        Test.add_func ("/controller-navigation/switch-restore", test_switch_restores_correct_page);
        Test.add_func ("/controller-navigation/stale-restore", test_stale_restore_is_rejected);
    }
}
