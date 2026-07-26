namespace AppTests.CliTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/cli/exit-codes", test_exit_codes);
    }

    private int run_cli (string[] args) {
        var loop = new MainLoop ();
        var handler = new ProtonPlus.CLI.Handler ();
        var exit_code = -1;

        handler.run.begin (args, (obj, result) => {
            exit_code = handler.run.end (result);
            loop.quit ();
        });
        loop.run ();

        return exit_code;
    }

    private void test_exit_codes () {
        assert (run_cli ({ "protonplus" }) == 1);
        assert (run_cli ({ "protonplus", "version" }) == 0);
        assert (run_cli ({ "protonplus", "help" }) == 0);
        assert (run_cli ({ "protonplus", "unknown" }) == 1);
    }
}
