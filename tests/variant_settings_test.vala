namespace AppTests.VariantSettingsTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;

    public void register_tests () {
        Test.add_func ("/variant-settings/id-key-and-legacy-fallback", test_id_key_and_legacy_fallback);
    }

    private string create_temp_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-variant-settings-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create test directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private void delete_directory (string directory) {
        var loop = new MainLoop ();
        bool deleted = false;
        ProtonPlus.Utils.Filesystem.delete_directory.begin (directory, (obj, res) => {
            deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (res);
            loop.quit ();
        });
        loop.run ();
        assert (deleted);
    }

    private string serialize_settings (Json.Object root_obj) {
        var node = new Json.Node (Json.NodeType.OBJECT);
        node.set_object (root_obj);
        var generator = new Json.Generator ();
        generator.set_root (node);
        return generator.to_data (null);
    }

    private Tools.ProviderTool create_tool (string root) {
        var launcher = new Launcher (
            "Fixture launcher", Launcher.InstallationTypes.SYSTEM, "", { root }, "fixture"
        );
        var group = new Group ("Fixture group", "", "", launcher, "fixture");
        var definition = new ProviderRegistry ().get_by_id ("proton-ge");
        assert (definition != null);
        var tool = ProviderCatalog.create_tool ((!) definition, group);
        assert (tool != null);
        return tool;
    }

    private void test_id_key_and_legacy_fallback () {
        var root = create_temp_directory ();
        var tool = create_tool (root);
        var legacy_key = "%s::%s::%s".printf (tool.group.launcher.title, tool.group.title, tool.title);

        var legacy_settings = new Json.Object ();
        legacy_settings.set_string_member (legacy_key, "aarch64");
        var legacy_json = serialize_settings (legacy_settings);
        assert (ProtonPlus.Widgets.Tools.ReleasesBox.get_saved_variant_name_from_json (
            legacy_json, tool
        ) == "aarch64");

        var saved = ProtonPlus.Utils.Parser.get_node_from_json (
            ProtonPlus.Widgets.Tools.ReleasesBox.get_json_with_saved_variant_name (legacy_json, tool, "x86")
        );
        assert (saved != null);
        var saved_settings = saved.get_object ();
        assert (saved_settings.get_string_member (tool.id) == "x86");
        assert (saved_settings.get_string_member (legacy_key) == "aarch64");

        var mixed_settings = new Json.Object ();
        mixed_settings.set_string_member (legacy_key, "aarch64");
        mixed_settings.set_string_member (tool.id, "x86");
        assert (ProtonPlus.Widgets.Tools.ReleasesBox.get_saved_variant_name_from_json (
            serialize_settings (mixed_settings), tool
        ) == "x86");

        delete_directory (root);
    }
}
