namespace AppTests.CompatibilityToolTest {
    using GLib;
    using ProtonPlus.Models;

    public void register_tests () {
        Test.add_func ("/compatibility-tool/model-properties-and-synthetic-entries", test_model_properties_and_synthetic_entries);
        Test.add_func ("/compatibility-tool/loader-parses-and-falls-back", test_loader_parses_and_falls_back);
    }

    private string temporary_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-compatibility-tool-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create temporary directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private void test_model_properties_and_synthetic_entries () {
        var tool = new CompatibilityTool ("Display", "internal", "/tools/display");
        assert (!tool.get_type ().is_a (typeof (Tool)));
        assert (tool.display_title == "Display");
        assert (tool.internal_title == "internal");
        assert (tool.path == "/tools/display");
        assert (tool.sort_priority == 1000);

        var model = new GLib.ListStore (typeof (CompatibilityTool));
        model.append (tool);
        assert (model.get_item (0) == tool);

        var default_tool = new CompatibilityTool ("Default", "Default");
        var native_tool = new CompatibilityTool ("Native", "Default");
        assert (default_tool.path == "");
        assert (native_tool.path == "");
    }

    private void test_loader_parses_and_falls_back () {
        var root = temporary_directory ();
        var missing_path = Path.build_filename (root, "missing-tool");
        var missing = ProtonPlus.Utils.VDF.CompatibilityToolLoader.from_path (missing_path);
        assert (missing.display_title == "missing-tool");
        assert (missing.internal_title == "missing-tool");
        assert (missing.path == missing_path);

        var parsed_path = Path.build_filename (root, "parsed-tool");
        assert (ProtonPlus.Utils.Filesystem.create_directory (parsed_path));
        ProtonPlus.Utils.Filesystem.create_file (
            Path.build_filename (parsed_path, "compatibilitytool.vdf"),
            "\"compat_tools\" // tools\n{\n  \"internal_name\" // Internal name of this tool\n  {\n    \"display_name\" \"Display name\"\n  }\n}\n"
        );
        var parsed = ProtonPlus.Utils.VDF.CompatibilityToolLoader.from_path (parsed_path);
        assert (parsed.display_title == "Display name");
        assert (parsed.internal_title == "internal_name");

        var malformed_path = Path.build_filename (root, "malformed-tool");
        assert (ProtonPlus.Utils.Filesystem.create_directory (malformed_path));
        ProtonPlus.Utils.Filesystem.create_file (
            Path.build_filename (malformed_path, "compatibilitytool.vdf"), "not a compatibility tool"
        );
        var malformed = ProtonPlus.Utils.VDF.CompatibilityToolLoader.from_path (malformed_path);
        assert (malformed.display_title == "malformed-tool");
        assert (malformed.internal_title == "malformed-tool");

        assert (FileUtils.remove (Path.build_filename (parsed_path, "compatibilitytool.vdf")) == 0);
        assert (DirUtils.remove (parsed_path) == 0);
        assert (FileUtils.remove (Path.build_filename (malformed_path, "compatibilitytool.vdf")) == 0);
        assert (DirUtils.remove (malformed_path) == 0);
        assert (FileUtils.remove (root) == 0);
    }
}
