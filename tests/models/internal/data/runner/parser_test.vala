using GLib;
using Json;
using Gee;
using ProtonPlus.Models.Internal.Data.Runner;

namespace AppTests.Models.Internal.Data.Runner {

    public class ParserTest : AppTests.BaseTest {

        construct {
            add_test ("success", test_parser_success);
            add_test ("invalid", test_parser_invalid);
            add_test ("parse_version_valid", test_parse_version_valid);
            add_test ("parse_version_invalid_type", test_parse_version_invalid_type);
            add_test ("parse_directory_formats", test_parse_directory_formats);
            add_test ("parse_asset_lists", test_parse_asset_lists);
            add_test ("real_file", test_parser_real_file);
        }

        private const string TEST_JSON = """
        {
          "version": 1,
          "compat_layers": [
            {
              "title": "Proton",
              "description": "Compatibility tools by Valve",
              "runners": [
                {
                  "title": "Proton-GE",
                  "description": "Steam compatibility tool",
                  "endpoint": "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases",
                  "asset_position": 1,
                  "directory_name_formats": [
                    {
                      "launcher": "Steam",
                      "directory_name_format": "Proton-$release_name"
                    }
                  ],
                  "support_latest": true,
                  "tag": "Recommended",
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

        private void test_parser_success () {
            var root = ProtonPlus.Models.Internal.Data.Runner.Parser.parse_runners_json (TEST_JSON);

            assert_nonnull (root);
            assert_true (root.version == 1);
            assert_true (root.compat_layers.size == 1);

            var group = root.compat_layers.get (0);
            assert_true (group.title == "Proton");
            assert_true (group.runners.size == 1);

            var runner = group.runners.get (0);
            assert_true (runner.title == "Proton-GE");
            assert_true (runner.runner_type == "github");
            assert_true (runner.support_latest == true);
            assert_true (runner.tag == "Recommended");

            assert_true (runner.directory_name_formats.size == 1);
            assert_true (runner.directory_name_formats.get (0).launcher == "Steam");

            assert_true (root.launchers.size == 1);
            var launcher = root.launchers.get (0);
            assert_true (launcher.title == "Steam");
            assert_true (launcher.compat_layers.size == 1);
            assert_true (launcher.compat_layers.get (0).directory == "/compatibilitytools.d");
        }

        private void test_parser_success_new () {
            string js = """
        {
          "version": 1,
          "compat_layers": [
            {
              "title": "Proton",
              "description": "Compatibility tools by Valve",
              "runners": [
                {
                  "title": "Proton-GE",
                  "description": "Steam compatibility tool",
                  "endpoint": "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases",
                  "asset_position": 1,
                  "directory_name_formats": [
                    {
                      "launcher": "Steam",
                      "directory_name_format": "Proton-$release_name"
                    }
                  ],
                  "support_latest": true,
                  "tag": "Recommended",
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

            var root = ProtonPlus.Models.Internal.Data.Runner.Parser.parse_runners_json (js);

            assert_nonnull (root);
            assert_true (root.version == 1);
            assert_true (root.compat_layers.size == 1);

            var group = root.compat_layers.get (0);
            assert_true (group.title == "Proton");
            assert_true (group.runners.size == 1);

            var runner = group.runners.get (0);
            assert_true (runner.title == "Proton-GE");
            assert_true (runner.runner_type == "github");
            assert_true (runner.support_latest == true);
            assert_true (runner.tag == "Recommended");

            assert_true (runner.directory_name_formats.size == 1);
            assert_true (runner.directory_name_formats.get (0).launcher == "Steam");

            assert_true (root.launchers.size == 1);
            var launcher = root.launchers.get (0);
            assert_true (launcher.title == "Steam");
            assert_true (launcher.compat_layers.size == 1);
            assert_true (launcher.compat_layers.get (0).directory == "/compatibilitytools.d");
        }

        private void test_parser_invalid () {
            var root = ProtonPlus.Models.Internal.Data.Runner.Parser.parse_runners_json ("{ \"version\": \"nečíselná_hodnota\" }");
            assert_null (root);
        }

        private void test_parse_version_valid () {
            var root_obj = new Json.Object ();
            root_obj.set_int_member ("version", 42);

            var root = new Root ();
            bool result = ProtonPlus.Models.Internal.Data.Runner.Parser.parse_version (root_obj, root);

            assert_true (result);
            assert_true (root.version == 42);
        }

        private void test_parse_version_invalid_type () {
            var root_obj = new Json.Object ();
            root_obj.set_string_member ("version", "v1");

            var root = new Root ();
            bool result = ProtonPlus.Models.Internal.Data.Runner.Parser.parse_version (root_obj, root);

            assert_false (result);
        }

        private void test_parse_directory_formats () {
            var format_obj = new Json.Object ();
            format_obj.set_string_member ("launcher", "Lutris");
            format_obj.set_string_member ("directory_name_format", "wine-ge-$release_name");

            var formats_array = new Json.Array ();
            var node = new Json.Node (Json.NodeType.OBJECT);
            node.set_object (format_obj);
            formats_array.add_element (node);


            var runner = new ProtonPlus.Models.Internal.Data.Runner.Runner ();
            ProtonPlus.Models.Internal.Data.Runner.Parser.parse_directory_formats (formats_array, runner);

            assert_true (runner.directory_name_formats.size == 1);
            var format = runner.directory_name_formats.get (0);
            assert_true (format.launcher == "Lutris");
            assert_true (format.directory_name_format == "wine-ge-$release_name");
        }

        private void test_parse_asset_lists () {
            var exclude_array = new Json.Array ();
            exclude_array.add_string_element (".tar.gz");
            exclude_array.add_string_element (".sha512");

            var runner_obj = new Json.Object ();
            runner_obj.set_array_member ("request_asset_exclude", exclude_array);
            runner_obj.set_null_member ("request_asset_filter");

            var runner = new ProtonPlus.Models.Internal.Data.Runner.Runner ();

            ProtonPlus.Models.Internal.Data.Runner.Parser.parse_asset_lists (runner_obj, runner);

            assert_nonnull (runner.request_asset_exclude);
            assert_true (runner.request_asset_exclude.size == 2);
            assert_true (runner.request_asset_exclude.get (0) == ".tar.gz");
            assert_true (runner.request_asset_exclude.get (1) == ".sha512");

            assert_null (runner.request_asset_filter);
        }

        private void test_parser_real_file () {

            string file_path = GLib.Environment.get_variable ("TEST_RUNNERS_JSON_PATH");
            if (file_path == null) {
                file_path = "tests/data/runners.json";
            }

            uint8[] raw_data;
            try {
                FileUtils.get_data (file_path, out raw_data);
            } catch (GLib.FileError e) {
                assert_not_reached ();
            }
            string json_content = (string) raw_data;

            var root = ProtonPlus.Models.Internal.Data.Runner.Parser.parse_runners_json (json_content);

            assert_nonnull (root);
            assert_true (root.version > 0);

            assert_true (root.compat_layers.size > 0);
            assert_true (root.launchers.size > 0);

            bool found_steam = false;
            foreach (var launcher in root.launchers) {
                if (launcher.title == "Steam") {
                    found_steam = true;
                    assert_true (launcher.compat_layers.size > 0);
                    break;
                }
            }
            assert_true (found_steam);
        }
    }
}
