using GLib;

int main (string[] args) {
    Test.init (ref args);

    AppTests.FilesystemTest.register_tests ();
    AppTests.MetadataTest.register_tests ();
    AppTests.ParserTest.register_tests ();
    AppTests.ProviderSourceTest.register_tests ();
    AppTests.SteamTest.register_tests ();
    AppTests.VdfBinaryTest.register_tests ();

    return Test.run ();
}
