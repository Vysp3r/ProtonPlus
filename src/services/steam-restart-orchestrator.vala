namespace ProtonPlus.Services {
    using ProtonPlus.Models;

    public class SteamRestartOrchestrator : Object {
        private SteamSessionService session_service;
        private SteamRestartManager restart_manager;
        private SteamRestartBackend backend;
        private SteamConfigurationReconciler? configuration_reconciler;
        private uint poll_interval_msec;
        private uint exit_poll_limit;
        private uint start_poll_limit;
        private bool operation_active = false;

        public SteamRestartOperationState state { get; private set; default = SteamRestartOperationState.IDLE; }
        public SteamSessionSnapshot? last_snapshot { get; private set; default = null; }
        public bool is_operation_active { get { return operation_active; } }

        public signal void state_changed (SteamRestartOperationState state);
        public signal void progress_changed (SteamSessionSnapshot snapshot);
        public signal void operation_completed (SteamRestartOperationResult result);

        public SteamRestartOrchestrator (
            SteamSessionService session_service, SteamRestartManager restart_manager,
            SteamRestartBackend? backend = null, uint poll_interval_msec = 500,
            uint exit_poll_limit = 40, uint start_poll_limit = 60,
            SteamConfigurationReconciler? configuration_reconciler = null
        ) {
            this.session_service = session_service;
            this.restart_manager = restart_manager;
            this.backend = backend ?? new HostSteamRestartBackend ();
            this.poll_interval_msec = poll_interval_msec;
            this.exit_poll_limit = exit_poll_limit;
            this.start_poll_limit = start_poll_limit;
            this.configuration_reconciler = configuration_reconciler;
        }

        /* Keep the cancellation token out of Vala's generated GTask slot: a
         * cancelled GTask would erase our typed result.  Callers pass a
         * GCancellable here; it is checked and forwarded below. */
        public async SteamRestartOperationResult restart_target (SteamRestartTarget target, Object? cancellation = null) {
            if (operation_active)
                return result (target, SteamRestartOperationState.FAILED, SteamRestartFailureReason.ALREADY_IN_PROGRESS, false, false, false, false, false, false, last_snapshot, "Another Steam restart transaction is still active.");
            operation_active = true;
            SteamRestartOperationResult completed;
            try {
                /* Ensure even an immediately rejected/cancelled request
                 * completes through the main context like all other async
                 * transactions. */
                yield yield_main_context ();
                completed = yield run (target, cancellation);
            } finally {
                operation_active = false;
            }
            operation_completed (completed);
            return completed;
        }

        private async SteamRestartOperationResult run (SteamRestartTarget target, Object? cancellation) {
            var cancellable = cancellation as Cancellable;
            var shutdown_sent = false;
            var stopped = false;
            var launch_sent = false;
            var started = false;
            transition (SteamRestartOperationState.PREFLIGHT);
            if (cancelled (cancellable))
                return cancelled_result (target, shutdown_sent, stopped, launch_sent, started, "Cancelled before preflight.");
            if (restart_manager.pending_count_for_target (target) == 0)
                return fail (target, SteamRestartFailureReason.NO_PENDING_CHANGES, shutdown_sent, stopped, launch_sent, started, "No pending restart receipts exist for this physical target.");
            var preflight = observe (target);
            var preflight_reason = reject_preflight (target, preflight);
            if (preflight_reason != SteamRestartFailureReason.NONE)
                return fail (target, preflight_reason, shutdown_sent, stopped, launch_sent, started, "Restart preflight rejected the current Steam observation.");
            var original_identity = identity (target, preflight) ?? pending_identity (target);

            /* Resolve a policy-approved relaunch capability before we ask a
             * running client to exit.  Dispatch validates it again. */
            if (!has_relaunch_strategy (target))
                return fail (target, SteamRestartFailureReason.RELAUNCH_UNAVAILABLE, shutdown_sent, stopped, launch_sent, started, "No validated target-specific relaunch strategy is currently available.");

            /* The stopped path intentionally persists the stop observation then
             * launches only through the narrow installation-kind policy. */
            if (is_confirmed_stopped (preflight)) {
                stopped = true;
                return yield reconcile_and_launch (target, original_identity, shutdown_sent, stopped, cancellable);
            }
            if (target.installation_kind != SteamInstallationKind.NATIVE)
                return fail (target, SteamRestartFailureReason.GRACEFUL_SHUTDOWN_UNSUPPORTED, shutdown_sent, stopped, launch_sent, started, "This running target has no established graceful automatic shutdown strategy.");

            var dispatch_snapshot = observe (target);
            var dispatch_reason = reject_preflight (target, dispatch_snapshot);
            if (dispatch_reason != SteamRestartFailureReason.NONE)
                return fail (target, dispatch_reason, shutdown_sent, stopped, launch_sent, started, "Steam observation changed before shutdown dispatch.");
            if (!same_identity (original_identity, identity (target, dispatch_snapshot)))
                return fail (target, SteamRestartFailureReason.TARGET_SNAPSHOT_MISMATCH, shutdown_sent, stopped, launch_sent, started, "Steam generation changed between preflight and shutdown dispatch.");
            if (cancelled (cancellable))
                return cancelled_result (target, shutdown_sent, stopped, launch_sent, started, "Cancelled before shutdown dispatch.");

            transition (SteamRestartOperationState.REQUESTING_SHUTDOWN);
            SteamRestartCommandResult? shutdown = yield backend.request_native_shutdown (ProtonPlus.Globals.IS_FLATPAK, cancellable);
            if (shutdown == null)
                return cancelled_result (target, shutdown_sent, stopped, launch_sent, started, "Shutdown dispatch was cancelled before a command result was available.");
            var shutdown_result = (!) shutdown;
            shutdown_sent = shutdown_result.status == SteamRestartCommandStatus.ACCEPTED || shutdown_result.status == SteamRestartCommandStatus.CANCELLED;
            if (shutdown_result.status == SteamRestartCommandStatus.CANCELLED || cancelled (cancellable))
                return cancelled_result (target, shutdown_sent, stopped, launch_sent, started, "Shutdown may continue independently after cancellation: " + shutdown_result.diagnostic);
            if (shutdown_result.status != SteamRestartCommandStatus.ACCEPTED)
                return fail (target, SteamRestartFailureReason.GRACEFUL_SHUTDOWN_FAILED, shutdown_sent, stopped, launch_sent, started, shutdown_result.diagnostic);

            transition (SteamRestartOperationState.WAITING_FOR_EXIT);
            for (uint poll = 0; poll < exit_poll_limit; poll++) {
                if (cancelled (cancellable))
                    return cancelled_result (target, shutdown_sent, stopped, launch_sent, started, "Shutdown was dispatched; no automatic relaunch follows cancellation.");
                var observed = observe (target);
                if (is_confirmed_stopped (observed)) {
                    stopped = true;
                    return yield reconcile_and_launch (target, original_identity, shutdown_sent, stopped, cancellable);
                }
                if (observed.state == SteamSessionState.UNKNOWN || observed.state == SteamSessionState.STARTING || observed.state == SteamSessionState.UPDATING)
                    return fail (target, SteamRestartFailureReason.STATE_UNKNOWN_OR_AMBIGUOUS, shutdown_sent, stopped, launch_sent, started, "Unsafe Steam state while waiting for shutdown.");
                if (!yield backend.delay (poll_interval_msec, cancellable))
                    return cancelled_result (target, shutdown_sent, stopped, launch_sent, started, "Shutdown was dispatched; polling was cancelled.");
            }
            return fail (target, SteamRestartFailureReason.EXIT_TIMEOUT, shutdown_sent, stopped, launch_sent, started, "Timed out waiting for confirmed Steam exit; no force termination was attempted.");
        }

        private async SteamRestartOperationResult reconcile_and_launch (SteamRestartTarget target,
            SteamSessionIdentity? original_identity, bool shutdown_sent, bool stopped, Cancellable? cancellable) {
            if (cancelled (cancellable))
                return cancelled_result (target, shutdown_sent, stopped, false, false, "Cancelled after Steam stopped; pending changes were retained.");
            transition (SteamRestartOperationState.APPLYING_CHANGES);
            if (configuration_reconciler != null) {
                var outcome = ((!) configuration_reconciler).reconcile_target (target);
                if (outcome.result == SteamConfigurationMutationResult.FAILED
                    || outcome.result == SteamConfigurationMutationResult.CONFLICT
                    || outcome.result == SteamConfigurationMutationResult.PERSISTENCE_FAILED)
                    return fail (target, SteamRestartFailureReason.CONFIGURATION_RECONCILIATION_FAILED,
                        shutdown_sent, stopped, false, false, outcome.error ?? "Pending configuration could not be reconciled.");
            }
            if (cancelled (cancellable))
                return cancelled_result (target, shutdown_sent, stopped, false, false, "Cancelled after applying changes; no relaunch was requested.");
            return yield launch_and_wait (target, original_identity, shutdown_sent, stopped, cancellable);
        }

        private async SteamRestartOperationResult launch_and_wait (SteamRestartTarget target, SteamSessionIdentity? original_identity, bool shutdown_sent, bool stopped, Object? cancellation) {
            var cancellable = cancellation as Cancellable;
            var launch_sent = false;
            var started = false;
            if (cancelled (cancellable))
                return cancelled_result (target, shutdown_sent, stopped, launch_sent, started, "Cancelled before launch dispatch.");
            transition (SteamRestartOperationState.LAUNCHING);
            SteamRestartCommandResult? launch;
            switch (target.installation_kind) {
            case SteamInstallationKind.NATIVE:
                launch = yield backend.launch_desktop_application ("steam.desktop", cancellable);
                if (launch != null && launch.status == SteamRestartCommandStatus.UNAVAILABLE)
                    launch = yield backend.launch_native_fallback (cancellable);
                break;
            case SteamInstallationKind.FLATPAK:
                launch = yield backend.launch_desktop_application ("com.valvesoftware.Steam.desktop", cancellable);
                break;
            default:
                return fail (target, SteamRestartFailureReason.RELAUNCH_UNAVAILABLE, shutdown_sent, stopped, launch_sent, started, "This installation kind has no validated relaunch strategy.");
            }
            if (launch == null)
                return cancelled_result (target, shutdown_sent, stopped, launch_sent, started, "Launch dispatch was cancelled before a command result was available.");
            var launch_result = (!) launch;
            launch_sent = launch_result.status == SteamRestartCommandStatus.ACCEPTED || launch_result.status == SteamRestartCommandStatus.CANCELLED;
            if (launch_result.status == SteamRestartCommandStatus.CANCELLED || cancelled (cancellable))
                return cancelled_result (target, shutdown_sent, stopped, launch_sent, started, "Launch may have been requested before cancellation: " + launch_result.diagnostic);
            if (launch_result.status == SteamRestartCommandStatus.UNAVAILABLE)
                return fail (target, SteamRestartFailureReason.RELAUNCH_UNAVAILABLE, shutdown_sent, stopped, launch_sent, started, launch_result.diagnostic);
            if (launch_result.status != SteamRestartCommandStatus.ACCEPTED)
                return fail (target, SteamRestartFailureReason.RELAUNCH_FAILED, shutdown_sent, stopped, launch_sent, started, launch_result.diagnostic);

            transition (SteamRestartOperationState.WAITING_FOR_START);
            for (uint poll = 0; poll < start_poll_limit; poll++) {
                if (cancelled (cancellable))
                    return cancelled_result (target, shutdown_sent, stopped, launch_sent, started, "Launch was dispatched; no additional control action follows cancellation.");
                var observed = observe (target);
                if (is_new_confirmed_session (target, original_identity, observed)) {
                    started = true;
                    if (configuration_reconciler != null)
                        ((!) configuration_reconciler).verify_target_after_session (target);
                    var cleared = restart_manager.pending_count_for_target (target) == 0;
                    var persistence_failed = restart_manager.last_persistence_error != null;
                    if (!cleared)
                        return fail (target, persistence_failed
                            ? SteamRestartFailureReason.PENDING_STATE_PERSISTENCE_FAILED
                            : SteamRestartFailureReason.NEW_SESSION_UNCONFIRMED,
                            shutdown_sent, stopped, launch_sent, started,
                            persistence_failed ? "Steam restarted, but clearing verified pending state could not be persisted."
                            : "A new Steam process was observed but pending state did not reconcile.");
                    transition (SteamRestartOperationState.SUCCEEDED);
                    return result (target, SteamRestartOperationState.SUCCEEDED,
                        persistence_failed ? SteamRestartFailureReason.PENDING_STATE_PERSISTENCE_FAILED : SteamRestartFailureReason.NONE,
                        shutdown_sent, stopped, launch_sent, started, cleared, persistence_failed, observed,
                        persistence_failed ? "Steam restarted, but persistence of cleared pending state failed." : "A new confirmed Steam session reconciled all pending records for this target.");
                }
                if (!yield backend.delay (poll_interval_msec, cancellable))
                    return cancelled_result (target, shutdown_sent, stopped, launch_sent, started, "Launch was dispatched; startup polling was cancelled.");
            }
            return fail (target, SteamRestartFailureReason.START_TIMEOUT, shutdown_sent, stopped, launch_sent, started, "Launch was requested but a new confirmed Steam session was not observed.");
        }

        private SteamSessionSnapshot observe (SteamRestartTarget target) {
            var snapshot = session_service.inspect (target);
            last_snapshot = snapshot;
            if (snapshot.target_id == target.id)
                restart_manager.reconcile_snapshot (target, snapshot);
            progress_changed (snapshot);
            return snapshot;
        }

        private SteamRestartFailureReason reject_preflight (SteamRestartTarget target, SteamSessionSnapshot snapshot) {
            if (snapshot.target_id != target.id)
                return SteamRestartFailureReason.TARGET_SNAPSHOT_MISMATCH;
            if (snapshot.state == SteamSessionState.UNKNOWN || snapshot.state_confidence != SteamEvidenceLevel.CONFIRMED)
                return SteamRestartFailureReason.STATE_UNKNOWN_OR_AMBIGUOUS;
            if (snapshot.state == SteamSessionState.STARTING)
                return SteamRestartFailureReason.STEAM_STARTING;
            if (snapshot.state == SteamSessionState.UPDATING)
                return SteamRestartFailureReason.STEAM_UPDATING;
            foreach (var blocker in snapshot.blockers) {
                if (blocker.blocker == SteamSessionBlocker.GAME_OR_COMPATIBILITY_PROCESS)
                    return SteamRestartFailureReason.GAME_OR_COMPATIBILITY_PROCESS;
                if (blocker.blocker != SteamSessionBlocker.NONE)
                    return SteamRestartFailureReason.SESSION_BLOCKER;
            }
            return SteamRestartFailureReason.NONE;
        }

        private bool is_confirmed_stopped (SteamSessionSnapshot snapshot) {
            return snapshot.state == SteamSessionState.STOPPED && snapshot.state_confidence == SteamEvidenceLevel.CONFIRMED;
        }

        private bool has_relaunch_strategy (SteamRestartTarget target) {
            switch (target.installation_kind) {
            case SteamInstallationKind.NATIVE:
                return backend.has_desktop_application ("steam.desktop") || backend.has_native_fallback ();
            case SteamInstallationKind.FLATPAK:
                return backend.has_desktop_application ("com.valvesoftware.Steam.desktop");
            default:
                return false;
            }
        }

        private SteamSessionIdentity? identity (SteamRestartTarget target, SteamSessionSnapshot snapshot) {
            if (snapshot.state != SteamSessionState.RUNNING || snapshot.state_confidence != SteamEvidenceLevel.CONFIRMED)
                return null;
            if (target.installation_kind == SteamInstallationKind.FLATPAK) {
                if (snapshot.flatpak_instance_id == null || snapshot.flatpak_instance_id == "") return null;
                return new SteamSessionIdentity (null, 0, 0, snapshot.flatpak_instance_id);
            }
            if (snapshot.generation == null) return null;
            var generation = (!) snapshot.generation;
            if (generation.boot_id == null || generation.boot_id == "" || generation.start_time_ticks <= 0 || generation.pid <= 0) return null;
            return new SteamSessionIdentity (generation.boot_id, generation.start_time_ticks, generation.pid, null);
        }

        private SteamSessionIdentity? pending_identity (SteamRestartTarget target) {
            foreach (var record in restart_manager.get_pending_changes_for_target (target)) {
                if (record.observed_session != null)
                    return record.observed_session;
            }
            return null;
        }

        private bool same_identity (SteamSessionIdentity? first, SteamSessionIdentity? second) {
            if (first == null || second == null) return first == null && second == null;
            return ((!) first).equals ((!) second);
        }

        private bool is_new_confirmed_session (SteamRestartTarget target, SteamSessionIdentity? original, SteamSessionSnapshot observed) {
            if (observed.target_id != target.id) return false;
            var current = identity (target, observed);
            return current != null && (original == null || !((!) original).equals ((!) current));
        }

        private bool cancelled (Cancellable? cancellable) { return cancellable != null && cancellable.is_cancelled (); }
        private async void yield_main_context () {
            Idle.add (() => { yield_main_context.callback (); return Source.REMOVE; });
            yield;
        }
        private void transition (SteamRestartOperationState next) { state = next; state_changed (state); }
        private SteamRestartOperationResult cancelled_result (SteamRestartTarget target, bool shutdown, bool stopped, bool launch, bool started, string detail) {
            transition (SteamRestartOperationState.CANCELLED);
            return result (target, SteamRestartOperationState.CANCELLED, SteamRestartFailureReason.CANCELLED, shutdown, stopped, launch, started, false, false, last_snapshot, detail);
        }
        private SteamRestartOperationResult fail (SteamRestartTarget target, SteamRestartFailureReason reason, bool shutdown, bool stopped, bool launch, bool started, string detail) {
            transition (SteamRestartOperationState.FAILED);
            return result (target, SteamRestartOperationState.FAILED, reason, shutdown, stopped, launch, started, false, false, last_snapshot, detail);
        }
        private SteamRestartOperationResult result (SteamRestartTarget target, SteamRestartOperationState final_state, SteamRestartFailureReason reason, bool shutdown, bool stopped, bool launch, bool started, bool cleared, bool persistence_failed, SteamSessionSnapshot? snapshot, string detail) {
            return new SteamRestartOperationResult (target, final_state, reason, shutdown, stopped, launch, started, cleared, persistence_failed, snapshot, detail);
        }
    }
}
