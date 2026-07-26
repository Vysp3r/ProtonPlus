namespace AppTests.InstallLayoutTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Launchers.Runners;

    public void register_tests () {
        Test.add_func ("/install-layout/launcher-specific-names", test_launcher_specific_names);
    }

    private Json.Object get_snapshot () {
        try {
            var content = ProtonPlus.Utils.Filesystem.get_file_content (
                Path.build_filename ("fixtures", "definitions", "runners.json")
            );
            var root = Json.from_string (content);
            assert (root.get_node_type () == Json.NodeType.OBJECT);
            return root.get_object ();
        } catch (Error e) {
            critical ("Could not load installation layout snapshot: %s", e.message);
            assert_not_reached ();
        }
    }

    private IRunner get_runner (Gee.ArrayList<IRunner> runners, string title) {
        foreach (var runner in runners) {
            if (runner.title == title)
                return runner;
        }
        assert_not_reached ();
    }

    private Gee.ArrayList<IRunner> get_all_runners () {
        var all_runners = new Gee.ArrayList<IRunner> ();
        var runners = new Runners ();
        foreach (var type in new RunnerType[] { RunnerType.DXVK, RunnerType.VKD3D, RunnerType.Proton, RunnerType.Wine }) {
            all_runners.add_all (runners.getRunners (type));
        }
        return all_runners;
    }

    private void test_launcher_specific_names () {
        string root;
        try {
            root = DirUtils.make_tmp ("protonplus-install-layout-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create temporary launcher root: %s", e.message);
            assert_not_reached ();
        }
        var snapshot = get_snapshot ();
        var definitions = snapshot.get_array_member ("definitions");
        var release_name = snapshot.get_string_member ("release_name");
        var runners = get_all_runners ();
        var launcher_titles = new string[] {
            "Steam", "Lutris", "Bottles", "Heroic Games Launcher", "WineZGUI"
        };

        foreach (var launcher_title in launcher_titles) {
            var launcher = new Launcher (
                launcher_title, Launcher.InstallationTypes.SYSTEM, "", { root }
            );
            var group = new Group ("Test", "", "", launcher);

            for (var index = 0; index < definitions.get_length (); index++) {
                var expected = definitions.get_object_element (index);
                var tool = get_runner (runners, expected.get_string_member ("title")).create_tool (group);
                assert (tool != null);
                var install_names = expected.get_object_member ("install_names");
                var expected_name = install_names.get_string_member_with_default (
                    launcher_title, install_names.get_string_member ("default")
                );
                assert (tool.get_directory_name (release_name) == expected_name);
            }
        }

        assert (FileUtils.remove (root) == 0);
    }
}
