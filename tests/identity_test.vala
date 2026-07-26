namespace AppTests.IdentityTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;

    public void register_tests () {
        Test.add_func ("/identity/launchers/families-and-instances", test_launcher_family_and_instance_ids);
        Test.add_func ("/identity/providers/nonempty-and-unique", test_provider_ids_are_nonempty_and_unique);
        Test.add_func ("/identity/variants/nonempty-and-unique-per-provider", test_variant_ids_are_nonempty_and_unique_per_provider);
        Test.add_func ("/identity/tools/deterministic-and-scoped", test_tool_ids_are_deterministic_and_scoped);
        Test.add_func ("/identity/cli/stable-and-legacy-aliases", test_cli_stable_and_legacy_aliases);
    }

    private ProviderDefinition get_definition (string provider_id) {
        foreach (var definition in new ProviderDefinitions ().get_all ()) {
            if (definition.provider_id == provider_id)
                return definition;
        }
        assert_not_reached ();
    }

    private Launcher launcher (string family_id, Launcher.InstallationTypes installation_type) {
        return new Launcher ("Fixture launcher", installation_type, "", {}, family_id);
    }

    private Tools.ProviderTool tool (ProviderDefinition definition, Launcher launcher, string group_id) {
        var value = ProviderCatalog.create_tool (definition, new Group ("Fixture group", "", "", launcher, group_id));
        assert (value != null);
        return value;
    }

    private void test_launcher_family_and_instance_ids () {
        var instances = new Launcher[] {
            launcher ("steam", Launcher.InstallationTypes.SYSTEM),
            launcher ("steam", Launcher.InstallationTypes.FLATPAK),
            launcher ("steam", Launcher.InstallationTypes.SNAP),
            launcher ("lutris", Launcher.InstallationTypes.SYSTEM)
        };
        var ids = new Gee.HashSet<string> ();
        foreach (var value in instances)
            assert (ids.add (value.instance_id));
        assert (ids.contains ("steam-system"));
        assert (ids.contains ("steam-flatpak"));
        assert (ids.contains ("steam-snap"));
    }

    private void test_provider_ids_are_nonempty_and_unique () {
        var ids = new Gee.HashSet<string> ();
        var definitions = new ProviderDefinitions ().get_all ();
        assert (definitions.size == 19);
        foreach (var definition in definitions) {
            assert (definition.provider_id != "");
            assert (ids.add (definition.provider_id));
            assert (definition.source_id == "github" || definition.source_id == "github-actions" ||
                    definition.source_id == "gitlab" || definition.source_id == "forgejo");
        }
    }

    private void test_variant_ids_are_nonempty_and_unique_per_provider () {
        foreach (var definition in new ProviderDefinitions ().get_all ()) {
            var ids = new Gee.HashSet<string> ();
            foreach (var variant in definition.get_variants ()) {
                assert (variant.id != "");
                assert (!variant.id.contains ("_"));
                assert (ids.add (variant.id));
            }
        }
    }

    private void test_tool_ids_are_deterministic_and_scoped () {
        var definition = get_definition ("proton-ge");
        var system = launcher ("steam", Launcher.InstallationTypes.SYSTEM);
        var repeated = tool (definition, system, "proton");
        var same = tool (definition, system, "proton");
        var flatpak = tool (definition, launcher ("steam", Launcher.InstallationTypes.FLATPAK), "proton");
        var lutris = tool (definition, launcher ("lutris", Launcher.InstallationTypes.SYSTEM), "proton");
        assert (repeated.id == "steam-system/proton/proton-ge");
        assert (same.id == repeated.id);
        assert (flatpak.id == "steam-flatpak/proton/proton-ge");
        assert (lutris.id == "lutris-system/proton/proton-ge");
        assert (repeated.id != flatpak.id);
        assert (repeated.id != lutris.id);
        repeated.title = "Translated title";
        assert (repeated.id == "steam-system/proton/proton-ge");
    }

    private void test_cli_stable_and_legacy_aliases () {
        var steam = launcher ("heroic", Launcher.InstallationTypes.SYSTEM);
        steam.title = "Heroic Games Launcher";
        assert (ProtonPlus.CLI.Handler.get_launcher_id (steam) == "heroic-system");
        assert (ProtonPlus.CLI.Handler.matches_launcher_id (steam, "heroic-games-launcher-system"));

        var definition = get_definition ("dxvk-doitsujin");
        var runner = tool (definition, steam, "dxvk");
        assert (ProtonPlus.CLI.Handler.get_runner_id (runner) == "dxvk-doitsujin");
        assert (ProtonPlus.CLI.Handler.matches_runner_id (runner, "dxvk-(doitsujin)"));
    }
}
