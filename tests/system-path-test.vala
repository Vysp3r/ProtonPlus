namespace AppTests.SystemPathTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/system/file-uri-escapes-special-characters", test_file_uri_escapes_special_characters);
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
