namespace AppTests.LaunchCommandWriterTest {
    using GLib;
    using ProtonPlus.Widgets.Games.LaunchOptionsEditor;

    public void register_tests () {
        Test.add_func ("/launch-command-writer/pristine-and-clear", test_pristine_and_clear);
        Test.add_func ("/launch-command-writer/fresh-and-preserving-merge", test_fresh_and_preserving_merge);
        Test.add_func ("/launch-command-writer/blocked-source", test_blocked_source);
        Test.add_func ("/launch-command-writer/managed-edit-preserves-boundary-and-legacy", test_managed_edit_preserves_boundary_and_legacy);
        Test.add_func ("/launch-command-writer/composite-output-has-one-owner", test_composite_output_has_one_owner);
        Test.add_func ("/launch-command-writer/post-boundary-assignment-blocks-edit", test_post_boundary_assignment_blocks_edit);
        Test.add_func ("/launch-command-writer/prepare-source-is-per-game", test_prepare_source_is_per_game);
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

    private void test_managed_edit_preserves_boundary_and_legacy () {
        var merged = write ("PROTON_LOG=1 %command% --custom-argument",
            { new LaunchCommandSelection ("gamemode") }, { "gamemode" },
            { LaunchOptionCapability.GAMEMODE });
        assert (merged.writing_allowed);
        assert (merged.launch_line == "PROTON_LOG=1 gamemoderun %command% --custom-argument");

        var unsupported = write ("VKD3D_GPUVA=1 %command% --custom-argument",
            { new LaunchCommandSelection ("gamemode") }, { "gamemode" },
            { LaunchOptionCapability.GAMEMODE });
        assert (unsupported.writing_allowed);
        assert (unsupported.launch_line == "VKD3D_GPUVA=1 gamemoderun %command% --custom-argument");
    }

    private void test_composite_output_has_one_owner () {
        var automatic = write ("%command%", {
            new LaunchCommandSelection ("launch-backend", {}, "scopebuddy"),
            new LaunchCommandSelection ("scopebuddy-resolution", { "auto" })
        }, { "launch-backend", "scopebuddy-resolution" }, { LaunchOptionCapability.SCOPEBUDDY });
        assert (automatic.writing_allowed);
        assert (automatic.launch_line == "SCB_AUTO_RES=1 scopebuddy -- %command%");

        var manual = write ("%command%", {
            new LaunchCommandSelection ("launch-backend", {}, "scopebuddy"),
            new LaunchCommandSelection ("scopebuddy-resolution", { "1920", "1080" })
        }, { "launch-backend", "scopebuddy-resolution" }, { LaunchOptionCapability.SCOPEBUDDY });
        assert (manual.writing_allowed);
        assert (manual.launch_line == "scopebuddy -W 1920 -H 1080 -- %command%");
    }

    private void test_post_boundary_assignment_blocks_edit () {
        var blocked = write ("%command% PROTON_LOG=1", { new LaunchCommandSelection ("gamemode") },
            { "gamemode" }, { LaunchOptionCapability.GAMEMODE });
        assert (blocked.status == LaunchCommandWriteStatus.BLOCKED_UNSAFE_SOURCE);
        assert (!blocked.writing_allowed);
    }

    private void test_prepare_source_is_per_game () {
        var writer = new LaunchCommandWriter ();
        LaunchCommandSelection[] selections = { new LaunchCommandSelection ("gamemode") };
        var first = writer.prepare_source ("PROTON_LOG=1 %command% --foo", selections, { "gamemode" }, {},
            new LaunchCommandCapabilityContext ({ LaunchOptionCapability.GAMEMODE }));
        var second = writer.prepare_source ("CUSTOM_ENV=\"value\" mangohud %command% --bar", selections,
            { "gamemode" }, {}, new LaunchCommandCapabilityContext ({ LaunchOptionCapability.GAMEMODE,
                LaunchOptionCapability.MANGOHUD }));
        assert (first.launch_line == "PROTON_LOG=1 gamemoderun %command% --foo");
        assert (second.launch_line == "CUSTOM_ENV=\"value\" mangohud gamemoderun %command% --bar");
    }
}
