namespace AppTests.FaugusGamesTest {
    using ProtonPlus.Models;
    using ProtonPlus.Models.Launchers;
    using ProtonPlus.Services;

    private class Backend : Object, FaugusBackend {
        public bool closed = true;
        public bool last_checked_flatpak;
        public bool last_probed_flatpak;
        public bool runner_present = true;
        public string? inaccessible_path;
        public string? changed_during_guard_path;
        public string changed_during_guard_contents;
        public string[] command;
        public string working_directory;

        public bool is_closed (bool flatpak) throws Error {
            last_checked_flatpak = flatpak;
            if (changed_during_guard_path != null) {
                var file = File.new_for_path (changed_during_guard_path);
                var timestamps = file.query_info ("time::modified,time::modified-usec,time::modified-nsec",
                    FileQueryInfoFlags.NONE);
                var before = file.query_info (FileAttribute.ETAG_VALUE, FileQueryInfoFlags.NONE);
                var stream = file.open_readwrite ();
                size_t written;
                stream.output_stream.write_all (changed_during_guard_contents.data, out written);
                stream.close ();
                file.set_attributes_from_info (timestamps, FileQueryInfoFlags.NONE);
                var after = file.query_info (FileAttribute.ETAG_VALUE, FileQueryInfoFlags.NONE);
                assert (before.get_etag () == after.get_etag ());
            }
            return closed;
        }

        public bool host_path_exists (string path) {
            return path == inaccessible_path;
        }

        public Gee.List<CompatibilityTool> installed_runners (bool flatpak) {
            last_probed_flatpak = flatpak;
            var result = new Gee.ArrayList<CompatibilityTool> ();
            if (runner_present)
                result.add (new CompatibilityTool ("Fixture Proton", "fixture-proton"));
            return result;
        }

        public Subprocess? spawn (string[] argv, string working_directory) {
            command = argv;
            this.working_directory = working_directory;
            return null;
        }
    }

    private class Fixture : Object {
        public string home;
        public string config;
        public string data;
        public string flatpak_config;
        public string flatpak_data;
        public Backend backend = new Backend ();

        public Fixture () throws Error {
            home = DirUtils.make_tmp ("protonplus-faugus-games-XXXXXX");
            config = Path.build_filename (home, "native-config", "faugus-launcher");
            data = Path.build_filename (home, "native-data", "faugus-launcher");
            var app = Path.build_filename (home, ".var", "app", FaugusLauncher.FLATPAK_ID);
            flatpak_config = Path.build_filename (app, "config", "faugus-launcher");
            flatpak_data = Path.build_filename (app, "data", "faugus-launcher");
            string[] directories = { config, data, flatpak_config, flatpak_data, Path.build_filename (home, "game"),
                Path.build_filename (home, "prefix") };
            foreach (var directory in directories)
                assert (DirUtils.create_with_parents (directory, 0700) == 0);
        }

        public void cleanup () {
            var loop = new MainLoop ();
            ProtonPlus.Utils.Filesystem.delete_directory.begin (home, (object, result) => {
                assert (ProtonPlus.Utils.Filesystem.delete_directory.end (result));
                loop.quit ();
            });
            loop.run ();
        }

        public FaugusLauncher launcher (bool flatpak = false, bool through_host = false) {
            var config_home = Path.get_dirname (config);
            var data_home = Path.get_dirname (data);
            var service = new FaugusConfigurationService (flatpak, home, config_home, data_home, backend, through_host);
            return new FaugusLauncher (flatpak ? Launcher.InstallationTypes.FLATPAK : Launcher.InstallationTypes.SYSTEM,
                home, home, config_home, data_home, home, service);
        }
    }

    public void register_tests () {
        Test.add_func ("/faugus-games/library-roots-and-actions", test_library_roots_and_actions);
        Test.add_func ("/faugus-games/legacy-and-inaccessible-library", test_legacy_and_inaccessible_library);
        Test.add_func ("/faugus-games/runner-changes-and-reset", test_runner_changes_and_reset);
        Test.add_func ("/faugus-games/external-edits-and-ambiguity", test_external_edits_and_ambiguity);
        Test.add_func ("/faugus-games/selected-instance-launch", test_selected_instance_launch);
    }

    private bool load (Launcher launcher) {
        var loop = new MainLoop ();
        var loaded = false;
        launcher.load_profile_library.begin ((source, result) => {
            loaded = launcher.load_profile_library.end (result);
            loop.quit ();
        });
        assert (launcher.game_library_loading);
        loop.run ();
        assert (!launcher.game_library_loading);
        return loaded;
    }

