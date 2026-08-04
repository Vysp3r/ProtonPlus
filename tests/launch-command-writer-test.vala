namespace AppTests.LaunchCommandWriterTest {
    using GLib;
    using ProtonPlus.Widgets.Games.LaunchOptionsEditor;

    public void register_tests () {
        Test.add_func ("/launch-command-writer/pristine-and-clear", test_pristine_and_clear);
        Test.add_func ("/launch-command-writer/fresh-and-preserving-merge", test_fresh_and_preserving_merge);
        Test.add_func ("/launch-command-writer/unsafe-source-is-blocked", test_unsafe_source_is_blocked);
        Test.add_func ("/launch-command-writer/custom-prefix-combines-with-managed-options", test_custom_prefix_combines_with_managed_options);
        Test.add_func ("/launch-command-writer/managed-edit-preserves-boundary-and-legacy", test_managed_edit_preserves_boundary_and_legacy);
        Test.add_func ("/launch-command-writer/composite-output-has-one-owner", test_composite_output_has_one_owner);
        Test.add_func ("/launch-command-writer/post-boundary-assignment-is-custom-argument", test_post_boundary_assignment_is_custom_argument);
        Test.add_func ("/launch-command-writer/prepare-source-is-per-game", test_prepare_source_is_per_game);
        Test.add_func ("/launch-command-writer/clear-remains-a-replacement-session", test_clear_remains_a_replacement_session);
        Test.add_func ("/launch-command-writer/edit-state-preserves-clear-intent", test_edit_state_preserves_clear_intent);
        Test.add_func ("/launch-command-writer/custom-arguments-replace-unrecognized-arguments", test_custom_arguments_replace_unrecognized_arguments);
        Test.add_func ("/launch-command-writer/custom-arguments-preserve-source-anchors", test_custom_arguments_preserve_source_anchors);
        Test.add_func ("/launch-command-writer/opaque-custom-argument-survives-managed-edit", test_opaque_custom_argument_survives_managed_edit);
        Test.add_func ("/launch-command-writer/pre-command-custom-argument-keeps-its-slot", test_pre_command_custom_argument_keeps_its_slot);
        Test.add_func ("/launch-command-writer/custom-argument-anchors-are-source-local", test_custom_argument_anchors_are_source_local);
        Test.add_func ("/launch-command-writer/intentional-custom-duplicates-survive", test_intentional_custom_duplicates_survive);
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

    private void test_unsafe_source_is_blocked () {
        var blocked = write ("$(custom-wrapper) %command%", { new LaunchCommandSelection ("gamemode") },
            { "gamemode" }, { LaunchOptionCapability.GAMEMODE });
        assert (blocked.status == LaunchCommandWriteStatus.BLOCKED_UNSAFE_SOURCE);
        assert (!blocked.writing_allowed);
        assert (blocked.launch_line == "");
    }

    private void test_custom_prefix_combines_with_managed_options () {
        var source = "PROTON_USE_WAYLAND=1 game-performance %command%";
        var parsed = new LaunchCommandParser ().parse (source);
        var custom = parsed.get_custom_game_arguments ();
        var indexes = parsed.get_custom_game_argument_indexes ();
        assert (custom.size == 2);
        assert (custom[0].raw == "PROTON_USE_WAYLAND=1");
        assert (custom[1].raw == "game-performance");

        var skip_launcher = write (source, {
            new LaunchCommandSelection ("custom-game-arguments",
                { custom[0].raw, custom[1].raw }, "", {}, true, indexes, source),
            new LaunchCommandSelection ("skip-launcher")
        }, { "skip-launcher" });
        assert (skip_launcher.writing_allowed);
        assert (skip_launcher.launch_line
            == "PROTON_USE_WAYLAND=1 game-performance %command% -skip-launcher");

        var combined = write (source, {
            new LaunchCommandSelection ("proton-debug-log"),
            new LaunchCommandSelection ("gamemode"),
            new LaunchCommandSelection ("skip-launcher"),
            new LaunchCommandSelection ("custom-game-arguments",
                { custom[0].raw, "game-performance-v2", "--new-custom" },
                "", {}, true, { indexes[0], indexes[1], -1 }, source)
        }, { "proton-debug-log", "gamemode", "skip-launcher", "custom-game-arguments" },
            { LaunchOptionCapability.PROTON, LaunchOptionCapability.GAMEMODE });
        assert (combined.writing_allowed);
        assert (combined.launch_line
            == "PROTON_USE_WAYLAND=1 PROTON_LOG=1 game-performance-v2 gamemoderun %command% -skip-launcher --new-custom");

        var removed = write (
            "PROTON_USE_WAYLAND=1 game-performance %command% -skip-launcher",
            { new LaunchCommandSelection ("custom-game-arguments",
                { "PROTON_USE_WAYLAND=1", "game-performance" }) },
            { "skip-launcher" }
        );
        assert (removed.writing_allowed);
        assert (removed.launch_line == "PROTON_USE_WAYLAND=1 game-performance %command%");

        var fresh_combined = write ("", {
            new LaunchCommandSelection ("skip-launcher"),
            new LaunchCommandSelection ("custom-game-arguments", { "--new-custom" }, "", {}, true)
        }, { "skip-launcher", "custom-game-arguments" });
        assert (fresh_combined.writing_allowed);
        assert (fresh_combined.launch_line == "-skip-launcher --new-custom");
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

    private void test_post_boundary_assignment_is_custom_argument () {
        var merged = write ("%command% PROTON_LOG=1", { new LaunchCommandSelection ("gamemode") },
            { "gamemode" }, { LaunchOptionCapability.GAMEMODE });
        assert (merged.writing_allowed);
        assert (merged.launch_line == "gamemoderun %command% PROTON_LOG=1");
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
        assert (!state.is_dirty);

        source.selection = null;
        state.update (sources);
        assert (state.is_option_modified ("proton-debug-log"));
        assert (state.is_dirty);

        source.selection = new LaunchCommandSelection ("proton-debug-log");
        state.update (sources);
        assert (!state.is_option_modified ("proton-debug-log"));
        assert (!state.is_dirty);

        source.selection = null;
        state.update (sources);
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

    private void test_custom_arguments_preserve_source_anchors () {
        var source = "PROTON_LOG=1 %command% --first=\"Exact one\" -console '--second=Exact two'";
        var parsed = new LaunchCommandParser ().parse (source);
        var indexes = parsed.get_custom_game_argument_indexes ();
        assert (indexes.length == 2);

        var removed_first_and_edited_second = write (
            source,
            {
                new LaunchCommandSelection ("proton-debug-log"),
                new LaunchCommandSelection ("developer-console"),
                new LaunchCommandSelection ("custom-game-arguments",
                    { "--second=\"Edited exactly\"" }, "", {}, true, { indexes[1] })
            },
            { "custom-game-arguments" }, { LaunchOptionCapability.PROTON }
        );
        assert (removed_first_and_edited_second.writing_allowed);
        assert (removed_first_and_edited_second.launch_line
            == "PROTON_LOG=1 %command% -console --second=\"Edited exactly\"");

        var added = write (
            source,
            {
                new LaunchCommandSelection ("proton-debug-log"),
                new LaunchCommandSelection ("developer-console"),
                new LaunchCommandSelection ("custom-game-arguments",
                    { "--first=\"Exact one\"", "'--second=Exact two'", "--new=\"Keep this\"" },
                    "", {}, true, { indexes[0], indexes[1], -1 })
            },
            { "custom-game-arguments" }, { LaunchOptionCapability.PROTON }
        );
        assert (added.writing_allowed);
        assert (added.launch_line
            == "PROTON_LOG=1 %command% --first=\"Exact one\" -console '--second=Exact two' --new=\"Keep this\"");
    }

    private void test_opaque_custom_argument_survives_managed_edit () {
        var source = "  %command% --before $(opaque) -console  ";
        var pristine = write (source, {});
        assert (pristine.writing_allowed);
        assert (!pristine.requires_persistence);
        assert (pristine.launch_line == source);

        var parsed = new LaunchCommandParser ().parse (source);
        var custom = parsed.get_custom_game_arguments ();
        var indexes = parsed.get_custom_game_argument_indexes ();
        assert (custom.size == 2);
        assert (custom[1].raw == "$(opaque)");

        var merged = write (
            source,
            {
                new LaunchCommandSelection ("gamemode"),
                new LaunchCommandSelection ("developer-console"),
                new LaunchCommandSelection ("custom-game-arguments",
                    { custom[0].raw, custom[1].raw }, "", {}, true, indexes)
            },
            { "gamemode" }, { LaunchOptionCapability.GAMEMODE }
        );
        assert (merged.writing_allowed);
        assert (merged.launch_line == "gamemoderun %command% --before $(opaque) -console");
    }

    private void test_pre_command_custom_argument_keeps_its_slot () {
        var source = "custom-wrapper gamescope --unknown-wrapper-value -- %command% --game-value";
        var parsed = new LaunchCommandParser ().parse (source);
        var custom = parsed.get_custom_game_arguments ();
        var indexes = parsed.get_custom_game_argument_indexes ();
        assert (custom.size == 3);

        var edited = write (
            source,
            {
                new LaunchCommandSelection ("launch-backend", {}, "gamescope"),
                new LaunchCommandSelection ("custom-game-arguments", {
                    "custom-wrapper-v2", "--edited-wrapper-value", "--game-value"
                }, "", {}, true, indexes)
            },
            { "custom-game-arguments" }, { LaunchOptionCapability.GAMESCOPE }
        );
        assert (edited.writing_allowed);
        assert (edited.launch_line
            == "custom-wrapper-v2 gamescope --edited-wrapper-value -- %command% --game-value");
    }

    private void test_custom_argument_anchors_are_source_local () {
        var primary_source = "%command% --primary";
        var primary = new LaunchCommandParser ().parse (primary_source);
        var selection = new LaunchCommandSelection (
            "custom-game-arguments", { "--replacement" }, "", {}, true,
            primary.get_custom_game_argument_indexes (), primary_source
        );

        var secondary = write (
            "PROTON_LOG=1 %command% --secondary",
            { new LaunchCommandSelection ("proton-debug-log"), selection },
            { "custom-game-arguments" }, { LaunchOptionCapability.PROTON }
        );
        assert (secondary.writing_allowed);
        assert (secondary.launch_line == "PROTON_LOG=1 %command% --replacement");
    }

    private void test_intentional_custom_duplicates_survive () {
        var merged = write (
            "%command% --tag --tag",
            { new LaunchCommandSelection ("gamemode") },
            { "gamemode" }, { LaunchOptionCapability.GAMEMODE }
        );
        assert (merged.writing_allowed);
        assert (merged.launch_line == "gamemoderun %command% --tag --tag");
    }
}
