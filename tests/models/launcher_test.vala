using GLib;
using Gee;
using ProtonPlus.Models;

namespace AppTests.Models {
    public class MockSteam : Launchers.Steam {
        public MockSteam () {
            base (Launcher.InstallationTypes.SYSTEM);
            this.directory = "/tmp";
            this.installed = true;
        }

        public override async bool setup_profile_library_for_test () {
            this.profiles = new GLib.List<SteamProfile> ();
            return true;
        }
    }

    public class MockLutris : Launchers.Lutris {
        public MockLutris () {
            base (Launcher.InstallationTypes.SYSTEM);
            this.directory = "/tmp";
            this.installed = true;
        }

        public override async bool setup_profile_library_for_test () {
            return true;
        }
    }

    public class MockUnknownLauncher : Launcher {
        public MockUnknownLauncher () {
            base (
                  "UnknownAtypicLauncher",
                  Launcher.InstallationTypes.SYSTEM,
                  "icon",
                  new string[] { "/tmp" });
            this.directory = "/tmp";
            this.installed = true;
        }

        public override async bool setup_profile_library_for_test () {
            return true;
        }
    }


    public class LauncherTest : AppTests.BaseTest {

        construct {
            add_test ("initialize_launchers_success", test_initialize_launchers_success);
            add_test ("initialize_launchers_missing_json", test_initialize_launchers_missing_json);
            add_test ("initialize_launchers_unknown_launcher", test_initialize_launchers_unknown_launcher);
            add_test ("initialize_launchers_missing_directory_format", test_initialize_launchers_missing_directory_format);
        }

        private void test_initialize_launchers_success () {
            var steam = new MockSteam ();
            var lutris = new MockLutris ();

            var launchers = new Gee.LinkedList<Launcher> ();
            launchers.add (steam);
            launchers.add (lutris);
            string real_json_path = GLib.Environment.get_variable ("TEST_RUNNERS_JSON_PATH");

            bool result = false;
            var loop = new MainLoop ();

            Launcher.initialize_launchers.begin (launchers, real_json_path, (obj, res) => {
                result = Launcher.initialize_launchers.end (res);
                loop.quit ();
            });

            loop.run ();

            assert_true (result);
            assert_nonnull (steam.groups);
            assert_true (steam.groups.length > 0);
        }

        private void test_initialize_launchers_missing_json () {
            var steam = new MockSteam ();
            var launchers = new Gee.LinkedList<Launcher> ();
            launchers.add (steam);

            bool result = true;
            var loop = new MainLoop ();

            Launcher.initialize_launchers.begin (launchers, "neexistujici_soubor.json", (obj, res) => {
                result = Launcher.initialize_launchers.end (res);
                loop.quit ();
            });

            loop.run ();

            assert_false (result);
        }

        private void test_initialize_launchers_unknown_launcher () {
            var neznamy = new MockUnknownLauncher ();

            var launchers = new Gee.LinkedList<Launcher> ();
            launchers.add (neznamy);

            string real_json_path = GLib.Environment.get_variable ("TEST_RUNNERS_JSON_PATH");

            bool result = true;
            var loop = new MainLoop ();

            Launcher.initialize_launchers.begin (launchers, real_json_path, (obj, res) => {
                result = Launcher.initialize_launchers.end (res);
                loop.quit ();
            });

            loop.run ();

            assert_false (result);
        }

        private void test_initialize_launchers_missing_directory_format () {
            var steam = new MockSteam ();
            var launchers = new Gee.LinkedList<Launcher> ();
            launchers.add (steam);

            string broken_json = """
            {
            "version": 1,
            "compat_layers": [
                {
                "title": "Proton",
                "description": "Compatibility tools",
                "runners": [
                    {
                    "title": "Poškozený Nástroj",
                    "description": "Test chybějícího formátu",
                    "endpoint": "https://api.github.com",
                    "asset_position": 1,
                    "directory_name_formats": [
                        {
                        "launcher": "Lutris",
                        "directory_name_format": "wine-format"
                        }
                    ],
                    "support_latest": true,
                    "type": "github"
                    }
                ]
                }
            ],
            "launchers": [
                {
                "title": "Steam",
                "compat_layers": [
                    {
                    "title": "Proton",
                    "directory": "/compatibilitytools.d"
                    }
                ]
                }
            ]
            }
            """;

            string tmp_path = Path.build_filename (GLib.Environment.get_tmp_dir (), "broken_runners.json");
            try {
                FileUtils.set_data (tmp_path, broken_json.data);
            } catch (FileError e) {
                assert_not_reached ();
                return;
            }

            bool result = false;
            var loop = new MainLoop ();

            Launcher.initialize_launchers.begin (launchers, tmp_path, (obj, res) => {
                result = Launcher.initialize_launchers.end (res);
                loop.quit ();
            });

            loop.run ();

            FileUtils.remove (tmp_path);

            assert_true (result);
            assert_nonnull (steam.groups);
            assert_true (steam.groups.length == 1);

            var proton_group = steam.groups[0];
            assert_true (proton_group.title == "Proton");

            foreach (var tool in proton_group.tools) {
                assert_true (tool.title != "Poškozený Nástroj");
            }
        }
    }
}