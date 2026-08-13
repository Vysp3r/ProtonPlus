using GLib;

int main (string[] args) {
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);
    Test.init (ref args);
    ProtonPlus.Globals.CPU_CAPABILITIES = new ProtonPlus.Models.CpuCapabilities (
        ProtonPlus.Models.CpuArchitecture.X86_64,
        ProtonPlus.Models.X86_64Level.BASELINE
    );

    AppTests.ControllerControlPolicyTest.register_tests ();
    AppTests.ControllerHintPolicyTest.register_tests ();
    AppTests.ControllerHapticsTest.register_tests ();
    AppTests.ControllerInputPolicyTest.register_tests ();
    AppTests.ControllerTextInputPolicyTest.register_tests ();
    AppTests.ControllerNavigationPolicyTest.register_tests ();
    AppTests.ControllerSurfacePolicyTest.register_tests ();
    AppTests.ApplicationActionTest.register_tests ();
    AppTests.GameActionPolicyTest.register_tests ();
    AppTests.ReleaseRowPresentationTest.register_tests ();
    AppTests.InlineReleaseRequestGuardTest.register_tests ();
    AppTests.GameCollectionTest.register_tests ();
    AppTests.CpuCapabilitiesTest.register_tests ();
    AppTests.VariantCompatibilityTest.register_tests ();
    AppTests.VariantSelectorTest.register_tests ();
    AppTests.AssetTest.register_tests ();
    AppTests.FilesystemTest.register_tests ();
    AppTests.WebTest.register_tests ();
    AppTests.SystemPathTest.register_tests ();
    AppTests.SystemdTimerTest.register_tests ();
    AppTests.FaugusLauncherTest.register_tests ();
    AppTests.MetadataTest.register_tests ();
    AppTests.CompatibilityToolTest.register_tests ();
    AppTests.SteamCompatibilityToolDiscoveryTest.register_tests ();
    AppTests.InstalledToolInventoryTest.register_tests ();
    AppTests.ParserTest.register_tests ();
    AppTests.LaunchCommandTest.register_tests ();
    AppTests.LaunchCommandParserTest.register_tests ();
    AppTests.LaunchCommandComposerTest.register_tests ();
    AppTests.LaunchCommandEditorProjectionTest.register_tests ();
    AppTests.LaunchCommandWriterTest.register_tests ();
    AppTests.LaunchOptionCapabilityResolverTest.register_tests ();
    AppTests.ProviderDefinitionTest.register_tests ();
    AppTests.ProviderRegistryTest.register_tests ();
    AppTests.ProviderSourceTest.register_tests ();
    AppTests.IdentityTest.register_tests ();
    AppTests.CliTest.register_tests ();
    AppTests.ReleaseIdentityTest.register_tests ();
    AppTests.ReleasePageTest.register_tests ();
    AppTests.VariantSettingsTest.register_tests ();
    AppTests.InstallLayoutTest.register_tests ();
    AppTests.CompatibilityProcessGuardTest.register_tests ();
    AppTests.InstallerTransactionTest.register_tests ();
    AppTests.SteamTest.register_tests ();
    AppTests.SteamSessionTest.register_tests ();
    AppTests.SteamConfigurationServiceTest.register_tests ();
    AppTests.SteamRestartManagerTest.register_tests ();
    AppTests.SteamRestartOrchestratorTest.register_tests ();
    AppTests.SteamRestartPresentationTest.register_tests ();
    AppTests.SteamTinkerLaunchTest.register_tests ();
    AppTests.UpdateTransactionTest.register_tests ();
    AppTests.VdfBinaryTest.register_tests ();

    return Test.run ();
}
