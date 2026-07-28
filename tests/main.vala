using GLib;

int main (string[] args) {
    Test.init (ref args);

    AppTests.AssetTest.register_tests ();
    AppTests.FilesystemTest.register_tests ();
    AppTests.FaugusLauncherTest.register_tests ();
    AppTests.MetadataTest.register_tests ();
    AppTests.CompatibilityToolTest.register_tests ();
    AppTests.InstalledToolInventoryTest.register_tests ();
    AppTests.ParserTest.register_tests ();
    AppTests.LaunchCommandTest.register_tests ();
    AppTests.LaunchCommandParserTest.register_tests ();
    AppTests.LaunchCommandComposerTest.register_tests ();
    AppTests.LaunchCommandEditorProjectionTest.register_tests ();
    AppTests.LaunchCommandWriterTest.register_tests ();
    AppTests.ProviderDefinitionTest.register_tests ();
    AppTests.ProviderRegistryTest.register_tests ();
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
