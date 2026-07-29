namespace AppTests.SteamSessionTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Launchers;
    using ProtonPlus.Services;

    private class FakeBackend : Object, SteamSessionBackend {
        public NativeProcessQuery native_query = new NativeProcessQuery (true);
        public FlatpakProcessQuery flatpak_query = new FlatpakProcessQuery (true);
        public string? boot_id = "fixture-boot";
        public int64 now_usec = 100 * 1000 * 1000;
        public SteamDesktopEntry? desktop_entry = new SteamDesktopEntry ("steam.desktop", "/fixture/steam.desktop", true);
        public int native_calls = 0;
        public int flatpak_calls = 0;

        public string? get_boot_id () { return boot_id; }
        public int64 get_monotonic_time_usec () { return now_usec; }
        public int64 get_clock_ticks_per_second () { return 1000 * 1000; }
        public NativeProcessQuery query_native_processes () { native_calls++; return native_query; }
        public FlatpakProcessQuery query_flatpak_processes () { flatpak_calls++; return flatpak_query; }
        public SteamDesktopEntry? find_desktop_entry (string? id) { return desktop_entry; }
    }

    public void register_tests () {
        Test.add_func ("/steam-session/target-identity-and-launcher-capability", test_target_identity_and_launcher_capability);
        Test.add_func ("/steam-session/native-stopped-running-and-starting", test_native_states);
        Test.add_func ("/steam-session/native-ambiguity-and-blocker-evidence", test_native_ambiguity_and_blockers);
        Test.add_func ("/steam-session/flatpak-exact-match-and-unavailable", test_flatpak_states);
        Test.add_func ("/steam-session/generation-and-monitor-lifecycle", test_generation_and_monitor_lifecycle);
    }

    private string temporary_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-steam-session-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create temporary directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private SteamRestartTarget native_target (string root) {
        return SteamRestartTarget.for_native (root);
    }

    private SteamProcessRecord anchor (string root, int pid = 42, int64 start = 1 * 1000 * 1000, string extra = "") {
        return new SteamProcessRecord (pid, Path.build_filename (root, "ubuntu12_32", "steam"),
                                       "%s %s".printf (root, extra), start);
    }

    private void test_target_identity_and_launcher_capability () {
        var root = temporary_directory ();
        var steam_root = Path.build_filename (root, "Steam");
        assert (ProtonPlus.Utils.Filesystem.create_directory (steam_root));
        var spelling = Path.build_filename (root, "Steam", "..", "Steam");
        var direct = native_target (steam_root);
        var equivalent = native_target (spelling);
        assert (direct.id == equivalent.id);

        var link_path = Path.build_filename (root, "steam-link");
        assert (Posix.symlink (steam_root, link_path) == 0);
        assert (direct.id == native_target (link_path).id);
        assert (direct.id != native_target (Path.build_filename (root, "OtherSteam")).id);
        assert (direct.id != SteamRestartTarget.for_flatpak (Path.build_filename (root, "FlatpakSteam")).id);

        var steam = new ProtonPlus.Models.Launchers.Steam (Launcher.InstallationTypes.SYSTEM);
        steam.directory = steam_root;
        var steam_target = steam.get_steam_restart_target ();
        assert (steam_target != null);
        assert (((!) steam_target).id == direct.id);

        var faugus = new FaugusLauncher (
            Launcher.InstallationTypes.SYSTEM,
            Path.build_filename (root, "home"), root,
            Path.build_filename (root, "config"), Path.build_filename (root, "data"), Path.build_filename (root, "state")
        );
        var faugus_target = faugus.get_steam_restart_target ();
        assert (faugus_target != null);
        assert (((!) faugus_target).id == direct.id);
        var unrelated = new Launcher ("Other", Launcher.InstallationTypes.SYSTEM, "", {}, "other");
        assert (unrelated.get_steam_restart_target () == null);

        assert (FileUtils.remove (link_path) == 0);
        assert (DirUtils.remove (steam_root) == 0);
        assert (DirUtils.remove (root) == 0);
    }

    private void test_native_states () {
        var target = native_target ("/fixture/Steam");
        var backend = new FakeBackend ();
        var service = new SteamSessionService (backend);
        var stopped = service.inspect (target);
        assert (stopped.state == SteamSessionState.STOPPED);
        assert (!stopped.matching_process_found);
        assert (backend.native_calls == 1);

        var processes = new Gee.ArrayList<SteamProcessRecord> ();
        processes.add (anchor (target.data_root, 42, 1 * 1000 * 1000));
        backend.native_query = new NativeProcessQuery (true, processes);
        var running = service.inspect (target);
        assert (running.state == SteamSessionState.RUNNING);
        assert (running.main_process_pid == 42);
        assert (running.generation != null);
        assert (((!) running.generation).describe () == "fixture-boot:1000000:42");
        assert (running.relaunch.desktop_entry_path == "/fixture/steam.desktop");

        backend.now_usec = 10 * 1000 * 1000;
        processes.clear ();
        processes.add (anchor (target.data_root, 43, 1 * 1000 * 1000));
        var starting = service.inspect (target);
        assert (starting.state == SteamSessionState.STARTING);
        assert (starting.blockers.size == 1);

        processes.clear ();
        processes.add (anchor (target.data_root, 44, 1 * 1000 * 1000, "-update"));
        var updating = service.inspect (target);
        assert (updating.state == SteamSessionState.UPDATING);
    }

    private void test_native_ambiguity_and_blockers () {
        var target = native_target ("/fixture/Steam");
        var backend = new FakeBackend ();
        var processes = new Gee.ArrayList<SteamProcessRecord> ();
        processes.add (anchor (target.data_root, 42));
        processes.add (anchor (target.data_root, 43));
        backend.native_query = new NativeProcessQuery (true, processes);
        var service = new SteamSessionService (backend);
        assert (service.inspect (target).state == SteamSessionState.UNKNOWN);

        processes.clear ();
        processes.add (anchor (target.data_root));
        processes.add (new SteamProcessRecord (80, "/usr/bin/proton", target.data_root, 2 * 1000 * 1000));
        processes.add (new SteamProcessRecord (81, "/usr/bin/bash", "%s game.exe".printf (target.data_root), 2 * 1000 * 1000));
        var blocked = service.inspect (target);
        assert (blocked.state == SteamSessionState.RUNNING);
        assert (blocked.blockers.size == 2);
        assert (blocked.blockers[0].blocker == SteamSessionBlocker.GAME_OR_COMPATIBILITY_PROCESS);
        assert (blocked.blockers[0].confidence == SteamEvidenceLevel.CONFIRMED);

        backend.boot_id = null;
        assert (service.inspect (target).state == SteamSessionState.UNKNOWN);
    }

    private void test_flatpak_states () {
        var target = SteamRestartTarget.for_flatpak ("/fixture/FlatpakSteam");
        var backend = new FakeBackend ();
        var records = new Gee.ArrayList<FlatpakProcessRecord> ();
        records.add (new FlatpakProcessRecord ("wrong", "org.example.Other", 9, 10));
        backend.flatpak_query = new FlatpakProcessQuery (true, records);
        var service = new SteamSessionService (backend);
        assert (service.inspect (target).state == SteamSessionState.STOPPED);
        assert (backend.native_calls == 0);

        records.add (new FlatpakProcessRecord ("steam-instance", "com.valvesoftware.Steam", 20, 21));
        var running = service.inspect (target);
        assert (running.state == SteamSessionState.RUNNING);
        assert (running.main_process_pid == 21);
        assert (running.flatpak_instance_id == "steam-instance");

        backend.flatpak_query = new FlatpakProcessQuery (false, null, "flatpak ps unavailable");
        var unavailable = service.inspect (target);
        assert (unavailable.state == SteamSessionState.UNKNOWN);
        assert (unavailable.blockers[0].blocker == SteamSessionBlocker.UNKNOWN_PROCESS_STATE);
    }

    private void test_generation_and_monitor_lifecycle () {
        var first = new SteamProcessGeneration (42, 100, "boot-a");
        var reused = new SteamProcessGeneration (42, 101, "boot-a");
        var rebooted = new SteamProcessGeneration (42, 100, "boot-b");
        assert (first.describe () != reused.describe ());
        assert (first.describe () != rebooted.describe ());

        var backend = new FakeBackend ();
        var service = new SteamSessionService (backend);
        var target = native_target ("/fixture/Steam");
        service.watch_target (target);
        var emissions = 0;
        SteamSessionState last_state = SteamSessionState.UNKNOWN;
        service.state_changed.connect ((changed_target, snapshot) => { emissions++; last_state = snapshot.state; });
        service.poll_monitored ();
        assert (emissions == 1);
        var processes = new Gee.ArrayList<SteamProcessRecord> ();
        processes.add (anchor (target.data_root));
        backend.native_query = new NativeProcessQuery (true, processes);
        service.poll_monitored ();
        processes.clear ();
        service.poll_monitored ();
        assert (last_state == SteamSessionState.SHUTTING_DOWN);
        service.start_monitoring ();
        assert (service.is_monitoring);
        service.stop_monitoring ();
        assert (!service.is_monitoring);
        assert (backend.native_calls == 3);
    }
}
