using ProtonPlus.Models;
using ProtonPlus.Services;

namespace AppTests.LutrisTest {
    class FixtureBackend : Object, LutrisBackend {
        public bool native_closed = true;
        public bool flatpak_closed = true;
        public bool wine_present = true;
        public bool proton_present = true;
        public bool custom_present;
        public string[] arguments = {};
        public string? last_custom_path;

        public bool is_closed (bool flatpak) {
            return flatpak ? flatpak_closed : native_closed;
        }

        public Gee.List<CompatibilityTool> get_runners (bool flatpak, string? custom_path) {
            last_custom_path = custom_path;
            var tools = new Gee.ArrayList<CompatibilityTool> ();
            if (wine_present)
                tools.add (new CompatibilityTool ("Wine test", "wine-test", "", CompatibilityToolRuntimeKind.WINE));
            if (proton_present)
                tools.add (new CompatibilityTool ("Proton test", "proton-test", "", CompatibilityToolRuntimeKind.PROTON));
            if (custom_present && custom_path != null)
                tools.add (new CompatibilityTool ("Custom test", "custom", custom_path,
                    CompatibilityToolRuntimeKind.WINE) { is_assignable = false });
            return tools;
        }

        public Subprocess? spawn (string[] argv) {
            arguments = argv;
            return null;
        }
    }

    class Fixture : Object {
        public string home;
        public string data_home;
        public string config_home;
        public string data;
        public string legacy;
        public string db_file;
        public string profile;
        public FixtureBackend backend;
        public LutrisConfigurationService service;
        public Sqlite.Database db;

        public Fixture (bool flatpak = false, bool use_legacy = false, bool through_host = false) throws Error {
            home = DirUtils.make_tmp ("protonplus-lutris-XXXXXX");
            data_home = Path.build_filename (home, "xdg-data");
            config_home = Path.build_filename (home, "xdg-config");
            if (flatpak) {
                var app = Path.build_filename (home, ".var", "app", "net.lutris.Lutris");
                data = Path.build_filename (app, "data", "lutris");
                legacy = Path.build_filename (app, "config", "lutris");
            } else {
                data = Path.build_filename (data_home, "lutris");
                legacy = Path.build_filename (config_home, "lutris");
            }
            assert (DirUtils.create_with_parents (data, 0700) == 0);
            var config = use_legacy ? legacy : data;
            assert (DirUtils.create_with_parents (Path.build_filename (config, "games"), 0700) == 0);
            profile = Path.build_filename (config, "games", "one.yml");
            db_file = Path.build_filename (data, "pga.db");
            if (use_legacy) {
                db_file = Path.build_filename (home, "override.db");
                FileUtils.set_contents (Path.build_filename (legacy, "lutris.conf"),
                    "[DEFAULT]\nroot = %s\n[lutris]\nPGA_PATH = %%(root)s/override.db\nrunner_dir = %s\n"
                        .printf (home, Path.build_filename (home, "custom runners")));
            }
            assert (Sqlite.Database.open (db_file, out db) == Sqlite.OK);
            assert (db.exec ("CREATE TABLE games (id INTEGER, name TEXT, runner TEXT, directory TEXT, configpath TEXT, installed INTEGER, slug TEXT, installed_at INTEGER)") == Sqlite.OK);
            backend = new FixtureBackend ();
            service = new LutrisConfigurationService (flatpak, home, data_home, config_home, backend, through_host);
        }

        public void add (int64 id, string name, string runner, string config, int installed = 1) {
            Sqlite.Statement row;
            assert (db.prepare_v2 ("INSERT INTO games (id, name, runner, directory, configpath, installed) VALUES (?1,?2,?3,?4,?5,?6)", -1, out row) == Sqlite.OK);
            row.bind_int64 (1, id);
            row.bind_text (2, name);
            row.bind_text (3, runner);
            row.bind_text (4, home);
            row.bind_text (5, config);
            row.bind_int (6, installed);
            assert (row.step () == Sqlite.DONE);
        }

        public void close () {
            var loop = new MainLoop ();
            ProtonPlus.Utils.Filesystem.delete_directory.begin (home, (source, result) => {
                assert (ProtonPlus.Utils.Filesystem.delete_directory.end (result));
                loop.quit ();
            });
            loop.run ();
        }
    }

    bool load (Launcher launcher) {
        var loop = new MainLoop ();
        bool loaded = false;
        launcher.load_profile_library.begin ((source, result) => {
            loaded = launcher.load_profile_library.end (result);
            loop.quit ();
        });
        loop.run ();
        return loaded;
    }

    Gee.List<CompatibilityTool>? choices (Game game) {
        var loop = new MainLoop ();
        Gee.List<CompatibilityTool>? result = null;
        game.load_game_tool_choices.begin ((source, pending) => {
            result = game.load_game_tool_choices.end (pending);
            loop.quit ();
        });
        loop.run ();
        return result;
    }

