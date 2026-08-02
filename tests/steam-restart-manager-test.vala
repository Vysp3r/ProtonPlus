namespace AppTests.SteamRestartManagerTest {
    using ProtonPlus.Models;
    using ProtonPlus.Services;

    private class FakeBackend : Object, SteamSessionBackend {
        public NativeProcessQuery native_query = new NativeProcessQuery (true);
        public FlatpakProcessQuery flatpak_query = new FlatpakProcessQuery (true);

        public string? get_boot_id () { return "test-boot"; }
        public int64 get_monotonic_time_usec () { return 60 * 1000 * 1000; }
        public int64 get_clock_ticks_per_second () { return 100; }
        public NativeProcessQuery query_native_processes () { return native_query; }
        public FlatpakProcessQuery query_flatpak_processes () { return flatpak_query; }
        public SteamDesktopEntry? find_desktop_entry (string? id) { return null; }
        public bool is_steamos_gaming_mode () { return false; }
    }

    private class FailingStateStore : SteamRestartStateStore {
        public bool fail_saves = false;
        public FailingStateStore (string path) { base (path); }
        public override bool save (Gee.Collection<SteamRestartPendingRecord> records) {
            return !fail_saves && base.save (records);
        }
    }

    private class ReconcilerFixture : Object, SteamConfigurationReconciler {
        public SteamConfigurationMutationResult next_result = SteamConfigurationMutationResult.CHANGED;
        public int reconcile_calls = 0;
        public int verify_calls = 0;
        public SteamConfigurationMutation reconcile_target (SteamRestartTarget target) {
            reconcile_calls++;
            return new SteamConfigurationMutation (next_result);
        }
        public bool verify_target_after_session (SteamRestartTarget target) {
            verify_calls++;
            return true;
        }
    }

    private string temp_state_path () {
        var directory = DirUtils.mkdtemp (Path.build_filename (Environment.get_tmp_dir (), "protonplus-restart-test-XXXXXX"));
        return Path.build_filename (directory, "state.json");
    }

    private SteamRestartTarget native_target (string state_path) {
        return SteamRestartTarget.for_native (Path.build_filename (Path.get_dirname (state_path), "Steam"));
    }

    private SteamSessionSnapshot snapshot (
        SteamRestartTarget target, SteamSessionState state, SteamProcessGeneration? generation = null,
        string? flatpak_instance_id = null
    ) {
        return new SteamSessionSnapshot (target.id, state, state != SteamSessionState.STOPPED,
            generation != null ? generation.pid : 0, generation, flatpak_instance_id, null,
            new SteamRelaunchMetadata (null, null, null, false, "test"),
            new Gee.ArrayList<SteamSessionBlockerEvidence> (), SteamEvidenceLevel.CONFIRMED,
            SteamSessionMode.UNKNOWN,
            new Gee.ArrayList<string> ());
    }

    private SteamChangeReceipt receipt (SteamRestartTarget target, string resource_key, string changed_at = "2026-07-29T12:00:00Z") {
        return new SteamChangeReceipt (target, SteamChangeKind.GAME_COMPATIBILITY_TOOL_CHANGED,
            SteamRestartRequirement.CONSERVATIVE, resource_key, "123", "Test game", changed_at);
    }

    private SteamChangeReceipt configuration_receipt (SteamRestartTarget target, string desired,
        SteamChangeKind kind = SteamChangeKind.GAME_COMPATIBILITY_TOOL_CHANGED) {
        var path = Filename.canonicalize (Path.build_filename (target.data_root, "config", "config.vdf"), null);
        var intent = new SteamConfigurationIntent (SteamConfigurationFile.CONFIG,
            SteamConfigurationOperation.COMPATIBILITY_MAPPING, path, "42", "proton-a", desired);
        return new SteamChangeReceipt (target, kind,
            SteamRestartRequirement.CONSERVATIVE, "%s#CompatToolMapping/42".printf (path), "42", null, null, intent);
    }

    private SteamRestartManager running_manager (string state_path, out FakeBackend backend) {
        backend = new FakeBackend ();
        var target = native_target (state_path);
        var processes = new Gee.ArrayList<SteamProcessRecord> ();
        processes.add (new SteamProcessRecord (101, Path.build_filename (target.data_root, "steam"), target.data_root, 100));
        backend.native_query = new NativeProcessQuery (true, processes);
        return new SteamRestartManager (new SteamSessionService (backend), new SteamRestartStateStore (state_path));
    }

    private SteamChangeReceipt shortcut_receipt (SteamRestartTarget target, bool desired_present,
        SteamChangeKind kind) {
        var path = Filename.canonicalize (Path.build_filename (target.data_root, "userdata", "1", "config", "shortcuts.vdf"), null);
        var intent = new SteamConfigurationIntent (SteamConfigurationFile.SHORTCUTS,
            SteamConfigurationOperation.SHORTCUT_PRESENCE, path, "ProtonPlus", "", desired_present ? "present" : "",
            false, desired_present);
        return new SteamChangeReceipt (target, kind, SteamRestartRequirement.CONSERVATIVE,
            "%s#ProtonPlus".printf (path), "ProtonPlus", null, null, intent);
    }

    private SteamChangeReceipt shortcuts_file_receipt (SteamRestartTarget target) {
        var path = Filename.canonicalize (Path.build_filename (target.data_root, "userdata", "1", "config", "shortcuts.vdf"), null);
        var intent = new SteamConfigurationIntent (SteamConfigurationFile.SHORTCUTS,
            SteamConfigurationOperation.SHORTCUTS_FILE_PRESENT, path, "shortcuts.vdf", "", "present",
            false, true);
        return new SteamChangeReceipt (target, SteamChangeKind.SHORTCUTS_VDF_CREATED,
            SteamRestartRequirement.CONSERVATIVE, "%s#shortcuts.vdf".printf (path),
            "shortcuts.vdf", null, null, intent);
    }

    private void test_deduplicates_and_persists () {
        FakeBackend backend;
        var path = temp_state_path ();
        var manager = running_manager (path, out backend);
        var target = native_target (path);
        var transitions = 0;
        manager.restart_became_required.connect ((changed_target) => { transitions++; });

        assert (manager.record (receipt (target, "config.vdf/compat-tool-mapping/123")) == SteamRestartRecordResult.ADDED);
        assert (manager.record (receipt (target, "config.vdf/compat-tool-mapping/123", "2026-07-29T12:01:00Z")) == SteamRestartRecordResult.UPDATED);
        assert (manager.pending_count () == 1);
        assert (manager.get_pending_changes ().get (0).occurrence_count == 2);
        assert (transitions == 1);

        var restored = new SteamRestartManager (new SteamSessionService (backend), new SteamRestartStateStore (path));
        assert (restored.pending_count () == 1);
        assert (restored.get_pending_changes ().get (0).receipt.target.id == target.id);
    }

    private void test_stopped_change_is_already_satisfied () {
        var backend = new FakeBackend ();
        var path = temp_state_path ();
        var manager = new SteamRestartManager (new SteamSessionService (backend), new SteamRestartStateStore (path));
        assert (manager.record (receipt (native_target (path), "config.vdf/compat-tool-mapping/0")) == SteamRestartRecordResult.ALREADY_SATISFIED);
        assert (!manager.has_pending_restarts ());
    }

    private void test_native_reconciliation_requires_new_session () {
        FakeBackend backend;
        var path = temp_state_path ();
        var manager = running_manager (path, out backend);
        var target = native_target (path);
        manager.record (receipt (target, "config.vdf/compat-tool-mapping/0"));

        manager.reconcile_snapshot (target, snapshot (target, SteamSessionState.RUNNING, new SteamProcessGeneration (101, 100, "test-boot")));
        assert (manager.pending_count () == 1);
        manager.reconcile_snapshot (target, snapshot (target, SteamSessionState.STOPPED));
        assert (manager.get_pending_changes ().get (0).stop_observed);
        assert (manager.pending_count () == 1);
        manager.reconcile_snapshot (target, snapshot (target, SteamSessionState.RUNNING, new SteamProcessGeneration (102, 200, "test-boot")));
        assert (!manager.has_pending_restarts ());
    }

    private void test_reloaded_installation_receipt_clears_when_steam_is_stopped () {
        FakeBackend backend;
        var path = temp_state_path ();
        var manager = running_manager (path, out backend);
        var target = native_target (path);
        assert (manager.record (receipt (target, "compatibilitytools.d/fixture")) == SteamRestartRecordResult.ADDED);

        var restored = new SteamRestartManager (
            new SteamSessionService (backend), new SteamRestartStateStore (path)
        );
        assert (restored.pending_count_for_target (target) == 1);
        restored.reconcile_target (target);
        assert (restored.pending_count_for_target (target) == 1);

        backend.native_query = new NativeProcessQuery (true);
        restored.start_observation ();
        assert (restored.pending_count_for_target (target) == 0);
        restored.stop_observation ();
        var persisted = new SteamRestartStateStore (path).load ();
        assert (persisted.error == null && persisted.records.size == 0);
    }

    private void test_startup_stopped_configuration_clears_only_after_reconciliation () {
        FakeBackend backend;
        var path = temp_state_path ();
        var manager = running_manager (path, out backend);
        var target = native_target (path);
        assert (manager.record (receipt (target, "compatibilitytools.d/fixture")) == SteamRestartRecordResult.ADDED);
        assert (manager.record (configuration_receipt (target, "proton-b")) == SteamRestartRecordResult.ADDED);

        backend.native_query = new NativeProcessQuery (true);
        var reconciler = new ReconcilerFixture ();
        var restored = new SteamRestartManager (
            new SteamSessionService (backend), new SteamRestartStateStore (path), reconciler
        );
        restored.start_observation ();
        assert (reconciler.reconcile_calls == 1);
        assert (restored.pending_count_for_target (target) == 0);
        restored.stop_observation ();

        manager = running_manager (path, out backend);
        assert (manager.record (configuration_receipt (target, "proton-c")) == SteamRestartRecordResult.ADDED);
        backend.native_query = new NativeProcessQuery (true);
        reconciler = new ReconcilerFixture ();
        reconciler.next_result = SteamConfigurationMutationResult.CONFLICT;
        restored = new SteamRestartManager (
            new SteamSessionService (backend), new SteamRestartStateStore (path), reconciler
        );
        restored.start_observation ();
        assert (reconciler.reconcile_calls == 1);
        assert (restored.pending_count_for_target (target) == 1);
        assert (restored.get_pending_changes_for_target (target)[0].stop_observed);
        restored.stop_observation ();
    }

    private void test_startup_stopped_receipt_is_retained_when_clear_cannot_persist () {
        FakeBackend backend;
        var path = temp_state_path ();
        var target = native_target (path);
        var store = new FailingStateStore (path);
        var manager = running_manager (path, out backend);
        manager = new SteamRestartManager (new SteamSessionService (backend), store);
        assert (manager.record (receipt (target, "compatibilitytools.d/fixture")) == SteamRestartRecordResult.ADDED);

        backend.native_query = new NativeProcessQuery (true);
        store.fail_saves = true;
        manager.start_observation ();
        assert (manager.pending_count_for_target (target) == 1);
        assert (manager.last_persistence_error != null);
        manager.stop_observation ();
    }

    private void test_unidentified_record_is_retained_without_stop_evidence () {
        FakeBackend backend;
        var path = temp_state_path ();
        var manager = running_manager (path, out backend);
        var target = native_target (path);
        manager.record (receipt (target, "config.vdf/compat-tool-mapping/one"));
        backend.native_query = new NativeProcessQuery (false, null, "fixture unavailable");
        manager.record (receipt (target, "config.vdf/compat-tool-mapping/two"));

        manager.reconcile_snapshot (target, snapshot (target, SteamSessionState.RUNNING, new SteamProcessGeneration (102, 200, "test-boot")));
        assert (manager.pending_count () == 1);
        assert (manager.get_pending_changes ().get (0).receipt.resource_key == "config.vdf/compat-tool-mapping/two");
    }

    private void test_flatpak_reconciliation_requires_different_instance () {
        var path = temp_state_path ();
        var backend = new FakeBackend ();
        var records = new Gee.ArrayList<FlatpakProcessRecord> ();
        records.add (new FlatpakProcessRecord ("instance-a", "com.valvesoftware.Steam", 20, 21));
        backend.flatpak_query = new FlatpakProcessQuery (true, records);
        var manager = new SteamRestartManager (new SteamSessionService (backend), new SteamRestartStateStore (path));
        var target = SteamRestartTarget.for_flatpak (Path.build_filename (Path.get_dirname (path), "FlatpakSteam"));
        manager.record (receipt (target, "shortcuts.vdf/shortcut/one"));
        manager.reconcile_snapshot (target, snapshot (target, SteamSessionState.RUNNING, null, "instance-a"));
        assert (manager.pending_count () == 1);
        manager.reconcile_snapshot (target, snapshot (target, SteamSessionState.RUNNING, null, "instance-b"));
        assert (!manager.has_pending_restarts ());
    }

    private void test_store_skips_invalid_individual_entries () {
        var path = temp_state_path ();
        var target = native_target (path);
        var valid = new SteamRestartPendingRecord (receipt (target, "config.vdf/compat-tool-mapping/0"),
            "2026-07-29T12:00:00Z", "2026-07-29T12:00:00Z", 1, null);
        var store = new SteamRestartStateStore (path);
        var records = new Gee.ArrayList<SteamRestartPendingRecord> ();
        records.add (valid);
        assert (store.save (records));
        string content = "";
        try {
            FileUtils.get_contents (path, out content);
        } catch (FileError e) {
            assert_not_reached ();
        }
        var changed_content = content.replace ("\"records\":[", "\"records\":[{\"kind\":\"future-kind\"},");
        assert (changed_content != content);
        content = changed_content;
        try {
            FileUtils.set_contents (path, content);
        } catch (FileError e) {
            assert_not_reached ();
        }
        var loaded = store.load ();
        assert (loaded.error != null);
        assert (loaded.records.size == 1);
    }

    private void test_persistence_failure_keeps_memory_state () {
        FakeBackend backend;
        var directory = DirUtils.mkdtemp (Path.build_filename (Environment.get_tmp_dir (), "protonplus-restart-test-XXXXXX"));
        var manager = running_manager (directory, out backend);
        var target = native_target (directory);
        assert (manager.record (receipt (target, "config.vdf/compat-tool-mapping/0")) == SteamRestartRecordResult.PERSISTENCE_FAILED);
        assert (manager.pending_count () == 0);
        assert (manager.last_persistence_error != null);
    }

    private void test_configuration_coalesces_reversion_without_duplicate_occurrences () {
        FakeBackend backend;
        var path = temp_state_path ();
        var manager = running_manager (path, out backend);
        var target = native_target (path);
        assert (manager.record (configuration_receipt (target, "proton-b")) == SteamRestartRecordResult.ADDED);
        assert (manager.record (configuration_receipt (target, "proton-b")) == SteamRestartRecordResult.UNCHANGED);
        assert (manager.get_pending_changes ().get (0).occurrence_count == 1);
        assert (manager.record (configuration_receipt (target, "proton-c")) == SteamRestartRecordResult.UPDATED);
        assert (manager.get_pending_changes ().get (0).occurrence_count == 2);
        assert (manager.get_pending_changes ().get (0).receipt.configuration_intent.desired == "proton-c");
        assert (manager.record (configuration_receipt (target, "proton-a")) == SteamRestartRecordResult.REQUIREMENT_CLEARED);
        assert (manager.pending_count () == 0);
    }

    private void test_configuration_identity_ignores_descriptive_kind () {
        FakeBackend backend;
        var path = temp_state_path ();
        var manager = running_manager (path, out backend);
        var target = native_target (path);
        var changed = 0;
        manager.pending_changed.connect (() => { changed++; });

        assert (manager.record (configuration_receipt (target, "present",
            SteamChangeKind.PROTONPLUS_SHORTCUT_CREATED)) == SteamRestartRecordResult.ADDED);
        assert (manager.record (configuration_receipt (target, "present",
            SteamChangeKind.PROTONPLUS_SHORTCUT_REMOVED)) == SteamRestartRecordResult.UNCHANGED);
        assert (manager.pending_count () == 1);
        assert (manager.get_pending_changes ().get (0).occurrence_count == 1);
        assert (changed == 1);
    }

    private void test_reverting_legacy_shortcut_create_removes_prerequisite () {
        FakeBackend backend;
        var path = temp_state_path ();
        var manager = running_manager (path, out backend);
        var target = native_target (path);
        assert (manager.record (shortcuts_file_receipt (target)) == SteamRestartRecordResult.ADDED);
        assert (manager.record (shortcut_receipt (target, true,
            SteamChangeKind.PROTONPLUS_SHORTCUT_CREATED)) == SteamRestartRecordResult.ADDED);
        assert (manager.pending_count () == 2);
        assert (manager.record (shortcut_receipt (target, false,
            SteamChangeKind.PROTONPLUS_SHORTCUT_REMOVED)) == SteamRestartRecordResult.REQUIREMENT_CLEARED);
        assert (manager.pending_count () == 0);
        assert (!new SteamRestartManager (new SteamSessionService (backend),
            new SteamRestartStateStore (path)).has_pending_restarts ());
    }

    private void test_configuration_state_uses_stable_ids_and_rejects_unsafe_paths () {
        FakeBackend backend;
        var path = temp_state_path ();
        var manager = running_manager (path, out backend);
        var target = native_target (path);
        assert (manager.record (configuration_receipt (target, "private launch value")) == SteamRestartRecordResult.ADDED);
        string content = "";
        try { FileUtils.get_contents (path, out content); } catch (FileError e) { assert_not_reached (); }
        assert (content.contains ("\"file\":\"config\""));
        assert (!content.contains ("\"baseline\":\"proton-a\""));
        var unsafe_content = content.replace ("/config/config.vdf", "/../outside.vdf");
        try { FileUtils.set_contents (path, unsafe_content); } catch (FileError e) { assert_not_reached (); }
        var loaded = new SteamRestartStateStore (path).load ();
        assert (loaded.records.size == 0);
        assert (loaded.error != null);
    }

    private void test_persistence_failures_restore_exact_configuration_state () {
        var path = temp_state_path ();
        var backend = new FakeBackend ();
        var target = native_target (path);
        var processes = new Gee.ArrayList<SteamProcessRecord> ();
        processes.add (new SteamProcessRecord (101, Path.build_filename (target.data_root, "steam"), target.data_root, 100));
        backend.native_query = new NativeProcessQuery (true, processes);
        var store = new FailingStateStore (path);
        var manager = new SteamRestartManager (new SteamSessionService (backend), store);
        var changed = 0;
        manager.pending_changed.connect (() => { changed++; });

        assert (manager.record (configuration_receipt (target, "proton-b")) == SteamRestartRecordResult.ADDED);
        var before = manager.get_pending_changes ().get (0);
        store.fail_saves = true;
        assert (manager.record (configuration_receipt (target, "proton-c")) == SteamRestartRecordResult.PERSISTENCE_FAILED);
        var after_update = manager.get_pending_changes ().get (0);
        assert (after_update.receipt.configuration_intent.desired == "proton-b");
        assert (after_update.occurrence_count == before.occurrence_count);
        assert (after_update.first_recorded_at == before.first_recorded_at);
        assert (after_update.last_updated_at == before.last_updated_at);
        assert (changed == 1);

        assert (manager.record (configuration_receipt (target, "proton-a")) == SteamRestartRecordResult.PERSISTENCE_FAILED);
        assert (manager.pending_count () == 1);
        assert (manager.get_pending_changes ().get (0).receipt.configuration_intent.desired == "proton-b");
        assert (changed == 1);
        assert (!manager.clear_verified_configuration (manager.get_pending_changes ().get (0)));
        assert (manager.pending_count () == 1);
        assert (changed == 1);
    }

    private void test_bulk_configuration_verification_is_atomic () {
        var path = temp_state_path ();
        FakeBackend backend;
        var manager = running_manager (path, out backend);
        var target = native_target (path);
        var store = new FailingStateStore (Path.build_filename (Path.get_dirname (path), "atomic-state.json"));
        manager = new SteamRestartManager (new SteamSessionService (backend), store);
        assert (manager.record (configuration_receipt (target, "proton-b")) == SteamRestartRecordResult.ADDED);
        var config = Filename.canonicalize (Path.build_filename (target.data_root, "config", "config.vdf"), null);
        var second_intent = new SteamConfigurationIntent (SteamConfigurationFile.CONFIG,
            SteamConfigurationOperation.COMPATIBILITY_MAPPING, config, "43", "proton-c", "proton-d");
        var second = new SteamChangeReceipt (target, SteamChangeKind.GAME_COMPATIBILITY_TOOL_CHANGED,
            SteamRestartRequirement.CONSERVATIVE, "%s#CompatToolMapping/43".printf (config), "43", null, null, second_intent);
        assert (manager.record (second) == SteamRestartRecordResult.ADDED);
        var before = manager.get_pending_changes ();
        store.fail_saves = true;
        assert (!manager.clear_verified_configurations (before));
        assert (manager.pending_count () == 2);
        assert (manager.get_pending_changes ().get (0).receipt.configuration_intent != null);
        assert (manager.get_pending_changes ().get (1).receipt.configuration_intent != null);
    }

    private void test_injected_reconciler_handles_manual_stop_and_new_session () {
        FakeBackend backend;
        var path = temp_state_path ();
        var manager = running_manager (path, out backend);
        var target = native_target (path);
        var reconciler = new ReconcilerFixture ();
        manager.configure_configuration_reconciler (reconciler);
        assert (manager.record (configuration_receipt (target, "proton-b")) == SteamRestartRecordResult.ADDED);

        /* Reopen ProtonPlus before Steam exits: the restored manager must use
         * the configured seam rather than the process-global service. */
        manager = new SteamRestartManager (new SteamSessionService (backend),
            new SteamRestartStateStore (path), reconciler);
        assert (manager.pending_count () == 1);

        backend.native_query = new NativeProcessQuery (true);
        manager.reconcile_target (target);
        assert (reconciler.reconcile_calls == 1);
        assert (manager.pending_count () == 1);

        var processes = new Gee.ArrayList<SteamProcessRecord> ();
        processes.add (new SteamProcessRecord (102, Path.build_filename (target.data_root, "steam"), target.data_root, 200));
        backend.native_query = new NativeProcessQuery (true, processes);
        manager.reconcile_target (target);
        assert (reconciler.verify_calls == 1);
        assert (manager.pending_count () == 1);

        var tool_target = native_target (Path.build_filename (Path.get_dirname (path), "tool-state.json"));
        var tool_processes = new Gee.ArrayList<SteamProcessRecord> ();
        tool_processes.add (new SteamProcessRecord (201, Path.build_filename (tool_target.data_root, "steam"), tool_target.data_root, 100));
        backend.native_query = new NativeProcessQuery (true, tool_processes);
        var tool_manager = new SteamRestartManager (new SteamSessionService (backend), new SteamRestartStateStore (Path.build_filename (Path.get_dirname (path), "tool-state.json")), reconciler);
        assert (tool_manager.record (receipt (tool_target, "compatibilitytools.d/fixture")) == SteamRestartRecordResult.ADDED);
        backend.native_query = new NativeProcessQuery (true);
        tool_manager.reconcile_target (tool_target);
        tool_processes = new Gee.ArrayList<SteamProcessRecord> ();
        tool_processes.add (new SteamProcessRecord (202, Path.build_filename (tool_target.data_root, "steam"), tool_target.data_root, 200));
        backend.native_query = new NativeProcessQuery (true, tool_processes);
        tool_manager.reconcile_target (tool_target);
        assert (tool_manager.pending_count () == 0);
        assert (reconciler.reconcile_calls == 1);
        assert (reconciler.verify_calls == 1);
    }

    private void test_state_store_migrates_lifecycle_v1_and_secures_permissions () {
        var path = temp_state_path ();
        var target = native_target (path);
        var store = new SteamRestartStateStore (path);
        var records = new Gee.ArrayList<SteamRestartPendingRecord> ();
        records.add (new SteamRestartPendingRecord (receipt (target, "compatibilitytools.d/fixture"),
            "2026-07-29T12:00:00Z", "2026-07-29T12:00:00Z", 1, null));
        assert (store.save (records));
        assert (Posix.chmod (path, 0644) == 0);
        assert (store.save (records));
        try {
            var info = File.new_for_path (path).query_info ("unix::mode", FileQueryInfoFlags.NONE, null);
            assert ((info.get_attribute_uint32 ("unix::mode") & 0777) == 0600);
        } catch (Error e) { assert_not_reached (); }
        var v2 = "";
        try { FileUtils.get_contents (path, out v2); } catch (FileError e) { assert_not_reached (); }
        var v1 = v2.replace ("\"schema_version\":2", "\"schema_version\":1");
        assert (v1 != v2);
        try { FileUtils.set_contents (path, v1); } catch (FileError e) { assert_not_reached (); }
        var loaded = store.load ();
        assert (loaded.error == null);
        assert (loaded.records.size == 1);
        assert (loaded.records.get (0).receipt.resource_key == "compatibilitytools.d/fixture");
    }

    public void register_tests () {
        Test.add_func ("/steam-restart-manager/deduplicates-and-persists", test_deduplicates_and_persists);
        Test.add_func ("/steam-restart-manager/stopped-change-is-already-satisfied", test_stopped_change_is_already_satisfied);
        Test.add_func ("/steam-restart-manager/native-reconciliation-requires-new-session", test_native_reconciliation_requires_new_session);
        Test.add_func ("/steam-restart-manager/startup-stopped-installation-clears", test_reloaded_installation_receipt_clears_when_steam_is_stopped);
        Test.add_func ("/steam-restart-manager/startup-stopped-configuration-reconciles", test_startup_stopped_configuration_clears_only_after_reconciliation);
        Test.add_func ("/steam-restart-manager/startup-stopped-persistence-failure-retains", test_startup_stopped_receipt_is_retained_when_clear_cannot_persist);
        Test.add_func ("/steam-restart-manager/unidentified-record-is-retained-without-stop-evidence", test_unidentified_record_is_retained_without_stop_evidence);
        Test.add_func ("/steam-restart-manager/flatpak-reconciliation-requires-different-instance", test_flatpak_reconciliation_requires_different_instance);
        Test.add_func ("/steam-restart-manager/store-skips-invalid-individual-entries", test_store_skips_invalid_individual_entries);
        Test.add_func ("/steam-restart-manager/persistence-failure-keeps-memory-state", test_persistence_failure_keeps_memory_state);
        Test.add_func ("/steam-restart-manager/configuration-coalesces-reversion", test_configuration_coalesces_reversion_without_duplicate_occurrences);
        Test.add_func ("/steam-restart-manager/configuration-identity-ignores-kind", test_configuration_identity_ignores_descriptive_kind);
        Test.add_func ("/steam-restart-manager/reverting-legacy-shortcut-create-removes-prerequisite", test_reverting_legacy_shortcut_create_removes_prerequisite);
        Test.add_func ("/steam-restart-manager/configuration-state-stable-and-safe", test_configuration_state_uses_stable_ids_and_rejects_unsafe_paths);
        Test.add_func ("/steam-restart-manager/persistence-failures-restore-configuration-state", test_persistence_failures_restore_exact_configuration_state);
        Test.add_func ("/steam-restart-manager/bulk-verification-is-atomic", test_bulk_configuration_verification_is_atomic);
        Test.add_func ("/steam-restart-manager/injected-reconciler-manual-stop-and-new-session", test_injected_reconciler_handles_manual_stop_and_new_session);
        Test.add_func ("/steam-restart-manager/state-store-v1-and-private-mode", test_state_store_migrates_lifecycle_v1_and_secures_permissions);
    }
}
