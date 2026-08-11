namespace AppTests.GameCollectionTest {
    using ProtonPlus.Models;
    using ProtonPlus.Widgets.Games;

    private Game fixture_game (string name, bool native = false, uint appid = 1) {
        var launcher = new ProtonPlus.Models.Launchers.Steam (
            Launcher.InstallationTypes.SYSTEM
        );
        var game = new ProtonPlus.Models.Games.Steam.non_steam (
            appid, name, "", "Default", launcher
        );
        game.is_non_steam = false;
        game.is_native = native;
        return game;
    }

    private List<Game> game_list (Game[] games) {
        var result = new List<Game> ();
        foreach (var game in games)
            result.append (game);
        return result;
    }

    private void test_filter_and_sort_projection () {
        var collection = new GameCollection ();
        collection.replace (game_list ({
            fixture_game ("Zulu", false, 3),
            fixture_game ("Alpha", true, 1),
            fixture_game ("Bravo", false, 2)
        }));

        assert (collection.visible_count () == 3);
        assert (collection.item_at (0).game.name == "Alpha");
        assert (collection.item_at (2).game.name == "Zulu");

        collection.set_filter ("a", GameFilterMode.NATIVE);
        assert (collection.visible_count () == 1);
        assert (collection.item_at (0).game.name == "Alpha");
    }

    private void test_column_sorters_and_tool_refresh () {
        var zulu = fixture_game ("Zulu", false, 2);
        zulu.launcher.compatibility_tools.add (new CompatibilityTool (
            "Alpha Tool", "alpha-tool"
        ));
        zulu.compatibility_tool = "alpha-tool";
        var alpha = fixture_game ("Alpha", false, 3);
        alpha.launcher.compatibility_tools.add (new CompatibilityTool (
            "Middle Tool", "middle-tool"
        ));
        alpha.compatibility_tool = "middle-tool";
        var bravo = fixture_game ("Bravo", false, 1);
        bravo.launcher.compatibility_tools.add (new CompatibilityTool (
            "Zulu Tool", "zulu-tool"
        ));
        bravo.compatibility_tool = "zulu-tool";

        var collection = new GameCollection ();
        collection.replace (game_list ({ zulu, alpha, bravo }));
        assert (collection.item_at (0).game.name == "Alpha");

        collection.set_sorter (collection.prefix_sorter);
        assert (collection.item_at (0).game.name == "Bravo");
        assert (collection.item_at (1).game.name == "Zulu");
        assert (collection.item_at (2).game.name == "Alpha");

        var selected = collection.item_at (1);
        selected.selected = true;
        collection.prefix_sorter.set_sort_order (Gtk.SortType.DESCENDING);
        assert (collection.item_at (0).game.name == "Alpha");
        assert (collection.item_at (1).game.name == "Zulu");
        assert (collection.item_at (2).game.name == "Bravo");
        assert (selected.selected);
        assert (collection.selected_visible_count () == 1);

        collection.set_sorter (collection.tool_sorter);
        assert (collection.item_at (0).game.name == "Zulu");
        assert (collection.item_at (1).game.name == "Alpha");
        assert (collection.item_at (2).game.name == "Bravo");
        assert (selected.selected);
        assert (collection.selected_visible_count () == 1);

        var bravo_item = collection.item_at (2);
        bravo.launcher.compatibility_tools.add (new CompatibilityTool (
            "Aardvark Tool", "aardvark-tool"
        ));
        bravo.compatibility_tool = "aardvark-tool";
        bravo_item.refresh_tool_title ();
        assert (collection.item_at (0).game.name == "Bravo");
        assert (selected.selected);
        assert (collection.selected_visible_count () == 1);
    }

    private void test_filtered_selection_is_preserved () {
        var collection = new GameCollection ();
        collection.replace (game_list ({
            fixture_game ("Alpha", false, 1),
            fixture_game ("Bravo", false, 2)
        }));
        var alpha = collection.item_at (0);
        var bravo = collection.item_at (1);
        alpha.selected = true;
        bravo.selected = true;

        collection.set_filter ("bravo", GameFilterMode.ALL);
        assert (collection.visible_count () == 1);
        assert (collection.selected_visible_count () == 1);
        assert (collection.selected_items ().length == 2);
        assert (collection.selected_items ()[0].game.name == "Alpha");
        assert (collection.selected_items ()[1].game.name == "Bravo");

        collection.select_all_visible (false);
        assert (alpha.selected);
        assert (!bravo.selected);
        collection.set_filter ("", GameFilterMode.ALL);
        assert (collection.selected_visible_count () == 1);
    }

    private void test_model_replacement_drops_stale_selection () {
        var collection = new GameCollection ();
        collection.replace (game_list ({ fixture_game ("Old profile") }));
        collection.item_at (0).selected = true;
        var generation = collection.generation;

        collection.replace (game_list ({ fixture_game ("New profile") }));
        assert (collection.generation > generation);
        assert (collection.visible_count () == 1);
        assert (collection.selected_items ().length == 0);
        assert (collection.item_at (0).game.name == "New profile");
    }

    private void test_long_title_and_empty_results () {
        var collection = new GameCollection ();
        var title = "A very long localized game title that should remain a model value without truncation";
        collection.replace (game_list ({ fixture_game (title) }));
        assert (collection.item_at (0).game.name == title);

        collection.set_filter ("not present", GameFilterMode.ALL);
        assert (collection.visible_count () == 0);
        assert (collection.item_at (0) == null);
    }

    public void register_tests () {
        Test.add_func ("/games-collection/filter-and-sort", test_filter_and_sort_projection);
        Test.add_func ("/games-collection/column-sorters", test_column_sorters_and_tool_refresh);
        Test.add_func ("/games-collection/filtered-selection", test_filtered_selection_is_preserved);
        Test.add_func ("/games-collection/model-replacement", test_model_replacement_drops_stale_selection);
        Test.add_func ("/games-collection/long-title-and-empty", test_long_title_and_empty_results);
    }
}
