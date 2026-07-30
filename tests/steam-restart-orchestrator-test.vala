namespace AppTests.SteamRestartOrchestratorTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Services;

    private class SessionFixture : Object, SteamSessionBackend {
        public NativeProcessQuery native_query = new NativeProcessQuery (true);
        public FlatpakProcessQuery flatpak_query = new FlatpakProcessQuery (true);
        public string? get_boot_id () { return "fixture-boot"; }
        public int64 get_monotonic_time_usec () { return 60 * 1000 * 1000; }
        public int64 get_clock_ticks_per_second () { return 100; }
        public NativeProcessQuery query_native_processes () { return native_query; }
        public FlatpakProcessQuery query_flatpak_processes () { return flatpak_query; }
        public SteamDesktopEntry? find_desktop_entry (string? id) { return null; }
    }

    /* This test seam has no host-side implementation.  It merely records the
     * typed action that production would request and advances fixture state. */
    private class ControlFixture : Object, SteamRestartBackend {
        public SessionFixture session;
        public SteamRestartCommandStatus shutdown_status = SteamRestartCommandStatus.ACCEPTED;
        public SteamRestartCommandStatus desktop_status = SteamRestartCommandStatus.ACCEPTED;
        public SteamRestartCommandStatus fallback_status = SteamRestartCommandStatus.ACCEPTED;
        public bool stop_on_shutdown = true;
        public bool start_on_launch = true;
        public bool reuse_original_identity = false;
        public int shutdown_requests = 0;
        public int launch_requests = 0;
        public Gee.List<string> last_argv = new Gee.ArrayList<string> ();
        public string? last_desktop_id = null;
        public SteamRestartTarget target;

        public ControlFixture (SessionFixture session, SteamRestartTarget target) { this.session = session; this.target = target; }
        public bool has_desktop_application (string desktop_id) { return true; }
        public bool has_native_fallback () { return true; }
        public async SteamRestartCommandResult request_native_shutdown (bool through_flatpak_host, Cancellable? cancellable) {
            shutdown_requests++;
            last_argv.clear ();
            if (through_flatpak_host) { last_argv.add ("flatpak-spawn"); last_argv.add ("--host"); }
            last_argv.add ("/usr/bin/steam"); last_argv.add ("-shutdown");
            if (shutdown_status == SteamRestartCommandStatus.ACCEPTED && stop_on_shutdown)
                session.native_query = new NativeProcessQuery (true);
            return new SteamRestartCommandResult (shutdown_status, last_argv, "fixture shutdown");
        }
        public async SteamRestartCommandResult launch_desktop_application (string desktop_id, Cancellable? cancellable) {
            launch_requests++; last_desktop_id = desktop_id;
            if (desktop_status == SteamRestartCommandStatus.ACCEPTED && start_on_launch)
                start_target ();
            return new SteamRestartCommandResult (desktop_status, null, "fixture desktop launch");
        }
        public async SteamRestartCommandResult launch_native_fallback (Cancellable? cancellable) {
            launch_requests++; last_desktop_id = "native-fallback";
            if (fallback_status == SteamRestartCommandStatus.ACCEPTED && start_on_launch)
                start_target ();
            return new SteamRestartCommandResult (fallback_status, null, "fixture native fallback");
        }
        public async bool delay (uint milliseconds, Cancellable? cancellable) { return cancellable == null || !cancellable.is_cancelled (); }
        private void start_target () {
            if (target.installation_kind == SteamInstallationKind.FLATPAK) {
                var records = new Gee.ArrayList<FlatpakProcessRecord> ();
                records.add (new FlatpakProcessRecord ("fixture-new-instance", "com.valvesoftware.Steam", 201, 202));
                session.flatpak_query = new FlatpakProcessQuery (true, records);
            } else {
                var processes = new Gee.ArrayList<SteamProcessRecord> ();
                processes.add (new SteamProcessRecord (reuse_original_identity ? 101 : 202, Path.build_filename (target.data_root, "steam"), target.data_root, reuse_original_identity ? 100 : 200));
                session.native_query = new NativeProcessQuery (true, processes);
            }
        }
    }

    private class LongRunningLaunchFactory : Object, SteamRestartProcessFactory {
        public bool received_trusted_argv = false;
        public Subprocess spawn (string[] argv) throws Error {
            received_trusted_argv = argv.length == 1 && argv[0] == "/usr/bin/steam";
            /* The fixture substitutes a harmless, deliberately long-lived
             * child.  Acceptance must arrive before this child exits. */
            return new Subprocess.newv ({ "/bin/sleep", "1" }, SubprocessFlags.NONE);
        }
    }

    private class ReconcilerFixture : Object, SteamConfigurationReconciler {
        public SteamConfigurationMutationResult next_result = SteamConfigurationMutationResult.CHANGED;
        public int reconcile_calls = 0;
        public int verify_calls = 0;
        public SteamRestartManager? manager_for_verification = null;
        public virtual SteamConfigurationMutation reconcile_target (SteamRestartTarget target) {
            reconcile_calls++;
            return new SteamConfigurationMutation (next_result,
                next_result == SteamConfigurationMutationResult.CONFLICT ? "fixture conflict" : null);
        }
        public bool verify_target_after_session (SteamRestartTarget target) {
            verify_calls++;
            if (manager_for_verification != null) {
                foreach (var record in ((!) manager_for_verification).get_pending_changes_for_target (target)) {
                    if (record.receipt.configuration_intent != null)
                        ((!) manager_for_verification).clear_verified_configuration (record);
                }
            }
            return true;
        }
    }

    private string state_path () {
        var directory = DirUtils.mkdtemp (Path.build_filename (Environment.get_tmp_dir (), "protonplus-restart-orchestrator-XXXXXX"));
        return Path.build_filename (directory, "state.json");
    }
    private SteamRestartTarget native_target (string path) { return SteamRestartTarget.for_native (Path.build_filename (Path.get_dirname (path), "Steam")); }
    private SteamChangeReceipt receipt (SteamRestartTarget target, string key = "config.vdf/compat-tool-mapping/1") {
        return new SteamChangeReceipt (target, SteamChangeKind.GAME_COMPATIBILITY_TOOL_CHANGED, SteamRestartRequirement.CONSERVATIVE, key, "1", "Fixture", "2026-07-29T12:00:00Z");
    }
    private SteamChangeReceipt configuration_receipt (SteamRestartTarget target) {
        var path = Filename.canonicalize (Path.build_filename (target.data_root, "config", "config.vdf"), null);
        var intent = new SteamConfigurationIntent (SteamConfigurationFile.CONFIG,
            SteamConfigurationOperation.COMPATIBILITY_MAPPING, path, "1", "proton-a", "proton-b");
        return new SteamChangeReceipt (target, SteamChangeKind.GAME_COMPATIBILITY_TOOL_CHANGED,
            SteamRestartRequirement.CONSERVATIVE, "%s#CompatToolMapping/1".printf (path), "1", "Fixture", null, intent);
    }
    private void set_native_running (SessionFixture fixture, SteamRestartTarget target, int pid = 101, int64 start = 100, string extra = "") {
        var processes = new Gee.ArrayList<SteamProcessRecord> ();
        processes.add (new SteamProcessRecord (pid, Path.build_filename (target.data_root, "steam"), "%s %s".printf (target.data_root, extra), start));
        fixture.native_query = new NativeProcessQuery (true, processes);
    }
    private SteamRestartOperationResult run (SteamRestartOrchestrator orchestrator, SteamRestartTarget target, Cancellable? cancellable = null) {
        var loop = new MainLoop (); SteamRestartOperationResult? result = null;
        orchestrator.restart_target.begin (target, cancellable, (obj, response) => { result = orchestrator.restart_target.end (response); loop.quit (); });
        loop.run (); return (!) result;
    }
    private SteamRestartOrchestrator setup_native (out SessionFixture session, out ControlFixture control, out SteamRestartManager manager, out SteamRestartTarget target) {
        var path = state_path (); target = native_target (path); session = new SessionFixture (); set_native_running (session, target);
        var service = new SteamSessionService (session); manager = new SteamRestartManager (service, new SteamRestartStateStore (path));
        assert (manager.record (receipt (target)) == SteamRestartRecordResult.ADDED);
        control = new ControlFixture (session, target);
        return new SteamRestartOrchestrator (service, manager, control, 0, 2, 2);
    }

    private void test_no_pending_rejected () {
        var path = state_path (); var target = native_target (path); var session = new SessionFixture (); set_native_running (session, target);
        var service = new SteamSessionService (session); var manager = new SteamRestartManager (service, new SteamRestartStateStore (path)); var control = new ControlFixture (session, target);
        var result = run (new SteamRestartOrchestrator (service, manager, control, 0, 1, 1), target);
        assert (result.reason == SteamRestartFailureReason.NO_PENDING_CHANGES); assert (control.shutdown_requests == 0);
    }
    private void test_native_shutdown_and_new_generation () {
        SessionFixture session; ControlFixture control; SteamRestartManager manager; SteamRestartTarget target;
        var orchestrator = setup_native (out session, out control, out manager, out target); var completions = 0;
        orchestrator.operation_completed.connect ((result) => { completions++; });
        var result = run (orchestrator, target);
        assert (result.final_state == SteamRestartOperationState.SUCCEEDED); assert (result.shutdown_request_sent); assert (result.new_running_session_confirmed);
        assert (control.last_argv.size == 2 && control.last_argv[0] == "/usr/bin/steam" && control.last_argv[1] == "-shutdown");
        assert (manager.pending_count_for_target (target) == 0); assert (completions == 1);
    }
    private void test_preflight_rejections () {
        SessionFixture session; ControlFixture control; SteamRestartManager manager; SteamRestartTarget target;
        var orchestrator = setup_native (out session, out control, out manager, out target);
        session.native_query = new NativeProcessQuery (false, null, "fixture unavailable");
        assert (run (orchestrator, target).reason == SteamRestartFailureReason.STATE_UNKNOWN_OR_AMBIGUOUS);
        set_native_running (session, target, 101, 5900); assert (run (orchestrator, target).reason == SteamRestartFailureReason.STEAM_STARTING);
        set_native_running (session, target, 101, 100, "-update"); assert (run (orchestrator, target).reason == SteamRestartFailureReason.STEAM_UPDATING);
        set_native_running (session, target); var processes = session.native_query.processes; processes.add (new SteamProcessRecord (88, "/usr/bin/proton", target.data_root, 200));
        assert (run (orchestrator, target).reason == SteamRestartFailureReason.GAME_OR_COMPATIBILITY_PROCESS); assert (control.shutdown_requests == 0);
    }
    private void test_exit_timeout_does_not_launch () {
        SessionFixture session; ControlFixture control; SteamRestartManager manager; SteamRestartTarget target;
        var orchestrator = setup_native (out session, out control, out manager, out target); control.stop_on_shutdown = false;
        var result = run (orchestrator, target);
        assert (result.reason == SteamRestartFailureReason.EXIT_TIMEOUT); assert (control.shutdown_requests == 1); assert (control.launch_requests == 0); assert (manager.pending_count () == 1);
    }
    private void test_second_request_is_rejected_without_disturbing_first () {
        SessionFixture session; ControlFixture control; SteamRestartManager manager; SteamRestartTarget target;
        var orchestrator = setup_native (out session, out control, out manager, out target);
        var loop = new MainLoop (); SteamRestartOperationResult? first = null; SteamRestartOperationResult? second = null;
        orchestrator.restart_target.begin (target, null, (obj, response) => { first = orchestrator.restart_target.end (response); if (second != null) loop.quit (); });
        orchestrator.restart_target.begin (target, null, (obj, response) => { second = orchestrator.restart_target.end (response); if (first != null) loop.quit (); });
        loop.run ();
        assert (((!) second).reason == SteamRestartFailureReason.ALREADY_IN_PROGRESS); assert (((!) first).final_state == SteamRestartOperationState.SUCCEEDED);
    }
    private void test_cancel_before_dispatch () {
        SessionFixture session; ControlFixture control; SteamRestartManager manager; SteamRestartTarget target;
        var orchestrator = setup_native (out session, out control, out manager, out target); var cancellable = new Cancellable ();
        var loop = new MainLoop (); SteamRestartOperationResult? result = null;
        orchestrator.restart_target.begin (target, cancellable, (obj, response) => { result = orchestrator.restart_target.end (response); loop.quit (); });
        /* The orchestrator yields to the main context before its preflight;
         * cancellation is therefore observed before any control dispatch. */
        Idle.add_full (Priority.HIGH_IDLE, () => { cancellable.cancel (); return Source.REMOVE; });
        loop.run ();
        assert (((!) result).final_state == SteamRestartOperationState.CANCELLED); assert (!((!) result).shutdown_request_sent); assert (control.shutdown_requests == 0);
    }
    private void test_flatpak_running_unsupported_and_stopped_relaunches_exact_id () {
        var path = state_path (); var target = SteamRestartTarget.for_flatpak (Path.build_filename (Path.get_dirname (path), "FlatpakSteam")); var session = new SessionFixture ();
        var records = new Gee.ArrayList<FlatpakProcessRecord> (); records.add (new FlatpakProcessRecord ("fixture-old-instance", "com.valvesoftware.Steam", 101, 102)); session.flatpak_query = new FlatpakProcessQuery (true, records);
        var service = new SteamSessionService (session); var manager = new SteamRestartManager (service, new SteamRestartStateStore (path)); assert (manager.record (receipt (target)) == SteamRestartRecordResult.ADDED);
        var control = new ControlFixture (session, target); var orchestrator = new SteamRestartOrchestrator (service, manager, control, 0, 1, 2);
        assert (run (orchestrator, target).reason == SteamRestartFailureReason.GRACEFUL_SHUTDOWN_UNSUPPORTED); assert (control.shutdown_requests == 0);
        session.flatpak_query = new FlatpakProcessQuery (true); var result = run (orchestrator, target);
        assert (result.final_state == SteamRestartOperationState.SUCCEEDED); assert (control.last_desktop_id == "com.valvesoftware.Steam.desktop"); assert (manager.pending_count () == 0);
    }
    private void test_untrusted_metadata_never_changes_native_argv () {
        SessionFixture session; ControlFixture control; SteamRestartManager manager; SteamRestartTarget target;
        var orchestrator = setup_native (out session, out control, out manager, out target);
        target = new SteamRestartTarget (target.data_root, SteamInstallationKind.NATIVE, "fixture", null, "/tmp/untrusted", "untrusted.desktop");
        /* Same physical target ID, deliberately hostile descriptive metadata. */
        var result = run (orchestrator, target);
        assert (result.final_state == SteamRestartOperationState.SUCCEEDED); assert (control.last_argv[0] == "/usr/bin/steam"); assert (control.last_argv[1] == "-shutdown");
    }
    private void test_relaunch_request_does_not_prove_start () {
        SessionFixture session; ControlFixture control; SteamRestartManager manager; SteamRestartTarget target;
        var orchestrator = setup_native (out session, out control, out manager, out target); control.start_on_launch = false;
        var result = run (orchestrator, target);
        assert (result.reason == SteamRestartFailureReason.START_TIMEOUT); assert (result.launch_request_sent); assert (!result.new_running_session_confirmed); assert (manager.pending_count () == 1);
    }
    private void test_stopped_native_skips_shutdown_and_original_identity_is_not_success () {
        SessionFixture session; ControlFixture control; SteamRestartManager manager; SteamRestartTarget target;
        var orchestrator = setup_native (out session, out control, out manager, out target); session.native_query = new NativeProcessQuery (true);
        var restarted = run (orchestrator, target);
        assert (restarted.final_state == SteamRestartOperationState.SUCCEEDED); assert (control.shutdown_requests == 0);

        orchestrator = setup_native (out session, out control, out manager, out target); control.reuse_original_identity = true;
        var unchanged = run (orchestrator, target);
        assert (unchanged.reason == SteamRestartFailureReason.START_TIMEOUT); assert (manager.pending_count () == 1);
    }
    private void test_heuristic_game_and_unsupported_kinds_preserve_pending () {
        SessionFixture session; ControlFixture control; SteamRestartManager manager; SteamRestartTarget target;
        var orchestrator = setup_native (out session, out control, out manager, out target);
        session.native_query.processes.add (new SteamProcessRecord (88, "/usr/bin/bash", target.data_root + " game.exe", 200));
        assert (run (orchestrator, target).reason == SteamRestartFailureReason.GAME_OR_COMPATIBILITY_PROCESS);

        var path = state_path (); var snap = SteamRestartTarget.for_snap (Path.build_filename (Path.get_dirname (path), "SnapSteam")); session = new SessionFixture (); set_native_running (session, snap);
        var service = new SteamSessionService (session); manager = new SteamRestartManager (service, new SteamRestartStateStore (path)); assert (manager.record (receipt (snap)) == SteamRestartRecordResult.ADDED);
        control = new ControlFixture (session, snap); orchestrator = new SteamRestartOrchestrator (service, manager, control, 0, 1, 1);
        assert (run (orchestrator, snap).reason == SteamRestartFailureReason.RELAUNCH_UNAVAILABLE); assert (control.shutdown_requests == 0); assert (manager.pending_count () == 1);
    }
    private void test_native_fallback_dispatch_does_not_wait_for_application_exit () {
        var factory = new LongRunningLaunchFactory ();
        var backend = new HostSteamRestartBackend (factory);
        var loop = new MainLoop (); SteamRestartCommandResult? result = null;
        backend.launch_native_fallback.begin (null, (obj, response) => {
            result = backend.launch_native_fallback.end (response);
            loop.quit ();
        });
        Timeout.add (150, () => { assert (result != null); return Source.REMOVE; });
        loop.run ();
        assert (factory.received_trusted_argv);
        assert (((!) result).status == SteamRestartCommandStatus.ACCEPTED);
    }

    private void test_reconciliation_is_ordered_before_launch () {
        SessionFixture session; ControlFixture control; SteamRestartManager manager; SteamRestartTarget target;
        setup_native (out session, out control, out manager, out target);
        assert (manager.record (configuration_receipt (target)) == SteamRestartRecordResult.ADDED);
        var reconciler = new ReconcilerFixture ();
        reconciler.manager_for_verification = manager;
        var orchestrator = new SteamRestartOrchestrator (new SteamSessionService (session), manager,
            control, 0, 2, 2, reconciler);
        var transitions = new Gee.ArrayList<SteamRestartOperationState> ();
        orchestrator.state_changed.connect ((state) => { transitions.add (state); });
        var result = run (orchestrator, target);
        assert (result.final_state == SteamRestartOperationState.SUCCEEDED);
        assert (reconciler.reconcile_calls == 1);
        assert (transitions.index_of (SteamRestartOperationState.APPLYING_CHANGES)
            < transitions.index_of (SteamRestartOperationState.LAUNCHING));
        assert (control.launch_requests == 1);
        assert (transitions.size == 7);
        assert (transitions[0] == SteamRestartOperationState.PREFLIGHT);
        assert (transitions[1] == SteamRestartOperationState.REQUESTING_SHUTDOWN);
        assert (transitions[2] == SteamRestartOperationState.WAITING_FOR_EXIT);
        assert (transitions[3] == SteamRestartOperationState.APPLYING_CHANGES);
        assert (transitions[4] == SteamRestartOperationState.LAUNCHING);
        assert (transitions[5] == SteamRestartOperationState.WAITING_FOR_START);
        assert (transitions[6] == SteamRestartOperationState.SUCCEEDED);
    }

    private void test_reconciliation_conflict_prevents_launch () {
        SessionFixture session; ControlFixture control; SteamRestartManager manager; SteamRestartTarget target;
        setup_native (out session, out control, out manager, out target);
        assert (manager.record (configuration_receipt (target)) == SteamRestartRecordResult.ADDED);
        var reconciler = new ReconcilerFixture ();
        reconciler.next_result = SteamConfigurationMutationResult.CONFLICT;
        var orchestrator = new SteamRestartOrchestrator (new SteamSessionService (session), manager,
            control, 0, 2, 2, reconciler);
        var result = run (orchestrator, target);
        assert (result.reason == SteamRestartFailureReason.CONFIGURATION_RECONCILIATION_FAILED);
        assert (reconciler.reconcile_calls == 1);
        assert (control.launch_requests == 0);
        assert (manager.pending_count_for_target (target) == 2);
    }

    private void test_reconciliation_outcomes_and_tool_only_receipts () {
        SessionFixture session; ControlFixture control; SteamRestartManager manager; SteamRestartTarget target;
        setup_native (out session, out control, out manager, out target);
        var reconciler = new ReconcilerFixture ();
        reconciler.next_result = SteamConfigurationMutationResult.UNCHANGED;
        var tool_only = new SteamRestartOrchestrator (new SteamSessionService (session), manager,
            control, 0, 2, 2, reconciler);
        assert (run (tool_only, target).final_state == SteamRestartOperationState.SUCCEEDED);
        assert (reconciler.reconcile_calls == 0);

        setup_native (out session, out control, out manager, out target);
        assert (manager.record (configuration_receipt (target)) == SteamRestartRecordResult.ADDED);
        reconciler = new ReconcilerFixture (); reconciler.next_result = SteamConfigurationMutationResult.FAILED;
        var failed = run (new SteamRestartOrchestrator (new SteamSessionService (session), manager,
            control, 0, 2, 2, reconciler), target);
        assert (failed.reason == SteamRestartFailureReason.CONFIGURATION_RECONCILIATION_FAILED);
        assert (control.launch_requests == 0);

        setup_native (out session, out control, out manager, out target);
        assert (manager.record (configuration_receipt (target)) == SteamRestartRecordResult.ADDED);
        reconciler = new ReconcilerFixture (); reconciler.next_result = SteamConfigurationMutationResult.PERSISTENCE_FAILED;
        var persistence_failed = run (new SteamRestartOrchestrator (new SteamSessionService (session), manager,
            control, 0, 2, 2, reconciler), target);
        assert (persistence_failed.reason == SteamRestartFailureReason.CONFIGURATION_RECONCILIATION_FAILED);
        assert (control.launch_requests == 0);
    }

    public void register_tests () {
        Test.add_func ("/steam-restart-orchestrator/no-pending-rejected", test_no_pending_rejected);
        Test.add_func ("/steam-restart-orchestrator/native-shutdown-and-new-generation", test_native_shutdown_and_new_generation);
        Test.add_func ("/steam-restart-orchestrator/preflight-rejections", test_preflight_rejections);
        Test.add_func ("/steam-restart-orchestrator/exit-timeout-does-not-launch", test_exit_timeout_does_not_launch);
        Test.add_func ("/steam-restart-orchestrator/second-request-rejected", test_second_request_is_rejected_without_disturbing_first);
        Test.add_func ("/steam-restart-orchestrator/cancel-before-dispatch", test_cancel_before_dispatch);
        Test.add_func ("/steam-restart-orchestrator/flatpak-safe-handling", test_flatpak_running_unsupported_and_stopped_relaunches_exact_id);
        Test.add_func ("/steam-restart-orchestrator/untrusted-metadata-cannot-execute", test_untrusted_metadata_never_changes_native_argv);
        Test.add_func ("/steam-restart-orchestrator/relaunch-does-not-prove-start", test_relaunch_request_does_not_prove_start);
        Test.add_func ("/steam-restart-orchestrator/stopped-native-and-original-identity", test_stopped_native_skips_shutdown_and_original_identity_is_not_success);
        Test.add_func ("/steam-restart-orchestrator/heuristic-game-and-unsupported-kinds", test_heuristic_game_and_unsupported_kinds_preserve_pending);
        Test.add_func ("/steam-restart-orchestrator/native-fallback-dispatch-is-nonblocking", test_native_fallback_dispatch_does_not_wait_for_application_exit);
        Test.add_func ("/steam-restart-orchestrator/reconciliation-is-ordered-before-launch", test_reconciliation_is_ordered_before_launch);
        Test.add_func ("/steam-restart-orchestrator/reconciliation-conflict-prevents-launch", test_reconciliation_conflict_prevents_launch);
        Test.add_func ("/steam-restart-orchestrator/reconciliation-outcomes-and-tool-only-receipts", test_reconciliation_outcomes_and_tool_only_receipts);
    }
}
