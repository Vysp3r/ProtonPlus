namespace ProtonPlus.Services {
    using ProtonPlus.Models;

    public enum SteamRestartRecordResult {
        ADDED,
        UPDATED,
        REQUIREMENT_CLEARED,
        ALREADY_SATISFIED,
        PERSISTENCE_FAILED
    }

    public class SteamRestartManager : Object, SteamChangeRecorder {
        private SteamSessionService session_service;
        private SteamRestartStateStore state_store;
        private Gee.HashMap<string, SteamRestartPendingRecord> pending = new Gee.HashMap<string, SteamRestartPendingRecord> ();
        private Gee.HashMap<string, SteamRestartTarget> targets = new Gee.HashMap<string, SteamRestartTarget> ();
        private ulong state_changed_handler_id = 0;
        private bool observation_started = false;

        public string? last_persistence_error { get; private set; default = null; }
        public string? last_load_error { get; private set; default = null; }
        public bool is_observing { get { return observation_started; } }

        public signal void pending_changed ();
        public signal void restart_became_required (SteamRestartTarget target);
        public signal void restart_requirement_satisfied (SteamRestartTarget target);
        public signal void persistence_failed (string message);

        public SteamRestartManager (SteamSessionService session_service, SteamRestartStateStore state_store) {
            this.session_service = session_service;
            this.state_store = state_store;
            var loaded = state_store.load ();
            last_load_error = loaded.error;
            foreach (var record in loaded.records)
                add_loaded_record (record);
        }

        ~SteamRestartManager () {
            stop_observation ();
        }

        public bool has_pending_restarts () { return pending.size > 0; }
        public int pending_count () { return pending.size; }

        public int pending_count_for_target (SteamRestartTarget target) {
            var count = 0;
            foreach (var record in pending.values) {
                if (record.receipt.target.id == target.id)
                    count++;
            }
            return count;
        }

        public Gee.List<SteamRestartPendingRecord> get_pending_changes () {
            var copy = new Gee.ArrayList<SteamRestartPendingRecord> ();
            foreach (var record in pending.values)
                copy.add (record);
            return copy;
        }

        public Gee.List<SteamRestartPendingRecord> get_pending_changes_for_target (SteamRestartTarget target) {
            var copy = new Gee.ArrayList<SteamRestartPendingRecord> ();
            foreach (var record in pending.values) {
                if (record.receipt.target.id == target.id)
                    copy.add (record);
            }
            return copy;
        }

        /* Configuration callers use this narrow lookup to coalesce against
         * accepted desired state before making an on-disk no-op decision. */
        public SteamConfigurationIntent? get_pending_configuration_intent (SteamRestartTarget target, string resource_key) {
            foreach (var record in pending.values) {
                if (record.receipt.target.id == target.id && record.receipt.resource_key == resource_key)
                    return record.receipt.configuration_intent;
            }
            return null;
        }

        /* Targets are immutable value objects.  Return a new collection so
         * presentation code cannot mutate the manager's ownership map. */
        public Gee.List<SteamRestartTarget> get_pending_targets () {
            var copy = new Gee.ArrayList<SteamRestartTarget> ();
            foreach (var target in targets.values)
                copy.add (target);
            return copy;
        }

        public SteamRestartRecordResult record (SteamChangeReceipt receipt) {
            var snapshot = session_service.inspect (receipt.target);
            reconcile_snapshot (receipt.target, snapshot);
            if (is_confirmed_stopped (snapshot))
                return SteamRestartRecordResult.ALREADY_SATISFIED;

            var key = receipt.deduplication_key;
            var was_empty = pending_count_for_target (receipt.target) == 0;
            var existing = pending.get (key);
            var stable_session = identity_from_snapshot (receipt.target, snapshot);
            /* Coalesce replayable configuration changes.  A return to the
             * original field value removes only this pending resource. */
            if (existing != null && receipt.configuration_intent != null
                && existing.receipt.configuration_intent != null) {
                var old_intent = (!) existing.receipt.configuration_intent;
                var new_intent = (!) receipt.configuration_intent;
                if (old_intent.desired_present == new_intent.desired_present
                    && old_intent.desired == new_intent.desired)
                    return SteamRestartRecordResult.UPDATED;
                var baseline = old_intent.baseline;
                /* New-format records deliberately omit the raw baseline.  The
                 * request was read from disk, so it safely restores it for
                 * this process after its fingerprint has been checked. */
                if (baseline == "" && old_intent.baseline_fingerprint
                    == SteamConfigurationIntent.fingerprint (new_intent.baseline, new_intent.baseline_present))
                    baseline = new_intent.baseline;
                var merged = new SteamConfigurationIntent (new_intent.file, new_intent.operation,
                    new_intent.path, new_intent.field_id, baseline, new_intent.desired,
                    old_intent.baseline_present, new_intent.desired_present, old_intent.baseline_fingerprint);
                if (merged.desired_present == merged.baseline_present
                    && merged.desired == merged.baseline) {
                    pending.unset (key);
                    var target_cleared = pending_count_for_target (receipt.target) == 0;
                    if (target_cleared) targets.unset (receipt.target.id);
                    if (!persist ()) {
                        pending.set (key, existing);
                        targets.set (receipt.target.id, receipt.target);
                        return SteamRestartRecordResult.PERSISTENCE_FAILED;
                    }
                    pending_changed ();
                    if (target_cleared) restart_requirement_satisfied (receipt.target);
                    return SteamRestartRecordResult.REQUIREMENT_CLEARED;
                }
                var merged_receipt = new SteamChangeReceipt (receipt.target, receipt.kind,
                    receipt.restart_requirement, receipt.resource_key, receipt.subject_id,
                    receipt.subject_label, receipt.changed_at, merged);
                var replacement = updated_record (existing, merged_receipt, stable_session);
                pending.set (key, replacement);
                if (!persist ()) {
                    pending.set (key, existing);
                    return SteamRestartRecordResult.PERSISTENCE_FAILED;
                }
                pending_changed ();
                return SteamRestartRecordResult.UPDATED;
            }
            if (existing == null) {
                pending.set (key, new SteamRestartPendingRecord (receipt, receipt.changed_at, receipt.changed_at, 1, stable_session));
                targets.set (receipt.target.id, receipt.target);
            } else {
                pending.set (key, updated_record (existing, receipt, stable_session));
            }
            watch_target (receipt.target);
            if (!persist ()) {
                /* A staged-only value exists nowhere but this state file.  Do
                 * not leave a false in-memory success when durability fails. */
                if (existing == null) {
                    pending.unset (key);
                    if (pending_count_for_target (receipt.target) == 0)
                        targets.unset (receipt.target.id);
                } else {
                    pending.set (key, existing);
                }
                return SteamRestartRecordResult.PERSISTENCE_FAILED;
            }
            pending_changed ();
            if (was_empty)
                restart_became_required (receipt.target);
            return existing == null ? SteamRestartRecordResult.ADDED : SteamRestartRecordResult.UPDATED;
        }

        public void start_observation () {
            if (observation_started)
                return;
            state_changed_handler_id = session_service.state_changed.connect ((target, snapshot) => {
                reconcile_snapshot (target, snapshot);
            });
            foreach (var target in targets.values) {
                session_service.watch_target (target);
                reconcile_target (target);
            }
            session_service.start_monitoring ();
            observation_started = true;
        }

        public void stop_observation () {
            if (!observation_started)
                return;
            if (state_changed_handler_id != 0) {
                session_service.disconnect (state_changed_handler_id);
                state_changed_handler_id = 0;
            }
            session_service.stop_monitoring ();
            observation_started = false;
        }

        public void reconcile_target (SteamRestartTarget target) {
            reconcile_snapshot (target, session_service.inspect (target));
        }

        /* A target clears only after a demonstrated new stable session.  A
         * disappearance is merely a stop observation: it is not a restart.
         * Native identity requires boot ID, start ticks, and PID; Flatpak
         * identity requires the exact instance ID.  Heuristic or incomplete
         * observations therefore cannot satisfy a pending requirement. */
        public void reconcile_snapshot (SteamRestartTarget target, SteamSessionSnapshot snapshot) {
            if (snapshot.target_id != target.id || pending_count_for_target (target) == 0)
                return;
            var material_change = false;
            if (is_confirmed_stopped (snapshot)) {
                foreach (var record in get_pending_changes_for_target (target))
                    material_change |= record.mark_stop_observed ();
                if (material_change) {
                    pending_changed ();
                    persist ();
                }
                /* A manually observed stop is authorization to reconcile the
                 * already-persisted intent; it never implies a relaunch. */
                var configuration = SteamConfigurationService.instance;
                if (configuration != null)
                    configuration.reconcile_target (target);
                return;
            }
            if (snapshot.state != SteamSessionState.RUNNING)
                return;
            var current = identity_from_snapshot (target, snapshot);
            if (current == null)
                return;
            var configuration_needs_verification = false;
            foreach (var record in get_pending_changes_for_target (target)) {
                if (record.receipt.configuration_intent == null) continue;
                var recorded = record.observed_session;
                if ((recorded == null && record.stop_observed)
                    || (recorded != null && !recorded.equals ((!) current))) {
                    configuration_needs_verification = true;
                    break;
                }
            }
            if (configuration_needs_verification) {
                var configuration = SteamConfigurationService.instance;
                if (configuration != null)
                    configuration.verify_target_after_session (target);
            }
            var cleared = new Gee.ArrayList<SteamRestartPendingRecord> ();
            foreach (var record in get_pending_changes_for_target (target)) {
                if (record.receipt.configuration_intent != null)
                    continue;
                var recorded = record.observed_session;
                /* A prior stable identity must change even after a confirmed
                 * stop.  Stop evidence alone only permits clearance when the
                 * receipt was recorded without a stable session identity. */
                if ((recorded == null && record.stop_observed)
                    || (recorded != null && !recorded.equals ((!) current)))
                    cleared.add (record);
            }
            if (cleared.size == 0)
                return;
            foreach (var record in cleared)
                pending.unset (record.receipt.deduplication_key);
            var target_cleared = pending_count_for_target (target) == 0;
            if (target_cleared)
                targets.unset (target.id);
            pending_changed ();
            if (target_cleared)
                restart_requirement_satisfied (target);
            persist ();
        }

        /* Configuration records require on-disk verification by the service;
         * a process generation alone is deliberately not enough evidence. */
        public bool clear_verified_configuration (SteamRestartPendingRecord record) {
            if (record.receipt.configuration_intent == null)
                return false;
            var key = record.receipt.deduplication_key;
            if (!pending.has_key (key))
                return false;
            pending.unset (key);
            var target_cleared = pending_count_for_target (record.receipt.target) == 0;
            if (target_cleared) targets.unset (record.receipt.target.id);
            if (!persist ()) {
                pending.set (key, record);
                targets.set (record.receipt.target.id, record.receipt.target);
                return false;
            }
            pending_changed ();
            if (target_cleared) restart_requirement_satisfied (record.receipt.target);
            return true;
        }

        private void add_loaded_record (SteamRestartPendingRecord record) {
            var key = record.receipt.deduplication_key;
            if (pending.has_key (key))
                return;
            pending.set (key, record);
            targets.set (record.receipt.target.id, record.receipt.target);
            watch_target (record.receipt.target);
        }

        private SteamRestartPendingRecord updated_record (SteamRestartPendingRecord old,
            SteamChangeReceipt receipt, SteamSessionIdentity? session) {
            var observed = old.observed_session;
            if (observed == null && session != null)
                observed = session;
            return new SteamRestartPendingRecord (receipt, old.first_recorded_at,
                receipt.changed_at, old.occurrence_count + 1, observed, old.stop_observed);
        }

        private void watch_target (SteamRestartTarget target) {
            session_service.watch_target (target);
        }

        private bool persist () {
            if (state_store.save (pending.values)) {
                last_persistence_error = null;
                return true;
            }
            last_persistence_error = state_store.last_error ?? "Unable to save Steam restart state.";
            persistence_failed ((!) last_persistence_error);
            return false;
        }

        private bool is_confirmed_stopped (SteamSessionSnapshot snapshot) {
            return snapshot.state == SteamSessionState.STOPPED
                && snapshot.state_confidence == SteamEvidenceLevel.CONFIRMED;
        }

        private SteamSessionIdentity? identity_from_snapshot (SteamRestartTarget target, SteamSessionSnapshot snapshot) {
            if (snapshot.state != SteamSessionState.RUNNING || snapshot.state_confidence != SteamEvidenceLevel.CONFIRMED)
                return null;
            if (target.installation_kind == SteamInstallationKind.FLATPAK) {
                if (snapshot.flatpak_instance_id == null || snapshot.flatpak_instance_id == "")
                    return null;
                return new SteamSessionIdentity (null, 0, 0, snapshot.flatpak_instance_id);
            }
            var generation = snapshot.generation;
            if (generation == null || generation.boot_id == null || generation.boot_id == ""
                || generation.start_time_ticks <= 0 || generation.pid <= 0)
                return null;
            return new SteamSessionIdentity (generation.boot_id, generation.start_time_ticks, generation.pid, null);
        }
    }
}