    bool save (Game game, string id) {
        var loop = new MainLoop ();
        bool saved = false;
        game.change_compatibility_tool_async.begin (id, null, (source, result) => {
            saved = game.change_compatibility_tool_async.end (result);
            loop.quit ();
        });
        loop.run ();
        return saved;
    }

    void play (Game game) throws Error {
        var loop = new MainLoop ();
        Error? failure = null;
        game.launch_external.begin ((source, result) => {
            try {
                game.launch_external.end (result);
            } catch (Error error) {
                failure = error;
            }
            loop.quit ();
        });
        loop.run ();
        if (failure != null)
            throw (owned) failure;
    }

    void library_and_launch (bool through_host) throws Error {
        var native = new Fixture (false, false, through_host);
        var flatpak = new Fixture (true, true, through_host);
        try {
            Game? native_row = null;
            Game? flatpak_row = null;
            foreach (var fixture in new Fixture[] { native, flatpak }) {
                var type = fixture == flatpak ? Launcher.InstallationTypes.FLATPAK : Launcher.InstallationTypes.SYSTEM;
                var launcher = new Launchers.Lutris (type, fixture.service);
                fixture.add (11, "Duplicate name", "wine", "one");
                fixture.add (12, "Duplicate name", "linux", "two");
                fixture.add (13, "Emulator", "dolphin", "three");
                fixture.add (14, "Uninstalled", "wine", "four", 0);
                FileUtils.set_contents (fixture.profile, "game: { prefix: " + fixture.home + " }\n");
                FileUtils.set_contents (Path.build_filename (Path.get_dirname (fixture.profile), "three.yml"), "game: [invalid");
                assert (load (launcher));
                assert (launcher.games.length () == 3);
                var wine = (Games.Lutris) launcher.games.nth_data (0);
                var native_game = (Games.Lutris) launcher.games.nth_data (1);
                var emulator = (Games.Lutris) launcher.games.nth_data (2);
                assert (wine.id == 11 && native_game.id == 12 && emulator.id == 13);
                assert (wine.launcher == launcher && wine.name == native_game.name);
                assert (wine.installdir == fixture.home && wine.prefixdir == fixture.home);
                assert (wine.can_launch && wine.can_edit_compatibility_tool);
                assert (native_game.can_launch && native_game.is_native && !native_game.can_edit_compatibility_tool);
                assert (emulator.can_launch && !emulator.is_native && !emulator.can_edit_compatibility_tool);
                play (wine);
                if (fixture == flatpak)
                    flatpak_row = wine;
                else
                    native_row = wine;
            }
            var host = through_host ? "flatpak-spawn\n--host\n" : "";
            assert (string.joinv ("\n", native.backend.arguments) == host + "lutris\nlutris:rungameid/11");
            assert (string.joinv ("\n", flatpak.backend.arguments) ==
                host + "flatpak\nrun\nnet.lutris.Lutris\nlutris:rungameid/11");
            flatpak.backend.native_closed = false;
            try {
                play (flatpak_row);
                assert_not_reached ();
            } catch (IOError.BUSY error) {
            }
            assert (flatpak.backend.arguments[flatpak.backend.arguments.length - 1] == "lutris:rungameid/11");

            foreach (var fixture in new Fixture[] { native, flatpak }) {
                var type = fixture == flatpak ? Launcher.InstallationTypes.FLATPAK : Launcher.InstallationTypes.SYSTEM;
                var selected = new Launchers.Lutris (type, fixture.service);
                var other = fixture == flatpak ? native : flatpak;
                string other_before;
                FileUtils.get_contents (other.profile, out other_before);
                var game = fixture == flatpak ? flatpak_row : native_row;
                assert (save (game, "wine-test"));
                assert (load (selected) && selected.games.nth_data (0).compatibility_tool == "wine-test");
                assert (save (selected.games.nth_data (0), "Default"));
                assert (load (selected) && selected.games.nth_data (0).compatibility_tool == "Default");
                string other_after;
                FileUtils.get_contents (other.profile, out other_after);
                assert (other_before == other_after);
            }

            native.add (11, "Duplicate ID", "wine", "different");
            native.backend.arguments = {};
            try {
                play (native_row);
                assert_not_reached ();
            } catch (IOError.NOT_FOUND error) {
                assert (native.backend.arguments.length == 0);
            }
            var remaining = new Launchers.Lutris (Launcher.InstallationTypes.SYSTEM, native.service);
            assert (load (remaining));
            assert (remaining.games.length () == 2);
            assert (((Games.Lutris) remaining.games.nth_data (0)).id == 12);
            assert (((Games.Lutris) remaining.games.nth_data (1)).id == 13);

            FileUtils.set_contents (Path.build_filename (flatpak.legacy, "lutris.conf"),
                "[DEFAULT]\npga_path = %s\n".printf (flatpak.db_file));
            var default_path = new Launchers.Lutris (Launcher.InstallationTypes.FLATPAK, flatpak.service);
            assert (load (default_path) && default_path.games.is_empty ());
        } finally {
            native.close ();
            flatpak.close ();
        }
    }

