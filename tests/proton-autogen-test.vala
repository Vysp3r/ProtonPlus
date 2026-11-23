namespace AppTests.ProtonAutogenTest {
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Utils;

    private class Fixture : Object {
        public string root;
        public string games_directory;
        public string steam_directory;

        public Fixture () throws Error {
            root = DirUtils.make_tmp ("protonplus-autogen-test-XXXXXX");
            games_directory = Path.build_filename (root, ".config", "proton-autogen", "games");
            steam_directory = Path.build_filename (root, "Steam");
            assert (DirUtils.create_with_parents (games_directory, 0700) == 0);
        }

        public string write (string name, string contents) throws Error {
            var path = Path.build_filename (games_directory, name);
            FileUtils.set_contents (path, contents);
            return path;
        }

        public string add_tool (string name, bool executable = true) throws Error {
            var path = Path.build_filename (steam_directory, "compatibilitytools.d", name);
            assert (DirUtils.create_with_parents (path, 0700) == 0);
            var proton = Path.build_filename (path, "proton");
            FileUtils.set_contents (proton, "fixture");
            if (executable)
                assert (Posix.chmod (proton, 0700) == 0);
            return path;
        }

        public ProtonAutogenProfile read_only_profile () throws Error {
            var profiles = ProtonAutogenConfig.read_profiles (games_directory);
            assert (profiles.size == 1);
            return profiles[0];
        }

        public void cleanup () {
            var loop = new MainLoop ();
            Filesystem.delete_directory.begin (root, (source, result) => {
                assert (Filesystem.delete_directory.end (result));
                loop.quit ();
            });
            loop.run ();
        }
    }

    public void register_tests () {
        Test.add_func ("/proton-autogen/profile-preserves-unrelated-bytes", test_exact_profile_edit);
        Test.add_func ("/proton-autogen/profile-fallbacks-and-bad-files", test_profile_fallbacks);
        Test.add_func ("/proton-autogen/profile-rejects-conflicts", test_profile_conflicts);
        Test.add_func ("/proton-autogen/launcher-and-shared-tools", test_launcher);
    }

    private string read (string path) throws Error {
        string contents;
        FileUtils.get_contents (path, out contents);
        return contents;
    }

    private void test_exact_profile_edit () {
        try {
            var fixture = new Fixture ();
            const string original = """
{
  "id": "abc123", "name": "Café", "path": "/games/Café/game.exe",
  "config_path": "elsewhere.json", "unknown": {"proton": "nested, [ }]", "number": 9991234567890000000},
  "env": {"A": "preserve"}, "\u0070roton" : "/steam/Old-Proton", "last": 1.2300e+04
}
""";
            var path = fixture.write ("profile.json", original);
            var sentinel = fixture.write ("elsewhere.json", "untouched");
            var profile = fixture.read_only_profile ();
            assert (profile.name == "Café" && profile.proton == "/steam/Old-Proton");

            // An external write to an unrelated setting is merged from disk.
            var fresh = original.replace ("preserve", "changed outside ProtonPlus");
            FileUtils.set_contents (path, fresh);
            var updated = ProtonAutogenConfig.update_proton (profile, "GE-Proton Latest");
            var expected = fresh.replace ("\"/steam/Old-Proton\"", "\"GE-Proton Latest\"");
            assert_cmpstr (read (path), CompareOperator.EQ, expected);
            assert_cmpstr (read (sentinel), CompareOperator.EQ, "untouched");
            assert_cmpstr (updated.proton, CompareOperator.EQ, "GE-Proton Latest");
            fixture.cleanup ();
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
    }

    private void test_profile_fallbacks () {
        try {
            var fixture = new Fixture ();
            var original = "{\"path\": \"/games/a program.exe\", \"config_path\": null}\n";
            var path = fixture.write ("valid.json", original);
            fixture.write ("invalid.json", "{broken}");
            fixture.write ("relative.json", "{\"path\":\"game.exe\"}");
            fixture.write ("invalid-setting.json", "{\"path\":\"/game.exe\",\"proton\":{}}");
            var link_path = Path.build_filename (fixture.games_directory, "linked.json");
            assert (Posix.symlink (path, link_path) == 0);
            var profile = fixture.read_only_profile ();
            assert (profile.name == "a program.exe" && profile.proton == "");
            ProtonAutogenConfig.update_proton (profile, "");
            assert_cmpstr (read (path), CompareOperator.EQ, original);
            var changed = ProtonAutogenConfig.update_proton (profile, "GE-Proton \"Latest\"");
            assert (fixture.read_only_profile ().proton == changed.proton);
            ProtonAutogenConfig.update_proton (changed, "");
            assert (fixture.read_only_profile ().proton == "");
            fixture.cleanup ();
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
    }

    private void test_profile_conflicts () {
        try {
            var fixture = new Fixture ();
            var original = "{\"id\":\"original\",\"path\":\"/game.exe\",\"proton\":\"old\"}";
            var path = fixture.write ("profile.json", original);
            var profile = fixture.read_only_profile ();

            foreach (var conflict in new string[] {
                original.replace ("old", "external"),
                original.replace ("original", "different"),
                original.replace ("game.exe", "new.exe")
            }) {
                FileUtils.set_contents (path, conflict);
                try {
                    ProtonAutogenConfig.update_proton (profile, "new");
                    assert_not_reached ();
                } catch (IOError.WRONG_ETAG error) {
                    assert_cmpstr (read (path), CompareOperator.EQ, conflict);
                }
            }
            var sentinel = fixture.write ("sentinel", original);
            assert (FileUtils.unlink (path) == 0);
            assert (Posix.symlink (sentinel, path) == 0);
            try {
                ProtonAutogenConfig.update_proton (profile, "new");
                assert_not_reached ();
            } catch (IOError.INVALID_DATA error) {
                assert_cmpstr (read (sentinel), CompareOperator.EQ, original);
            }
            fixture.cleanup ();
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
    }

    private void test_launcher () {
        var loop = new MainLoop ();
        exercise_launcher.begin ((source, result) => {
            try {
                exercise_launcher.end (result);
            } catch (Error error) {
                GLib.error ("%s", error.message);
            }
            loop.quit ();
        });
        loop.run ();
    }

    private async void exercise_launcher () throws Error {
        var fixture = new Fixture ();
        var old = fixture.add_tool ("GE-Proton Latest");
        fixture.add_tool ("Luxtorpeda");
        fixture.add_tool ("Proton-Autogen Latest");
        fixture.add_tool ("Missing-Executable-Proton", false);
        var alias = Path.build_filename (fixture.root, "steam-alias");
        assert (Posix.symlink (fixture.steam_directory, alias) == 0);
        var saved_path = Path.build_filename (alias, "compatibilitytools.d", Path.get_basename (old));
        var profile_file = fixture.write ("game.json", "{\"id\":\"game\",\"path\":\"/game.exe\",\"proton\":\"%s\"}".printf (saved_path));

        var native = new Launchers.Steam (Launcher.InstallationTypes.SYSTEM);
        native.directory = "";
        var fallback = new Launchers.ProtonAutogen (native, fixture.root, false);
        var fallback_group = new Group ("Proton", "", "/compatibilitytools.d", fallback, "proton");
        assert (fallback.get_primary_managed_tool_directory (fallback_group) ==
                Path.build_filename (fixture.root, ".local", "share", "Steam", "compatibilitytools.d"));
        assert (fallback.get_steam_restart_target () == null);

        native.directory = fixture.steam_directory;
        native.installed = true;
        var launcher = new Launchers.ProtonAutogen (native, fixture.root, false);
        assert (launcher.installed && launcher.has_library_support);
        assert (launcher.instance_id == "proton-autogen-system");
        assert (launcher.tool_target_id == native.tool_target_id);
        assert (launcher.get_steam_restart_target ().id == native.get_steam_restart_target ().id);
        var launchers = new Gee.LinkedList<Launcher> ();
        launchers.add (launcher);
        var definitions = new ProviderRegistry ();
        assert (yield Launcher.initialize_launchers (launchers, definitions));
        assert (launcher.groups.length == 1 && launcher.groups[0].tools.size == 7);
        assert (launcher.get_primary_managed_tool_directory (launcher.groups[0]) ==
                native.get_primary_managed_tool_directory (launcher.groups[0]));
        assert (launcher.compatibility_tools.size == 1);
        var game = launcher.games.first ().data;
        assert (game.compatibility_tool == "GE-Proton Latest");

        launcher.register_compatibility_tool_from_path (old);
        assert (native.find_compatibility_tool ("GE-Proton Latest") != null);
        launcher.unregister_compatibility_tool_by_path (old);
        assert (native.find_compatibility_tool ("GE-Proton Latest") == null);

        var installed_id = "Proton-CachyOS Latest-x86_64_v3";
        var installed = fixture.add_tool (installed_id);
        yield launcher.refresh_game_compatibility_tools ();
        assert (yield game.change_compatibility_tool_async (installed_id));
        assert (game.compatibility_tool == installed_id);
        assert (fixture.read_only_profile ().proton == installed_id);
        assert (FileUtils.unlink (Path.build_filename (installed, "proton")) == 0);
        assert (!(yield game.change_compatibility_tool_async (installed_id)));
        assert (fixture.read_only_profile ().proton == installed_id);
        yield launcher.refresh_game_compatibility_tools ();
        assert (launcher.compatibility_tools.first_match ((tool) => tool.internal_title == installed_id && !tool.is_available) != null);
        assert (yield game.change_compatibility_tool_async ("Default"));
        assert (game.compatibility_tool == "Default" && fixture.read_only_profile ().proton == "");
        assert (FileUtils.test (profile_file, FileTest.IS_REGULAR));
        yield Filesystem.delete_directory (fixture.root);
    }
}
