using ProtonPlus;
using ProtonPlus.Widgets.Games;

class GameListFixture : Object {
    public GameCollection collection;
    public GameListView view;
    public Models.Launchers.Steam launcher;
    public GameListItem? activated_item;
    public uint activation_count = 0;

    public GameListFixture (string root) {
        launcher = new Models.Launchers.Steam (Models.Launcher.InstallationTypes.SYSTEM);
        launcher.directory = root;
        collection = new GameCollection ();
        replace_games ("Alpha", "Bravo");
        view = new GameListView (collection, focus_relative, focus_relative, activate_item);
    }

    public void replace_games (string first, string second) {
        var games = new List<Models.Game> ();
        games.append (new Models.Games.Steam.non_steam (1, first, "", "Default", launcher));
        games.append (new Models.Games.Steam.non_steam (2, second, "", "Default", launcher));
        collection.replace (games);
    }

    bool focus_relative (GameListItem item, int delta, GameFocusLane lane) {
        return false;
    }

    void activate_item (GameListItem item) {
        activated_item = item;
        activation_count++;
    }
}

class GameListLifetimeProbe : Object {
    public WeakRef widget;

    public GameListLifetimeProbe (Object widget) {
        this.widget = WeakRef (widget);
    }
}

void settle () {
    var loop = new MainLoop ();
    Timeout.add (200, () => {
        loop.quit ();
        return Source.REMOVE;
    });
    loop.run ();
}

Gtk.ColumnViewColumn actions_column (GameListView view) {
    var columns = view.wide_view.get_columns ();
    return (Gtk.ColumnViewColumn) columns.get_item (columns.get_n_items () - 1);
}

void check_binding_selection_and_activation (string root) {
    var fixture = new GameListFixture (root);
    var window = new Adw.Window () {
        default_width = 850,
        default_height = 450,
        content = fixture.view
    };
    window.present ();
    settle ();

    var first = fixture.collection.item_at (0);
    assert (first != null);
    var selection = fixture.view.get_selection_target ((!) first) as GameSelectionCell;
    assert (selection != null && selection.get_mapped ());
    assert (actions_column (fixture.view).get_visible ());
    assert (fixture.view.focus_item (0, GameFocusLane.FIRST_ACTION));
    assert (fixture.view.find_focused_item () == first);

    // Activation is forwarded to the page; the fixture never launches a game.
    fixture.view.wide_view.activate (0);
    assert (fixture.activation_count == 1 && fixture.activated_item == first);
    assert (selection.controller_activate (selection));
    assert (first.selected && fixture.collection.selected_count () == 1);
    fixture.view.set_selection_mode (true);
    assert (!actions_column (fixture.view).get_visible ());

    fixture.view.show_narrow (true);
    settle ();
    var row = fixture.view.get_selection_target ((!) first) as GameRow;
    assert (row != null && row.get_mapped ());
    fixture.view.narrow_view.activate (0);
    assert (fixture.activation_count == 2 && fixture.activated_item == first);
    first.selected = false;
    fixture.view.set_selection_mode (false);

    // A profile replacement must retire the old selection bindings in both
    // views. GTK may recycle those cells immediately for replacement items.
    fixture.replace_games ("Charlie", "Delta");
    settle ();
    assert (fixture.view.get_selection_target ((!) first) == null);
    assert (row.get_item () != first);
    assert (selection.get_item () != first);
    var replacement = fixture.collection.item_at (0);
    assert (replacement != null && replacement != first);
    var replacement_row = fixture.view.get_selection_target ((!) replacement) as GameRow;
    assert (replacement_row != null && replacement_row.get_item () == replacement);
    first.selected = true;
    assert (!replacement.selected && fixture.collection.selected_count () == 0);

    fixture.view.show_narrow (false);
    settle ();
    assert (fixture.view.get_selection_target ((!) replacement) is GameSelectionCell);
    assert (actions_column (fixture.view).get_visible ());
    fixture.view.detach ();
    assert (replacement_row.get_item () == null);
    assert (fixture.view.get_selection_target ((!) replacement) == null);
    window.destroy ();
}

GameListLifetimeProbe detach_pending_focus (GameCollection collection) {
    var view = new GameListView (collection,
        (item, delta, lane) => false,
        (item, delta, lane) => false,
        (item) => {});
    // The view is not mapped yet, so this schedules a deferred bind/focus retry.
    assert (view.focus_item (0, GameFocusLane.SELECTION));
    var probe = new GameListLifetimeProbe (view);
    view.detach ();
    return probe;
}

void check_pending_focus_cleanup (string root) {
    var fixture = new GameListFixture (root);
    var probe = detach_pending_focus (fixture.collection);
    assert (probe.widget.get () == null);
    settle ();
    fixture.replace_games ("New profile", "Other game");
    assert (probe.widget.get () == null);
    fixture.view.detach ();
}

int main (string[] args) {
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);
    if (!Gtk.init_check ())
        return 77;
    Adw.init ();
    Gtk.Settings.get_default ().gtk_enable_animations = false;
    string root;
    try {
        root = DirUtils.make_tmp ("protonplus-games-presentation-XXXXXX");
    } catch (Error e) {
        error ("%s", e.message);
    }
    check_binding_selection_and_activation (root);
    check_pending_focus_cleanup (root);
    assert (DirUtils.remove (root) == 0);
    return 0;
}
