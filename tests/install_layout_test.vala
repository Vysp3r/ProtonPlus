namespace AppTests.InstallLayoutTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;

    public void register_tests () {
        Test.add_func ("/install-layout/launcher-specific-names", test_launcher_specific_names);
        Test.add_func ("/install-layout/render/plain-template", test_plain_template_rendering);
        Test.add_func ("/install-layout/render/lowercase", test_lowercase_rendering);
        Test.add_func ("/install-layout/render/replacement", test_replacement_rendering);
        Test.add_func ("/install-layout/render/conditional", test_conditional_rendering);
        Test.add_func ("/install-layout/definition-lookup", test_definition_lookup);
        Test.add_func ("/install-layout/definition-defensive-copy", test_definition_defensive_copy);
        Test.add_func ("/install-layout/catalog-missing-layout", test_catalog_missing_layout);
        Test.add_func ("/install-layout/latest-name", test_latest_name);
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

    private ProviderDefinition fixture_definition (InstallLayout[] layouts) {
        return new ProviderDefinition (
            Category.DXVK, SourceType.GITHUB, "fixture", "Fixture title", "",
            "https://example.test/releases", 0, {}, layouts
        );
    }

    private Group fixture_group (string family_id) {
        var launcher = new Launcher ("Fixture launcher", Launcher.InstallationTypes.SYSTEM, "", {}, family_id);
        return new Group ("Fixture group", "", "", launcher, "fixture");
    }

    private void test_plain_template_rendering () {
        var layout = InstallLayout.template ("default", "$title-$release_name");
        assert (layout.render ("Provider", "v10.2") == "Provider-v10.2");
    }

    private void test_lowercase_rendering () {
        var layout = InstallLayout.lowercase ("bottles", "$title-$release_name");
        assert (layout.render ("Proton-GE", "V10.2") == "proton-ge-v10.2");
    }

    private void test_replacement_rendering () {
        var layout = InstallLayout.replace ("default", "$release_name", "v", "dxvk-");
        assert (layout.render ("DXVK", "v10.2") == "dxvk-10.2");
    }

    private void test_conditional_rendering () {
        var layout = InstallLayout.conditional ("steam", ".", "Proton-$release_name", "$release_name");
        assert (layout.render ("Proton-GE", "v10.2") == "Proton-v10.2");
        assert (layout.render ("Proton-GE", "v102") == "v102");
    }

    private void test_definition_lookup () {
        var definition = fixture_definition ({
            InstallLayout.template ("default", "default-$release_name"),
            InstallLayout.template ("steam", "steam-$release_name")
        });

        var exact = definition.get_install_layout ("steam");
        assert (exact != null);
        assert (exact.render ("Fixture", "v1") == "steam-v1");

        var fallback = definition.get_install_layout ("heroic");
        assert (fallback != null);
        assert (fallback.render ("Fixture", "v1") == "default-v1");
    }

    private void test_definition_defensive_copy () {
        var definition = fixture_definition ({ InstallLayout.template ("default", "$release_name") });
        var first = definition.get_install_layouts ();
        var second = definition.get_install_layouts ();

        assert (first.length == 1);
        assert (second.length == 1);
        assert (first[0] != second[0]);
        assert (first[0].render ("Fixture", "v1") == "v1");
        assert (second[0].render ("Fixture", "v2") == "v2");
    }

    private void test_catalog_missing_layout () {
        var definition = fixture_definition ({ InstallLayout.template ("bottles", "$release_name") });
        assert (ProviderCatalog.create_tool (definition, fixture_group ("steam")) == null);
    }

    private void test_latest_name () {
        var tool = ProviderCatalog.create_tool (
            fixture_definition ({ InstallLayout.template ("default", "prefix-$release_name") }),
            fixture_group ("steam")
        );
        assert (tool != null);
        assert (tool.get_directory_name ("Latest release") == "Latest release");
    }
}
