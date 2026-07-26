namespace AppTests.IdentityTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Launchers.Runners;

    public void register_tests () {
        Test.add_func ("/identity/launchers/families-and-instances", test_launcher_family_and_instance_ids);
        Test.add_func ("/identity/providers/nonempty-and-unique", test_provider_ids_are_nonempty_and_unique);
        Test.add_func ("/identity/variants/nonempty-and-unique-per-provider", test_variant_ids_are_nonempty_and_unique_per_provider);
        Test.add_func ("/identity/tools/deterministic-and-scoped", test_tool_ids_are_deterministic_and_scoped);
        Test.add_func ("/identity/titles/do-not-change-ids", test_titles_do_not_change_ids);
    }

    private Gee.ArrayList<IRunner> get_all_runners () {
        var all_runners = new Gee.ArrayList<IRunner> ();
        var runners = new Runners ();
        foreach (var type in new RunnerType[] { RunnerType.DXVK, RunnerType.VKD3D, RunnerType.Proton, RunnerType.Wine })
            all_runners.add_all (runners.getRunners (type));
        return all_runners;
    }

    private string get_group_id (RunnerType type) {
        switch (type) {
        case RunnerType.DXVK:
            return "dxvk";
        case RunnerType.VKD3D:
            return "vkd3d";
        case RunnerType.Proton:
            return "proton";
        case RunnerType.Wine:
            return "wine";
        default:
            assert_not_reached ();
        }
    }

    private void assert_source_id_is_valid (string source_id) {
        assert (source_id == "github" ||
                source_id == "github-actions" ||
                source_id == "gitlab" ||
                source_id == "forgejo");
    }

    private Launcher create_launcher (string family_id, Launcher.InstallationTypes installation_type) {
        return new Launcher ("Fixture launcher", installation_type, "", {}, family_id);
    }

    private Group create_group (Launcher launcher, string id) {
        return new Group ("Fixture group", "", "", launcher, id);
    }

    private IRunner get_proton_ge () {
        foreach (var runner in get_all_runners ()) {
            if (runner.provider_id == "proton-ge")
                return runner;
        }
        assert_not_reached ();
    }

    private void test_launcher_family_and_instance_ids () {
        var family_ids = new Gee.HashSet<string> ();
        assert (family_ids.add (ProtonPlus.Models.Launchers.Steam.FAMILY_ID));
        assert (family_ids.add (ProtonPlus.Models.Launchers.Lutris.FAMILY_ID));
        assert (family_ids.add (ProtonPlus.Models.Launchers.Bottles.FAMILY_ID));
        assert (family_ids.add (ProtonPlus.Models.Launchers.HeroicGamesLauncher.FAMILY_ID));
        assert (family_ids.add (ProtonPlus.Models.Launchers.WineZGUI.FAMILY_ID));
        assert (family_ids.size == 5);

        var instances = new Launcher[] {
            create_launcher (ProtonPlus.Models.Launchers.Steam.FAMILY_ID, Launcher.InstallationTypes.SYSTEM),
            create_launcher (ProtonPlus.Models.Launchers.Steam.FAMILY_ID, Launcher.InstallationTypes.FLATPAK),
            create_launcher (ProtonPlus.Models.Launchers.Steam.FAMILY_ID, Launcher.InstallationTypes.SNAP),
            create_launcher (ProtonPlus.Models.Launchers.Lutris.FAMILY_ID, Launcher.InstallationTypes.SYSTEM),
            create_launcher (ProtonPlus.Models.Launchers.Lutris.FAMILY_ID, Launcher.InstallationTypes.FLATPAK),
            create_launcher (ProtonPlus.Models.Launchers.Bottles.FAMILY_ID, Launcher.InstallationTypes.SYSTEM),
            create_launcher (ProtonPlus.Models.Launchers.Bottles.FAMILY_ID, Launcher.InstallationTypes.FLATPAK),
            create_launcher (ProtonPlus.Models.Launchers.HeroicGamesLauncher.FAMILY_ID, Launcher.InstallationTypes.SYSTEM),
            create_launcher (ProtonPlus.Models.Launchers.HeroicGamesLauncher.FAMILY_ID, Launcher.InstallationTypes.FLATPAK),
            create_launcher (ProtonPlus.Models.Launchers.WineZGUI.FAMILY_ID, Launcher.InstallationTypes.SYSTEM),
            create_launcher (ProtonPlus.Models.Launchers.WineZGUI.FAMILY_ID, Launcher.InstallationTypes.FLATPAK)
        };
        var instance_ids = new Gee.HashSet<string> ();
        foreach (var launcher in instances)
            assert (instance_ids.add (launcher.instance_id));

        assert (instance_ids.contains ("steam-system"));
        assert (instance_ids.contains ("steam-flatpak"));
        assert (instance_ids.contains ("steam-snap"));
    }

    private void test_provider_ids_are_nonempty_and_unique () {
        var ids = new Gee.HashSet<string> ();
        var runners = get_all_runners ();
        assert (runners.size == 19);

        foreach (var runner in runners) {
            assert (runner.provider_id != "");
            assert (ids.add (runner.provider_id));
            assert_source_id_is_valid (runner.source_id);
        }
    }

    private void test_variant_ids_are_nonempty_and_unique_per_provider () {
        foreach (var runner in get_all_runners ()) {
            var variant_ids = new Gee.HashSet<string> ();
            foreach (var variant in runner.variants) {
                assert (variant.id != "");
                assert (variant.id != "default");
                assert (!variant.id.contains ("_"));
                assert (variant_ids.add (variant.id));
            }
        }
    }

    private void test_tool_ids_are_deterministic_and_scoped () {
        var launcher = create_launcher ("steam", Launcher.InstallationTypes.SYSTEM);
        var tool_ids = new Gee.HashSet<string> ();
        var runners = new Runners ();

        foreach (var type in new RunnerType[] { RunnerType.DXVK, RunnerType.VKD3D, RunnerType.Proton, RunnerType.Wine }) {
            var group = create_group (launcher, get_group_id (type));
            foreach (var runner in runners.getRunners (type)) {
                var tool = runner.create_tool (group);
                assert (tool != null);
                assert (tool.id == "%s/%s/%s".printf (launcher.instance_id, group.id, runner.provider_id));
                assert (tool.provider_id == runner.provider_id);
                assert (tool.source_id == runner.source_id);
                assert (tool_ids.add (tool.id));
            }
        }

        var steam_tinker_launch = new ProtonPlus.Models.Tools.SteamTinkerLaunch (
            create_group (launcher, "proton")
        );
        assert (steam_tinker_launch.id == "steam-system/proton/steam-tinker-launch");
        assert (steam_tinker_launch.provider_id == "steam-tinker-launch");
        assert (steam_tinker_launch.source_id == "github");
        assert (tool_ids.add (steam_tinker_launch.id));

        var proton_ge = get_proton_ge ();
        var system_tool = proton_ge.create_tool (create_group (launcher, "proton"));
        var repeated_system_tool = proton_ge.create_tool (create_group (launcher, "proton"));
        var flatpak_launcher = create_launcher ("steam", Launcher.InstallationTypes.FLATPAK);
        var flatpak_tool = proton_ge.create_tool (create_group (flatpak_launcher, "proton"));
        var lutris_launcher = create_launcher ("lutris", Launcher.InstallationTypes.SYSTEM);
        var lutris_tool = proton_ge.create_tool (create_group (lutris_launcher, "proton"));
        assert (system_tool != null);
        assert (repeated_system_tool != null);
        assert (flatpak_tool != null);
        assert (lutris_tool != null);
        assert (system_tool.id == "steam-system/proton/proton-ge");
        assert (system_tool.id == repeated_system_tool.id);
        assert (flatpak_tool.id == "steam-flatpak/proton/proton-ge");
        assert (lutris_tool.id == "lutris-system/proton/proton-ge");
        assert (system_tool.id != flatpak_tool.id);
        assert (system_tool.id != lutris_tool.id);
    }

    private void test_titles_do_not_change_ids () {
        var launcher = create_launcher ("steam", Launcher.InstallationTypes.SYSTEM);
        var launcher_id = launcher.instance_id;
        launcher.title = "Translated launcher title";
        assert (launcher.instance_id == launcher_id);

        var runner = get_proton_ge ();
        var variant = runner.variants.get (0);
        var variant_id = variant.id;
        variant.name = "Translated variant";
        assert (variant.id == variant_id);

        var provider_id = runner.provider_id;
        runner.title = "Translated title";
        assert (runner.provider_id == provider_id);

        var tool = runner.create_tool (create_group (create_launcher ("steam", Launcher.InstallationTypes.SYSTEM), "proton"));
        assert (tool != null);
        var tool_id = tool.id;
        tool.title = "Another translated title";
        assert (tool.id == tool_id);
        assert (tool.provider_id == provider_id);
    }
}