    private Gee.List<CompatibilityTool>? choices (Game game) {
        var loop = new MainLoop ();
        Gee.List<CompatibilityTool>? tools = null;
        game.load_game_tool_choices.begin ((source, result) => {
            tools = game.load_game_tool_choices.end (result);
            loop.quit ();
        });
        // The editor only calls this for editable rows.
        loop.run ();
        return tools;
    }

    private bool apply (Game game, string runner) {
        var loop = new MainLoop ();
        var saved = false;
        game.change_compatibility_tool_async.begin (runner, null, (source, result) => {
            saved = game.change_compatibility_tool_async.end (result);
            loop.quit ();
        });
        loop.run ();
        return saved;
    }

    private void launch (Game game) {
        var loop = new MainLoop ();
        game.launch_external.begin ((source, result) => {
            try {
                game.launch_external.end (result);
            } catch (Error error) {
                GLib.error ("%s", error.message);
            }
            loop.quit ();
        });
        loop.run ();
    }

    private void write (string root, string name, string data) throws Error {
        FileUtils.set_contents (Path.build_filename (root, name), data);
    }

    private Json.Node read (string root) throws Error {
        var parser = new Json.Parser ();
        parser.load_from_file (Path.build_filename (root, "games.json"));
        return parser.get_root ().copy ();
    }

    private Games.Faugus row (Launcher launcher, string id) {
        foreach (var entry in launcher.games) {
            var game = (Games.Faugus) entry;
            if (game.game_id == id)
                return game;
        }
        assert_not_reached ();
    }

