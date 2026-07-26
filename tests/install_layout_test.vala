namespace AppTests.InstallLayoutTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;

    public void register_tests () {
        Test.add_func ("/install-layout/launcher-specific-names", test_launcher_specific_names);
    }

    private Json.Object snapshot () {
        var content = ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename ("fixtures", "definitions", "runners.json")
        );
        try {
            return Json.from_string (content).get_object ();
        } catch (Error e) {
            critical ("Could not parse installation layout snapshot: %s", e.message);
            assert_not_reached ();
        }
    }

    private ProviderDefinition get_definition (string title) {
        foreach (var definition in new ProviderDefinitions ().get_all ()) {
            if (definition.title == title)
                return definition;
        }
        assert_not_reached ();
    }

    private void assert_launcher_names (Json.Array definitions, string release_name, string title, string family) {
        var launcher = new Launcher (title, Launcher.InstallationTypes.SYSTEM, "", {}, family);
        var group = new Group ("Test", "", "", launcher);

        for (var definition_index = 0; definition_index < definitions.get_length (); definition_index++) {
            var entry = definitions.get_object_element (definition_index);
            var tool = ProviderCatalog.create_tool (get_definition (entry.get_string_member ("title")), group);
            assert (tool != null);
            var names = entry.get_object_member ("install_names");
            var expected_name = names.get_string_member_with_default (title, names.get_string_member ("default"));
            assert (tool.get_directory_name (release_name) == expected_name);
        }
    }

    private void test_launcher_specific_names () {
        var expected = snapshot ();
        var release_name = expected.get_string_member ("release_name");
        var definitions = expected.get_array_member ("definitions");

        assert_launcher_names (definitions, release_name, "Steam", "steam");
        assert_launcher_names (definitions, release_name, "Lutris", "lutris");
        assert_launcher_names (definitions, release_name, "Bottles", "bottles");
        assert_launcher_names (definitions, release_name, "Heroic Games Launcher", "heroic");
        assert_launcher_names (definitions, release_name, "WineZGUI", "winezgui");
    }
}