    void save_and_revalidate () throws Error {
        var fixture = new Fixture ();
        try {
            fixture.add (7, "Example", "wine", "one");
            var launcher = new Launchers.Lutris (Launcher.InstallationTypes.SYSTEM, fixture.service);
            var runner_config = Path.build_filename (fixture.data, "runners", "wine.yml");
            assert (DirUtils.create_with_parents (Path.get_dirname (runner_config), 0700) == 0);
            FileUtils.set_contents (runner_config, "wine: {version: wine-test, custom_wine_path: /custom/bin/wine}\n");
            var source = "game: {prefix: '%s', arch: win64}\nwine: {version: missing, esync: true}\nfuture: &a [!!str 123, false]\ncopy: *a\n"
                .printf (fixture.home);
            FileUtils.set_contents (fixture.profile, source);
            assert (load (launcher));
            var game = launcher.games.nth_data (0);
            assert (game.compatibility_tool == "missing" && game.get_game_tool_title ().contains ("Unavailable"));
            var options = choices (game);
            assert (options.size == 4);
            assert (!options[3].is_assignable);
            assert (options[0].display_title.contains ("Wine test") || options[0].display_title.contains ("wine-test"));
            assert (fixture.backend.last_custom_path == "/custom/bin/wine");

            fixture.backend.native_closed = false;
            assert (!save (game, "wine-test"));
            assert (game.compatibility_edit_error.contains ("Close"));
            fixture.backend.native_closed = true;
            fixture.backend.wine_present = false;
            assert (!save (game, "wine-test"));
            assert (game.compatibility_edit_error.contains ("no longer available"));
            fixture.backend.wine_present = true;

            var registry = Path.build_filename (fixture.home, "system.reg");
            FileUtils.set_contents (registry, "WINE REGISTRY Version 2\n#arch=win32\n");
            assert (choices (game).size == 3);
            assert (!save (game, "proton-test"));
            assert (FileUtils.remove (registry) == 0);

            assert (save (game, "proton-test"));
            assert (game.compatibility_tool == "proton-test");
            string latest;
            FileUtils.get_contents (fixture.profile, out latest);
            assert (latest.contains ("proton-test"));
            assert (latest.contains ("esync: true"));
            assert (latest.contains ("!!str 123"));
            assert (latest.contains ("copy: *a"));

            assert (save (game, "Default"));
            FileUtils.get_contents (fixture.profile, out latest);
            assert (!latest.contains ("version"));
            assert (latest.contains ("esync: true"));
            assert (game.get_game_tool_title () == "Inherited (Wine test)");

            FileUtils.set_contents (fixture.profile, source + "external: true\n");
            assert (!save (game, "wine-test"));
            assert (game.compatibility_tool == "Default");
            FileUtils.get_contents (fixture.profile, out latest);
            assert (latest == source + "external: true\n");

            assert (load (launcher));
            game = launcher.games.nth_data (0);
            fixture.add (19, "Same configuration", "wine", "one", 0);
            assert (!save (game, "Default"));

            FileUtils.set_contents (fixture.profile, "game: [broken");
            assert (load (launcher));
            assert (!launcher.games.nth_data (0).can_edit_compatibility_tool);

            assert (fixture.db.exec ("DELETE FROM games WHERE id = 19") == Sqlite.OK);
            FileUtils.set_contents (fixture.profile, "game: {exe: example.exe}\n");
            assert (load (launcher));
            game = launcher.games.nth_data (0);
            assert (game.compatibility_tool == "Default");
            assert (save (game, "wine-test"));
            assert (game.compatibility_tool == "wine-test");
            assert (save (game, "Default"));
            FileUtils.get_contents (fixture.profile, out latest);
            assert (!latest.contains ("version") && latest.contains ("example.exe"));

            var custom_path = Path.build_filename (fixture.home, "Custom Wine", "bin", "wine");
            FileUtils.set_contents (fixture.profile,
                "wine: {version: custom, custom_wine_path: '%s'}\n".printf (custom_path));
            assert (load (launcher));
            game = launcher.games.nth_data (0);
            fixture.backend.custom_present = true;
            assert (choices (game).any_match (tool => tool.internal_title == "custom" && !tool.is_assignable));
            assert (fixture.backend.last_custom_path == custom_path);
            assert (game.get_game_tool_title () == "Custom (%s)".printf (custom_path));
            fixture.backend.custom_present = false;
            assert (choices (game) != null && game.get_game_tool_title ().contains ("Unavailable"));
        } finally {
            fixture.close ();
        }
    }

    public void register_tests () {
        Test.add_func ("/lutris/library-and-launch", () => {
            try {
                library_and_launch (false);
                library_and_launch (true);
            } catch (Error error) {
                GLib.error ("%s", error.message);
            }
        });
        Test.add_func ("/lutris/save-and-revalidate", () => {
            try {
                save_and_revalidate ();
            } catch (Error error) {
                GLib.error ("%s", error.message);
            }
        });
    }
}
