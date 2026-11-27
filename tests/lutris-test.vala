using ProtonPlus;
using ProtonPlus.Models;
using ProtonPlus.Services;

namespace AppTests.LutrisTest {
    class FixtureBackend : Object, LutrisBackend {
        public bool native_closed = true;
        public bool flatpak_closed = true;
        public bool wine_present = true;
        public bool proton_present = true;
        public bool custom_present;
        public bool latest_available = true;
        public bool explicit_latest = true;
        public bool probe_failed;
        public string proton_path = "";
        public string[] arguments = {};
        public string? last_custom_path;

        public bool is_closed (bool flatpak) {
            return flatpak ? flatpak_closed : native_closed;
        }

        public Gee.List<CompatibilityTool> get_runners (bool flatpak, string? custom_path) throws Error {
            if (probe_failed)
                throw new IOError.FAILED ("Fixture probe failed");
            last_custom_path = custom_path;
            var tools = new Gee.ArrayList<CompatibilityTool> ();
            if (wine_present)
                tools.add (new CompatibilityTool ("Wine test", "wine-test", "", CompatibilityToolRuntimeKind.WINE));
            if (proton_present) {
                tools.add (new CompatibilityTool ("Proton test", "proton-test", proton_path, CompatibilityToolRuntimeKind.PROTON));
                tools.add (new CompatibilityTool ("GE-Proton (Latest)", "ge-proton", "", CompatibilityToolRuntimeKind.PROTON) {
                    is_assignable = explicit_latest, is_available = latest_available,
                    availability_diagnostic = latest_available ? null : "umu is required"
                });
            }
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

        public Fixture (bool flatpak = false, bool use_legacy = false, bool through_host = false,
            bool flatpak_override = false) throws Error {
            home = DirUtils.make_tmp ("protonplus-lutris-XXXXXX");
            data_home = Path.build_filename (home, "xdg-data");
            config_home = Path.build_filename (home, "xdg-config");
            if (flatpak && !flatpak_override) {
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
            service = new LutrisConfigurationService (flatpak, home, data_home, config_home, backend, through_host,
                flatpak_override ? data_home : null, flatpak_override ? config_home : null);
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
            var native_env = through_host ? "env\nXDG_DATA_HOME=%s\nXDG_CONFIG_HOME=%s\n"
                .printf (native.data_home, native.config_home) : "";
            assert (string.joinv ("\n", native.backend.arguments) == host + native_env + "lutris\nlutris:rungameid/11");
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
        fixture.backend.explicit_latest = false;
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
            assert (game.compatibility_tool == "missing" && game.get_game_tool_title ().contains ("Runner is missing"));
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
            assert (choices (game) != null && game.get_game_tool_title ().contains ("Runner is missing"));
        } finally {
            fixture.close ();
        }
    }

    private bool initialize (Gee.LinkedList<Launcher> launchers) {
        var loop = new MainLoop ();
        bool initialized = false;
        Launcher.initialize_launchers.begin (launchers, new ProtonPlus.Models.Providers.ProviderRegistry (), (obj, res) => {
            initialized = Launcher.initialize_launchers.end (res);
            loop.quit ();
        });
        loop.run ();
        return initialized;
    }

    private Tools.ProviderTool ge_proton (Launcher launcher) {
        var group = launcher.groups[0];
        return (Tools.ProviderTool) group.tools.first_match ((tool) => tool.provider_id == "proton-ge");
    }

    private void path_resolution () throws Error {
        foreach (var flatpak in new bool[] {false, true}) {
            var fixture = new Fixture (flatpak, true, false, flatpak);
            try {
                var runtime = Path.build_filename (fixture.home, "custom-runtime");
                var wine = Path.build_filename (fixture.home, "custom runners", "wine");
                var conf = Path.build_filename (fixture.legacy, "lutris.conf");
                string text;
                FileUtils.get_contents (conf, out text);
                FileUtils.set_contents (conf, text + "Runtime_DIR = " + runtime + "\n");
                FileUtils.set_contents (Path.build_filename (fixture.data, "lutris.conf"),
                    "[lutris]\nrunner_dir = /ignored\nruntime_dir = /ignored\npga_path = /ignored\n");
                var old_wine = Path.build_filename (fixture.data, "runners", "wine");
                var old_build = Path.build_filename (old_wine, "GE-Proton9-99");
                assert (DirUtils.create_with_parents (old_build, 0700) == 0);
                var type = flatpak ? Launcher.InstallationTypes.FLATPAK : Launcher.InstallationTypes.SYSTEM;
                var launcher = new Launchers.Lutris (type, fixture.service);
                assert (launcher.installed);
                assert (launcher.instance_id == (flatpak ? "lutris-flatpak" : "lutris-system"));
                assert (launcher.instance_id == launcher.tool_target_id);
                var launchers = new Gee.LinkedList<Launcher> ();
                launchers.add (launcher);
                assert (initialize (launchers));
                assert (launcher.get_primary_managed_tool_directory (launcher.groups[0]) == wine);
                assert (launcher.get_primary_managed_tool_directory (launcher.groups[1]) == wine);
                assert (FileUtils.test (Path.build_filename (runtime, "dxvk"), FileTest.IS_DIR));
                assert (FileUtils.test (Path.build_filename (runtime, "vkd3d"), FileTest.IS_DIR));
                var provider = ge_proton (launcher);
                assert (provider != null);
                assert (new Utils.Metadata () {
                    provider_id = provider.provider_id, tool_id = provider.id, launcher_id = launcher.tool_target_id,
                    tag = "GE-Proton9-99", variant_id = "x86", install_mode = "versioned"
                }.save (old_build));
                provider.group.refresh_installed_state (false);
                assert (provider.group.installed_tool_inventory.get_installations_for_tool (provider).size == 1);
                var old_job = new InstallJob (new Release ("GE-Proton9-99", "", "", new Assets.Asset ("", ""), ""), provider);
                assert (old_job.install_location == old_build);
                var old_latest = Path.build_filename (old_wine, "Proton-GE Latest");
                assert (DirUtils.create (old_latest, 0700) == 0);
                assert (new Utils.Metadata () {
                    provider_id = provider.provider_id, tool_id = provider.id, launcher_id = launcher.tool_target_id,
                    tag = "GE-Proton9-99", variant_id = "x86", install_mode = "latest"
                }.save (old_latest));
                provider.group.refresh_installed_state (false);
                var latest_job = new InstallJob (old_job.release, provider, InstallJob.Mode.LATEST);
                assert (latest_job.install_location == old_latest && old_job.install_location == old_build);
                var new_job = new InstallJob (new Release ("GE-Proton9-98", "", "", new Assets.Asset ("", ""), ""), provider);
                assert (new_job.install_location == Path.build_filename (wine, "GE-Proton9-98"));
                fixture.add (8, "Active library", "linux", "");
                assert (load (launcher) && launcher.games.length () == 1);
            } finally {
                fixture.close ();
            }
        }
    }

    private void effective_selection () throws Error {
        var fixture = new Fixture ();
        try {
            fixture.add (7, "Wine prefix", "wine", "one");
            var game_config = "game: {prefix: '%s'}\nwine: {version: wine-test, esync: true}\n".printf (fixture.home);
            FileUtils.set_contents (fixture.profile, game_config);
            var launcher = new Launchers.Lutris (Launcher.InstallationTypes.SYSTEM, fixture.service);
            assert (load (launcher));
            var game = (Games.Lutris) launcher.games.nth_data (0);
            var options = choices (game);
            assert (options[0].display_title.contains ("GE-Proton (Latest)"));
            assert (options.any_match ((tool) => tool.internal_title == "ge-proton" && tool.is_assignable));

            fixture.backend.latest_available = false;
            options = choices (game);
            assert (options[0].display_title.contains ("umu is required"));
            assert (!save (game, "Default") && game.compatibility_edit_error.contains ("umu"));
            fixture.backend.latest_available = true;
            fixture.backend.probe_failed = true;
            assert (choices (game) == null && game.compatibility_edit_error.contains ("Runner probe failed"));
            fixture.backend.probe_failed = false;

            var registry = Path.build_filename (fixture.home, "system.reg");
            FileUtils.set_contents (registry, "WINE REGISTRY Version 2\n#arch=win32\n");
            assert (!save (game, "Default") && game.compatibility_edit_error.contains ("64-bit"));
            FileUtils.set_contents (registry, "WINE REGISTRY Version 2\n#arch=win64\n");
            FileUtils.set_contents (Path.build_filename (fixture.home, "user.reg"), "");
            assert (!save (game, "Default") && game.pending_conversion != null);
            string contents;
            FileUtils.get_contents (fixture.profile, out contents);
            assert (contents == game_config);
            var loop = new MainLoop ();
            game.confirm_runner_change.begin ("Default", game.pending_conversion, null, (obj, res) => {
                assert (game.confirm_runner_change.end (res));
                loop.quit ();
            });
            loop.run ();
            FileUtils.get_contents (fixture.profile, out contents);
            assert (!contents.contains ("version:") && contents.contains ("esync: true"));
            assert (game.get_game_tool_title ().contains ("GE-Proton (Latest)"));

            FileUtils.set_contents (Path.build_filename (fixture.home, "tracked_files"), "");
            assert (save (game, "ge-proton"));
            assert (game.compatibility_tool == "ge-proton");
            var default_path = Path.build_filename (fixture.data, "runners", "wine.yml");
            assert (DirUtils.create_with_parents (Path.get_dirname (default_path), 0700) == 0);
            FileUtils.set_contents (default_path, "wine: {version: wine-test}\n");
            assert (choices (game)[0].display_title.contains ("Wine test"));
            assert (game.get_game_tool_title () == "GE-Proton (Latest)");
            fixture.backend.explicit_latest = false;
            assert (choices (game) != null);
            assert (game.compatibility_tool == "ge-proton" && game.get_game_tool_title ().contains ("uses Wine test"));
        } finally {
            fixture.close ();
        }
    }

    private class EmptyProcessBackend : Object, CompatibilityProcessQueryBackend {
        public async CompatibilityProcessInspectionResult inspect_processes () {
            return CompatibilityProcessInspectionResult.clear ();
        }
    }

    private LutrisRemovalReview review_removal (InstallJob job) {
        var loop = new MainLoop ();
        LutrisRemovalReview? review = null;
        var service = InstallationService.instance;
        service.inspect_lutris_removal.begin (job, (obj, res) => {
            review = service.inspect_lutris_removal.end (res);
            loop.quit ();
        });
        loop.run ();
        return review;
    }

    private ReturnCode remove_reviewed (InstallJob job, LutrisRemovalReview review) {
        var loop = new MainLoop ();
        ReturnCode code = ReturnCode.FILESYSTEM_ERROR;
        var service = InstallationService.instance;
        service.remove.begin (job, false, review, (obj, res) => {
            code = service.remove.end (res);
            loop.quit ();
        });
        loop.run ();
        return code;
    }

    private int uninstall (Gee.LinkedList<Launcher> launchers, string id, CLI.RecordingCliOutputSink output) {
        var loop = new MainLoop ();
        var cli = new CLI.Handler (launchers, output);
        int code = 0;
        string[] args = { "protonplus", "uninstall", id, "proton-ge", "all" };
        cli.run.begin (args, (obj, res) => {
            code = cli.run.end (res);
            loop.quit ();
        });
        loop.run ();
        return code;
    }

    private void dependency_removal () throws Error {
        var fixture = new Fixture (true);
        InstallationService.instance.configure_compatibility_process_guard (new CompatibilityProcessGuard (new EmptyProcessBackend ()));
        try {
            var launcher = new Launchers.Lutris (Launcher.InstallationTypes.FLATPAK, fixture.service);
            var launchers = new Gee.LinkedList<Launcher> ();
            launchers.add (launcher);
            assert (initialize (launchers));
            var provider = ge_proton (launcher);
            var root = launcher.get_primary_managed_tool_directory (provider.group);
            var runner = Path.build_filename (root, "GE-Proton9-99");
            var executable = Path.build_filename (runner, "files", "bin", "wine");
            assert (DirUtils.create_with_parents (Path.get_dirname (executable), 0700) == 0);
            FileUtils.set_contents (executable, "fixture");
            var link = Path.build_filename (fixture.home, "runner-alias");
            assert (FileUtils.symlink (runner, link) == 0);
            fixture.backend.proton_path = Path.build_filename (link, "files", "bin", "wine");
            assert (new Utils.Metadata () {
                provider_id = provider.provider_id, tool_id = provider.id, launcher_id = launcher.tool_target_id,
                tag = "GE-Proton9-99", variant_id = "x86", install_mode = "versioned"
            }.save (runner));
            var release = new Release ("GE-Proton9-99", "", "", new Assets.Asset ("", ""), "");
            var job = new InstallJob (release, provider, InstallJob.Mode.VERSIONED, runner);
            fixture.add (7, "Pinned Game", "wine", "one");
            FileUtils.set_contents (fixture.profile, "wine: {version: proton-test}\n");
            var prior = review_removal (job);
            assert (prior.error == null && prior.affected_games == "Pinned Game · Lutris Flatpak");
            var output = new CLI.RecordingCliOutputSink ();
            assert (uninstall (launchers, launcher.instance_id, output) == 1);
            assert (output.stderr_text.contains ("Choose a different runner") && output.stderr_text.contains ("Pinned Game"));
            assert (FileUtils.test (runner, FileTest.IS_DIR));

            fixture.add (8, "Inherited Game", "wine", "two");
            var default_path = Path.build_filename (fixture.data, "runners", "wine.yml");
            FileUtils.set_contents (default_path, "wine: {version: proton-test}\n");
            assert (remove_reviewed (job, prior) == ReturnCode.LUTRIS_RUNNER_REQUIRED);
            assert (job.error_message.contains ("Inherited Game"));
            assert (fixture.db.exec ("ALTER TABLE games RENAME TO hidden_games") == Sqlite.OK);
            var unreadable = review_removal (job);
            assert (unreadable.error != null);
            assert (remove_reviewed (job, prior) == ReturnCode.LIBRARY_INSPECTION_FAILED);
            assert (FileUtils.test (runner, FileTest.IS_DIR));
            assert (fixture.db.exec ("ALTER TABLE hidden_games RENAME TO games") == Sqlite.OK);
            assert (remove_reviewed (job, review_removal (job)) == ReturnCode.RUNNER_REMOVED);
            assert (!FileUtils.test (runner, FileTest.EXISTS));
        } finally {
            InstallationService.reset_lifecycle_configuration_for_tests ();
            fixture.close ();
        }
    }

    private class RecordingRestart : Object, SteamChangeRecorder {
        public SteamChangeReceipt? receipt;

        public SteamRestartRecordResult record (SteamChangeReceipt receipt) {
            this.receipt = receipt;
            return SteamRestartRecordResult.ADDED;
        }
    }

    private void shared_tool_ownership () throws Error {
        var fixture = new Fixture (false, true);
        var restart = new RecordingRestart ();
        var installation = InstallationService.instance;
        installation.configure_steam_change_recorder (restart);
        installation.configure_compatibility_process_guard (new CompatibilityProcessGuard (new EmptyProcessBackend ()));
        try {
            var steam = new Launchers.Steam (Launcher.InstallationTypes.SYSTEM);
            steam.directory = Path.build_filename (fixture.home, "Steam");
            steam.installed = false;
            var steam_root = Path.build_filename (steam.directory, "compatibilitytools.d");
            var runner_dir = Path.build_filename (fixture.home, "custom runners");
            assert (DirUtils.create_with_parents (runner_dir, 0700) == 0);
            assert (DirUtils.create_with_parents (steam_root, 0700) == 0);
            assert (FileUtils.symlink (steam_root, Path.build_filename (runner_dir, "wine")) == 0);

            var lutris = new Launchers.Lutris (Launcher.InstallationTypes.SYSTEM, fixture.service);
            var launchers = new Gee.LinkedList<Launcher> ();
            launchers.add (steam);
            launchers.add (lutris);
            assert (initialize (launchers));
            var steam_tool = ge_proton (steam);
            var lutris_tool = ge_proton (lutris);
            var managed = Path.build_filename (steam_root, "GE-Proton9-99");
            var foreign = Path.build_filename (steam_root, "GE-Proton9-98");
            var unmanaged = Path.build_filename (steam_root, "GE-Proton9-97");
            assert (DirUtils.create (managed, 0700) == 0);
            assert (DirUtils.create (foreign, 0700) == 0);
            assert (DirUtils.create (unmanaged, 0700) == 0);
            assert (new Utils.Metadata () {
                provider_id = lutris_tool.provider_id, tool_id = lutris_tool.id, launcher_id = lutris.tool_target_id,
                variant_id = "x86", install_mode = "versioned"
            }.save (managed));
            assert (new Utils.Metadata () {
                provider_id = steam_tool.provider_id, tool_id = steam_tool.id, launcher_id = steam.tool_target_id,
                variant_id = "x86", install_mode = "versioned"
            }.save (foreign));

            lutris_tool.group.refresh_installed_state (false);
            var visible = lutris_tool.group.installed_tool_inventory.get_installations_for_tool (lutris_tool);
            assert (visible.size == 1 && Path.get_basename (visible[0].path) == "GE-Proton9-99");
            steam_tool.group.refresh_installed_state (false);
            assert (steam_tool.group.installed_tool_inventory.get_installations_for_tool (steam_tool)
                .all_match ((entry) => entry.path != managed));

            var foreign_job = new InstallJob (new Release ("GE-Proton9-98", "", "", new Assets.Asset ("", ""), ""),
                lutris_tool, InstallJob.Mode.VERSIONED, foreign);
            assert (remove_reviewed (foreign_job, review_removal (foreign_job)) == ReturnCode.UNSUPPORTED_OPERATION);
            assert (restart.receipt == null && FileUtils.test (foreign, FileTest.IS_DIR));

            var owned_job = new InstallJob (new Release ("GE-Proton9-99", "", "", new Assets.Asset ("", ""), ""),
                lutris_tool, InstallJob.Mode.VERSIONED, visible[0].path);
            assert (remove_reviewed (owned_job, review_removal (owned_job)) == ReturnCode.RUNNER_REMOVED);
            assert (restart.receipt != null && restart.receipt.target.id == steam.get_steam_restart_target ().id);
            assert (!FileUtils.test (managed, FileTest.EXISTS) && FileUtils.test (foreign, FileTest.IS_DIR));
        } finally {
            InstallationService.reset_lifecycle_configuration_for_tests ();
            fixture.close ();
        }
    }

    private class ProbeBackend : HostLutrisBackend {
        private SubprocessLauncher process_launcher;

        public ProbeBackend (string home, bool modern, bool has_umu, bool fail = false) {
            process_launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            process_launcher.setenv ("HOME", home, true);
            process_launcher.setenv ("PATH", Path.build_filename (home, "bin") + ":/usr/bin:/bin", true);
            process_launcher.setenv ("FIXTURE_MODERN_LUTRIS", modern ? "1" : "", true);
            process_launcher.setenv ("FIXTURE_UMU", has_umu ? "1" : "", true);
            process_launcher.setenv ("FIXTURE_PROBE_FAILURE", fail ? "1" : "", true);
        }

        protected override string query_runner_probe (string[] argv) throws Error {
            var process = process_launcher.spawnv (argv);
            string? output;
            string? stderr_text;
            process.communicate_utf8 (null, null, out output, out stderr_text);
            if (!process.get_successful ())
                throw new IOError.FAILED (stderr_text ?? "Fixture runner probe did not finish");
            return output ?? "";
        }
    }

    private void probe_fixture () throws Error {
        if (Environment.find_program_in_path ("python3") == null) {
            Test.skip ("Python 3 is required to exercise the Lutris runner probe");
            return;
        }
        var fixture = new Fixture ();
        try {
            var modules = Path.build_filename (fixture.home, "lutris", "util", "wine");
            var bin = Path.build_filename (fixture.home, "bin");
            assert (DirUtils.create_with_parents (modules, 0700) == 0);
            assert (DirUtils.create_with_parents (bin, 0700) == 0);
            var launcher = Path.build_filename (bin, "lutris");
            FileUtils.set_contents (launcher, "#!/bin/sh\nexit 99\n");
            assert (FileUtils.chmod (launcher, 0700) == 0);
            var package_path = Path.build_filename (fixture.home, "lutris");
            FileUtils.set_contents (Path.build_filename (package_path, "__init__.py"), "");
            FileUtils.set_contents (Path.build_filename (package_path, "settings.py"),
                "import os\nWINE_DIR = os.path.join(os.environ['HOME'], 'active-wine')\n");
            FileUtils.set_contents (Path.build_filename (package_path, "exceptions.py"),
                "class MissingExecutableError(Exception): pass\n");
            FileUtils.set_contents (Path.build_filename (modules, "proton.py"), """
import os, re
from types import SimpleNamespace
from lutris.settings import WINE_DIR
from lutris.exceptions import MissingExecutableError

MODERN = bool(os.environ["FIXTURE_MODERN_LUTRIS"])
LINUX_SYSTEM = SimpleNamespace(arch="x86_64")

def _iter_proton_locations():
    yield WINE_DIR
    if MODERN:
        yield os.path.join(os.environ["HOME"], "Steam", "compatibilitytools.d")

def get_umu_path():
    if os.environ["FIXTURE_PROBE_FAILURE"]:
        raise RuntimeError("Unexpected fixture failure")
    if not os.environ["FIXTURE_UMU"]:
        raise MissingExecutableError()
    return os.path.join(os.environ["HOME"], "bin", "umu-run")

def get_proton_versions():
    return {name: os.path.join(root, name) for root in _iter_proton_locations()
            for name in os.listdir(root) if os.path.isfile(os.path.join(root, name, "proton"))}

def is_ge_proton_release(version):
    return bool(re.fullmatch(r"GE-Proton[0-9]+-[0-9]+", version))

if MODERN:
    def find_proton_version(version):
        versions = get_proton_versions()
        return next((candidate for candidate in (version, version + "-x86_64") if candidate in versions), None)

def is_umu_path(path):
    return path.endswith("/umu-run")
""");
            FileUtils.set_contents (Path.build_filename (modules, "wine.py"), """
import os
from . import proton

WINE_PATHS = {}

def list_lutris_wine_versions():
    return []

def get_default_wine_version():
    return "ge-proton"

def get_wine_path_for_version(version):
    installed = proton.find_proton_version(version) if proton.MODERN else version
    return os.path.join(proton.get_proton_versions()[installed], "files", "bin", "wine")
""");
            var local = Path.build_filename (fixture.home, "active-wine", "GE-Proton11-1-x86_64");
            var shared = Path.build_filename (fixture.home, "Steam", "compatibilitytools.d", "GE-Proton11-2-x86_64");
            foreach (var root in new string[] { local, shared }) {
                var wine = Path.build_filename (root, "files", "bin", "wine");
                assert (DirUtils.create_with_parents (Path.get_dirname (wine), 0700) == 0);
                foreach (var executable in new string[] { wine, Path.build_filename (root, "proton") }) {
                    FileUtils.set_contents (executable, "#!/bin/sh\nexit 99\n");
                    assert (FileUtils.chmod (executable, 0700) == 0);
                }
            }
            var umu = Path.build_filename (bin, "umu-run");
            FileUtils.set_contents (umu, "#!/bin/sh\nexit 99\n");
            assert (FileUtils.chmod (umu, 0700) == 0);
            var old = new ProbeBackend (fixture.home, false, true).get_runners (false, null);
            assert (old.any_match ((tool) => tool.internal_title == "GE-Proton11-1-x86_64" && tool.is_available));
            assert (!old.any_match ((tool) => tool.internal_title == "GE-Proton11-1" ||
                tool.internal_title.has_prefix ("GE-Proton11-2")));
            assert (old.any_match ((tool) => tool.internal_title == "ge-proton" && !tool.is_assignable));
            var modern = new ProbeBackend (fixture.home, true, true).get_runners (false, null);
            var bare = modern.first_match ((tool) => tool.internal_title == "GE-Proton11-2");
            assert (bare != null && bare.is_available && bare.installation_path == shared);
            assert (modern.any_match ((tool) => tool.internal_title == "GE-Proton11-2-x86_64" &&
                tool.installation_path == bare.installation_path));
            assert (modern.any_match ((tool) => tool.internal_title == "ge-proton" && tool.is_assignable && tool.is_available));
            var missing = new ProbeBackend (fixture.home, true, false).get_runners (false, null);
            var missing_alias = missing.first_match ((tool) => tool.internal_title == "GE-Proton11-2");
            assert (missing_alias != null && !missing_alias.is_available &&
                missing_alias.availability_diagnostic.contains ("umu") && missing_alias.installation_path == shared);
            try {
                new ProbeBackend (fixture.home, true, true, true).get_runners (false, null);
                assert_not_reached ();
            } catch (IOError.FAILED error) {
                assert (error.message.contains ("Unexpected fixture failure"));
            }
        } finally {
            fixture.close ();
        }
    }

    public void register_tests () {
        Test.add_func ("/lutris/shared-steam-storage", () => {
            try {
                shared_tool_ownership ();
            } catch (Error error) {
                GLib.error ("%s", error.message);
            }
        });
        Test.add_func ("/lutris/production-runner-probe", () => {
            try {
                probe_fixture ();
            } catch (Error error) {
                GLib.error ("%s", error.message);
            }
        });
        Test.add_func ("/lutris/dependency-removal", () => {
            try {
                dependency_removal ();
            } catch (Error error) {
                GLib.error ("%s", error.message);
            }
        });
        Test.add_func ("/lutris/effective-selection", () => {
            try {
                effective_selection ();
            } catch (Error error) {
                GLib.error ("%s", error.message);
            }
        });
        Test.add_func ("/lutris/path-resolution", () => {
            try {
                path_resolution ();
            } catch (Error error) {
                GLib.error ("%s", error.message);
            }
        });
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
