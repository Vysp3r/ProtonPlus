using GLib;

int main (string[] args) {
    Test.init (ref args);

    AppTests.FilesystemTest.register_tests ();
    AppTests.MetadataTest.register_tests ();
    AppTests.InstalledToolInventoryTest.register_tests ();
    AppTests.ParserTest.register_tests ();
    AppTests.ProviderDefinitionTest.register_tests ();
    AppTests.ProviderSourceTest.register_tests ();
    AppTests.IdentityTest.register_tests ();
    AppTests.CliTest.register_tests ();
    AppTests.ReleaseIdentityTest.register_tests ();
    AppTests.ReleasePageTest.register_tests ();
    AppTests.VariantSettingsTest.register_tests ();
    AppTests.InstallLayoutTest.register_tests ();
    AppTests.InstallerTransactionTest.register_tests ();
    AppTests.SteamTest.register_tests ();
    AppTests.SteamTinkerLaunchTest.register_tests ();
    AppTests.UpdateTransactionTest.register_tests ();
    AppTests.VdfBinaryTest.register_tests ();

    return Test.run ();
}
