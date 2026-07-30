namespace ProtonPlus.Models {
    /* These values are intentionally nonlocalized.  The presentation layer owns
     * translated wording and may map this evidence to a retry/manual flow. */
    public enum SteamRestartOperationState {
        IDLE,
        PREFLIGHT,
        REQUESTING_SHUTDOWN,
        WAITING_FOR_EXIT,
        LAUNCHING,
        WAITING_FOR_START,
        SUCCEEDED,
        FAILED,
        CANCELLED
    }

    public enum SteamRestartFailureReason {
        NONE,
        NO_PENDING_CHANGES,
        ALREADY_IN_PROGRESS,
        TARGET_SNAPSHOT_MISMATCH,
        STATE_UNKNOWN_OR_AMBIGUOUS,
        STEAM_STARTING,
        STEAM_UPDATING,
        GAME_OR_COMPATIBILITY_PROCESS,
        SESSION_BLOCKER,
        GRACEFUL_SHUTDOWN_UNSUPPORTED,
        GRACEFUL_SHUTDOWN_FAILED,
        EXIT_TIMEOUT,
        RELAUNCH_UNAVAILABLE,
        RELAUNCH_FAILED,
        START_TIMEOUT,
        NEW_SESSION_UNCONFIRMED,
        CANCELLED,
        PENDING_STATE_PERSISTENCE_FAILED
    }

    public class SteamRestartOperationResult : Object {
        public SteamRestartTarget target { get; private set; }
        public SteamRestartOperationState final_state { get; private set; }
        public SteamRestartFailureReason reason { get; private set; }
        public bool shutdown_request_sent { get; private set; }
        public bool steam_confirmed_stopped { get; private set; }
        public bool launch_request_sent { get; private set; }
        public bool new_running_session_confirmed { get; private set; }
        public bool pending_state_cleared { get; private set; }
        public bool persistence_failed { get; private set; }
        public ProtonPlus.Services.SteamSessionSnapshot? last_snapshot { get; private set; }
        public string diagnostic_detail { get; private set; }

        public SteamRestartOperationResult (
            SteamRestartTarget target, SteamRestartOperationState final_state,
            SteamRestartFailureReason reason, bool shutdown_request_sent,
            bool steam_confirmed_stopped, bool launch_request_sent,
            bool new_running_session_confirmed, bool pending_state_cleared,
            bool persistence_failed, ProtonPlus.Services.SteamSessionSnapshot? last_snapshot,
            string diagnostic_detail
        ) {
            this.target = target;
            this.final_state = final_state;
            this.reason = reason;
            this.shutdown_request_sent = shutdown_request_sent;
            this.steam_confirmed_stopped = steam_confirmed_stopped;
            this.launch_request_sent = launch_request_sent;
            this.new_running_session_confirmed = new_running_session_confirmed;
            this.pending_state_cleared = pending_state_cleared;
            this.persistence_failed = persistence_failed;
            this.last_snapshot = last_snapshot;
            this.diagnostic_detail = diagnostic_detail;
        }
    }
}
