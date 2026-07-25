namespace AppTests.ParserTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/parser/length-aware-byte-conversion", test_length_aware_byte_conversion);
        Test.add_func ("/launch-options/shell-words-preserve-quoting", test_launch_option_shell_words);
        Test.add_func ("/launch-options/opaque-shell-spans", test_opaque_shell_spans);
    }

    private void test_length_aware_byte_conversion () {
        uint8 data[4];
        data[0] = 't';
        data[1] = 'e';
        data[2] = 's';
        data[3] = 't';

        assert (ProtonPlus.Utils.Parser.data_to_string (data) == "test");
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
}
