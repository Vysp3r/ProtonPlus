namespace AppTests.SystemPathTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/system/file-uri-escapes-special-characters", test_file_uri_escapes_special_characters);
        Test.add_func ("/system/flatpak-dependency/installed-branches", test_flatpak_installed_branches);
        Test.add_func ("/system/flatpak-dependency/exact-id", test_flatpak_exact_id);
        Test.add_func ("/system/flatpak-dependency/command-status", test_flatpak_command_status);
    }

    private const string MANGOHUD_ID = "org.freedesktop.Platform.VulkanLayer.MangoHud";

    private bool has_dependency (string stdout, string stderr = "", int exit_status = 0) {
        return ProtonPlus.Utils.System.flatpak_list_contains_dependency (
            new ProtonPlus.Utils.CommandResult (stdout, stderr, exit_status), MANGOHUD_ID
        );
    }

    private void test_flatpak_installed_branches () {
        assert (!has_dependency (""));
        assert (has_dependency (MANGOHUD_ID + "\n"));
        // Different branches/installations can produce the same application ID.
        assert (has_dependency (MANGOHUD_ID + "\n" + MANGOHUD_ID + "\n"));
        assert (has_dependency ("com.valvesoftware.Steam\n" + MANGOHUD_ID));
    }

    private void test_flatpak_exact_id () {
        assert (!has_dependency ("com.valvesoftware.Steam\n"));
        assert (!has_dependency (MANGOHUD_ID + ".Locale\n"));
        assert (!has_dependency ("prefix." + MANGOHUD_ID + "\n"));
        assert (!ProtonPlus.Utils.System.flatpak_list_contains_dependency (
            new ProtonPlus.Utils.CommandResult ("\n", "", 0), ""
        ));
    }

    private void test_flatpak_command_status () {
        assert (!has_dependency (MANGOHUD_ID + "\n", "localized failure", 1));
        assert (!has_dependency ("", "spawn failed", -1));
        assert (!has_dependency ("", MANGOHUD_ID));
        assert (has_dependency (MANGOHUD_ID + "\n", "warning: error: diagnostic"));
    }

    private void test_file_uri_escapes_special_characters () {
        var path = Path.build_filename (
            Environment.get_tmp_dir (), "ProtonPlus folder", "#100%", "café"
        );
        var uri = ProtonPlus.Utils.System.file_uri_for_path (path);

        assert (uri.has_prefix ("file://"));
        assert (uri.contains ("%20"));
        assert (uri.contains ("%23"));
        assert (uri.contains ("%25"));
        assert (uri.contains ("%C3%A9"));
        assert (File.new_for_uri (uri).get_path () == path);
    }
}
