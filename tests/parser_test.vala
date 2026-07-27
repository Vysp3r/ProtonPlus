namespace AppTests.ParserTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/parser/length-aware-byte-conversion", test_length_aware_byte_conversion);
        Test.add_func ("/vdf/text-parser-replaces-key-and-value", test_vdf_document_replacements);
        Test.add_func ("/launch-options/shell-words-preserve-quoting", test_launch_option_shell_words);
        Test.add_func ("/launch-options/opaque-shell-spans", test_opaque_shell_spans);
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
