namespace AppTests.CompatibilityProcessGuardTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Services;

    private class FixtureBackend : Object, CompatibilityProcessQueryBackend {
        private Gee.List<CompatibilityProcessRecord> processes;

        public FixtureBackend (Gee.List<CompatibilityProcessRecord> processes) {
            this.processes = processes;
        }

        public Gee.List<CompatibilityProcessRecord> query_processes () {
            return processes;
        }
    }

    public void register_tests () {
        Test.add_func ("/compatibility-process-guard/detects-supported-runner-tokens", test_detects_supported_runner_tokens);
        Test.add_func ("/compatibility-process-guard/ignores-lookalikes-and-text", test_ignores_lookalikes_and_text);
    }

    private CompatibilityProcessGuard guard_for (string executable, string[] argv) {
        var processes = new Gee.ArrayList<CompatibilityProcessRecord> ();
        var values = new Gee.ArrayList<string> ();
        foreach (var value in argv)
            values.add (value);
        processes.add (new CompatibilityProcessRecord (executable, values));
        return new CompatibilityProcessGuard (new FixtureBackend (processes));
    }

    private void test_detects_supported_runner_tokens () {
        string[] executables = { "/tmp/Proton/proton", "/usr/bin/umu-run", "/usr/bin/wine", "/usr/bin/wine64", "/games/Runner.exe" };
        foreach (var executable in executables) {
            assert (guard_for (executable, { executable }).check () == ReturnCode.RUNNERS_IN_USE);
        }
    }

    private void test_ignores_lookalikes_and_text () {
        assert (guard_for ("/tmp/protonplus-tests", { "/tmp/protonplus-tests" }).check () == ReturnCode.RUNNER_INSTALLED);
        assert (guard_for ("/tmp/unrelated-winery", { "/tmp/unrelated-winery" }).check () == ReturnCode.RUNNER_INSTALLED);
        assert (guard_for ("/usr/bin/echo", { "echo", "Proton is mentioned in this text argument" }).check () == ReturnCode.RUNNER_INSTALLED);
    }
}
