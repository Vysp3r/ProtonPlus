namespace AppTests.LaunchCommandWriterTest {
    using GLib;
    using ProtonPlus.Widgets.Games.LaunchOptionsEditor;

    public void register_tests () {
        Test.add_func ("/launch-command-writer/pristine-and-clear", test_pristine_and_clear);
        Test.add_func ("/launch-command-writer/fresh-and-preserving-merge", test_fresh_and_preserving_merge);
        Test.add_func ("/launch-command-writer/blocked-source", test_blocked_source);
    }

    private LaunchCommandWriteResult write (string source, LaunchCommandSelection[] selections,
                                            string[] changed = {}, LaunchOptionCapability[] capabilities = {},
                                            bool clear = false) {
        var parser = new LaunchCommandParser ();
        return new LaunchCommandWriter ().prepare (new LaunchCommandWriteRequest (parser.parse (source), selections,
            changed, {}, new LaunchCommandCapabilityContext (capabilities), clear,
            source == "%command%"));
    }

    private void test_pristine_and_clear () {
        var source = "  PROTON_LOG=1  %command% --mod-loader=\\\"custom path\\\"  ";
        var pristine = write (source, {});
        assert (pristine.status == LaunchCommandWriteStatus.UNCHANGED_PRISTINE_SOURCE);
        assert (pristine.writing_allowed);
        assert (!pristine.requires_persistence);
        assert (pristine.launch_line == source);

        var cleared = write (source, {}, { "proton-debug-log" }, {}, true);
        assert (cleared.writing_allowed);
        assert (cleared.requires_persistence);
        assert (cleared.launch_line == "");
    }

    private void test_fresh_and_preserving_merge () {
        var fresh = write ("", { new LaunchCommandSelection ("proton-debug-log") },
            { "proton-debug-log" }, { LaunchOptionCapability.PROTON });
        assert (fresh.status == LaunchCommandWriteStatus.FRESH_MANAGED_OUTPUT);
        assert (fresh.launch_line == "PROTON_LOG=1 %command%");

        var merged = write ("PROTON_USE_NTSYNC=0 %command% --mod-loader=\"custom path\"",
            { new LaunchCommandSelection ("ntsync-mode"), new LaunchCommandSelection ("gamemode") },
            { "gamemode" }, { LaunchOptionCapability.PROTON, LaunchOptionCapability.GAMEMODE });
        assert (merged.status == LaunchCommandWriteStatus.SOURCE_PRESERVING_MANAGED_MERGE);
        assert (merged.writing_allowed);
        assert (merged.launch_line == "PROTON_USE_NTSYNC=0 gamemoderun %command% --mod-loader=\"custom path\"");

        var arguments_only = write ("-console", { new LaunchCommandSelection ("developer-console"),
            new LaunchCommandSelection ("proton-debug-log") }, { "proton-debug-log" },
            { LaunchOptionCapability.PROTON });
        assert (arguments_only.launch_line == "PROTON_LOG=1 %command% -console");
    }

    private void test_blocked_source () {
        var blocked = write ("custom-wrapper %command%", { new LaunchCommandSelection ("gamemode") },
            { "gamemode" }, { LaunchOptionCapability.GAMEMODE });
        assert (blocked.status == LaunchCommandWriteStatus.BLOCKED_UNSAFE_SOURCE);
        assert (!blocked.writing_allowed);
        assert (blocked.launch_line == "");
    }
}
