namespace AppTests.SteamRestartPresentationTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Widgets.Main;

    private SteamRestartTarget native_target (string suffix = "native") {
        return SteamRestartTarget.for_native (Path.build_filename ("/tmp", "protonplus-presentation-" + suffix));
    }

    private SteamRestartPendingRecord record (SteamRestartTarget target, string key, SteamRestartRequirement requirement = SteamRestartRequirement.CONSERVATIVE) {
        var receipt = new SteamChangeReceipt (target, SteamChangeKind.GAME_COMPATIBILITY_TOOL_CHANGED, requirement, key, null, null, "2026-07-29T12:00:00Z");
        return new SteamRestartPendingRecord (receipt, receipt.changed_at, receipt.changed_at, 1, null);
    }

    private class RecordingNotificationSender : Object, SteamRestartNotificationSender {
        public Gee.List<string> messages = new Gee.ArrayList<string> ();
        public bool fail = false;

        public void send_restart_required (string message) throws Error {
            messages.add (message);
            if (fail)
                throw new SteamRestartNotificationError.DELIVERY_FAILED ("fixture delivery failure");
        }
    }

    private Gee.List<SteamRestartPendingRecord> records (params SteamRestartPendingRecord[] values) {
        var result = new Gee.ArrayList<SteamRestartPendingRecord> ();
        foreach (var value in values)
            result.add (value);
        return result;
    }

    private void test_banner_states_and_grouping () {
        assert (!SteamRestartPresentation.banner_state (records ()).visible);
        var native = native_target (); var one = records (record (native, "one"));
        assert (SteamRestartPresentation.banner_state (one).visible);
        assert (SteamRestartPresentation.banner_state (one).title.contains ("1"));
        var flatpak = SteamRestartTarget.for_flatpak ("/tmp/protonplus-presentation-flatpak");
        var many = records (record (native, "one"), record (native, "two", SteamRestartRequirement.DOCUMENTED), record (flatpak, "three"));
        var summaries = SteamRestartPresentation.summarize (many);
        assert (summaries.size == 2 && summaries[0].target.display_name == "Steam" && summaries[1].target.display_name == "Steam (Flatpak)");
        assert (SteamRestartPresentation.banner_state (many).multiple_targets);
        assert (SteamRestartPresentation.requirement_explanation (summaries[0]).contains ("compatibility tool"));
    }

    private void test_toast_policy () {
        var policy = new SteamRestartToastPolicy ();
        assert (policy.update (0, 1, true) == null);
        assert (policy.update (0, 1, false) != null);
        assert (policy.update (1, 1, false) == null);
        assert (policy.update (1, 2, false) != null);
        assert (policy.update (2, 3, false) == null);
        assert (policy.update (3, 0, false) == null);
        assert (policy.update (0, 1, false) != null);
    }

    private void test_failure_messages_are_actionable () {
        var flatpak = SteamRestartPresentation.failure_message (SteamRestartFailureReason.GRACEFUL_SHUTDOWN_UNSUPPORTED);
        assert (flatpak.heading == "Close Steam manually" && flatpak.body.contains ("cannot safely close") && !flatpak.body.contains ("kill"));
        var blocker = SteamRestartPresentation.failure_message (SteamRestartFailureReason.GAME_OR_COMPATIBILITY_PROCESS);
        assert (blocker.body.contains ("game"));
        var gaming_mode = SteamRestartPresentation.failure_message (SteamRestartFailureReason.STEAMOS_GAMING_MODE);
        assert (gaming_mode.heading == "SteamOS handoff isn’t available" && gaming_mode.body.contains ("native Steam"));
        var staged_configuration = SteamRestartPresentation.failure_message (
            SteamRestartFailureReason.STEAMOS_CONFIGURATION_REQUIRES_DESKTOP_MODE
        );
        assert (staged_configuration.heading == "Switch to Desktop Mode");
        assert (staged_configuration.body.contains ("while Steam is stopped"));
        assert (staged_configuration.body.contains ("close ProtonPlus"));
        foreach (var reason in new SteamRestartFailureReason[] {
            SteamRestartFailureReason.TARGET_SNAPSHOT_MISMATCH, SteamRestartFailureReason.STEAM_STARTING,
            SteamRestartFailureReason.STEAM_UPDATING, SteamRestartFailureReason.SESSION_BLOCKER,
            SteamRestartFailureReason.GRACEFUL_SHUTDOWN_FAILED, SteamRestartFailureReason.EXIT_TIMEOUT,
            SteamRestartFailureReason.RELAUNCH_UNAVAILABLE, SteamRestartFailureReason.RELAUNCH_FAILED,
            SteamRestartFailureReason.START_TIMEOUT, SteamRestartFailureReason.NEW_SESSION_UNCONFIRMED,
            SteamRestartFailureReason.PENDING_STATE_PERSISTENCE_FAILED
        }) {
            var message = SteamRestartPresentation.failure_message (reason, true);
            assert (message.heading != null && message.body != null);
        }
        assert (SteamRestartPresentation.failure_message (SteamRestartFailureReason.NO_PENDING_CHANGES).toast != null);
        assert (SteamRestartPresentation.success_message (false, false).toast == "Steam restarted");
        assert (SteamRestartPresentation.success_message (false, true).heading != null);
        assert (SteamRestartPresentation.progress_title (
            SteamRestartOperationState.STEAMOS_HANDOFF_REQUESTED
        ) == "SteamOS is restarting Steam");
        assert (SteamRestartPresentation.steamos_handoff_message ().toast == "SteamOS is restarting Steam");
    }

    private void test_inactive_notification_policy () {
        var policy = new SteamRestartNotificationPolicy ();
        assert (policy.update (0, 1, true, false) == null);
        assert (policy.update (0, 1, false, true) == null);
        assert (policy.update (0, 1, false, false) != null);
        assert (policy.update (1, 1, false, false) == null);
        assert (policy.update (1, 2, false, false) != null);
        assert (policy.update (2, 3, false, false) == null);
        assert (policy.update (3, 0, false, false) == null);
        assert (policy.update (0, 1, false, false) != null);
    }

    private void test_notification_delivery_is_private_and_deduplicated () {
        var sender = new RecordingNotificationSender ();
        var coordinator = new SteamRestartNotificationCoordinator (sender);

        coordinator.update (0, 1, false, false);
        assert (sender.messages.size == 1);
        coordinator.update (1, 1, false, false);
        assert (sender.messages.size == 1);
        coordinator.update (1, 2, false, false);
        assert (sender.messages.size == 2);
        coordinator.update (2, 3, false, false);
        assert (sender.messages.size == 2);
        foreach (var message in sender.messages) {
            assert (!message.contains ("Fixture game"));
            assert (!message.contains ("123456"));
            assert (!message.contains ("%command%"));
            assert (!message.contains ("/tmp/"));
        }

        coordinator.update (3, 0, false, false);
        coordinator.update (0, 1, true, false);
        assert (sender.messages.size == 2);
        coordinator.update (1, 0, false, false);
        coordinator.update (0, 1, false, true);
        assert (sender.messages.size == 2);
        coordinator.update (1, 2, false, false);
        assert (sender.messages.size == 3);

        coordinator.update (2, 0, false, false);
        sender.fail = true;
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING,
            "*Failed to send Steam restart notification: fixture delivery failure*");
        coordinator.update (0, 1, false, false);
        Test.assert_expected_messages ();
        assert (sender.messages.size == 4);
        coordinator.update (1, 1, false, false);
        assert (sender.messages.size == 4);
        sender.fail = false;
        coordinator.update (1, 0, false, false);
        coordinator.update (0, 1, false, false);
        assert (sender.messages.size == 5);
    }

    public void register_tests () {
        Test.add_func ("/steam-restart-presentation/banner-and-grouping", test_banner_states_and_grouping);
        Test.add_func ("/steam-restart-presentation/toast-policy", test_toast_policy);
        Test.add_func ("/steam-restart-presentation/failure-messages", test_failure_messages_are_actionable);
        Test.add_func ("/steam-restart-presentation/inactive-notification-policy", test_inactive_notification_policy);
        Test.add_func ("/steam-restart-presentation/notification-delivery-private-and-deduplicated", test_notification_delivery_is_private_and_deduplicated);
    }
}
