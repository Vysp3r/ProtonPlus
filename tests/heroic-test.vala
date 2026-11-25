namespace AppTests.HeroicTest {
    using ProtonPlus.Models;
    using ProtonPlus.Models.Launchers;
    using ProtonPlus.Models.Games;
    using ProtonPlus.Services;

    private const string EPIC = "legendaryConfig/legendary/installed.json";
    private const string GOG = "gog_store/installed.json";
    private const string AMAZON = "nile_config/nile/installed.json";
    private const string SIDELOAD = "sideload_apps/library.json";

    private class Fixture : Object {
        public string home;
        public string config_home;
        public string native_config;
        public string flatpak_config;
        public string applications;
        public string[] command;
        public bool fail_spawn;

        public Fixture () throws Error {
            home = DirUtils.make_tmp ("protonplus-heroic-XXXXXX");
            config_home = dir ("native-config");
            native_config = dir ("native-config/heroic");
            flatpak_config = dir (".var/app/" + HeroicGamesLauncher.FLATPAK_ID + "/config/heroic");
            applications = dir ("applications");
        }

        public string dir (string relative) {
            var path = Path.build_filename (home, relative);
            assert (DirUtils.create_with_parents (path, 0700) == 0);
            return path;
        }

        public void write (string root, string relative, string contents) throws Error {
            var path = Path.build_filename (root, relative);
            assert (DirUtils.create_with_parents (Path.get_dirname (path), 0700) == 0);
            FileUtils.set_contents (path, contents);
        }

        public HeroicGamesLauncher launcher (bool flatpak, bool through_host = false) {
            return new HeroicGamesLauncher (flatpak ? Launcher.InstallationTypes.FLATPAK : Launcher.InstallationTypes.SYSTEM,
                home, config_home, new HeroicLaunchService (through_host, applications, spawn));
        }

        public Subprocess? spawn (string[] argv) throws Error {
            command = argv;
            if (fail_spawn)
                throw new IOError.FAILED ("Heroic fixture launch failed");
            return null;
        }

        public void cleanup () {
            var loop = new MainLoop ();
            ProtonPlus.Utils.Filesystem.delete_directory.begin (home, (object, result) => {
                assert (ProtonPlus.Utils.Filesystem.delete_directory.end (result));
                loop.quit ();
            });
            loop.run ();
        }
    }

    public void register_tests () {
        Test.add_func ("/heroic/installed-stores-and-paths", test_installed_stores_and_paths);
        Test.add_func ("/heroic/metadata-errors-and-recovery", test_metadata_errors_and_recovery);
        Test.add_func ("/heroic/runner-settings", test_runner_settings);
        Test.add_func ("/heroic/selected-instance-launch", test_selected_instance_launch);
    }

    private bool load (Launcher launcher) {
        var loop = new MainLoop ();
        bool success = false;
        launcher.load_profile_library.begin ((source, result) => {
            success = launcher.load_profile_library.end (result);
            loop.quit ();
        });
        assert (launcher.game_library_loading);
        loop.run ();
        assert (!launcher.game_library_loading);
        return success;
    }

    private Heroic game (Launcher launcher, HeroicStore store, string id = "shared") {
        foreach (var item in launcher.games) {
            var heroic = (Heroic) item;
            if (heroic.store == store && heroic.app_name == id)
                return heroic;
        }
        assert_not_reached ();
    }

    private void test_installed_stores_and_paths () {
        try {
            var fixture = new Fixture ();
            var config = fixture.native_config;
            var game_dir = fixture.dir ("Games/Epic Game");
            var gog_dir = fixture.dir ("Games/GOG Native");
            var amazon_dir = fixture.dir ("Games/Amazon Game");
            var sideload_dir = fixture.dir ("Games/Sideload");
            var prefix = fixture.dir ("wine-prefix");
            var proton_pfx = fixture.dir ("proton-prefix/pfx");

            fixture.write (config, EPIC, """{
                "shared": {"app_name":"shared", "title":"Epic Game", "install_path":"%s", "platform":"Windows"},
                "addon": {"app_name":"addon", "is_dlc":true},
                "removed": {"app_name":"removed", "is_installed":false},
                "invalid": null
            }""".printf (game_dir));
            fixture.write (config, GOG, """{"installed":[
                {"appName":"shared", "install_path":"%s", "platform":"linux"},
                {"appName":"detached", "install_path":"/nonexistent/heroic-disk/Game", "platform":"windows"},
                false, {"title":"missing ID"}
            ]}""".printf (gog_dir));
            fixture.write (config, AMAZON, """[{"id":"amazon", "path":"%s", "version":"1"}]""".printf (amazon_dir));
            fixture.write (config, SIDELOAD, """{"games":[
                {"app_name":"local", "title":"Sideload", "is_installed":true,
                 "install":{"executable":"%s/start.exe","platform":"Windows"}},
                {"app_name":"browser", "title":"Browser game", "is_installed":true, "install":{"platform":"Browser"}},
                {"app_name":"removed", "title":"Removed", "is_installed":false, "install":{"platform":"Linux"}}
            ]}""".printf (sideload_dir));
            fixture.write (config, "config.json", """{"defaultSettings":{
                "wineVersion":{"name":"Wine Default", "type":"wine"}, "winePrefix":"~/wine-prefix"
            }}""");
            fixture.write (config, "GamesConfig/local.json", """{"local":{
                "wineVersion":{"name":"GE-Proton Fixture", "type":"proton"}, "winePrefix":"~/proton-prefix"
            }}""");
            fixture.write (fixture.flatpak_config, EPIC, """{"shared":{"title":"Flatpak Epic", "install_path":"%s"}}""".printf (game_dir));
            // The adjacent standalone Legendary library is independent from Heroic.
            fixture.write (fixture.config_home, "legendary/installed.json", """{"standalone":{"title":"Standalone Epic"}}""");
            fixture.write (Path.get_dirname (fixture.flatpak_config), "legendary/installed.json",
                """{"standalone":{"title":"Flatpak standalone Epic"}}""");

            var native = fixture.launcher (false);
            var flatpak = fixture.launcher (true);
            assert (native.installed && flatpak.installed);
            assert (!native.load_library_on_startup && native.has_library_support && !native.supports_bulk_game_edit);
            assert (load (native) && load (flatpak));
            assert (native.games.length () == 6 && flatpak.games.length () == 1);
            var epic = game (native, HeroicStore.LEGENDARY);
            var gog = game (native, HeroicStore.GOG);
            var amazon = game (native, HeroicStore.NILE, "amazon");
            var sideload = game (native, HeroicStore.SIDELOAD, "local");
            var browser = game (native, HeroicStore.SIDELOAD, "browser");
            var detached = game (native, HeroicStore.GOG, "detached");
            assert (epic.game_id == "heroic-system:legendary:shared");
            assert (epic.game_id != gog.game_id && epic.game_id != game (flatpak, HeroicStore.LEGENDARY).game_id);
            assert (epic.name == "Epic Game" && epic.installdir == game_dir && epic.prefixdir == prefix);
            assert (epic.get_game_tool_title () == "Inherited (Wine Default)");
            assert (gog.name == "GOG Native" && gog.installdir == gog_dir && gog.is_native && !gog.has_prefix_directory);
            assert (gog.get_game_tool_title () == "Native");
            assert (amazon.name == "Amazon Game" && amazon.installdir == amazon_dir && amazon.prefixdir == prefix);
            assert (sideload.installdir == sideload_dir && sideload.prefixdir == proton_pfx);
            assert (sideload.get_game_tool_title () == "GE-Proton Fixture");
            assert (browser.is_native && !browser.has_game_directory && !browser.has_prefix_directory);
            assert (!detached.has_game_directory && detached.can_launch);
            assert (!sideload.can_edit_compatibility_tool && !sideload.change_compatibility_tool ("Other"));
            assert (game (flatpak, HeroicStore.LEGENDARY).get_game_tool_title () == "Inherited");
            fixture.cleanup ();
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
    }

    private void test_metadata_errors_and_recovery () {
        try {
            var fixture = new Fixture ();
            var config = fixture.flatpak_config;
            var launcher = fixture.launcher (true);
            assert (load (launcher) && launcher.games.is_empty () && launcher.game_library_error == null);
            fixture.write (config, GOG, """{"installed":"invalid"}""");
            fixture.write (config, EPIC, "{");
            assert (!load (launcher) && launcher.game_library_error != null);
            fixture.write (config, AMAZON, """[true,{"id":"kept","path":"/missing/library/Kept Game"}]""");
            assert (load (launcher) && launcher.game_library_error == null);
            assert (launcher.games.length () == 1 && game (launcher, HeroicStore.NILE, "kept").name == "Kept Game");
            fixture.write (config, EPIC, "{}");
            fixture.write (config, GOG, "{}");
            fixture.write (config, AMAZON, "[]");
            assert (load (launcher) && launcher.games.is_empty ());
            fixture.cleanup ();
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
    }

    private void test_runner_settings () {
        try {
            var fixture = new Fixture ();
            var config = fixture.native_config;
            var launcher = fixture.launcher (false);
            var prefix = fixture.dir ("Games/Heroic/Prefixes/shared");
            fixture.write (config, EPIC, """{
                "wine":{"title":"Wine game"},
                "proton":{"title":"Proton game"},
                "broken":{"title":"Broken settings"}
            }""");
            fixture.write (config, "config.json", """{"defaultSettings":{"wineVersion":{"name":"Wine", "type":"wine"}}}""");
            fixture.write (config, "GamesConfig/proton.json", """{"proton":{"wineVersion":{"name":"Proton", "type":"proton"}}}""");
            fixture.write (config, "GamesConfig/broken.json", """{"broken":false}""");
            assert (load (launcher));
            assert (game (launcher, HeroicStore.LEGENDARY, "wine").prefixdir == prefix);
            var proton = game (launcher, HeroicStore.LEGENDARY, "proton");
            assert (proton.get_game_tool_title () == "Proton" && !proton.has_prefix_directory);
            var broken = game (launcher, HeroicStore.LEGENDARY, "broken");
            assert (broken.get_game_tool_title () == "Configuration unavailable" && !broken.has_prefix_directory);
            fixture.write (config, "config.json", "null");
            assert (load (launcher));
            assert (game (launcher, HeroicStore.LEGENDARY, "wine").get_game_tool_title () == "Configuration unavailable");
            assert (game (launcher, HeroicStore.LEGENDARY, "proton").get_game_tool_title () == "Proton");
            fixture.cleanup ();
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
    }

    private void play (Game game, bool expect_error = false) {
        var loop = new MainLoop ();
        game.launch_external.begin ((source, result) => {
            try {
                game.launch_external.end (result);
                assert (!expect_error);
            } catch (Error error) {
                assert (expect_error && error.message == "Heroic fixture launch failed");
            }
            loop.quit ();
        });
        loop.run ();
    }

    private void test_selected_instance_launch () {
        try {
            var fixture = new Fixture ();
            var appimage = Path.build_filename (fixture.home, "Heroic Fixture.AppImage");
            fixture.write (fixture.applications, "com.heroicgameslauncher.hgl.desktop",
                "[Desktop Entry]\nExec=flatpak run com.heroicgameslauncher.hgl %U\n");
            fixture.write (fixture.applications, "appimagekit_fixture-Heroic.desktop",
                "[Desktop Entry]\nExec=\"%s\" --fixture %%U\n".printf (appimage));
            FileUtils.set_contents (appimage, "");
            assert (FileUtils.chmod (appimage, 0700) == 0);

            foreach (bool flatpak in new bool[] { false, true }) {
                var root = flatpak ? fixture.flatpak_config : fixture.native_config;
                fixture.write (root, EPIC, """{"shared":{"title":"Epic"}}""");
                fixture.write (root, GOG, """{"installed":[{"appName":"shared"}]}""");
                fixture.write (root, AMAZON, """[{"id":"shared"}]""");
                fixture.write (root, SIDELOAD, """{"games":[{"app_name":"id & runner=?", "is_installed":true,
                    "title":"Sideload", "install":{"platform":"Linux"}}]}""");
                foreach (bool through_host in new bool[] { false, true }) {
                    var launcher = fixture.launcher (flatpak, through_host);
                    assert (load (launcher) && launcher.games.length () == 4);
                    var offset = through_host ? 2 : 0;
                    foreach (var item in launcher.games) {
                        var heroic = (Heroic) item;
                        play (heroic);
                        var argv = fixture.command;
                        assert (argv.length == offset + 4);
                        if (through_host)
                            assert (argv[0] == "flatpak-spawn" && argv[1] == "--host");
                        if (flatpak) {
                            assert (argv[offset] == "flatpak" && argv[offset + 1] == "run" &&
                                argv[offset + 2] == HeroicGamesLauncher.FLATPAK_ID);
                        } else {
                            assert (argv[offset] == appimage && argv[offset + 1] == "--fixture" &&
                                argv[offset + 2] == "--no-sandbox");
                        }
                        var id = heroic.store == HeroicStore.SIDELOAD ? "id%20%26%20runner%3D%3F" : "shared";
                        assert (argv[offset + 3] == "heroic://launch?appName=%s&runner=%s".printf (
                            id, heroic.store.protocol_id ()));
                    }
                }
            }
            assert (FileUtils.remove (appimage) == 0);
            var native = fixture.launcher (false);
            assert (load (native));
            fixture.fail_spawn = true;
            play (game (native, HeroicStore.NILE), true);
            assert (fixture.command[0] == "heroic" && fixture.command.length == 2);
            fixture.cleanup ();
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
    }
}
