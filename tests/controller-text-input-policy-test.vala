namespace AppTests.ControllerTextInputPolicyTest {
    using GLib;
    using ProtonPlus.Utils;

    private void assert_metadata (TextInputFieldKind kind,
        Gtk.InputPurpose expected_purpose, Gtk.InputHints expected_hints) {
        var metadata = TextInputMetadataPolicy.for_kind (kind);
        assert (metadata.purpose == expected_purpose);
        assert (metadata.hints == expected_hints);
    }

    private void test_search_metadata () {
        assert_metadata (
            TextInputFieldKind.SEARCH,
            Gtk.InputPurpose.FREE_FORM,
            Gtk.InputHints.NO_SPELLCHECK | Gtk.InputHints.NO_EMOJI
        );
    }

    private void test_numeric_metadata () {
        assert_metadata (
            TextInputFieldKind.NUMERIC, Gtk.InputPurpose.NUMBER, Gtk.InputHints.NONE
        );
        assert_metadata (
            TextInputFieldKind.DIGITS, Gtk.InputPurpose.DIGITS, Gtk.InputHints.NONE
        );
    }

    private void test_url_metadata () {
        var metadata = TextInputMetadataPolicy.for_kind (TextInputFieldKind.URL);
        assert (metadata.purpose == Gtk.InputPurpose.URL);
        assert (metadata.has_hint (Gtk.InputHints.NO_SPELLCHECK));
        assert (metadata.has_hint (Gtk.InputHints.NO_EMOJI));
    }

    private void test_secret_metadata () {
        var metadata = TextInputMetadataPolicy.for_kind (TextInputFieldKind.SECRET);
        assert (metadata.purpose == Gtk.InputPurpose.PASSWORD);
        assert (metadata.has_hint (Gtk.InputHints.PRIVATE));
        assert (metadata.has_hint (Gtk.InputHints.NO_SPELLCHECK));
        assert (metadata.has_hint (Gtk.InputHints.NO_EMOJI));
    }

    private void test_command_metadata () {
        var metadata = TextInputMetadataPolicy.for_kind (TextInputFieldKind.COMMAND);
        assert (metadata.purpose == Gtk.InputPurpose.TERMINAL);
        assert (metadata.has_hint (Gtk.InputHints.NO_SPELLCHECK));
        assert (metadata.has_hint (Gtk.InputHints.NO_EMOJI));
    }

    private void test_path_or_identifier_metadata () {
        var metadata = TextInputMetadataPolicy.for_kind (
            TextInputFieldKind.PATH_OR_IDENTIFIER
        );
        assert (metadata.purpose == Gtk.InputPurpose.TERMINAL);
        assert (metadata.has_hint (Gtk.InputHints.NO_SPELLCHECK));
        assert (metadata.has_hint (Gtk.InputHints.NO_EMOJI));
    }

    private void test_free_form_metadata () {
        assert_metadata (
            TextInputFieldKind.FREE_FORM,
            Gtk.InputPurpose.FREE_FORM,
            Gtk.InputHints.NONE
        );
    }

    private void test_activation_decision () {
        assert (ControllerActivationPolicy.for_focused_control (true) ==
            ControllerActivationDecision.FOCUS_TEXT_INPUT);
        assert (ControllerActivationPolicy.for_focused_control (false) ==
            ControllerActivationDecision.ACTIVATE);
    }

    private void test_read_only_text_is_not_editable () {
        assert (!ControllerEditableTargetResolver.accepts_edits (true, false, true));
        assert (!ControllerEditableTargetResolver.accepts_edits (true, true, false));
        assert (!ControllerEditableTargetResolver.accepts_edits (false, true, true));
        assert (ControllerEditableTargetResolver.accepts_edits (true, true, true));
    }

    private void test_metadata_does_not_transform_text () {
        string original = "MANGOHUD_CONFIG='fps_limit=60,30' %command% -- --Flag=한글";
        string unchanged = original;
        foreach (var kind in new TextInputFieldKind[] {
            TextInputFieldKind.SEARCH,
            TextInputFieldKind.FREE_FORM,
            TextInputFieldKind.NUMERIC,
            TextInputFieldKind.DIGITS,
            TextInputFieldKind.URL,
            TextInputFieldKind.SECRET,
            TextInputFieldKind.COMMAND,
            TextInputFieldKind.PATH_OR_IDENTIFIER
        }) {
            TextInputMetadataPolicy.for_kind (kind);
        }
        assert (unchanged == original);
    }

    public void register_tests () {
        Test.add_func ("/controller-text-input/search-metadata", test_search_metadata);
        Test.add_func ("/controller-text-input/numeric-metadata", test_numeric_metadata);
        Test.add_func ("/controller-text-input/url-metadata", test_url_metadata);
        Test.add_func ("/controller-text-input/secret-metadata", test_secret_metadata);
        Test.add_func ("/controller-text-input/command-metadata", test_command_metadata);
        Test.add_func ("/controller-text-input/path-or-identifier-metadata",
            test_path_or_identifier_metadata);
        Test.add_func ("/controller-text-input/free-form-metadata", test_free_form_metadata);
        Test.add_func ("/controller-text-input/activation-decision", test_activation_decision);
        Test.add_func ("/controller-text-input/read-only-text", test_read_only_text_is_not_editable);
        Test.add_func ("/controller-text-input/no-text-transformation",
            test_metadata_does_not_transform_text);
    }
}
