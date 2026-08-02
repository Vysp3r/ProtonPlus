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
        Test.add_func ("/launch-command-writer/clear-remains-a-replacement-session", test_clear_remains_a_replacement_session);
        Test.add_func ("/launch-command-writer/edit-state-preserves-clear-intent", test_edit_state_preserves_clear_intent);
        Test.add_func ("/launch-command-writer/custom-arguments-replace-unrecognized-arguments", test_custom_arguments_replace_unrecognized_arguments);
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

        var cleared_opaque = write ("$(custom-wrapper) && %command%", {}, {}, {}, true);
        assert (cleared_opaque.writing_allowed);
        assert (cleared_opaque.requires_persistence);
        assert (cleared_opaque.launch_line == "");
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

    private void test_clear_remains_a_replacement_session () {
        var cleared_with_replacement = write (
            "UNKNOWN_VALUE=one %command% --old-argument",
            { new LaunchCommandSelection ("proton-debug-log") },
            { "proton-debug-log" },
            { LaunchOptionCapability.PROTON },
            true
        );
        assert (cleared_with_replacement.writing_allowed);
        assert (cleared_with_replacement.requires_persistence);
        assert (cleared_with_replacement.launch_line == "PROTON_LOG=1 %command%");

        var cleared_with_argument = write (
            "%command% --old-argument",
            { new LaunchCommandSelection ("developer-console") },
            { "developer-console" }, {}, true
        );
        assert (cleared_with_argument.writing_allowed);
        assert (cleared_with_argument.launch_line == "-console");
    }

    private class MutableSelectionSource : Object, ILaunchCommandSelectionSource {
        public string option_id { get; set; }
        public LaunchCommandSelection? selection;

        public MutableSelectionSource (string option_id, LaunchCommandSelection? selection = null) {
            this.option_id = option_id;
            this.selection = selection;
        }

        public LaunchCommandSelection? get_selection () {
            return selection;
        }
    }

    private void test_edit_state_preserves_clear_intent () {
        var source = new MutableSelectionSource (
            "proton-debug-log", new LaunchCommandSelection ("proton-debug-log")
        );
        var sources = new Gee.ArrayList<ILaunchCommandSelectionSource> ();
        sources.add (source);
        var state = new LaunchCommandEditState ();
        state.record_baseline (sources);

        source.selection = null;
        state.update (sources);
        assert (state.is_option_modified ("proton-debug-log"));
        assert (state.is_dirty);
        state.mark_explicit_clear (sources);
        assert (state.explicit_clear);
        assert (state.is_dirty);

        source.selection = new LaunchCommandSelection ("proton-debug-log");
        state.update (sources);
        assert (state.explicit_clear);
        assert (state.is_dirty);
    }

    private void test_custom_arguments_replace_unrecognized_arguments () {
        var preserved_while_editing_another_option = write (
            "--old 'old value'",
            {
                new LaunchCommandSelection ("proton-debug-log"),
                new LaunchCommandSelection ("custom-game-arguments", { "--old", "old value" })
            },
            { "proton-debug-log" }, { LaunchOptionCapability.PROTON }
        );
        assert (preserved_while_editing_another_option.writing_allowed);
        assert (preserved_while_editing_another_option.launch_line == "PROTON_LOG=1 %command% --old 'old value'");

        var replaced = write (
            "PROTON_LOG=1 %command% --old 'old value'",
            {
                new LaunchCommandSelection ("proton-debug-log"),
                new LaunchCommandSelection ("custom-game-arguments", { "--new", "new value" })
            },
            { "custom-game-arguments" }, { LaunchOptionCapability.PROTON }
        );
        assert (replaced.writing_allowed);
        assert (replaced.launch_line == "PROTON_LOG=1 %command% --new 'new value'");

        var arguments_only = write (
            "--old value",
            { new LaunchCommandSelection ("custom-game-arguments", { "--new" }) },
            { "custom-game-arguments" }
        );
        assert (arguments_only.writing_allowed);
        assert (arguments_only.launch_line == "--new");
    }
}
