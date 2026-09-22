namespace AppTests.SteamGameLaunchTest {
    using ProtonPlus.Models;
    using ProtonPlus.Services;

    private class LaunchFactory : Object, SteamRestartProcessFactory {
        public string[] last_argv;
        public bool fail = false;
        public int calls = 0;

        public Subprocess spawn_detached (string[] argv) throws Error {
            calls++;
            last_argv = argv;
            if (fail)
                throw new IOError.NOT_FOUND ("Fixture Steam executable is missing.");
            return new Subprocess.newv ({ "/bin/true" }, SubprocessFlags.NONE);
        }
    }

    public void register_tests () {
        Test.add_func ("/steam-game-launch/selected-installation", test_selected_installation);
        Test.add_func ("/steam-game-launch/non-steam-shortcut-game-id", test_non_steam_shortcut_game_id);
        Test.add_func ("/steam-game-launch/dispatch-errors", test_dispatch_errors);
    }

    private void test_selected_installation () {
        var factory = new LaunchFactory ();
        var service = new SteamGameLaunchService (factory);
        var targets = new SteamRestartTarget[] {
            SteamRestartTarget.for_native ("/fixture/native"),
            SteamRestartTarget.for_flatpak ("/fixture/flatpak"),
            SteamRestartTarget.for_snap ("/fixture/snap")
        };
        foreach (var target in targets) {
            foreach (var host in new bool[] { false, true }) {
                try {
                    service.launch (target, uint.MAX, false, host);
                } catch (Error e) {
                    assert_not_reached ();
                }
                var offset = host ? 2 : 0;
                if (host) {
                    assert (factory.last_argv[0] == "flatpak-spawn");
                    assert (factory.last_argv[1] == "--host");
                }
                if (target.installation_kind == SteamInstallationKind.NATIVE) {
                    assert (factory.last_argv.length == offset + 2);
                    assert (factory.last_argv[offset] == "/usr/bin/steam");
                } else {
                    assert (factory.last_argv.length == offset + 4);
                    assert (factory.last_argv[offset] ==
                        (target.installation_kind == SteamInstallationKind.FLATPAK ? "flatpak" : "snap"));
                    assert (factory.last_argv[offset + 1] == "run");
                    assert (factory.last_argv[offset + 2] ==
                        (target.installation_kind == SteamInstallationKind.FLATPAK ? "com.valvesoftware.Steam" : "steam"));
                }
                assert (factory.last_argv[factory.last_argv.length - 1] == "steam://run/4294967295");
            }
        }
        assert (factory.calls == 6);
    }

    private void test_non_steam_shortcut_game_id () {
        var factory = new LaunchFactory ();
        var service = new SteamGameLaunchService (factory);
        var ids = new uint[] { 0x80000000U, 0xf1234567U, uint.MAX };
        var expected = new string[] {
            "steam://rungameid/9223372036888330240",
            "steam://rungameid/17375808096043008000",
            "steam://rungameid/18446744069448138752"
        };
        foreach (var kind in new Launcher.InstallationTypes[] {
            Launcher.InstallationTypes.SYSTEM,
            Launcher.InstallationTypes.FLATPAK,
            Launcher.InstallationTypes.SNAP
        }) {
            var launcher = new Launchers.Steam (kind);
            launcher.directory = "/fixture/Steam";
            for (var i = 0; i < ids.length; i++) {
                // shortcuts.vdf stores signed int32 values, read as uint by
                // SteamProfile. Preserve their bits before widening to uint64.
                var stored_id = new GLib.Variant.int32 ((int32) ids[i]);
                var game = new Games.Steam.non_steam ((uint) stored_id.get_int32 (),
                    "Fixture shortcut", "", "Default", launcher);
                foreach (var host in new bool[] { false, true }) {
                    try {
                        service.launch (launcher.get_steam_restart_target (),
                            game.appid, game.is_non_steam, host);
                    } catch (Error e) {
                        assert_not_reached ();
                    }
                    assert (factory.last_argv[factory.last_argv.length - 1] == expected[i]);
                    assert (game.appid == ids[i]);
                }
            }
        }
        assert (factory.calls == 18);
    }

    private void test_dispatch_errors () {
        var factory = new LaunchFactory ();
        var service = new SteamGameLaunchService (factory);
        factory.fail = true;
        try {
            service.launch (SteamRestartTarget.for_native ("/fixture/Steam"), 123, false, false);
            assert_not_reached ();
        } catch (Error e) {
            assert (e is IOError.NOT_FOUND);
        }
        try {
            service.launch (new SteamRestartTarget ("/fixture/custom", SteamInstallationKind.CUSTOM), 123, false, false);
            assert_not_reached ();
        } catch (Error e) {
            assert (e is IOError.NOT_SUPPORTED);
        }
        assert (factory.calls == 1);
    }
}
