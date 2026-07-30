namespace ProtonPlus.Widgets.Main {
    using ProtonPlus.Models;

    public class SteamRestartTargetSummary : Object {
        public SteamRestartTarget target { get; private set; }
        public uint pending_count { get; private set; }
        public bool has_documented_requirement { get; private set; }
        public bool has_conservative_requirement { get; private set; }

        public SteamRestartTargetSummary (SteamRestartTarget target, uint pending_count, bool documented, bool conservative) {
            this.target = target;
            this.pending_count = pending_count;
            this.has_documented_requirement = documented;
            this.has_conservative_requirement = conservative;
        }
    }

    public class SteamRestartBannerState : Object {
        public bool visible { get; private set; }
        public string title { get; private set; }
        public bool multiple_targets { get; private set; }

        public SteamRestartBannerState (bool visible, string title, bool multiple_targets) {
            this.visible = visible;
            this.title = title;
            this.multiple_targets = multiple_targets;
        }
    }

    public class SteamRestartMessage : Object {
        public string? heading { get; private set; }
        public string? body { get; private set; }
        public string? toast { get; private set; }
        public bool can_retry { get; private set; }

        public SteamRestartMessage (string? heading = null, string? body = null, string? toast = null, bool can_retry = false) {
            this.heading = heading;
            this.body = body;
            this.toast = toast;
            this.can_retry = can_retry;
        }
    }

    /* Non-widget policy: it deliberately carries no manager/orchestrator
     * ownership so it can be tested without a graphical display. */
    public class SteamRestartPresentation : Object {
        public static Gee.List<SteamRestartTargetSummary> summarize (Gee.List<SteamRestartPendingRecord> records) {
            var counts = new Gee.HashMap<string, uint> ();
            var targets = new Gee.HashMap<string, SteamRestartTarget> ();
            var documented = new Gee.HashMap<string, bool> ();
            var conservative = new Gee.HashMap<string, bool> ();
            foreach (var record in records) {
                var id = record.receipt.target.id;
                counts.set (id, counts.get (id) + 1);
                targets.set (id, record.receipt.target);
                if (record.receipt.restart_requirement == SteamRestartRequirement.DOCUMENTED)
                    documented.set (id, true);
                else
                    conservative.set (id, true);
            }
            var summaries = new Gee.ArrayList<SteamRestartTargetSummary> ();
            foreach (var id in targets.keys)
                summaries.add (new SteamRestartTargetSummary (targets.get (id), counts.get (id), documented.get (id), conservative.get (id)));
            summaries.sort ((a, b) => {
                var by_name = strcmp (a.target.display_name, b.target.display_name);
                return by_name != 0 ? by_name : strcmp (a.target.id, b.target.id);
            });
            return summaries;
        }

        public static SteamRestartBannerState banner_state (Gee.List<SteamRestartPendingRecord> records) {
            var count = records.size;
            if (count == 0)
                return new SteamRestartBannerState (false, "", false);
            var targets = summarize (records);
            if (targets.size > 1)
                return new SteamRestartBannerState (true, ngettext ("Steam restarts are needed to apply %u change", "Steam restarts are needed to apply %u changes", count).printf (count), true);
            return new SteamRestartBannerState (true, ngettext ("Restart Steam to apply %u change", "Restart Steam to apply %u changes", count).printf (count), false);
        }

        public static string requirement_explanation (SteamRestartTargetSummary summary) {
            if (summary.has_documented_requirement)
                return summary.has_conservative_requirement
                    ? _ ("Steam must restart to detect a newly installed compatibility tool. Other pending changes will be applied at the same time.")
                    : _ ("Steam must restart to detect a newly installed compatibility tool.");
            return _ ("Restarting Steam lets it safely reload the changed configuration.");
        }

        public static string progress_title (SteamRestartOperationState state) {
            switch (state) {
            case SteamRestartOperationState.PREFLIGHT: return _ ("Checking Steam…");
            case SteamRestartOperationState.REQUESTING_SHUTDOWN: return _ ("Closing Steam…");
            case SteamRestartOperationState.WAITING_FOR_EXIT: return _ ("Waiting for Steam to close…");
            case SteamRestartOperationState.LAUNCHING: return _ ("Starting Steam…");
            case SteamRestartOperationState.WAITING_FOR_START: return _ ("Waiting for Steam to start…");
            default: return "";
            }
        }

        public static SteamRestartMessage failure_message (SteamRestartFailureReason reason, bool steam_stopped = false) {
            switch (reason) {
            case SteamRestartFailureReason.NO_PENDING_CHANGES:
                return new SteamRestartMessage (null, null, _ ("Steam no longer needs to restart"));
            case SteamRestartFailureReason.ALREADY_IN_PROGRESS:
                return new SteamRestartMessage ();
            case SteamRestartFailureReason.TARGET_SNAPSHOT_MISMATCH:
            case SteamRestartFailureReason.STATE_UNKNOWN_OR_AMBIGUOUS:
                return new SteamRestartMessage (_ ("Steam status couldn’t be confirmed"), _ ("ProtonPlus did not restart Steam. Try again or restart it manually."));
            case SteamRestartFailureReason.STEAM_STARTING:
                return new SteamRestartMessage (_ ("Steam is still starting"), _ ("Wait for Steam to finish starting, then try again."), null, true);
            case SteamRestartFailureReason.STEAM_UPDATING:
                return new SteamRestartMessage (_ ("Steam is updating"), _ ("Wait until the update finishes, then try again."), null, true);
            case SteamRestartFailureReason.GAME_OR_COMPATIBILITY_PROCESS:
                return new SteamRestartMessage (_ ("Close running games first"), _ ("ProtonPlus will not restart Steam while a game or compatibility process is running."));
            case SteamRestartFailureReason.SESSION_BLOCKER:
                return new SteamRestartMessage (_ ("Steam can’t restart right now"), _ ("Finish the current Steam activity, then try again."), null, true);
            case SteamRestartFailureReason.GRACEFUL_SHUTDOWN_UNSUPPORTED:
                return new SteamRestartMessage (_ ("Close Steam manually"), _ ("ProtonPlus cannot safely close this Steam installation automatically. The reminder will remain and ProtonPlus will detect when Steam closes. After closing Steam, select Restart Steam again to reopen it."));
            case SteamRestartFailureReason.GRACEFUL_SHUTDOWN_FAILED:
            case SteamRestartFailureReason.EXIT_TIMEOUT:
                return new SteamRestartMessage (_ ("Steam didn’t close"), _ ("No force termination was attempted. Close Steam manually or try again."), null, true);
            case SteamRestartFailureReason.RELAUNCH_UNAVAILABLE:
            case SteamRestartFailureReason.RELAUNCH_FAILED:
            case SteamRestartFailureReason.START_TIMEOUT:
            case SteamRestartFailureReason.NEW_SESSION_UNCONFIRMED:
                return new SteamRestartMessage (_ ("Steam couldn’t be reopened"), steam_stopped ? _ ("Steam is currently closed. Start it manually. ProtonPlus will keep the reminder until it confirms a new session.") : _ ("Start Steam manually. ProtonPlus will keep the reminder until it confirms a new session."));
            case SteamRestartFailureReason.CANCELLED:
                return new SteamRestartMessage (null, null, _ ("Steam restart was cancelled"));
            case SteamRestartFailureReason.PENDING_STATE_PERSISTENCE_FAILED:
                return new SteamRestartMessage (_ ("Steam restarted"), _ ("Steam restarted successfully, but ProtonPlus could not save the cleared reminder state."));
            default:
                return new SteamRestartMessage (_ ("Steam couldn’t restart"), _ ("Try again later or restart Steam manually."));
            }
        }

        public static SteamRestartMessage success_message (bool other_targets_pending, bool persistence_failed) {
            if (persistence_failed)
                return failure_message (SteamRestartFailureReason.PENDING_STATE_PERSISTENCE_FAILED);
            return new SteamRestartMessage (null, null, other_targets_pending ? _ ("Steam restarted; other changes still need a restart") : _ ("Steam restarted"));
        }
    }

    public class SteamRestartToastPolicy : Object {
        private bool initial_shown = false;
        private bool multiple_shown = false;

        public string? update (uint previous_count, uint current_count, bool restored) {
            if (current_count == 0) {
                initial_shown = false;
                multiple_shown = false;
                return null;
            }
            if (restored)
                return null;
            if (previous_count == 0 && current_count > 0 && !initial_shown) {
                initial_shown = true;
                return _ ("Steam needs to restart to apply your changes");
            }
            if (previous_count == 1 && current_count > 1 && !multiple_shown) {
                multiple_shown = true;
                return _ ("Multiple changes will be applied after Steam restarts");
            }
            return null;
        }
    }
}
