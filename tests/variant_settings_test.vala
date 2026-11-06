namespace AppTests.VariantSettingsTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;

    public void register_tests () {
        Test.add_func ("/variant-settings/id-key-and-legacy-fallback", test_id_key_and_legacy_fallback);
        Test.add_func ("/variant-settings/malformed-values", test_malformed_values);
        Test.add_func ("/variant-settings/preserves-unrelated-settings", test_preserves_unrelated_settings);
        Test.add_func ("/variant-settings/settings-round-trip", test_settings_round_trip);
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
        assert (ToolVariantPreferences.read_json (
            legacy_json, tool
        ) == "aarch64");

        var saved = ProtonPlus.Utils.Parser.get_node_from_json (
            ToolVariantPreferences.write_json (legacy_json, tool, "x86")
        );
        assert (saved != null);
        var saved_settings = saved.get_object ();
        assert (saved_settings.get_string_member (tool.id) == "x86");
        assert (saved_settings.get_string_member (legacy_key) == "aarch64");

        var mixed_settings = new Json.Object ();
        mixed_settings.set_string_member (legacy_key, "aarch64");
        mixed_settings.set_string_member (tool.id, "x86");
        assert (ToolVariantPreferences.read_json (
            serialize_settings (mixed_settings), tool
        ) == "x86");

        delete_directory (root);
    }

    private void test_malformed_values () {
        var root = create_temp_directory ();
        var tool = create_tool (root);
        foreach (var raw in new string[] { "", "{broken", "[]", "null", "true", "42", "\"name\"" }) {
            assert (ToolVariantPreferences.read_json (raw, tool) == "");
            var saved = ToolVariantPreferences.write_json (raw, tool, "x86");
            assert (ToolVariantPreferences.read_json (saved, tool) == "x86");
        }

        var legacy_key = "%s::%s::%s".printf (tool.group.launcher.title, tool.group.title, tool.title);
        var values = new Json.Object ();
        values.set_string_member (legacy_key, "aarch64");
        values.set_int_member (tool.id, 42);
        assert (ToolVariantPreferences.read_json (serialize_settings (values), tool) == "aarch64");
        values.set_string_member (tool.id, "");
        assert (ToolVariantPreferences.read_json (serialize_settings (values), tool) == "aarch64");
        values.set_boolean_member (legacy_key, true);
        assert (ToolVariantPreferences.read_json (serialize_settings (values), tool) == "");

        var unavailable = new ToolVariantPreferences (null);
        unavailable.save (tool, "x86");
        assert (unavailable.load (tool) == "");
        delete_directory (root);
    }

    private void test_preserves_unrelated_settings () {
        var root = create_temp_directory ();
        var tool = create_tool (root);
        var legacy_key = "%s::%s::%s".printf (tool.group.launcher.title, tool.group.title, tool.title);
        var values = new Json.Object ();
        values.set_string_member (legacy_key, "aarch64");
        values.set_string_member ("another-tool", "x86_64_v3");
        var future = new Json.Object ();
        future.set_int_member ("revision", 2);
        values.set_object_member ("future-setting", future);

        var saved = Utils.Parser.get_node_from_json (
            ToolVariantPreferences.write_json (serialize_settings (values), tool, "x86")
        );
        assert (saved != null);
        var actual = saved.get_object ();
        assert (actual.get_string_member (tool.id) == "x86");
        assert (actual.get_string_member (legacy_key) == "aarch64");
        assert (actual.get_string_member ("another-tool") == "x86_64_v3");
        assert (actual.get_object_member ("future-setting").get_int_member ("revision") == 2);
        delete_directory (root);
    }

    private void test_settings_round_trip () {
        var root = create_temp_directory ();
        var tool = create_tool (root);
        try {
            FileUtils.set_contents (Path.build_filename (root, "variant-test.gschema.xml"),
                "<schemalist><schema id=\"com.vysp3r.ProtonPlus.VariantTest\" " +
                "path=\"/com/vysp3r/ProtonPlus/tests/variants/\">" +
                "<key name=\"selected-tool-variants\" type=\"s\"><default>'{}'</default></key>" +
                "</schema></schemalist>");
            int status;
            Process.spawn_sync (null, { "glib-compile-schemas", root }, null,
                SpawnFlags.SEARCH_PATH, null, null, null, out status);
            assert (status == 0);
            var source = new SettingsSchemaSource.from_directory (root, null, false);
            var schema = source.lookup ("com.vysp3r.ProtonPlus.VariantTest", false);
            assert (schema != null);
            // tests/main.vala selects the memory backend before any settings use.
            var settings = new Settings.full (schema, null, null);
            var legacy_key = "%s::%s::%s".printf (tool.group.launcher.title, tool.group.title, tool.title);
            var values = new Json.Object ();
            values.set_string_member (legacy_key, "aarch64");
            values.set_string_member ("another-tool", "default");
            settings.set_string ("selected-tool-variants", serialize_settings (values));

            var preferences = new ToolVariantPreferences (settings);
            assert (preferences.load (tool) == "aarch64");
            preferences.save (tool, "x86");
            var reloaded = new ToolVariantPreferences (new Settings.full (schema, null, null));
            assert (reloaded.load (tool) == "x86");
            var actual = Utils.Parser.get_node_from_json (settings.get_string ("selected-tool-variants"));
            assert (actual.get_object ().get_string_member (legacy_key) == "aarch64");
            assert (actual.get_object ().get_string_member ("another-tool") == "default");
            settings.reset ("selected-tool-variants");
        } catch (Error e) {
            critical ("Could not create variant settings fixture: %s", e.message);
            assert_not_reached ();
        }
        delete_directory (root);
    }
}
