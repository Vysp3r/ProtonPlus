namespace AppTests.BottlesTest {
    using ProtonPlus.Models;
    using ProtonPlus.Services;

    private const string FLATPAK_PREFIX = "flatpak\nrun\n--command=bottles-cli\ncom.usebottles.bottles";
    private const string PLAY_NAME = "-Shared ; $(literal)";
    private const string BOTTLE_NAME = "-Gaming & <Library>";

    private class FixtureCli : Object, BottlesCliBackend {
        public string bottles = "{}";
        public string root = "";
        public bool unavailable;
        public bool supports_ids = true;
        public string[] dispatched = {};
        public Gee.ArrayList<string> queries = new Gee.ArrayList<string> ();
        public Gee.HashMap<string, string> programs = new Gee.HashMap<string, string> ();
        public string prefix;

        public FixtureCli (string prefix) {
            this.prefix = prefix;
        }

        public string query (string[] argv) throws Error {
            var command = string.joinv ("\n", argv);
            assert (command.has_prefix (prefix + "\n"));
            var args = command.substring (prefix.length + 1);
            queries.add (args);
            switch (args) {
            case "--json\nlist\nbottles":
                if (unavailable)
                    throw new IOError.NOT_FOUND ("Fixture CLI unavailable");
                return bottles;
            case "run\n--help":
                return supports_ids ? "usage: bottles-cli run [--program-id PROGRAM_ID]" : "usage: bottles-cli run [-p PROGRAM]";
            case "info\nbottles-path":
                return root;
            default:
                const string programs_command = "--json\nprograms\n--bottle=";
                assert (args.has_prefix (programs_command));
                var response = programs[args.substring (programs_command.length)];
                if (response == null)
                    throw new IOError.FAILED ("Fixture bottle unavailable");
                return response;
            }
        }

        public Subprocess? launch (string[] argv) throws Error {
            dispatched = argv.copy ();
            return null;
        }
    }

    private Launchers.Bottles launcher (FixtureCli cli, bool flatpak = false, bool host = false, string? home = null) {
        return new Launchers.Bottles (flatpak ? Launcher.InstallationTypes.FLATPAK : Launcher.InstallationTypes.SYSTEM,
            new BottlesLibrary (flatpak, host, cli, home));
    }

    private bool load (Launcher target) {
        var loop = new MainLoop ();
        bool success = false;
        target.load_profile_library.begin ((source, result) => {
            success = target.load_profile_library.end (result);
            loop.quit ();
        });
        assert (target.game_library_loading);
        loop.run ();
        assert (!target.game_library_loading);
        return success;
    }

    private bool play (Game game) {
        var loop = new MainLoop ();
        bool success = false;
        game.launch_external.begin ((source, result) => {
            try {
                game.launch_external.end (result);
                success = true;
            } catch (Error error) {
                Test.message ("%s", error.message);
            }
            loop.quit ();
        });
        loop.run ();
        return success;
    }

    private Games.Bottles game (Launcher launcher, uint index) {
        var found = launcher.games.nth_data (index) as Games.Bottles;
        assert (found != null);
        return found;
    }

    private void test_routing_and_identity () {
        foreach (var through_host in new bool[] { false, true }) {
            var host_prefix = through_host ? "flatpak-spawn\n--host\n" : "";
            var native_cli = new FixtureCli (host_prefix + "bottles-cli");
            var flatpak_cli = new FixtureCli (host_prefix + FLATPAK_PREFIX);
            var native = launcher (native_cli, false, through_host);
            var flatpak = launcher (flatpak_cli, true, through_host);
            native_cli.supports_ids = false;

            foreach (var cli in new FixtureCli[] { native_cli, flatpak_cli }) {
                cli.bottles = """{"%s":{"Runner":"soda-11"},"Other Bottle":{}}""".printf (BOTTLE_NAME);
                cli.programs[BOTTLE_NAME] = """[{"name":"%s","path":"C:\\Game.exe","id":"shared-id","arguments":"--saved args"}]""".printf (PLAY_NAME);
                cli.programs["Other Bottle"] = cli.programs[BOTTLE_NAME];
            }
            assert (load (native) && load (flatpak));
            assert (native.games.length () == 2 && flatpak.games.length () == 2);
            var native_game = game (native, 0);
            var flatpak_game = game (flatpak, 0);
            var other_bottle = game (flatpak, 1);
            assert (native_game.name == flatpak_game.name && flatpak_game.library_context == BOTTLE_NAME);
            assert (!native_game.identity.equal (flatpak_game.identity));
            assert (!flatpak_game.identity.equal (other_bottle.identity));
            assert (flatpak_game.get_game_tool_title () == "soda-11");
            assert (!flatpak_game.can_edit_compatibility_tool && !flatpak.supports_bulk_game_edit);
            assert (native_game.can_launch && flatpak_game.can_launch && other_bottle.can_launch);

            assert (play (native_game) && play (flatpak_game));
            assert (string.joinv ("\n", native_cli.dispatched) ==
                host_prefix + "bottles-cli\nrun\n--bottle=" + BOTTLE_NAME + "\n--program=" + PLAY_NAME);
            assert (string.joinv ("\n", flatpak_cli.dispatched) ==
                host_prefix + FLATPAK_PREFIX + "\nrun\n--bottle=" + BOTTLE_NAME + "\n--program-id=shared-id");
            assert (flatpak_cli.queries.contains ("--json\nprograms\n--bottle=" + BOTTLE_NAME));
        }
    }

    private void test_selector_collisions () {
        var cli = new FixtureCli ("bottles-cli");
        cli.bottles = """{"Bottle":{"External_Programs":{
            "a":{"name":"Shared","id":"one","path":"C:\\A.exe"},
            "b":{"name":"Shared","id":"two","path":"C:\\B.exe"},
            "c":{"name":"Unique","path":"C:\\C.exe"},
            "hidden":{"name":"Unique","path":"C:\\H.exe","removed":true}
        }}}""";
        cli.programs["Bottle"] = """[
            {"name":"Shared","id":"one","path":"C:\\A.exe"},
            {"name":"Shared","id":"two","path":"C:\\B.exe"},
            {"name":"Unique","path":"C:\\C.exe"},
            {"name":"Detected","id":"temporary","path":"C:\\D.exe","auto_discovered":true}
        ]""";
        var target = launcher (cli);
        assert (load (target) && target.games.length () == 3);
        var first = game (target, 0);
        var second = game (target, 1);
        assert (first.can_launch && second.can_launch);
        assert (!first.identity.equal (second.identity) && !game (target, 2).can_launch);
        assert (play (second) && cli.dispatched[3] == "--program-id=two");

        cli.supports_ids = false;
        cli.dispatched = {};
        assert (!play (first) && cli.dispatched.length == 0);
        assert (load (target));
        assert (!game (target, 0).can_launch && !game (target, 1).can_launch);

        cli.supports_ids = true;
        cli.bottles = """{"Bottle":{}}""";
        cli.programs["Bottle"] = """[
            {"name":"A","id":"duplicate","path":"C:\\A.exe"},
            {"name":"B","id":"duplicate","path":"C:\\B.exe"}
        ]""";
        assert (load (target) && target.games.length () == 2);
        assert (!game (target, 0).can_launch && !game (target, 1).can_launch);
        assert (!game (target, 0).identity.equal (game (target, 1).identity));

        cli.supports_ids = false;
        assert (load (target));
        assert (game (target, 0).can_launch && game (target, 1).can_launch);
        assert (play (game (target, 1)) && cli.dispatched[3] == "--program=B");
    }

    private void test_library_results () {
        var cli = new FixtureCli ("bottles-cli");
        var target = launcher (cli);
        assert (load (target) && target.games.length () == 0);
        assert (target.game_library_warning == null && target.game_library_error == null);
        cli.unavailable = true;
        assert (!load (target) && target.game_library_error != null);
        cli.unavailable = false;
        foreach (var invalid in new string[] { "{", "[]", "null" }) {
            cli.bottles = invalid;
            assert (!load (target) && target.game_library_error != null);
        }
        cli.bottles = """{"Good":{},"Missing":{},"Malformed":{},"WrongType":[],"Empty":{}}""";
        cli.programs["Good"] = """[{"name":"Playable","path":"C:\\Game.exe"},false,{"name":"Invalid","path":3}]""";
        cli.programs["Malformed"] = """{"programs":[]}""";
        cli.programs["Empty"] = "[]";
        assert (load (target) && target.games.length () == 1);
        assert (target.game_library_warning != null && target.game_library_error == null);
        cli.bottles = """{"Empty":{}}""";
        assert (load (target) && target.game_library_warning == null && target.games.length () == 0);
    }

    private void test_folders () {
        try {
            var home = DirUtils.make_tmp ("protonplus-bottles-XXXXXX");
            var flatpak_home = Path.build_filename (home, ".var", "app", BottlesLibrary.APP_ID, "data");
            var prefix = Path.build_filename (home, "custom library", "Storage");
            var defaults = Path.build_filename (flatpak_home, "bottles");
            var mapped = Path.build_filename (home, "mapped", "Game Files");
            var native_files = Path.build_filename (home, "custom", "drive_c", "Native Files");
            var inaccessible = Path.build_filename (home, "restricted");
            assert (DirUtils.create_with_parents (Path.build_filename (prefix, "dosdevices"), 0700) == 0);
            assert (DirUtils.create_with_parents (defaults, 0700) == 0);
            FileUtils.set_contents (Path.build_filename (defaults, "data.yml"),
                "custom_bottles_path: '%s'\n".printf (Path.get_dirname (prefix)));
            assert (DirUtils.create_with_parents (mapped, 0700) == 0);
            assert (DirUtils.create_with_parents (native_files, 0700) == 0);
            assert (DirUtils.create_with_parents (inaccessible, 0700) == 0);
            assert (FileUtils.chmod (inaccessible, 0) == 0);
            assert (FileUtils.symlink (Path.get_dirname (mapped), Path.build_filename (prefix, "dosdevices", "d:")) == 0);
            assert (FileUtils.symlink (inaccessible, Path.build_filename (prefix, "dosdevices", "e:")) == 0);
            // Native package builds can run as root and traverse mode-000
            // directories. Use a missing directory within the mapped drive
            // when permission bits do not make it inaccessible.
            var restricted_path = Posix.access (inaccessible, Posix.R_OK | Posix.X_OK) == 0
                ? """E:\\Missing\\Game.exe""" : """E:\\Game.exe""";

            var cli = new FixtureCli (FLATPAK_PREFIX);
            cli.root = "/var/data/bottles/bottles";
            cli.bottles = """{"Flat":{"Path":"Storage"},"Custom":{"Path":"%s/custom","Custom_Path":true},
                "Unknown":{"Path":"Missing"}}""".printf (home);
            cli.programs["Flat"] = """[
                {"name":"Mapped","path":"D:\\game files\\Game.exe"},
                {"name":"Restricted","path":"%s"},
                {"name":"Missing mapping","path":"Q:\\Game.exe"},
                {"name":"Sandbox absolute","path":"/var/data/bottles/Tools.exe"}
            ]""".printf (restricted_path);
            cli.programs["Custom"] = """[{"name":"Custom","path":"C:\\Native Files\\Game.exe"}]""";
            cli.programs["Unknown"] = """[{"name":"Unknown","path":"C:\\Game.exe"}]""";
            var target = launcher (cli, true, false, home);
            assert (load (target) && target.games.length () == 6);
            assert (game (target, 0).installdir == mapped && game (target, 0).prefixdir == prefix);
            assert (!game (target, 1).has_game_directory && game (target, 1).has_prefix_directory);
            assert (!game (target, 2).has_game_directory);
            assert (game (target, 3).installdir == defaults);
            assert (game (target, 4).installdir == native_files);
            assert (!game (target, 5).has_prefix_directory && !game (target, 5).has_game_directory);
            assert (FileUtils.chmod (inaccessible, 0700) == 0);

            var loop = new MainLoop ();
            ProtonPlus.Utils.Filesystem.delete_directory.begin (home, (source, result) => {
                assert (ProtonPlus.Utils.Filesystem.delete_directory.end (result));
                loop.quit ();
            });
            loop.run ();
        } catch (Error error) {
            assert_no_error (error);
        }
    }

    public void register_tests () {
        Test.add_func ("/bottles/routing-and-identity", test_routing_and_identity);
        Test.add_func ("/bottles/selector-collisions", test_selector_collisions);
        Test.add_func ("/bottles/library-results", test_library_results);
        Test.add_func ("/bottles/folders", test_folders);
    }
}
