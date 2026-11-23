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

class DeferredSteamLibrary : Models.Launchers.Steam {
    public bool defer_load;
    SourceFunc? pending_callback;
    bool loaded;

    public DeferredSteamLibrary (Models.Launcher.InstallationTypes type, string root) {
        base (type);
        directory = root;
    }

    public override async bool load_game_library () {
        if (defer_load) {
            pending_callback = load_game_library.callback;
            yield;
        }
        if (!loaded)
            return false;

        games = new List<Models.Game> ();
        games.append (new Models.Games.Steam (1, "Alpha", "Alpha", 0, directory, this));
        games.append (new Models.Games.Steam (2, "Bravo", "Bravo", 0, directory, this));
        foreach (var game in games)
            game.compatibility_tool = "Default";
        return true;
    }

    public void complete () {
        loaded = true;
        var callback = (!) pending_callback;
        pending_callback = null;
        callback ();
    }
}

delegate bool WidgetMatches (Gtk.Widget widget);

Gtk.Widget? find_widget (Gtk.Widget root, WidgetMatches matches) {
    if (matches (root))
        return root;
    for (var child = root.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var result = find_widget (child, matches);
        if (result != null)
            return result;
    }
    return null;
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

void wait_for_library_load (Models.Launchers.Steam steam) {
    if (!steam.game_library_loading)
        return;
    var loop = new MainLoop ();
    var handler = steam.notify["game-library-loading"].connect (() => {
        if (!steam.game_library_loading)
            loop.quit ();
    });
    var timeout = Timeout.add_seconds (5, () => {
        error ("Steam library test timed out");
    });
    loop.run ();
    Source.remove (timeout);
    steam.disconnect (handler);
}

void check_selection_footer_layout (Gtk.Widget page, Gtk.Widget summary,
    Gtk.Button clear, MassEditButton modify, bool compact) {
    Graphene.Rect summary_bounds, clear_bounds, modify_bounds;
    assert (summary.compute_bounds (page, out summary_bounds));
    assert (clear.compute_bounds (page, out clear_bounds));
    assert (modify.compute_bounds (page, out modify_bounds));
    assert (clear.get_parent () == modify.get_parent ());
    assert (Math.fabs (clear_bounds.origin.y - modify_bounds.origin.y) < 2);
    assert (clear_bounds.origin.x + clear_bounds.size.width < modify_bounds.origin.x);
    assert (modify_bounds.origin.x + modify_bounds.size.width <= page.get_width ());
    if (compact)
        assert (summary_bounds.origin.y + summary_bounds.size.height <= clear_bounds.origin.y);
    else
        assert (summary_bounds.origin.y + summary_bounds.size.height > clear_bounds.origin.y);
}

void check_empty_wide_list (Gtk.Widget page, string status_title, string[] headings) {
    var table = find_widget (page, (widget) => widget is Gtk.ColumnView && widget.get_mapped ()) as Gtk.ColumnView;
    assert (table != null && table.get_model ().get_n_items () == 0);
    var status = find_widget (page, (widget) => widget is Adw.StatusPage && widget.get_mapped () &&
        ((Adw.StatusPage) widget).title == status_title);
    assert (status != null);
    foreach (var heading in headings) {
        var label = find_widget (table, (widget) => widget is Gtk.Label && widget.get_mapped () &&
            ((Gtk.Label) widget).label == heading);
        assert (label != null && label.get_width () > 0 && label.get_height () > 0);
    }
    Graphene.Rect table_bounds, status_bounds;
    assert (table.compute_bounds (page, out table_bounds));
    assert (status.compute_bounds (page, out status_bounds));
    assert (table_bounds.origin.y + table_bounds.size.height <= status_bounds.origin.y);
}

void check_selection_scope_and_scoped_retry (string root) {
    var config = Path.build_filename (root, "config");
    var profile = Path.build_filename (root, "userdata", "1", "config");
    var loginusers = Path.build_filename (config, "loginusers.vdf");
    var localconfig = Path.build_filename (profile, "localconfig.vdf");
    assert (Utils.Filesystem.create_directory (config));
    assert (Utils.Filesystem.create_directory (profile));
    assert (Utils.Filesystem.modify_file (loginusers,
        "\"users\" { \"76561197960265729\" { \"PersonaName\" \"Fixture\" } }"));
    assert (Utils.Filesystem.modify_file (localconfig,
        "\"UserLocalConfigStore\" { \"Software\" { \"Valve\" { \"Steam\" { \"apps\" { } } } } }"));

    var first = new DeferredSteamLibrary (Models.Launcher.InstallationTypes.FLATPAK, root);
    var second = new DeferredSteamLibrary (Models.Launcher.InstallationTypes.SNAP, root);
    first.load_profile_library.begin ();
    second.load_profile_library.begin ();
    wait_for_library_load (first);
    wait_for_library_load (second);

    var page = new ProtonPlus.Widgets.Games.Box ();
    var viewport = new Adw.Clamp () {
        maximum_size = 430,
        tightening_threshold = 430,
        child = page
    };
    // A tiling compositor may give the test window less than its default
    // width. Let the fixture allocate a wide child inside that window.
    var scrolled = new Gtk.ScrolledWindow () {
        hscrollbar_policy = Gtk.PolicyType.EXTERNAL,
        vscrollbar_policy = Gtk.PolicyType.NEVER,
        child = viewport
    };
    var window = new Adw.Window () {
        default_width = 850,
        default_height = 650,
        content = scrolled
    };
    page.set_selected_launcher (first);
    window.present ();
    settle ();

    var status = find_widget (page, (widget) => widget is Adw.StatusPage && widget.get_mapped ()) as Adw.StatusPage;
    assert (status != null && status.get_description ().contains ("Steam (Flatpak)"));
    var retry = find_widget (page, (widget) =>
        widget is Gtk.Button && widget.get_mapped () && ((Gtk.Button) widget).label == "Retry") as Gtk.Button;
    assert (retry != null && page.get_controller_initial_focus () == retry);
    var copy = find_widget (page, (widget) =>
        widget is Gtk.Button && widget.get_mapped () && ((Gtk.Button) widget).label == "Copy Diagnostics") as Gtk.Button;
    assert (copy != null);
    bool copied = false;
    page.toast_sent.connect (() => { copied = true; });
    copy.clicked ();
    assert (copied);

    first.defer_load = true;
    retry.clicked ();
    assert (first.game_library_loading && !first.game_library_available);
    assert (status.get_title () == "Loading Steam games");
    page.set_selected_launcher (second);
    assert (status.get_description ().contains ("Steam (Snap)"));
    first.complete ();
    wait_for_library_load (first);
    assert (first.game_library_available && !second.game_library_available);
    assert (status.get_mapped () && status.get_description ().contains ("Steam (Snap)"));

    page.set_selected_launcher (first);
    settle ();
    assert (!status.get_mapped ());
    var select_all = find_widget (page, (widget) => widget is Gtk.CheckButton &&
        widget.get_mapped () && widget.get_tooltip_text () == "Select all visible games") as Gtk.CheckButton;
    var search = find_widget (page, (widget) => widget is Gtk.SearchEntry && widget.get_mapped ()) as Gtk.SearchEntry;
    var clear = find_widget (page, (widget) =>
        widget is Gtk.Button && ((Gtk.Button) widget).label == "Clear Selection") as Gtk.Button;
    var modify = find_widget (page, (widget) => widget is MassEditButton) as MassEditButton;
    assert (select_all != null && search != null && clear != null && modify != null);
    assert (!clear.get_mapped () && !modify.get_mapped ());
    select_all.active = true;
    search.set_text ("no games match this search");
    settle ();
    assert (!select_all.sensitive && clear.get_mapped () && modify.get_mapped ());
    var summary = find_widget (page, (widget) => widget is Gtk.Label && widget.get_mapped () &&
        ((Gtk.Label) widget).label == "2 games selected · 2 hidden by search or filters");
    assert (summary != null && page.get_controller_initial_focus () == modify);
    check_selection_footer_layout (page, summary, clear, modify, true);
    assert (find_widget (page, (widget) => widget is Gtk.ColumnView && widget.get_mapped ()) == null);

    assert (modify.grab_focus ());
    var clear_search = find_widget (page, (widget) => widget is Gtk.Button && widget.get_mapped () &&
        ((Gtk.Button) widget).label == "Clear Search");
    assert (clear_search != null);
    assert (modify.controller_focus_direction (modify, Utils.ControllerNavigationDirection.UP));
    assert (window.get_focus () == clear_search);

    viewport.maximum_size = 850;
    viewport.tightening_threshold = 850;
    viewport.width_request = 850;
    settle ();
    assert (page.get_width () >= 600);
    check_selection_footer_layout (page, summary, clear, modify, false);
    check_empty_wide_list (page, "No matching games", { "Game", "Prefix", "Tool" });

    var controller = find_widget (page, (widget) => widget.has_css_class ("games-sort-header-focus-proxy"));
    assert (controller is Utils.ControllerDirectionalFocus);
    var directional = (Utils.ControllerDirectionalFocus) controller;
    assert (directional.controller_focus_direction (search, Utils.ControllerNavigationDirection.DOWN));
    assert (window.get_focus () == controller);
    assert (directional.controller_focus_direction (controller, Utils.ControllerNavigationDirection.DOWN));
    assert (window.get_focus () == clear_search);

    clear.clicked ();
    assert (!clear.get_mapped () && !modify.get_mapped ());
    settle ();
    check_empty_wide_list (page, "No matching games", { "Game", "Prefix", "Tool", "Actions" });
    search.set_text ("");
    settle ();
    assert (!select_all.active && !modify.get_mapped ());

    select_all.active = true;
    search.set_text ("no games match this search");
    settle ();
    modify.clicked ();
    settle ();
    var affected = find_widget (page, (widget) => widget is Adw.ExpanderRow &&
        widget.get_mapped () && ((Adw.ExpanderRow) widget).title == "Affected games") as Adw.ExpanderRow;
    assert (affected != null);
    assert (find_widget (affected, (widget) => widget is Adw.ActionRow && ((Adw.ActionRow) widget).title == "Alpha") != null);
    assert (find_widget (affected, (widget) => widget is Adw.ActionRow && ((Adw.ActionRow) widget).title == "Bravo") != null);
    window.destroy ();

    assert (FileUtils.remove (localconfig) == 0);
    assert (FileUtils.remove (loginusers) == 0);
    assert (DirUtils.remove (profile) == 0);
    assert (DirUtils.remove (Path.get_dirname (profile)) == 0);
    assert (DirUtils.remove (Path.build_filename (root, "userdata")) == 0);
    assert (DirUtils.remove (config) == 0);
}

void load_autogen_library (Models.Launchers.ProtonAutogen launcher) {
    var loaded = new MainLoop ();
    launcher.load_profile_library.begin ((source, result) => {
        assert (launcher.load_profile_library.end (result));
        loaded.quit ();
    });
    loaded.run ();
}

void check_proton_autogen_game_edit (string root) throws Error {
    var profiles = Path.build_filename (root, ".config", "proton-autogen", "games");
    var proton = Path.build_filename (root, "compatibilitytools.d", "GE-Proton Latest", "proton");
    assert (DirUtils.create_with_parents (profiles, 0700) == 0);
    assert (DirUtils.create_with_parents (Path.get_dirname (proton), 0700) == 0);
    FileUtils.set_contents (proton, "fixture");
    assert (Posix.chmod (proton, 0700) == 0);
    string[] paths = {};
    foreach (var name in new string[] { "Alpha", "Bravo" }) {
        var path = Path.build_filename (profiles, name + ".json");
        paths += path;
        FileUtils.set_contents (path, "{\"name\":\"%s\",\"path\":\"%s/%s.exe\",\"proton\":\"\",\"future\":[1,2]}"
            .printf (name, root, name));
    }

    var steam = new Models.Launchers.Steam (Models.Launcher.InstallationTypes.SYSTEM);
    steam.directory = root;
    var launcher = new Models.Launchers.ProtonAutogen (steam, root, false);
    load_autogen_library (launcher);

    var page = new ProtonPlus.Widgets.Games.Box ();
    var viewport = new Adw.Clamp () {
        maximum_size = 850, tightening_threshold = 850, width_request = 850, child = page
    };
    var scrolled = new Gtk.ScrolledWindow () {
        hscrollbar_policy = Gtk.PolicyType.EXTERNAL, vscrollbar_policy = Gtk.PolicyType.NEVER, child = viewport
    };
    var window = new Adw.Window () { default_width = 850, default_height = 650, content = scrolled };
    page.set_selected_launcher (launcher);
    window.present ();
    settle ();
    var wide = find_widget (page, (widget) => widget is Gtk.ColumnView) as Gtk.ColumnView;
    assert (wide != null);
    assert (!((Gtk.ColumnViewColumn) wide.get_columns ().get_item (2)).visible);

    var select_all = find_widget (page, (widget) => widget is Gtk.CheckButton &&
        widget.get_tooltip_text () == "Select all visible games") as Gtk.CheckButton;
    assert (select_all != null);
    select_all.active = true;
    var modify = find_widget (page, (widget) => widget is MassEditButton) as MassEditButton;
    assert (modify != null && modify.get_mapped ());
    modify.clicked ();
    settle ();

    var change_tool = find_widget (page, (widget) => widget is Adw.SwitchRow &&
        ((Adw.SwitchRow) widget).title == "Change compatibility tool") as Adw.SwitchRow;
    assert (change_tool != null && change_tool.get_mapped ());
    change_tool.active = true;
    var choice = find_widget (page, (widget) => widget is CompatibilityToolRow) as CompatibilityToolRow;
    assert (choice != null && choice.get_mapped ());
    assert (choice.model.get_n_items () == 2);
    assert (((Models.CompatibilityTool) choice.model.get_item (0)).display_title == "Automatic");
    choice.selected = 1;
    var presentation = page.get_header_presentation ();
    assert (presentation != null);
    var apply = find_widget (presentation.end_actions[0], (widget) => widget is Gtk.Button &&
        ((Gtk.Button) widget).label == "Apply Changes") as Gtk.Button;
    assert (apply != null && apply.sensitive);
    apply.clicked ();
    settle ();
    assert (page.get_header_presentation () == null);
    foreach (var path in paths) {
        string updated;
        FileUtils.get_contents (path, out updated);
        assert (updated.contains ("\"proton\":\"GE-Proton Latest\",\"future\":[1,2]"));
        assert (FileUtils.remove (path) == 0);
    }

    var empty_launcher = new Models.Launchers.ProtonAutogen (steam, root, false);
    load_autogen_library (empty_launcher);
    page.set_selected_launcher (empty_launcher);
    settle ();
    check_empty_wide_list (page, "No games found", { "Game", "Tool", "Actions" });
    assert (find_widget (wide, (widget) => widget is Gtk.Label && widget.get_mapped () &&
        ((Gtk.Label) widget).label == "Prefix") == null);
    window.destroy ();
    assert (FileUtils.remove (proton) == 0);
    assert (DirUtils.remove (Path.get_dirname (proton)) == 0);
    assert (DirUtils.remove (Path.build_filename (root, "compatibilitytools.d")) == 0);
    assert (DirUtils.remove (profiles) == 0);
    assert (DirUtils.remove (Path.get_dirname (profiles)) == 0);
    assert (DirUtils.remove (Path.build_filename (root, ".config")) == 0);
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
    check_selection_scope_and_scoped_retry (root);
    try {
        check_proton_autogen_game_edit (root);
    } catch (Error error) {
        GLib.error ("%s", error.message);
    }
    assert (DirUtils.remove (root) == 0);
    return 0;
}