    private void test_library_roots_and_actions () {
        try {
            var fixture = new Fixture ();
            write (fixture.config, "config.json", """{"default-runner":"fixture-proton","show-hidden":"False"}""");
            write (fixture.data, "games.json", """
[
    {"title":"Shared title","gameid":"alpha","runner":"Default","path":"$HOME/game/test.exe","prefix":"~/prefix"},
    {"title":"Shared title","gameid":"beta","runner":"Removed Runner","path":"/missing-fixture/test.exe"},
    {"title":"Legacy entry","gameid":"older"},
    {"title":"Linux game","gameid":"linux","runner":"Linux-Native","runtime":"disable-runtime","disable_umu":true,"prefix":"~/prefix"},
    {"title":"Steam game","gameid":"steam","runner":"Steam","path":"12345"},
    {"title":"Hidden entry","gameid":"hidden","hidden":true},
    {"title":"Duplicate ID","gameid":"duplicate"},
    {"gameid":"duplicate","hidden":true},
    {"title":"No ID","path":"~/game"},
    {"title":42,"gameid":"invalid"},
    null
]
""");
            write (fixture.flatpak_config, "config.json", """{"default-runner":"Missing Default","show-hidden":"True"}""");
            write (fixture.flatpak_data, "games.json", """
[{"title":"Shared title","gameid":"alpha","runner":"Default","hidden":true}]
""");
            var native = fixture.launcher ();
            var sandboxed = fixture.launcher (true);
            assert (load (native));
            assert (native.games.length () == 5);
            assert (!fixture.backend.last_probed_flatpak);
            var alpha = row (native, "alpha");
            var beta = row (native, "beta");
            assert (alpha.name == beta.name && alpha.identity != beta.identity);
            assert (alpha.can_launch && alpha.has_game_directory && alpha.has_prefix_directory);
            assert (alpha.get_game_tool_title () == "Inherited (Fixture Proton)");
            assert (!beta.has_game_directory && !beta.has_prefix_directory);
            assert (beta.get_game_tool_title () == "Removed Runner (Unavailable)");
            assert (row (native, "older").get_game_tool_title () == "Automatic (UMU)");
            var linux_game = row (native, "linux");
            assert (linux_game.is_native && linux_game.can_launch && !linux_game.can_edit_compatibility_tool && !linux_game.has_prefix_directory);
            assert (!row (native, "steam").can_edit_compatibility_tool);
            assert (load (sandboxed) && fixture.backend.last_probed_flatpak);
            assert (sandboxed.games.length () == 1);
            assert (row (sandboxed, "alpha").identity != alpha.identity);
            assert (row (sandboxed, "alpha").get_game_tool_title () == "Inherited (Missing Default (Unavailable))");
            assert (native.tool_target_id == sandboxed.tool_target_id && native.tool_target_id == "steam-system");
            fixture.cleanup ();
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
    }

    private void test_legacy_and_inaccessible_library () {
        try {
            var fixture = new Fixture ();
            write (fixture.config, "config.ini", "show-hidden=True\n");
            write (fixture.config, "games.json", """[{"gameid":"legacy","title":"Legacy","runner":"","hidden":true}]""");
            var native = fixture.launcher ();
            assert (load (native));
            var game = row (native, "legacy");
            assert (!game.can_edit_compatibility_tool && game.can_launch);
            launch (game);
            assert (string.joinv (" ", fixture.backend.command) == "faugus-run --game legacy");
            assert (load (fixture.launcher (true)));
            var sandboxed = fixture.launcher (true, true);
            assert (load (sandboxed) && sandboxed.games.length () == 0);
            fixture.backend.inaccessible_path = Path.build_filename (fixture.flatpak_data, "games.json");
            assert (!load (sandboxed));
            assert (sandboxed.game_library_error.contains ("cannot access"));
            assert (sandboxed.game_library_error.contains (fixture.flatpak_data));
            write (fixture.flatpak_data, "games.json", "{bad JSON");
            assert (!load (sandboxed) && sandboxed.game_library_error.contains ("invalid"));
            write (fixture.flatpak_data, "games.json", """[{"gameid":"entry","title":"Entry","runner":"Default"}]""");
            fixture.backend.inaccessible_path = Path.build_filename (fixture.flatpak_config, "config.json");
            assert (load (sandboxed) && sandboxed.game_library_warning.contains (fixture.flatpak_config));
            var partial = row (sandboxed, "entry");
            assert (!partial.can_edit_compatibility_tool && partial.get_game_tool_title () == "Inherited");
            assert (partial.can_launch);
            launch (partial);
            assert (string.joinv (" ", fixture.backend.command) ==
                "flatpak-spawn --host flatpak run io.github.Faugus.faugus-launcher --game entry");
            write (fixture.flatpak_config, "config.json", "{bad JSON");
            assert (load (sandboxed) && sandboxed.game_library_warning.contains ("invalid"));
            write (fixture.flatpak_config, "config.json", "{}");
            assert (load (sandboxed) && sandboxed.game_library_warning == null);
            assert (row (sandboxed, "entry").can_edit_compatibility_tool);
            fixture.cleanup ();
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
    }

    private void test_runner_changes_and_reset () {
        try {
            var fixture = new Fixture ();
            write (fixture.flatpak_config, "config.json", """{"default-runner":"Proton-GE Latest","unrelated":17}""");
            write (fixture.flatpak_data, "games.json", """
[
    {"gameid":"one","title":"One","runner":"unknown","disable_umu":true,"nested":{"value":[false,3,null]}},
    {"gameid":"two","title":"Two","runner":"Default","unknown":["keep",21]}
]
""");
            var launcher = fixture.launcher (true);
            assert (load (launcher));
            var game = row (launcher, "one");
            var before = read (fixture.flatpak_data);
            var options = choices (game);
            assert (options != null);
            assert (options.any_match (tool => tool.internal_title == "unknown" && !tool.is_assignable));
            assert (options.any_match (tool => tool.internal_title == "Proton-Wineland Latest" && tool.is_assignable));
            assert (options.any_match (tool => tool.internal_title == "Default" && tool.display_title.contains ("GE-Proton Latest")));
            fixture.backend.runner_present = false;
            assert (!apply (game, "fixture-proton"));
            assert (read (fixture.flatpak_data).equal (before));
            fixture.backend.runner_present = true;
            fixture.backend.closed = false;
            assert (!apply (game, "fixture-proton") && fixture.backend.last_checked_flatpak);
            assert (game.compatibility_edit_error.contains ("Close the selected Faugus"));
            assert (read (fixture.flatpak_data).equal (before));
            fixture.backend.closed = true;
            assert (apply (game, "fixture-proton"));
            assert (game.get_game_tool_title () == "Fixture Proton");
            var expected = before.get_array ();
            expected.get_object_element (0).set_string_member ("runner", "fixture-proton");
            assert (read (fixture.flatpak_data).equal (before));
            assert (apply (game, "Default"));
            expected.get_object_element (0).set_string_member ("runner", "Default");
            assert (read (fixture.flatpak_data).equal (before));
            assert (game.get_game_tool_title () == "Inherited (GE-Proton Latest)");
            string config;
            FileUtils.get_contents (Path.build_filename (fixture.flatpak_config, "config.json"), out config);
            assert (config == """{"default-runner":"Proton-GE Latest","unrelated":17}""");
            fixture.cleanup ();
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
    }

    private void test_external_edits_and_ambiguity () {
        try {
            var fixture = new Fixture ();
            write (fixture.data, "games.json", """[{"gameid":"a","title":"A","runner":"Default"},{"gameid":"b","title":"B"}]""");
            var launcher = fixture.launcher ();
            assert (load (launcher));
            var game = row (launcher, "a");
            assert (choices (game) != null);
            write (fixture.data, "games.json", """[{"gameid":"b","title":"B","changed":true},{"gameid":"a","title":"A","runner":"Default"}]""");
            assert (apply (game, "fixture-proton"));
            assert (!fixture.backend.last_checked_flatpak);
            var entries = read (fixture.data).get_array ();
            assert (entries.get_object_element (0).get_boolean_member ("changed"));
            assert (entries.get_object_element (1).get_string_member ("runner") == "fixture-proton");

            write (fixture.data, "games.json", """[{"gameid":"a","title":"A","runner":"DW-Proton Latest"}]""");
            var external = read (fixture.data);
            assert (!apply (game, "Default"));
            assert (game.compatibility_edit_error.contains ("changed"));
            assert (read (fixture.data).equal (external));

            write (fixture.data, "games.json", """
[{"gameid":"a","title":"A","runner":"fixture-proton"},{"gameid":"a","title":"Another","hidden":true}]
""");
            external = read (fixture.data);
            assert (!apply (game, "Default"));
            assert (read (fixture.data).equal (external));

            write (fixture.data, "games.json",
                """[{"gameid":"a","title":"A","runner":"DW-Proton Latest","external_change":false}]""");
            assert (choices (game) != null);
            assert (game.compatibility_tool == "DW-Proton Latest");
            fixture.backend.changed_during_guard_path = Path.build_filename (fixture.data, "games.json");
            fixture.backend.changed_during_guard_contents =
                """[{"gameid":"a","title":"A","runner":"DW-Proton Latest","external_change": true}]""";
            assert (!apply (game, "Default"));
            var after_race = read (fixture.data).get_array ().get_object_element (0);
            assert (after_race.get_boolean_member ("external_change"));
            assert (after_race.get_string_member ("runner") == "DW-Proton Latest");
            fixture.cleanup ();
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
    }

    private void test_selected_instance_launch () {
        try {
            var fixture = new Fixture ();
            var games = """[{"gameid":"first","title":"One"},{"gameid":"second","title":"One","path":"~/game/exe"}]""";
            write (fixture.data, "games.json", games);
            write (fixture.flatpak_data, "games.json", games);
            var native = fixture.launcher ();
            var flatpak = fixture.launcher (true);
            assert (load (native) && load (flatpak));
            launch (row (native, "second"));
            assert (string.joinv (" ", fixture.backend.command) == "faugus-launcher --game second");
            assert (fixture.backend.working_directory == Path.build_filename (fixture.home, "game"));
            launch (row (flatpak, "second"));
            assert (string.joinv (" ", fixture.backend.command) ==
                "flatpak run io.github.Faugus.faugus-launcher --game second");

            var native_from_sandbox = fixture.launcher (false, true);
            var flatpak_from_sandbox = fixture.launcher (true, true);
            assert (load (native_from_sandbox) && load (flatpak_from_sandbox));
            launch (row (native_from_sandbox, "second"));
            assert (string.joinv (" ", fixture.backend.command) == "flatpak-spawn --host faugus-launcher --game second");
            launch (row (flatpak_from_sandbox, "second"));
            assert (string.joinv (" ", fixture.backend.command) ==
                "flatpak-spawn --host flatpak run io.github.Faugus.faugus-launcher --game second");

            foreach (var selected in new Launcher[] { native, flatpak, native_from_sandbox, flatpak_from_sandbox }) {
                var other_data = selected.installation_type == Launcher.InstallationTypes.FLATPAK
                    ? fixture.data : fixture.flatpak_data;
                var before = read (other_data);
                assert (load (selected));
                assert (apply (row (selected, "second"), "fixture-proton"));
                assert (load (selected) && row (selected, "second").compatibility_tool == "fixture-proton");
                assert (apply (row (selected, "second"), "Default"));
                assert (load (selected) && row (selected, "second").compatibility_tool == "Default");
                assert (read (other_data).equal (before));
            }
            fixture.cleanup ();
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
    }
}
