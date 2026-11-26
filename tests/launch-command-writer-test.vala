namespace AppTests.LaunchCommandWriterTest {
    using GLib;
    using ProtonPlus.LaunchOptions;

    public void register_tests () {
        Test.add_func ("/launch-command-writer/runtime-values", test_runtime_values);
        Test.add_func ("/launch-command-writer/corrected-flags-and-wrapper-order", test_corrected_flags_and_wrapper_order);
        Test.add_func ("/launch-command-writer/pristine-and-clear", test_pristine_and_clear);
        Test.add_func ("/launch-command-writer/quoted-source-survives-no-op", test_quoted_source_survives_no_op);
        Test.add_func ("/launch-command-writer/opaque-source-survives-no-op", test_opaque_source_survives_no_op);
        Test.add_func ("/launch-command-writer/removing-control-preserves-raw-content", test_removing_control_preserves_raw_content);
        Test.add_func ("/launch-command-writer/catalog-views-do-not-affect-serialization", test_catalog_views_do_not_affect_serialization);
        Test.add_func ("/launch-command-writer/fresh-and-preserving-merge", test_fresh_and_preserving_merge);
        Test.add_func ("/launch-command-writer/unsafe-source-is-blocked", test_unsafe_source_is_blocked);
        Test.add_func ("/launch-command-writer/custom-prefix-combines-with-managed-options", test_custom_prefix_combines_with_managed_options);
        Test.add_func ("/launch-command-writer/managed-edit-preserves-boundary-and-legacy", test_managed_edit_preserves_boundary_and_legacy);
        Test.add_func ("/launch-command-writer/composite-output-has-one-owner", test_composite_output_has_one_owner);
        Test.add_func ("/launch-command-writer/post-boundary-assignment-is-custom-argument", test_post_boundary_assignment_is_custom_argument);
        Test.add_func ("/launch-command-writer/prepare-source-is-per-game", test_prepare_source_is_per_game);
        Test.add_func ("/launch-command-writer/bulk-additions-preserve-custom-source", test_bulk_additions_preserve_custom_source);
        Test.add_func ("/launch-command-writer/wrapper-edit-retains-untouched-arguments", test_wrapper_edit_retains_untouched_arguments);
        Test.add_func ("/launch-command-writer/remove-argument-from-existing-backend", test_remove_argument_from_existing_backend);
        Test.add_func ("/launch-command-writer/backend-refresh-and-frame-limit", test_backend_refresh_and_frame_limit);
        Test.add_func ("/launch-command-writer/scopebuddy-config-and-diagnostics", test_scopebuddy_config_and_diagnostics);
        Test.add_func ("/launch-command-writer/gamescope-display-controls", test_gamescope_display_controls);
        Test.add_func ("/launch-command-writer/native-wrapper-executables", test_native_wrapper_executables);
        Test.add_func ("/launch-command-writer/obs-capture-forms", test_obs_capture_forms);
        Test.add_func ("/launch-command-writer/wrapper-edit-preserves-duplicates-and-order", test_wrapper_edit_preserves_duplicates_and_order);
        Test.add_func ("/launch-command-writer/clear-remains-a-replacement-session", test_clear_remains_a_replacement_session);
        Test.add_func ("/launch-command-writer/edit-state-preserves-clear-intent", test_edit_state_preserves_clear_intent);
        Test.add_func ("/launch-command-writer/custom-arguments-replace-unrecognized-arguments", test_custom_arguments_replace_unrecognized_arguments);
        Test.add_func ("/launch-command-writer/custom-arguments-preserve-source-anchors", test_custom_arguments_preserve_source_anchors);
        Test.add_func ("/launch-command-writer/opaque-custom-argument-survives-managed-edit", test_opaque_custom_argument_survives_managed_edit);
        Test.add_func ("/launch-command-writer/pre-command-custom-argument-keeps-its-slot", test_pre_command_custom_argument_keeps_its_slot);
        Test.add_func ("/launch-command-writer/custom-argument-anchors-are-source-local", test_custom_argument_anchors_are_source_local);
        Test.add_func ("/launch-command-writer/intentional-custom-duplicates-survive", test_intentional_custom_duplicates_survive);
        Test.add_func ("/launch-command-writer/append-arguments-before-trailing-comment", test_append_arguments_before_trailing_comment);
        Test.add_func ("/launch-command-writer/current-options-preview-and-validation", test_current_options_preview_and_validation);
        Test.add_func ("/launch-command-writer/custom-wrapper-lifecycle", test_custom_wrapper_lifecycle);
        Test.add_func ("/launch-command-writer/custom-wrapper-preserves-backends", test_custom_wrapper_preserves_backends);
        Test.add_func ("/launch-command-writer/custom-wrapper-batch", test_custom_wrapper_batch);
    }

    private LaunchCommandWriteResult write (string source, LaunchCommandSelection[] selections,
                                            string[] changed = {}, LaunchOptionCapability[] capabilities = {},
                                            bool clear = false) {
        var parser = new LaunchCommandParser ();
        return new LaunchCommandWriter ().prepare (new LaunchCommandWriteRequest (parser.parse (source), selections,
            changed, {}, new LaunchCommandCapabilityContext (capabilities), clear,
            source == "%command%"));
    }

    private void test_runtime_values () {
        var capabilities = new LaunchOptionCapability[] {
            LaunchOptionCapability.PROTON, LaunchOptionCapability.PROTON_OPTISCALER,
            LaunchOptionCapability.AMD, LaunchOptionCapability.PROTON_FSR4, LaunchOptionCapability.PROTON_MLFG,
            LaunchOptionCapability.DXVK_FRAME_CONFIG, LaunchOptionCapability.GAMEMODE
        };
        var pinned = "PROTON_USE_OPTISCALER='v0.9.0' PROTON_FSR4_UPGRADE=4.0.3 USER_ENV=\"keep spacing\" %command%";
        var unrelated = write (pinned, { new LaunchCommandSelection ("gamemode") }, { "gamemode" }, capabilities);
        assert (unrelated.writing_allowed);
        assert (unrelated.launch_line == pinned.replace ("%command%", "gamemoderun %command%"));
        var explicit_off = write (pinned, { new LaunchCommandSelection ("amd-mlfg", { "0" }) },
            { "amd-mlfg" }, capabilities);
        assert (explicit_off.writing_allowed && explicit_off.launch_line.contains ("PROTON_MLFG_UPGRADE=0"));
        var limit = new LaunchCommandSelection ("dxvk-config-frame-limit", { "-60" });
        var fresh = write ("", { limit }, { limit.option_id }, capabilities);
        assert (fresh.writing_allowed && fresh.launch_line == "DXVK_CONFIG='dxvk.maxFrameRate = -60' %command%");
        var updated = write (fresh.launch_line,
            { new LaunchCommandSelection (limit.option_id, { "144" }) }, { limit.option_id }, capabilities);
        assert (updated.writing_allowed && updated.launch_line == "DXVK_CONFIG='dxvk.maxFrameRate = 144' %command%");
        var compound = "DXVK_CONFIG='dxvk.maxFrameRate = 30; dxgi.hideAmdGpu=True' %command%";
        var protected_source = write (compound, { limit }, { limit.option_id }, capabilities);
        assert (!protected_source.writing_allowed);
        var preserved_config = write (compound, { new LaunchCommandSelection ("gamemode") }, { "gamemode" }, capabilities);
        assert (preserved_config.writing_allowed && preserved_config.launch_line == compound.replace ("%command%", "gamemoderun %command%"));
    }

    private void test_corrected_flags_and_wrapper_order () {
        var result = write ("--tag --tag", {
            new LaunchCommandSelection ("obs-gamecapture"),
            new LaunchCommandSelection ("proton-fsync"),
            new LaunchCommandSelection ("launch-backend", {}, "gamescope"),
            new LaunchCommandSelection ("ntsync-mode"),
            new LaunchCommandSelection ("gamescope-fps-limit", { "45" }),
            new LaunchCommandSelection ("gamemode")
        }, { "obs-gamecapture", "proton-fsync", "launch-backend", "ntsync-mode", "gamescope-fps-limit", "gamemode" }, {
            LaunchOptionCapability.OBS_GAMECAPTURE, LaunchOptionCapability.PROTON_FSYNC,
            LaunchOptionCapability.GAMESCOPE, LaunchOptionCapability.PROTON_NTSYNC, LaunchOptionCapability.GAMEMODE
        });
        assert (result.writing_allowed);
        assert_cmpstr (result.launch_line, CompareOperator.EQ, "PROTON_NO_FSYNC=1 PROTON_NO_NTSYNC=1 "
            + "gamemoderun gamescope --framerate-limit 45 -- obs-gamecapture %command% --tag --tag");
    }

    private void test_quoted_source_survives_no_op () {
        var source = "VAR=\"hello world\" gamescope -- %command% -windowed";
        var result = write (source, {});
        assert (result.writing_allowed);
        assert (!result.requires_persistence);
        assert (result.launch_line == source);
    }

    private void test_opaque_source_survives_no_op () {
        var source = "VAR=1 $(unsafe) %command%";
        var result = write (source, {});
        assert (result.writing_allowed);
        assert (!result.requires_persistence);
        assert (result.launch_line == source);
    }

    private void test_removing_control_preserves_raw_content () {
        var source = "VAR=\"hello world\" PROTON_LOG=1 %command% $(unsafe) -windowed";
        var result = write (source, {}, { "proton-debug-log" }, { LaunchOptionCapability.PROTON });
        assert (result.writing_allowed);
        assert (result.requires_persistence);
        assert (result.launch_line == "VAR=\"hello world\" %command% $(unsafe) -windowed");
    }

    private void test_catalog_views_do_not_affect_serialization () {
        var source = "VAR=\"hello world\" %command% $(unsafe) -windowed";
        var catalog = new LaunchOptionCatalog ();
        var writer = new LaunchCommandWriter (catalog);
        LaunchCommandSelection[] selections = { new LaunchCommandSelection ("gamemode") };
        var capabilities = new LaunchCommandCapabilityContext ({ LaunchOptionCapability.GAMEMODE });
        var before = writer.prepare_source (source, selections, { "gamemode" }, {}, capabilities);

        catalog.get_ordered ();
        catalog.search ("gamescope");
        var after = writer.prepare_source (source, selections, { "gamemode" }, {}, capabilities);
        assert (before.writing_allowed);
        assert (after.writing_allowed);
        assert (before.launch_line == "VAR=\"hello world\" gamemoderun %command% $(unsafe) -windowed");
        assert (after.launch_line == before.launch_line);
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
            { "gamemode" }, { LaunchOptionCapability.PROTON_NTSYNC, LaunchOptionCapability.GAMEMODE });
        assert (merged.status == LaunchCommandWriteStatus.SOURCE_PRESERVING_MANAGED_MERGE);
        assert (merged.writing_allowed);
        assert (merged.launch_line == "PROTON_USE_NTSYNC=0 gamemoderun %command% --mod-loader=\"custom path\"");

        var arguments_only = write ("-console", { new LaunchCommandSelection ("developer-console"),
            new LaunchCommandSelection ("proton-debug-log") }, { "proton-debug-log" },
            { LaunchOptionCapability.PROTON });
        assert (arguments_only.launch_line == "PROTON_LOG=1 %command% -console");
    }

    private void test_current_options_preview_and_validation () {
        var preview = write ("", {
            new LaunchCommandSelection ("dxvk-hdr"),
            new LaunchCommandSelection ("amd-fsr4"),
            new LaunchCommandSelection ("amd-mlfg"),
            new LaunchCommandSelection ("obs-vkcapture")
        }, { "dxvk-hdr", "amd-fsr4", "amd-mlfg", "obs-vkcapture" }, {
            LaunchOptionCapability.PROTON_DXVK_HDR, LaunchOptionCapability.AMD,
            LaunchOptionCapability.PROTON_FSR4, LaunchOptionCapability.PROTON_MLFG,
            LaunchOptionCapability.OBS_VKCAPTURE
        });
        assert (preview.writing_allowed);
        assert (preview.launch_line
            == "DXVK_HDR=1 PROTON_FSR4_UPGRADE=1 PROTON_MLFG_UPGRADE=1 OBS_VKCAPTURE=1 %command%");

        var conflict = write ("", {
            new LaunchCommandSelection ("amd-fsr4"),
            new LaunchCommandSelection ("cachyos-vulkan-low-latency"),
            new LaunchCommandSelection ("cachyos-vulkan-reflex"),
            new LaunchCommandSelection ("amd-reflex-force-nvapi")
        }, {
            "amd-fsr4", "cachyos-vulkan-low-latency", "cachyos-vulkan-reflex",
            "amd-reflex-force-nvapi"
        }, {
            LaunchOptionCapability.AMD, LaunchOptionCapability.PROTON_FSR4,
            LaunchOptionCapability.LOW_LATENCY_LAYER
        });
        assert (!conflict.writing_allowed);
        assert (conflict.status == LaunchCommandWriteStatus.BLOCKED_INVALID_SELECTIONS);
    }

    private void test_unsafe_source_is_blocked () {
        var blocked = write ("$(custom-wrapper) %command%", { new LaunchCommandSelection ("gamemode") },
            { "gamemode" }, { LaunchOptionCapability.GAMEMODE });
        assert (blocked.status == LaunchCommandWriteStatus.BLOCKED_UNSAFE_SOURCE);
        assert (!blocked.writing_allowed);
        assert (blocked.launch_line == "");
    }

    private void test_custom_prefix_combines_with_managed_options () {
        var source = "PROTON_USE_WAYLAND=1 custom-performance %command%";
        var parsed = new LaunchCommandParser ().parse (source);
        var custom = parsed.get_custom_game_arguments ();
        var indexes = parsed.get_custom_game_argument_indexes ();
        assert (custom.size == 2);
        assert (custom[0].raw == "PROTON_USE_WAYLAND=1");
        assert (custom[1].raw == "custom-performance");

        var skip_launcher = write (source, {
            new LaunchCommandSelection ("custom-game-arguments",
                { custom[0].raw, custom[1].raw }, "", {}, true, indexes, source),
            new LaunchCommandSelection ("skip-launcher")
        }, { "skip-launcher" });
        assert (skip_launcher.writing_allowed);
        assert (skip_launcher.launch_line
            == "PROTON_USE_WAYLAND=1 custom-performance %command% -skip-launcher");

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
            "PROTON_USE_WAYLAND=1 custom-performance %command% -skip-launcher",
            { new LaunchCommandSelection ("custom-game-arguments",
                { "PROTON_USE_WAYLAND=1", "custom-performance" }) },
            { "skip-launcher" }
        );
        assert (removed.writing_allowed);
        assert (removed.launch_line == "PROTON_USE_WAYLAND=1 custom-performance %command%");

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

        foreach (var prefix in new string[] {
            "VKD3D_CONFIG='shader_cache,no_alloc_view_descriptor_caches'",
            "RADV_DEBUG='novrs,precompile'", "ACO_DEBUG='validate,nowave32'"
        }) {
            var source = prefix + " %command% --custom-argument";
            var preserved = write (source, { new LaunchCommandSelection ("gamemode") },
                { "gamemode" }, { LaunchOptionCapability.GAMEMODE });
            assert (preserved.writing_allowed);
            assert (preserved.launch_line == prefix + " gamemoderun %command% --custom-argument");
            var clear = write (source, {}, {}, {}, true);
            assert (clear.writing_allowed);
            assert (clear.launch_line == "");
        }

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

    private void test_bulk_additions_preserve_custom_source () {
        var writer = new LaunchCommandWriter ();
        var capabilities = new LaunchCommandCapabilityContext ();
        var new_argument = new LaunchCommandSelection ("custom-game-arguments", { "--new='verbatim value'" },
            "", {}, true);
        var source = "UNKNOWN='local value' custom-wrapper %command% --local --local";
        var added = writer.prepare_source (source, { new_argument }, { "custom-game-arguments" }, {},
            capabilities, false, false, true);
        assert (added.writing_allowed);
        assert (added.launch_line == source + " --new='verbatim value'");

        var combined = writer.prepare_source (source,
            { new_argument, new LaunchCommandSelection ("developer-console") },
            { "custom-game-arguments", "developer-console" }, {}, capabilities, false, false, true);
        assert (combined.writing_allowed);
        assert (combined.launch_line == source + " -console --new='verbatim value'");
    }

    private void test_wrapper_edit_retains_untouched_arguments () {
        var capabilities = new LaunchCommandCapabilityContext ({ LaunchOptionCapability.GAMESCOPE });
        var writer = new LaunchCommandWriter ();
        var source = "gamescope --label='custom & safe' -r 60 -f -- %command% --game";
        var frame_limit = writer.prepare_source (source, {
            new LaunchCommandSelection ("launch-backend", {}, "gamescope"),
            new LaunchCommandSelection ("gamescope-frame-limit", { "90" })
        }, { "launch-backend", "gamescope-frame-limit" }, {}, capabilities, false, false, true);
        assert (frame_limit.writing_allowed);
        assert (frame_limit.launch_line == "gamescope --label='custom & safe' -r 90 -f -- %command% --game");

        var extra = writer.prepare_source (source, {
            new LaunchCommandSelection ("launch-backend", {}, "gamescope"),
            new LaunchCommandSelection ("gamescope-arguments", { "--label='new & safe'" })
        }, { "gamescope-arguments" }, {}, capabilities);
        assert (extra.writing_allowed);
        assert (extra.launch_line == "gamescope --label='new & safe' -r 60 -f -- %command% --game");
    }

    private void test_remove_argument_from_existing_backend () {
        var source = "LOCAL='quoted value' gamescope -r 90 --flag=one -- %command% --tag --tag";
        var removed = write (source, {}, { "gamescope-frame-limit" });
        assert (removed.writing_allowed);
        assert (removed.launch_line == "LOCAL='quoted value' gamescope --flag=one -- %command% --tag --tag");
    }

    private void test_backend_refresh_and_frame_limit () {
        foreach (var backend in new string[] { "gamescope", "scopebuddy" }) {
            var executable = backend == "gamescope" ? "gamescope" : "scb";
            var source = executable + " --unknown=one '-r' \"120\" --framerate-limit='60' -r144 -- %command%";
            var changed = write (source, {
                new LaunchCommandSelection ("launch-backend", {}, backend),
                new LaunchCommandSelection (backend + "-fps-limit", { "45" })
            }, { backend + "-fps-limit" }, { LaunchOptionCapability.GAMESCOPE, LaunchOptionCapability.SCOPEBUDDY });
            assert (changed.writing_allowed);
            assert (changed.launch_line == executable + " --unknown=one '-r' \"120\" --framerate-limit 45 -r144 -- %command%");
            var removed = write (source, {}, { backend + "-frame-limit" });
            assert (removed.writing_allowed);
            assert (removed.launch_line == executable + " --unknown=one --framerate-limit='60' -- %command%");
        }
    }

    private void test_scopebuddy_config_and_diagnostics () {
        var writer = new LaunchCommandWriter ();
        var context = new LaunchOptionCapabilityResolver ().resolve (
            { ProtonPlus.Models.CompatibilityToolRuntimeKind.NATIVE }, true,
            new LaunchOptionInstalledComponents (false, false, false, true, false, false, false, false, false, false, "scb"),
            ProtonPlus.Utils.GpuVendor.UNKNOWN
        );
        var selections = new LaunchCommandSelection[] {
            new LaunchCommandSelection ("launch-backend", {}, "scopebuddy"),
            new LaunchCommandSelection ("scopebuddy-profile", { "Living Room.conf" }),
            new LaunchCommandSelection ("scopebuddy-app-id", { "12345" }),
            new LaunchCommandSelection ("scopebuddy-environment-only", { "1" }),
            new LaunchCommandSelection ("scopebuddy-auto-refresh", { "1" }),
            new LaunchCommandSelection ("scopebuddy-auto-frame-limit", { "1" }),
            new LaunchCommandSelection ("scopebuddy-append-mode", { "1" }),
            new LaunchCommandSelection ("scopebuddy-debug", { "1" })
        };
        string[] changed = {};
        foreach (var selection in selections)
            changed += selection.option_id;
        var first = writer.prepare_source ("", selections, changed, {}, context);
        assert (first.writing_allowed);
        assert (first.launch_line == "SCB_CONF='Living Room.conf' SCB_APPID=12345 SCB_NOSCOPE=1 "
            + "SCB_AUTO_REFRESH=1 SCB_AUTO_FRAME_LIMIT=1 SCB_APPENDMODE=1 SCB_DEBUG=1 scb -- %command%");

        var source = "SCB_CONF=\"Old Profile.conf\" SCB_AUTO_RES=1 SCB_DEBUG=0 scb --extra='x y' -f -- %command% --game";
        var edited = writer.prepare_source (source, selections,
            { "scopebuddy-profile", "scopebuddy-debug" }, {}, context);
        assert (edited.writing_allowed);
        assert (edited.launch_line == "SCB_AUTO_RES=1 SCB_CONF='Living Room.conf' SCB_DEBUG=1 "
            + "scb --extra='x y' -f -- %command% --game");

        var removed = writer.prepare_source ("scb -W 1920 -H 1080 --extra -- %command%",
            {}, { "scopebuddy-resolution" });
        assert (removed.writing_allowed && removed.launch_line == "scb --extra -- %command%");

        var switched = write ("SCB_CONF='Local.conf' SCB_DEBUG=1 LOCAL=kept obs-gamecapture scb -- %command%",
            { new LaunchCommandSelection ("launch-backend", {}, "gamescope") },
            { "launch-backend" }, { LaunchOptionCapability.GAMESCOPE });
        assert (switched.writing_allowed && switched.launch_line == "LOCAL=kept obs-gamecapture gamescope -- %command%");
    }

    private void test_gamescope_display_controls () {
        var writer = new LaunchCommandWriter ();
        var source = "obs-gamecapture gamescope --nested-width=1600 --nested-height 900 "
            + "--custom='kept value' --scaler=fit -Ffsr -O DP-1,HDMI-A-1 -C 30 --hdr-sdr-content-nits=400 "
            + "--force-grab-cursor -- %command% --game";
        var context = new LaunchCommandCapabilityContext ({ LaunchOptionCapability.GAMESCOPE,
            LaunchOptionCapability.MANGOAPP });
        var result = writer.prepare_source (source, {
            new LaunchCommandSelection ("launch-backend", {}, "gamescope"),
            new LaunchCommandSelection ("gamescope-internal-resolution", { "1920", "1080" }),
            new LaunchCommandSelection ("gamescope-hdr-sdr-nits", { "320" }),
            new LaunchCommandSelection ("gamescope-mangoapp")
        }, { "gamescope-internal-resolution", "gamescope-hdr-sdr-nits", "gamescope-mangoapp" }, {}, context);
        assert (result.writing_allowed);
        assert (result.launch_line == "obs-gamecapture gamescope -w 1920 -h 1080 "
            + "--custom='kept value' --scaler=fit -Ffsr -O DP-1,HDMI-A-1 -C 30 --hdr-sdr-content-nits 320 "
            + "--force-grab-cursor --mangoapp -- %command% --game");

        var removed = writer.prepare_source (result.launch_line, {},
            { "gamescope-scaler", "gamescope-filter", "gamescope-prefer-output", "gamescope-hide-cursor-delay" });
        assert (removed.writing_allowed);
        assert (removed.launch_line == "obs-gamecapture gamescope -w 1920 -h 1080 "
            + "--custom='kept value' --hdr-sdr-content-nits 320 --force-grab-cursor --mangoapp -- %command% --game");
    }

    private void test_native_wrapper_executables () {
        try {
            var root = DirUtils.make_tmp ("protonplus-native-wrap-XXXXXX");
            var tinker_root = Path.build_filename (root, "Steam's tools", "TinkerGame");
            var legacy_root = Path.build_filename (root, "Steam's tools", "SteamTinkerLaunch");
            var tinker_executable = Path.build_filename (tinker_root, "tinkergame");
            var legacy_executable = Path.build_filename (legacy_root, "steamtinkerlaunch");
            foreach (var executable in new string[] { tinker_executable, legacy_executable }) {
                assert (DirUtils.create_with_parents (Path.get_dirname (executable), 0700) == 0);
                FileUtils.set_contents (executable, "#!/bin/sh\n");
                assert (FileUtils.chmod (executable, 0700) == 0);
            }
            var resolver = new LaunchOptionCapabilityResolver ();
            var components = new LaunchOptionInstalledComponents (false, false, true);
            var runtime = ProtonPlus.Models.CompatibilityToolRuntimeKind.NATIVE;
            var context = resolver.resolve ({ runtime }, true, components, ProtonPlus.Utils.GpuVendor.UNKNOWN,
                {}, { Path.get_dirname (tinker_root) });
            assert (context.has (LaunchOptionCapability.TINKERGAME));
            assert (context.has (LaunchOptionCapability.STEAMTINKERLAUNCH));
            var writer = new LaunchCommandWriter ();
            var source = "steamtinkerlaunch gamescope --extra='keep me' -- %command% --game";
            var selection = new LaunchCommandSelection ("native-game-wrapper", {}, "tinkergame");
            var result = writer.prepare_source (source, { selection }, { selection.option_id }, {}, context);
            assert (result.writing_allowed);
            assert (result.launch_line == Shell.quote (tinker_executable)
                + " gamescope --extra='keep me' -- %command% --game");
            assert (result.parsed.wrappers[0].wrapper_id == "steamtinkerlaunch");
            var parsed = new LaunchCommandParser ().parse (result.launch_line);
            assert (parsed.wrappers[0].wrapper_id == "tinkergame" && parsed.custom_wrapper_index < 0);
            var reverse = new LaunchCommandSelection ("native-game-wrapper", {}, "steamtinkerlaunch");
            var replaced = writer.prepare_source (result.launch_line, { reverse }, { reverse.option_id }, {}, context);
            assert (replaced.writing_allowed && replaced.launch_line.has_prefix (Shell.quote (legacy_executable) + " gamescope "));
            var removed = writer.prepare_source (result.launch_line, {}, { selection.option_id });
            assert (removed.writing_allowed && removed.launch_line == "gamescope --extra='keep me' -- %command% --game");

            FileUtils.remove (tinker_executable);
            FileUtils.remove (legacy_executable);
            DirUtils.remove (tinker_root);
            DirUtils.remove (legacy_root);
            DirUtils.remove (Path.get_dirname (tinker_root));
            DirUtils.remove (root);
        } catch (Error error) {
            Test.fail_printf ("%s", error.message);
        }
    }

    private void test_obs_capture_forms () {
        var wrapped = write ("gamescope -r '120' -- %command%", { new LaunchCommandSelection ("obs-gamecapture") },
            { "obs-gamecapture" }, { LaunchOptionCapability.OBS_GAMECAPTURE });
        assert (wrapped.writing_allowed && wrapped.launch_line == "gamescope -r '120' -- obs-gamecapture %command%");
        var switched = write (wrapped.launch_line, { new LaunchCommandSelection ("obs-vkcapture") },
            { "obs-vkcapture", "obs-gamecapture" }, { LaunchOptionCapability.OBS_VKCAPTURE });
        assert (switched.writing_allowed && switched.launch_line == "OBS_VKCAPTURE=1 gamescope -r '120' -- %command%");
    }

    private void test_wrapper_edit_preserves_duplicates_and_order () {
        var source = "gamemoderun mangohud 'gamemoderun' %command% --tag";
        var edited = write (source, {
            new LaunchCommandSelection ("gamemode"),
            new LaunchCommandSelection ("performance-overlay"),
            new LaunchCommandSelection ("launch-backend", {}, "gamescope")
        }, { "launch-backend" }, {
            LaunchOptionCapability.GAMEMODE, LaunchOptionCapability.MANGOHUD, LaunchOptionCapability.GAMESCOPE
        });

        assert (edited.writing_allowed);
        assert (edited.launch_line == "gamemoderun mangohud 'gamemoderun' gamescope -- %command% --tag");
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

    private void test_append_arguments_before_trailing_comment () {
        var source = "%command% '# literal' --tag=#exact # keep this comment";
        var console = new LaunchCommandSelection ("developer-console");
        var writer = new LaunchCommandWriter ();
        var capabilities = new LaunchCommandCapabilityContext ();
        var merged = writer.prepare_source (source, { console }, { "developer-console" }, {}, capabilities);
        assert (merged.writing_allowed);
        assert (merged.launch_line == "%command% '# literal' --tag=#exact -console # keep this comment");

        var appended = writer.prepare_source (source,
            { new LaunchCommandSelection ("custom-game-arguments", { "--extra" }) },
            { "custom-game-arguments" }, {}, capabilities, false, false, true);
        assert (appended.writing_allowed);
        assert (appended.launch_line == "%command% '# literal' --tag=#exact --extra # keep this comment");

        var compound = write ("%command% && echo trailer # keep this comment", { console }, { "developer-console" });
        assert (compound.status == LaunchCommandWriteStatus.BLOCKED_UNSAFE_SOURCE);
    }

    private LaunchCommandSelection custom_wrapper (string input) {
        return new LaunchCommandSelection ("custom-wrapper", { input }, "", {}, true);
    }

    private void test_custom_wrapper_lifecycle () {
        var source = "\"/tmp/Goverlay Config/bgmod\"";
        var selection = custom_wrapper (source + " %command%");
        assert (write ("", { selection }, { "custom-wrapper" }).launch_line == source + " %command%");
        assert (write ("--tag --tag", { selection }, { "custom-wrapper" }).launch_line
            == source + " %command% --tag --tag");
        assert (write ("%command% '/tmp/game data'", { selection }, { "custom-wrapper" }).launch_line
            == source + " %command% '/tmp/game data'");
        assert (write (source + " %command% --arg", {}, { "custom-wrapper" }).launch_line == "--arg");
        assert (write (source + " %command% --arg", { custom_wrapper ("./replacement") }, { "custom-wrapper" }).launch_line
            == "./replacement %command% --arg");
        assert (write ("$(opaque) %command% --old", { selection }, { "custom-wrapper" }, {}, true).launch_line
            == source + " %command%");

        foreach (var invalid in new string[] {
            "/tmp/bgmod %command% %command%", "%command% /tmp/bgmod", "'/tmp/%command%/bgmod'",
            "/tmp/bgmod --flag", "/tmp/bgmod | next", "/tmp/*/bgmod", "'/tmp/unclosed"
        }) {
            assert (!write ("", { custom_wrapper (invalid) }, { "custom-wrapper" }).writing_allowed);
        }
    }

    private void test_custom_wrapper_preserves_backends () {
        var capabilities = new LaunchOptionCapability[] { LaunchOptionCapability.PROTON, LaunchOptionCapability.GAMESCOPE };
        var original = "gamescope --label='safe value' -r 60 -- %command% -r 75";
        var nested = "gamescope --label='safe value' -r 60 -- '/tmp/bg mod' %command% -r 75";
        var added = write (original, { custom_wrapper ("'/tmp/bg mod'") }, { "custom-wrapper" }, capabilities);
        assert (added.writing_allowed && added.launch_line == nested);

        var logging = new LaunchCommandSelection ("proton-debug-log");
        assert (write (nested, { logging }, { "proton-debug-log" }, capabilities).launch_line == "PROTON_LOG=1 " + nested);
        var backend_edit = write (nested, {
            new LaunchCommandSelection ("launch-backend", {}, "gamescope"),
            new LaunchCommandSelection ("gamescope-frame-limit", { "90" })
        }, { "gamescope-frame-limit" }, capabilities);
        assert (backend_edit.writing_allowed && backend_edit.launch_line == nested.replace ("-r 60", "-r 90"));
        assert (write (nested, {}, { "custom-wrapper" }, capabilities).launch_line == original);

        var unknown = "gamescope -- /tmp/wrapper MODE=one --label gamemoderun %command% --tag";
        var preserved = write (unknown, { logging }, { "proton-debug-log" }, capabilities);
        assert (preserved.writing_allowed && preserved.launch_line == "PROTON_LOG=1 " + unknown);
        var blocked = write (unknown, { custom_wrapper ("/tmp/new") }, { "custom-wrapper" }, capabilities);
        assert (blocked.status == LaunchCommandWriteStatus.BLOCKED_CUSTOM_WRAPPER_CONFLICT);

        var scopebuddy = write ("scb -r 90 -- %command% --tag", { custom_wrapper ("/tmp/bgmod") }, { "custom-wrapper" });
        assert (scopebuddy.writing_allowed && scopebuddy.launch_line == "scb -r 90 -- /tmp/bgmod %command% --tag");
    }

    private void test_custom_wrapper_batch () {
        var writer = new LaunchCommandWriter ();
        var selection = custom_wrapper ("\"/tmp/bg mod\"");
        var capabilities = new LaunchCommandCapabilityContext ();
        var from_arguments = writer.prepare_source ("--tag --tag", { selection }, { "custom-wrapper" }, {}, capabilities, false, false, true);
        assert (from_arguments.launch_line == "\"/tmp/bg mod\" %command% --tag --tag");
        var same = "CUSTOM=1 '/tmp/bg mod' %command% --game";
        var already_set = writer.prepare_source (same, { selection }, { "custom-wrapper" }, {}, capabilities, false, false, true);
        assert (already_set.writing_allowed && !already_set.requires_persistence && already_set.launch_line == same);
        var different = writer.prepare_source ("/tmp/different %command%", { selection }, { "custom-wrapper" }, {}, capabilities, false, false, true);
        assert (!different.writing_allowed && different.status == LaunchCommandWriteStatus.BLOCKED_CUSTOM_WRAPPER_CONFLICT);
        var removed = writer.prepare_source (same, {}, { "custom-wrapper" }, {}, capabilities, false, false, true);
        assert (removed.writing_allowed && removed.launch_line == "CUSTOM=1 %command% --game");
    }
}
