namespace AppTests.GameActionPolicyTest {
    using ProtonPlus.Models;
    using ProtonPlus.Widgets.Games;

    private GameListItem fixture_item (string name, uint appid) {
        var launcher = new ProtonPlus.Models.Launchers.Steam (
            Launcher.InstallationTypes.SYSTEM
        );
        return new GameListItem (new ProtonPlus.Models.Games.Steam.non_steam (
            appid, name, "", "Default", launcher
        ));
    }

    private GameActionAvailability availability (bool is_steam = true,
        bool is_non_steam = false, bool is_native = false,
        bool has_install_directory = true, bool has_prefix_directory = true,
        bool protontricks_available = true, string? anticheat_status = "Supported",
        bool has_anticheat_page = true) {
        return GameActionAvailability.evaluate (
            is_steam, is_non_steam, is_native, has_install_directory,
            has_prefix_directory, protontricks_available, anticheat_status,
            has_anticheat_page
        );
    }

    private void test_steam_actions () {
        var actions = availability ();
        assert (actions.show_launch);
        assert (actions.show_custom_executable);
        assert (actions.enable_custom_executable);
        assert (actions.show_install_directory);
        assert (actions.show_prefix_directory);
        assert (actions.show_protontricks);
        assert (actions.show_protondb);
        assert (actions.show_anticheat);
        assert (actions.enable_anticheat);
        assert (actions.anticheat_state == GameAntiCheatState.SUPPORTED);
    }

    private void test_non_steam_restrictions () {
        var actions = availability (true, true);
        assert (actions.show_launch);
        assert (actions.show_custom_executable);
        assert (!actions.show_protontricks);
        assert (!actions.show_protondb);
        assert (!actions.show_anticheat);
    }

    private void test_native_and_missing_prefix () {
        var actions = availability (true, false, true, true, false);
        assert (actions.native_game);
        assert (actions.show_custom_executable);
        assert (!actions.enable_custom_executable);
        assert (!actions.show_prefix_directory);
        assert (actions.show_launch);
    }

    private void test_protontricks_unavailable () {
        var actions = availability (true, false, false, true, true, false);
        assert (!actions.show_protontricks);
        assert (actions.show_protondb);
    }

    private void test_non_steam_launcher_folders_only () {
        var actions = availability (false, false, false, true, false);
        assert (!actions.show_launch);
        assert (!actions.show_custom_executable);
        assert (actions.show_install_directory);
        assert (!actions.show_prefix_directory);
        assert (actions.has_secondary_actions);
    }

    private void test_delayed_anticheat_status () {
        var loading = availability (
            true, false, false, true, true, true, null, false
        );
        assert (loading.show_anticheat);
        assert (!loading.enable_anticheat);
        assert (loading.anticheat_state == GameAntiCheatState.LOADING);

        var loaded = availability (
            true, false, false, true, true, true, "Running", true
        );
        assert (loaded.enable_anticheat);
        assert (loaded.anticheat_state == GameAntiCheatState.RUNNING);
    }

    private void test_row_activation_modes () {
        assert (GameActionAvailability.row_activation (false) ==
            GameRowActivation.MODIFY);
        assert (GameActionAvailability.row_activation (true) ==
            GameRowActivation.TOGGLE_SELECTION);
    }

    private void test_action_target_rebind () {
        var first = fixture_item ("First", 1);
        var second = fixture_item ("Second", 2);
        var target = new GameActionTarget ();

        target.bind (first);
        var first_generation = target.generation;
        assert (target.item == first);
        target.unbind ();
        assert (target.item == null);
        assert (target.generation > first_generation);

        target.bind (second);
        assert (target.item == second);
        assert (target.item != first);
    }

    public void register_tests () {
        Test.add_func ("/games-actions/steam", test_steam_actions);
        Test.add_func ("/games-actions/non-steam", test_non_steam_restrictions);
        Test.add_func ("/games-actions/native-missing-prefix", test_native_and_missing_prefix);
        Test.add_func ("/games-actions/protontricks-unavailable", test_protontricks_unavailable);
        Test.add_func ("/games-actions/folders-only", test_non_steam_launcher_folders_only);
        Test.add_func ("/games-actions/delayed-anticheat", test_delayed_anticheat_status);
        Test.add_func ("/games-actions/activation-mode", test_row_activation_modes);
        Test.add_func ("/games-actions/rebind", test_action_target_rebind);
    }
}
