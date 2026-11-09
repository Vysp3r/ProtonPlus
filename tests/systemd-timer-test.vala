namespace AppTests.SystemdTimerTest {
    using GLib;
    using ProtonPlus.Utils;

    private const string SERVICE_TEMPLATE = "[Service]\nExecStart={ExecStart}\n";
    private const string TIMER_TEMPLATE = "[Timer]\nOnBootSec=1min\nOnUnitActiveSec={OnUnitActiveSec}\n";

    private class FakeSystemctlBackend : Object, SystemctlBackend {
        public bool enabled = false;
        public bool active = false;
        public Gee.ArrayList<string> calls = new Gee.ArrayList<string> ();

        public async CommandResult run (string arguments) {
            calls.add (arguments);
            switch (arguments) {
            case "is-enabled --quiet protonplus.timer":
                return result (enabled ? 0 : 1);
            case "is-active --quiet protonplus.timer":
                return result (active ? 0 : 3);
            case "enable --now protonplus.timer":
                enabled = true;
                active = true;
                return result (0);
            case "disable --now protonplus.timer":
                enabled = false;
                active = false;
                return result (0);
            case "daemon-reload":
            case "restart protonplus.timer":
                return result (0);
            default:
                return result (1);
            }
        }

        private CommandResult result (int exit_status) {
            return new CommandResult ("", "", exit_status);
        }

        public void clear_calls () {
            calls.clear ();
        }
    }

    public void register_tests () {
        Test.add_func ("/systemd-timer/native-user-directory", test_native_user_directory);
        Test.add_func ("/systemd-timer/flatpak-host-user-directory", test_flatpak_host_user_directory);
        Test.add_func ("/systemd-timer/flatpak-missing-host-directory-fallback", test_flatpak_missing_host_directory_fallback);
        Test.add_func ("/systemd-timer/new-schedule-starts-immediately", test_new_schedule_starts_immediately);
        Test.add_func ("/systemd-timer/schedule-change-restarts-active-timer", test_schedule_change_restarts_active_timer);
        Test.add_func ("/systemd-timer/startup-reenables-disabled-timer", test_startup_reenables_disabled_timer);
        Test.add_func ("/systemd-timer/startup-repairs-missing-unit", test_startup_repairs_missing_unit);
    }

    private string temporary_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-systemd-timer-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create temporary directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private SystemdTimerManager manager_for (string root, FakeSystemctlBackend backend) {
        return new SystemdTimerManager (
            backend, root, SERVICE_TEMPLATE, TIMER_TEMPLATE, "/fixture/protonplus update all"
        );
    }

    private bool reconcile (
        SystemdTimerManager manager,
        bool check_on_boot = true,
        bool background_updates = true,
        int frequency = 0
    ) {
        var loop = new MainLoop ();
        var reconciled = false;
        manager.reconcile.begin (check_on_boot, background_updates, frequency, (obj, response) => {
            reconciled = manager.reconcile.end (response);
            loop.quit ();
        });
        loop.run ();
        return reconciled;
    }

    private void assert_calls (FakeSystemctlBackend backend, string[] expected) {
        assert (backend.calls.size == expected.length);
        for (var index = 0; index < expected.length; index++)
            assert (backend.calls[index] == expected[index]);
    }

    private void remove_fixture (string root) {
        var service_path = Path.build_filename (root, "protonplus.service");
        var timer_path = Path.build_filename (root, "protonplus.timer");
        if (FileUtils.test (service_path, FileTest.EXISTS))
            assert (FileUtils.remove (service_path) == 0);
        if (FileUtils.test (timer_path, FileTest.EXISTS))
            assert (FileUtils.remove (timer_path) == 0);
        assert (DirUtils.remove (root) == 0);
    }

    private void test_native_user_directory () {
        var path = System.get_systemd_user_dir_for_environment (
            false,
            "/home/test/.config",
            null
        );
        assert (path == "/home/test/.config/systemd/user");
    }

    private void test_flatpak_host_user_directory () {
        var path = System.get_systemd_user_dir_for_environment (
            true,
            "/home/test/.var/app/com.vysp3r.ProtonPlus/config",
            "/home/test/.config"
        );
        assert (path == "/home/test/.config/systemd/user");
    }

    private void test_flatpak_missing_host_directory_fallback () {
        var path = System.get_systemd_user_dir_for_environment (
            true,
            "/home/test/.var/app/com.vysp3r.ProtonPlus/config",
            ""
        );
        assert (path == "/home/test/.var/app/com.vysp3r.ProtonPlus/config/systemd/user");
    }

    private void test_new_schedule_starts_immediately () {
        var root = temporary_directory ();
        var backend = new FakeSystemctlBackend ();
        assert (reconcile (manager_for (root, backend)));
        assert_calls (backend, {
            "daemon-reload",
            "is-enabled --quiet protonplus.timer",
            "is-active --quiet protonplus.timer",
            "enable --now protonplus.timer"
        });
        assert (backend.enabled && backend.active);

        string timer_contents;
        try {
            assert (FileUtils.get_contents (Path.build_filename (root, "protonplus.timer"), out timer_contents));
        } catch (FileError e) {
            assert_not_reached ();
        }
        assert (timer_contents.contains ("OnBootSec=1min"));
        assert (timer_contents.contains ("OnUnitActiveSec=1h"));
        remove_fixture (root);
    }

    private void test_schedule_change_restarts_active_timer () {
        var root = temporary_directory ();
        var backend = new FakeSystemctlBackend ();
        var manager = manager_for (root, backend);
        assert (reconcile (manager));
        backend.clear_calls ();

        assert (reconcile (manager, true, true, 3));
        assert_calls (backend, {
            "daemon-reload",
            "is-enabled --quiet protonplus.timer",
            "is-active --quiet protonplus.timer",
            "restart protonplus.timer"
        });

        string timer_contents;
        try {
            assert (FileUtils.get_contents (Path.build_filename (root, "protonplus.timer"), out timer_contents));
        } catch (FileError e) {
            assert_not_reached ();
        }
        assert (timer_contents.contains ("OnUnitActiveSec=12h"));
        remove_fixture (root);
    }

    private void test_startup_reenables_disabled_timer () {
        var root = temporary_directory ();
        var backend = new FakeSystemctlBackend ();
        var manager = manager_for (root, backend);
        assert (reconcile (manager));
        backend.enabled = false;
        backend.active = false;
        backend.clear_calls ();

        assert (reconcile (manager));
        assert_calls (backend, {
            "is-enabled --quiet protonplus.timer",
            "is-active --quiet protonplus.timer",
            "enable --now protonplus.timer"
        });
        assert (backend.enabled && backend.active);
        remove_fixture (root);
    }

    private void test_startup_repairs_missing_unit () {
        var root = temporary_directory ();
        var backend = new FakeSystemctlBackend ();
        var manager = manager_for (root, backend);
        assert (reconcile (manager));
        assert (FileUtils.remove (Path.build_filename (root, "protonplus.timer")) == 0);
        backend.active = false;
        backend.clear_calls ();

        assert (reconcile (manager));
        assert (FileUtils.test (Path.build_filename (root, "protonplus.timer"), FileTest.EXISTS));
        assert_calls (backend, {
            "daemon-reload",
            "is-enabled --quiet protonplus.timer",
            "is-active --quiet protonplus.timer",
            "enable --now protonplus.timer"
        });
        remove_fixture (root);
    }
}
