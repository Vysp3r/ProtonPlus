namespace AppTests.ParserTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/parser/length-aware-byte-conversion", test_length_aware_byte_conversion);
        Test.add_func ("/vdf/text-parser-replaces-key-and-value", test_vdf_document_replacements);
        Test.add_func ("/launch-options/shell-words-preserve-quoting", test_launch_option_shell_words);
        Test.add_func ("/launch-options/opaque-shell-spans", test_opaque_shell_spans);
        Test.add_func ("/launch-options/catalog-metadata-and-search", test_launch_option_catalog_metadata_and_search);
        Test.add_func ("/launch-options/catalog-active-options-survive-filters", test_launch_option_catalog_active_options_survive_filters);
        Test.add_func ("/launch-options/presentation-parent-visibility", test_launch_option_presentation_parent_visibility);
        Test.add_func ("/launch-options/launch-backend-chrome", test_launch_backend_chrome_visibility);
        Test.add_func ("/launch-options/changing-one-control-preserves-unrelated-raw-tokens", test_launch_option_single_control_edit_preserves_raw_tokens);
        Test.add_func ("/launch-options/category-order-does-not-affect-serialization", test_launch_option_category_order_does_not_affect_serialization);
        Test.add_func ("/system/gpu-vendor-from-pci-devices", test_gpu_vendor_from_pci_devices);
    }

    private void test_length_aware_byte_conversion () {
        uint8 data[4];
        data[0] = 't';
        data[1] = 'e';
        data[2] = 's';
        data[3] = 't';

        assert (ProtonPlus.Utils.Parser.data_to_string (data) == "test");
    }

    private void test_vdf_document_replacements () {
        string content = "\"compat_tools\" // tools\n{\n\t\"Old Name\" // internal name\n\t{\n\t\t\"display_name\"    \"Old Name\"\n\t}\n}\n";
        var document = ProtonPlus.Utils.VDF.VdfParser.parse_document (content);
        assert (document != null);

        var compat_tools = document.root.get_child ("compat_tools");
        assert (compat_tools != null);
        assert (compat_tools.children.size == 1);

        var tool = compat_tools.children.get (0);
        var renamed_content = document.replace_key (tool, "New Name");
        assert (renamed_content == "\"compat_tools\" // tools\n{\n\t\"New Name\" // internal name\n\t{\n\t\t\"display_name\"    \"Old Name\"\n\t}\n}\n");

        document = ProtonPlus.Utils.VDF.VdfParser.parse_document (renamed_content);
        assert (document != null);
        compat_tools = document.root.get_child ("compat_tools");
        assert (compat_tools != null);
        tool = compat_tools.children.get (0);
        var display_name = tool.get_child ("display_name");
        assert (display_name != null);

        var rewritten_content = document.replace_value (display_name, "New Name");
        assert (rewritten_content == "\"compat_tools\" // tools\n{\n\t\"New Name\" // internal name\n\t{\n\t\t\"display_name\"    \"New Name\"\n\t}\n}\n");
    }

    private void test_launch_option_shell_words () {
        var options = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionsList ();
        string source = "VAR=\"hello world\" gamescope -- %command% -windowed";

        var tokens = options.get_launch_option_tokens (source);

        assert (tokens.length == 5);
        assert (tokens[0] == "VAR=hello world");
        assert (tokens[3] == "%command%");
        options.load_from_string (source);
        assert (options.to_launch_line () == source);
        options.mark_modified ();
        assert (options.to_launch_line () == source);
    }

    private void test_opaque_shell_spans () {
        var tokenizer = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionShellTokenizer ();
        var tokens = tokenizer.tokenize ("VAR=1 $(unsafe) %command%");

        assert (tokens.size == 3);
        assert (!tokens[0].is_opaque);
        assert (tokens[1].is_opaque);
        assert (tokens[1].raw == "$(unsafe)");

        var options = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionsList ();
        string source = "VAR=1 $(unsafe) %command%";
        options.load_from_string (source);
        assert (options.to_launch_line () == source);
        options.mark_modified ();
        assert (options.to_launch_line () == source);
    }

    private void test_launch_option_catalog_metadata_and_search () {
        var catalog = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCatalog ();
        assert (catalog.is_valid ());

        var first_order = catalog.get_ordered ();
        var second_order = catalog.get_ordered ();
        assert (first_order.size == second_order.size);
        for (var index = 0; index < first_order.size; index++) {
            assert (first_order[index].id != "");
            assert (first_order[index].category >= ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PERFORMANCE);
            assert (first_order[index].category <= ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.DIAGNOSTICS);
            assert (first_order[index].id == second_order[index].id);
        }

        assert (catalog.search ("MangoHud").size > 0);
        assert (catalog.search ("temperatures").size > 0);
        assert (catalog.search ("WINEALSA_SPACIAL").size > 0);
        assert (catalog.search ("upload_hvv").size > 0);

        var winealsa = catalog.search ("WINEALSA_SPACIAL")[0];
        assert (winealsa.category == ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.INPUT_AUDIO);
        assert (catalog.should_display (
            winealsa,
            ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.PERFORMANCE,
            "WINEALSA_SPACIAL",
            false
        ));
    }

    private void test_launch_option_catalog_active_options_survive_filters () {
        var catalog = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCatalog ();
        var nvidia_option = catalog.lookup ("nvidia-nvapi");
        assert (nvidia_option != null);

        assert (catalog.should_display (
            nvidia_option,
            ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.QUICK,
            "AMD",
            true
        ));
        assert (!catalog.should_display (
            nvidia_option,
            ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.QUICK,
            "AMD",
            false
        ));
    }

    private void test_launch_option_presentation_parent_visibility () {
        var catalog = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCatalog ();
        var presentations = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionPresentationRegistry (catalog);
        var performance = new TestLaunchOption ("mangohud");
        var graphics = new TestLaunchOption ("DXVK_FRAME_RATE=");
        var proton = new TestLaunchOption ("PROTON_USE_WINED3D=1");
        var gamescope = new TestLaunchOption ("-r");

        presentations.register ("performance-overlay", null, performance);
        presentations.register ("dxvk-frame-limit", null, graphics);
        presentations.register ("wined3d", null, proton);
        presentations.register ("gamescope-frame-limit", null, gamescope, false);

        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.QUICK, "");
        assert (presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PERFORMANCE));
        assert (presentations.has_registered_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PERFORMANCE));
        assert (!presentations.has_registered_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.INPUT_AUDIO));
        assert (!presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PROTON));
        assert (!presentations.has_visible_in_subsection (
            ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.GRAPHICS, "DXVK"
        ));

        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.ACTIVE, "");
        assert (!presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PERFORMANCE));
        performance.active = true;
        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.ACTIVE, "");
        assert (presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PERFORMANCE));
        assert (!presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.GRAPHICS));

        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.ALL, "Gamescope");
        assert (!presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.GRAPHICS));
        assert (presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.DISPLAY));
        assert (presentations.has_visible_in_subsection (
            ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.DISPLAY, "Gamescope"
        ));

        proton.active = true;
        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.PERFORMANCE, "");
        assert (presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PERFORMANCE));
        assert (presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.PROTON));
        assert (!presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.GRAPHICS));

        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.ALL, "");
        assert (!presentations.has_visible_in_category (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.INPUT_AUDIO));
        presentations.apply_filter (ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionView.QUICK, "");
        assert (!presentations.has_visible_in_subsection (
            ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCategory.GRAPHICS, "DXVK"
        ));
    }

    private void test_launch_backend_chrome_visibility () {
        assert (!ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups.WrapperGroup.should_show_backend_chrome (
            false, false, false
        ));
        assert (ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups.WrapperGroup.should_show_backend_chrome (
            true, false, false
        ));
        assert (ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups.WrapperGroup.should_show_backend_chrome (
            false, true, false
        ));
        assert (ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups.WrapperGroup.should_show_backend_chrome (
            false, false, true
        ));

        assert (!ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups.WrapperGroup.should_show_backend_group (
            true, false
        ));
        assert (ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups.WrapperGroup.should_show_backend_group (
            true, true
        ));
    }

    private void test_launch_option_single_control_edit_preserves_raw_tokens () {
        var options = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionsList ();
        var proton_log = new TestLaunchOption ("PROTON_LOG=1");
        options.add (proton_log);

        string source = "VAR=\"hello world\" PROTON_LOG=1 %command% $(unsafe) -windowed";
        options.load_from_string (source);
        assert (proton_log.active);

        proton_log.active = false;
        options.mark_modified ();
        assert (options.to_launch_line () == "VAR=\"hello world\" %command% $(unsafe) -windowed");
    }

    private void test_launch_option_category_order_does_not_affect_serialization () {
        var options = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionsList ();
        string source = "VAR=\"hello world\" %command% $(unsafe) -windowed";
        options.load_from_string (source);

        var catalog = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchOptionCatalog ();
        catalog.get_ordered ();
        catalog.search ("gamescope");

        options.mark_modified ();
        assert (options.to_launch_line () == source);
    }

    private class TestLaunchOption : Object, ProtonPlus.Widgets.Games.LaunchOptionsEditor.ILaunchOption {
        public ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType line_type { get; set; default = ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType.ENVIRONMENT; }
        public bool is_advanced { get; set; default = false; }
        public bool active { get; set; default = false; }
        string token;

        public TestLaunchOption (string token) {
            this.token = token;
        }

        public void add_child (ProtonPlus.Widgets.Games.LaunchOptionsEditor.ILaunchOption child) {
        }

        public void parse_tokens (string[] tokens, bool[] consumed) {
            for (var index = 0; index < tokens.length; index++) {
                if (!consumed[index] && tokens[index] == token) {
                    active = true;
                    consumed[index] = true;
                    return;
                }
            }
        }

        public void clear () {
            active = false;
        }

        public void append_command_segments (Gee.LinkedList<string> segments) {
            if (active)
                segments.add (token);
        }

        public bool is_active () {
            return active;
        }
    }

    private void test_gpu_vendor_from_pci_devices () {
        var pci_devices = "00:00.0 Host bridge [0600]: Intel Corporation Device [8086:7d41]\n"
                          + "00:02.0 VGA compatible controller [0300]: Intel Corporation Device [8086:a7a0]\n"
                          + "01:00.0 Audio device [0403]: NVIDIA Corporation Device [10de:22ba]";

        assert (ProtonPlus.Utils.System.get_gpu_vendor_from_pci_devices (pci_devices)
                == ProtonPlus.Utils.GpuVendor.INTEL);
        assert (ProtonPlus.Utils.System.get_gpu_vendor_from_pci_devices (
            "01:00.0 3D controller [0302]: NVIDIA Corporation Device [10de:28a0]"
        ) == ProtonPlus.Utils.GpuVendor.NVIDIA);
        assert (ProtonPlus.Utils.System.get_gpu_vendor_from_pci_devices (
            "0c:00.0 Display controller [0380]: Advanced Micro Devices, Inc. [AMD/ATI] Device [1002:73bf]"
        ) == ProtonPlus.Utils.GpuVendor.AMD);
        assert (ProtonPlus.Utils.System.get_gpu_vendor_from_pci_devices (
            "00:14.0 USB controller [0c03]: Intel Corporation Device [8086:7a60]"
        ) == ProtonPlus.Utils.GpuVendor.UNKNOWN);
    }
}
