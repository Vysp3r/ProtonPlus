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
            new Gee.ArrayList<string> ());
    }

    private SteamChangeReceipt receipt (SteamRestartTarget target, string resource_key, string changed_at = "2026-07-29T12:00:00Z") {
        return new SteamChangeReceipt (target, SteamChangeKind.GAME_COMPATIBILITY_TOOL_CHANGED,
            SteamRestartRequirement.CONSERVATIVE, resource_key, "123", "Test game", changed_at);
    }

    private SteamChangeReceipt configuration_receipt (SteamRestartTarget target, string desired) {
        var path = Filename.canonicalize (Path.build_filename (target.data_root, "config", "config.vdf"), null);
        var intent = new SteamConfigurationIntent (SteamConfigurationFile.CONFIG,
            SteamConfigurationOperation.COMPATIBILITY_MAPPING, path, "42", "proton-a", desired);
        return new SteamChangeReceipt (target, SteamChangeKind.GAME_COMPATIBILITY_TOOL_CHANGED,
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
        assert (manager.record (configuration_receipt (target, "proton-b")) == SteamRestartRecordResult.UPDATED);
        assert (manager.get_pending_changes ().get (0).occurrence_count == 1);
        assert (manager.record (configuration_receipt (target, "proton-c")) == SteamRestartRecordResult.UPDATED);
        assert (manager.get_pending_changes ().get (0).occurrence_count == 2);
        assert (manager.get_pending_changes ().get (0).receipt.configuration_intent.desired == "proton-c");
        assert (manager.record (configuration_receipt (target, "proton-a")) == SteamRestartRecordResult.REQUIREMENT_CLEARED);
        assert (manager.pending_count () == 0);
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

    public void register_tests () {
        Test.add_func ("/steam-restart-manager/deduplicates-and-persists", test_deduplicates_and_persists);
        Test.add_func ("/steam-restart-manager/stopped-change-is-already-satisfied", test_stopped_change_is_already_satisfied);
        Test.add_func ("/steam-restart-manager/native-reconciliation-requires-new-session", test_native_reconciliation_requires_new_session);
        Test.add_func ("/steam-restart-manager/unidentified-record-is-retained-without-stop-evidence", test_unidentified_record_is_retained_without_stop_evidence);
        Test.add_func ("/steam-restart-manager/flatpak-reconciliation-requires-different-instance", test_flatpak_reconciliation_requires_different_instance);
        Test.add_func ("/steam-restart-manager/store-skips-invalid-individual-entries", test_store_skips_invalid_individual_entries);
        Test.add_func ("/steam-restart-manager/persistence-failure-keeps-memory-state", test_persistence_failure_keeps_memory_state);
        Test.add_func ("/steam-restart-manager/configuration-coalesces-reversion", test_configuration_coalesces_reversion_without_duplicate_occurrences);
        Test.add_func ("/steam-restart-manager/configuration-state-stable-and-safe", test_configuration_state_uses_stable_ids_and_rejects_unsafe_paths);
    }
}
