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

void settle (uint milliseconds = 200) {
    var loop = new MainLoop ();
    Timeout.add (milliseconds, () => {
        loop.quit ();
        return Source.REMOVE;
    });
    loop.run ();
}

delegate bool LayoutReady ();

void wait_for_layout (LayoutReady ready) {
    int64 deadline = get_monotonic_time () + 5 * TimeSpan.SECOND;
    while (!ready () && get_monotonic_time () < deadline)
        settle (20);
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
    var replacement = fixture.collection.item_at (0);
    assert (replacement != null && replacement != first);
    wait_for_layout (() => fixture.view.get_selection_target ((!) first) == null
        && row.get_item () != first && selection.get_item () != first
        && fixture.view.get_selection_target ((!) replacement) is GameRow);
    assert (fixture.view.get_selection_target ((!) first) == null);
    assert (row.get_item () != first);
    assert (selection.get_item () != first);
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
    wait_for_layout (() => {
        Graphene.Rect summary_allocation, clear_allocation;
        if (!summary.compute_bounds (page, out summary_allocation))
            return false;
        if (!clear.compute_bounds (page, out clear_allocation))
            return false;
        bool stacked = summary_allocation.origin.y + summary_allocation.size.height <= clear_allocation.origin.y;
        return summary_allocation.size.height > 0 && clear_allocation.size.height > 0 && stacked == compact;
    });
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
    wait_for_layout (() => page.get_width () >= 600);
    assert (page.get_width () >= 600);
    check_selection_footer_layout (page, summary, clear, modify, false);
    check_empty_wide_list (page, "No matching games", { "Game", "Compatibility" });
    var toolbar = search.get_parent ();
    int steam_toolbar_height = toolbar.get_height ();
    assert (steam_toolbar_height > 0 && page.controller_can_open_filter ());

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
    check_empty_wide_list (page, "No matching games", { "Game", "Compatibility", "Actions" });
    search.set_text ("");
    settle ();
    assert (!select_all.active && !modify.get_mapped ());

    select_all.active = true;
    search.set_text ("no games match this search");
    settle ();
    modify.clicked ();
    settle ();
    var title = page.get_header_presentation ().title_widget;
    var selected = find_widget (title, widget => widget is Gtk.MenuButton) as Gtk.MenuButton;
    assert (selected != null && selected.label == "2 games selected");
    var menu_window = new Gtk.Window () { transient_for = window, child = title };
    menu_window.present ();
    selected.popup ();
    var dropdown = selected.get_popover ();
    wait_for_layout (() => dropdown.get_mapped ());
    assert (dropdown.get_mapped ());
    assert (find_widget (dropdown, widget => widget is Gtk.Label && ((Gtk.Label) widget).label == "Alpha") != null);
    assert (find_widget (dropdown, widget => widget is Gtk.Label && ((Gtk.Label) widget).label == "Bravo") != null);
    assert (find_widget (dropdown, widget => widget is Gtk.Label && ((Gtk.Label) widget).label == selected.label) == null);
    assert (find_widget (page, widget => widget is Adw.ExpanderRow && ((Adw.ExpanderRow) widget).title == "Affected games") == null);
    selected.popdown ();
    menu_window.set_child (null);
    menu_window.destroy ();

    var autogen = new Models.Launchers.ProtonAutogen (first, root, false);
    load_autogen_library (autogen);
    page.set_selected_launcher (autogen);
    settle ();
    assert (search.get_mapped () && !page.controller_can_open_filter ());
    assert (toolbar.get_height () == steam_toolbar_height);
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

class GamesSteamSession : Object, Services.SteamSessionBackend {
    public string root;
    public bool running = true;

    public string? get_boot_id () { return "games-presentation-fixture"; }
    public int64 get_monotonic_time_usec () { return 60 * TimeSpan.SECOND; }
    public int64 get_clock_ticks_per_second () { return 100; }
    public Services.NativeProcessQuery query_native_processes () {
        var processes = new Gee.ArrayList<Services.SteamProcessRecord> ();
        if (running)
            processes.add (new Services.SteamProcessRecord (101, Path.build_filename (root, "steam"), root, 100));
        return new Services.NativeProcessQuery (true, processes);
    }
    public Services.FlatpakProcessQuery query_flatpak_processes () {
        return new Services.FlatpakProcessQuery (true);
    }
    public Services.SteamDesktopEntry? find_desktop_entry (string? id) { return null; }
    public bool is_steamos_gaming_mode () { return false; }
}

Gtk.Button steam_editor_button (ProtonPlus.Widgets.Games.Box page, string text) {
    var button = find_widget (page, widget => widget is Gtk.Button && widget.get_mapped () &&
        (((Gtk.Button) widget).label == text || widget.get_tooltip_text () == text)) as Gtk.Button;
    assert (button != null);
    return button;
}

void pick_launch_option (Adw.Window window, ProtonPlus.Widgets.Games.Box page,
    string query, string title, string excluded_title) {
    var add = steam_editor_button (page, "Add launch option");
    assert (add.grab_focus () && ((Gtk.Widget) add).activate ());
    wait_for_layout (() => window.visible_dialog != null && window.visible_dialog.get_mapped ());
    var dialog = window.visible_dialog;
    var search = find_widget (dialog, widget => widget is Gtk.SearchEntry) as Gtk.SearchEntry;
    assert (search != null);
    WidgetMatches match = widget => widget is Adw.ActionRow && widget.get_mapped ()
        && ((Adw.ActionRow) widget).title == title;
    search.text = query;
    wait_for_layout (() => find_widget (dialog, match) != null
        && find_widget (dialog, widget => widget is Adw.ActionRow && widget.get_mapped ()
            && ((Adw.ActionRow) widget).title == excluded_title) == null);
    var choice = find_widget (dialog, match);
    if (choice == null || !choice.grab_focus () || !choice.activate ())
        error ("Could not select launch option '%s' in the picker.", title);
    wait_for_layout (() => window.visible_dialog == null);
    assert (window.visible_dialog == null);
}

void check_saved_launch_options (string path, string alpha, string bravo) throws Error {
    string contents;
    FileUtils.get_contents (path, out contents);
    var document = Utils.VDF.VdfParser.parse_document (contents);
    var apps = document?.root.get_child ("UserLocalConfigStore")?.get_child ("Software")
        ?.get_child ("Valve")?.get_child ("Steam")?.get_child ("apps");
    assert (apps != null);
    assert (apps.get_child ("1")?.get_child ("LaunchOptions")?.value == alpha);
    assert (apps.get_child ("2")?.get_child ("LaunchOptions")?.value == bravo);
}

void check_launch_option_runtime_switch (string root) throws Error {
    var model = new ListStore (typeof (Models.CompatibilityTool));
    var paths = new Gee.ArrayList<string> ();
    string[] tools = { "Proton-CachyOS fixture", "GE-Proton fixture", "Plain Proton fixture" };
    foreach (var title in tools) {
        var path = Path.build_filename (root, title);
        assert (DirUtils.create (path, 0700) == 0);
        paths.add (path);
        FileUtils.set_contents (Path.build_filename (path, "proton"), title == tools[2]
            ? "import os\n" : "self.check_environment('LOW_LATENCY_LAYER', 'lowlatencylayer')\n");
        model.append (new Models.CompatibilityTool (title, title, path, Models.CompatibilityToolRuntimeKind.PROTON));
    }

    var steam = new Models.Launchers.Steam (Models.Launcher.InstallationTypes.SNAP);
    steam.directory = root;
    var game = new Models.Games.Steam.non_steam (100, "Fixture game", "", tools[0], steam);
    game.is_native = false;
    var view = new MassEditView (new Gtk.MenuButton ());
    var expression = new Gtk.PropertyExpression (typeof (Models.CompatibilityTool), null, "display-title");
    view.load ({ new GameListItem (game) }, model, expression, false, false);
    var window = new Adw.Window () { default_width = 850, default_height = 650, content = view };
    window.present ();
    var editor = find_widget (view, widget => widget is LaunchOptionsEditor.Box) as LaunchOptionsEditor.Box;
    var selector = find_widget (view, widget => widget is CompatibilityToolRow) as CompatibilityToolRow;
    var warning = find_widget (view, widget => widget.has_css_class ("launch-options-blocker"));
    var apply = find_widget (view, widget => widget is Gtk.Button
        && ((Gtk.Button) widget).label == "Apply Changes") as Gtk.Button;
    assert (editor != null && selector != null && warning != null && apply != null);
    assert (((Models.CompatibilityTool) selector.selected_item).internal_title == tools[0]);
    uint ge_index = Gtk.INVALID_LIST_POSITION;
    uint plain_index = Gtk.INVALID_LIST_POSITION;
    for (uint i = 0; i < selector.model.get_n_items (); i++) {
        var tool = (Models.CompatibilityTool) selector.model.get_item (i);
        if (tool.internal_title == tools[1])
            ge_index = i;
        if (tool.internal_title == tools[2])
            plain_index = i;
    }
    assert (ge_index != Gtk.INVALID_LIST_POSITION && plain_index != Gtk.INVALID_LIST_POSITION);

    var option = "Vulkan Anti-Lag 2 layer";
    const string command = "LOW_LATENCY_LAYER=1 %command%";
    var supported = "Requires a Proton build with the Vulkan low-latency layer.";
    const string unavailable = "The selected Proton build does not expose the low-latency Vulkan layer.";
    var row = find_widget (editor, widget => widget is Adw.ActionRow && ((Adw.ActionRow) widget).title == option) as Adw.ActionRow;
    assert (row != null);
    editor.set_text (command);
    wait_for_layout (() => row.subtitle.contains (supported));
    assert (row.subtitle.contains (supported));
    editor.set_text ("");
    var add = find_widget (view, widget => widget is Gtk.Button
        && ((Gtk.Button) widget).label == "Add launch option") as Gtk.Button;
    assert (add != null);
    add.clicked ();
    wait_for_layout (() => window.visible_dialog != null && window.visible_dialog.get_mapped ());
    var choice = find_widget (window.visible_dialog, widget => widget is Adw.ActionRow
        && ((Adw.ActionRow) widget).title == option);
    assert (choice != null && choice.activate ());
    wait_for_layout (() => window.visible_dialog == null);
    assert (row.visible && !warning.visible && apply.sensitive);

    selector.selected = ge_index;
    assert (!warning.has_css_class ("launch-options-blocker-error"));
    wait_for_layout (() => row.subtitle.contains (supported));
    assert (row.visible && row.subtitle.contains (supported) && !warning.visible && apply.sensitive);
    assert (editor.prepare_write ().launch_line == command);

    selector.selected = plain_index;
    wait_for_layout (() => warning.has_css_class ("launch-options-blocker-error"));
    assert (row.visible && row.subtitle.contains (unavailable) && row.has_css_class ("launch-option-incompatible"));
    assert (warning.visible && warning.has_css_class ("launch-options-blocker-error") && !apply.sensitive);
    assert (((Gtk.Label) warning.get_first_child ()).label == "“Vulkan Anti-Lag 2 layer” is unavailable with the selected compatibility tool.");
    var remove_option = find_widget (row, widget => widget is Gtk.Button
        && widget.tooltip_text == "Remove Vulkan Anti-Lag 2 layer") as Gtk.Button;
    assert (remove_option != null && remove_option.sensitive);
    remove_option.clicked ();
    assert (!row.visible && !warning.visible && apply.sensitive);

    editor.set_text (command);
    selector.selected = ge_index;
    wait_for_layout (() => row.subtitle.contains (supported));
    selector.selected = plain_index;
    wait_for_layout (() => warning.has_css_class ("launch-options-blocker-error"));
    assert (row.visible && warning.visible && warning.has_css_class ("launch-options-blocker-error"));
    assert (apply.sensitive && editor.prepare_write ().launch_line == command && game.launch_options == "");
    window.destroy ();
    foreach (var path in paths) {
        assert (FileUtils.remove (Path.build_filename (path, "proton")) == 0);
        assert (DirUtils.remove (path) == 0);
    }
}

void check_steam_compatibility_editor (string parent) throws Error {
    var root = Path.build_filename (parent, "steam-editor");
    var config = Path.build_filename (root, "config", "config.vdf");
    var login = Path.build_filename (root, "config", "loginusers.vdf");
    var localconfig = Path.build_filename (root, "userdata", "1", "config", "localconfig.vdf");
    assert (DirUtils.create_with_parents (Path.get_dirname (config), 0700) == 0);
    assert (DirUtils.create_with_parents (Path.get_dirname (localconfig), 0700) == 0);
    const string config_contents = """
        "InstallConfigStore" { "Software" { "Valve" { "Steam" { "CompatToolMapping" {
            "1" { "name" "removed-proton" "config" "" "priority" "250" }
        } } } } }
    """;
    var bravo_source = "BRAVO=\"keep spacing\" %command% --tag --tag --long=" + string.nfill (2400, 'x');
    var launch_contents = """
        "UserLocalConfigStore" { "Software" { "Valve" { "Steam" { "apps" {
            "1" { "LaunchOptions" "PROTON_ENABLE_HDR=1 ALPHA=1 %%command%%" }
        "2" { "LaunchOptions" %s }
        } } } } }
    """.printf (Utils.VDF.VdfDocument.quote (bravo_source));
    FileUtils.set_contents (config, config_contents);
    FileUtils.set_contents (login, """"users" { "76561197960265729" { "PersonaName" "Fixture" } }""");
    FileUtils.set_contents (localconfig, launch_contents);

    var backend = new GamesSteamSession () { root = root };
    var restart_store = new Services.SteamRestartStateStore (Path.build_filename (root, "restart-state.json"));
    var lifecycle = new Services.SteamLifecycle (new Services.SteamSessionService (backend), restart_store);
    var launcher = new DeferredSteamLibrary (Models.Launcher.InstallationTypes.SNAP, root) { defer_load = true };
    launcher.load_profile_library.begin ();
    launcher.complete ();
    wait_for_library_load (launcher);
    assert (launcher.game_library_available);
    var alpha = (Models.Games.Steam) launcher.games.nth_data (0);
    var bravo = (Models.Games.Steam) launcher.games.nth_data (1);
    var long_name = "Bravo and the Surprisingly Long Adventure Through Compatibility Country";
    bravo.name = long_name;
    launcher.update_game_compatibility_tool_mapping (alpha.appid, "removed-proton");
    alpha.apply_effective_compatibility_tool ("removed-proton");
    var tool_path = Path.build_filename (root, "fixture-proton");
    var dxvk = Path.build_filename (tool_path, "files", "lib", "wine", "dxvk", "x86_64-windows");
    assert (DirUtils.create_with_parents (dxvk, 0700) == 0);
    var binary = new StringBuilder ("MZ");
    binary.append_c ('\0');
    binary.append ("DXVK_HDR");
    binary.append_c ('\0');
    FileUtils.set_contents (Path.build_filename (dxvk, "dxgi.dll"), binary.str, (ssize_t) binary.len);
    launcher.register_compatibility_tool (new Models.CompatibilityTool ("Fixture Proton", "fixture-proton",
        tool_path, Models.CompatibilityToolRuntimeKind.PROTON));

    var page = new ProtonPlus.Widgets.Games.Box ();
    var viewport = new Adw.Clamp () {
        maximum_size = 850, tightening_threshold = 850, width_request = 850, child = page
    };
    var window = new Adw.Window () {
        default_width = 850, default_height = 720,
        content = new Gtk.ScrolledWindow () {
            hscrollbar_policy = Gtk.PolicyType.EXTERNAL, vscrollbar_policy = Gtk.PolicyType.NEVER, child = viewport
        }
    };
    page.set_selected_launcher (launcher);
    window.present ();
    WidgetMatches compatibility_text = widget => widget is GameCompatibilityCell && widget.get_mapped ();
    WidgetMatches picker = widget => widget is CompatibilityToolRow && widget.get_mapped ();
    WidgetMatches bulk_switch = widget => widget is Adw.SwitchRow && widget.get_mapped () &&
        ((Adw.SwitchRow) widget).title == "Change compatibility tool";
    wait_for_layout (() => find_widget (page, compatibility_text) != null);
    var compatibility = find_widget (page, compatibility_text);
    assert (compatibility != null && compatibility.get_first_child () is Gtk.Label);
    assert (!compatibility.get_focusable () && !compatibility.get_first_child ().get_focusable ());
    var wide_title = find_widget (page, widget => widget is GameTitleCell && widget.get_mapped () &&
        ((GameTitleCell) widget).get_item ().game == alpha) as GameTitleCell;
    var alpha_actions = find_widget (page, widget => widget is GameActions && widget.get_mapped () &&
        ((GameActions) widget).get_item ().game == alpha);
    assert (alpha_actions != null);
    var game_menu = find_widget (alpha_actions, widget => widget is Gtk.MenuButton) as Gtk.MenuButton;
    assert (game_menu != null);
    game_menu.popup ();
    var popover = game_menu.get_popover ();
    wait_for_layout (() => popover.get_mapped ());
    var anti_cheat = find_widget (popover, widget => widget is Gtk.Label &&
        ((Gtk.Label) widget).get_text () == "Anti-Cheat: Loading…");
    var proton_db = find_widget (popover, widget => widget is Gtk.Label &&
        ((Gtk.Label) widget).get_text () == "Open ProtonDB");
    Graphene.Rect anti_cheat_bounds, proton_db_bounds;
    assert (anti_cheat != null && proton_db != null);
    assert (anti_cheat.compute_bounds (popover, out anti_cheat_bounds));
    assert (proton_db.compute_bounds (popover, out proton_db_bounds));
    assert (Math.fabs (anti_cheat_bounds.origin.x - proton_db_bounds.origin.x) <= 1);
    game_menu.popdown ();
    assert (wide_title != null && wide_title.grab_focus () && wide_title.controller_activate (wide_title));
    wait_for_layout (() => find_widget (page, picker) != null);
    var choice = find_widget (page, picker) as CompatibilityToolRow;
    assert (choice != null && choice.title == "Version");
    var compatibility_group = choice.get_ancestor (typeof (Adw.PreferencesGroup)) as Adw.PreferencesGroup;
    assert (compatibility_group != null && compatibility_group.title == "Compatibility tool");
    var header_title = page.get_header_presentation ().title_widget;
    assert (find_widget (header_title, widget => widget is Gtk.Label && ((Gtk.Label) widget).label == "Alpha") != null);
    assert (((Models.CompatibilityTool) choice.get_selected_item ()).internal_title == "removed-proton");
    var add_option = steam_editor_button (page, "Add launch option");
    assert (page.get_controller_initial_focus () == add_option);
    assert (find_widget (page, bulk_switch) == null);
    WidgetMatches technical_details = widget => widget is Adw.ExpanderRow &&
        ((Adw.ExpanderRow) widget).title == "Technical details";
    assert (find_widget (page, technical_details) == null);
    var apply = steam_editor_button (page, "Apply Changes");
    var reset = steam_editor_button (page, "Reset Changes");
    assert (!apply.sensitive && !reset.sensitive);
    choice.selected = 0;
    assert (apply.sensitive && reset.sensitive);
    choice.selected = choice.model.get_n_items () - 1;
    assert (!apply.sensitive && !reset.sensitive);
    var preview = steam_editor_button (page, "Command preview") as Gtk.ToggleButton;
    assert (preview != null && !preview.active);
    var clear_options = steam_editor_button (page, "Clear Launch Options");
    var current_options = find_widget (page, widget => widget is Adw.PreferencesGroup && widget.get_mapped () &&
        ((Adw.PreferencesGroup) widget).title == "Launch options") as Adw.PreferencesGroup;
    assert (current_options != null && current_options.header_suffix == add_option);
    var arguments = find_widget (current_options, widget => widget is Adw.ExpanderRow &&
        ((Adw.ExpanderRow) widget).title == "Custom game arguments") as LaunchOptionsEditor.LaunchOptionArgumentList;
    assert (arguments != null && !arguments.expanded);
    assert (arguments.get_parent ().get_ancestor (typeof (Adw.ExpanderRow)) == null);
    var original_arguments = new Variant.strv (arguments.get_raw_arguments ());
    wait_for_layout (() => {
        Graphene.Rect group_allocation, options_allocation;
        if (!compatibility_group.compute_bounds (page, out group_allocation))
            return false;
        if (!current_options.compute_bounds (page, out options_allocation))
            return false;
        return group_allocation.size.height > 0
            && group_allocation.origin.y + group_allocation.size.height <= options_allocation.origin.y;
    });
    Graphene.Rect compatibility_bounds, options_bounds, clear_bounds, reset_bounds, preview_bounds, apply_bounds;
    assert (compatibility_group.compute_bounds (page, out compatibility_bounds));
    assert (current_options.compute_bounds (page, out options_bounds));
    assert (clear_options.compute_bounds (page, out clear_bounds));
    assert (reset.compute_bounds (page, out reset_bounds));
    assert (preview.compute_bounds (page, out preview_bounds));
    assert (apply.compute_bounds (page, out apply_bounds));
    assert (compatibility_bounds.origin.y + compatibility_bounds.size.height <= options_bounds.origin.y);
    assert (Math.fabs (preview_bounds.origin.x - options_bounds.origin.x) <= 1);
    assert (clear_bounds.origin.x - preview_bounds.origin.x - preview_bounds.size.width > 6);
    assert (Math.fabs (reset_bounds.origin.x - clear_bounds.origin.x - clear_bounds.size.width - 6) <= 1);
    assert (Math.fabs (apply_bounds.origin.x - reset_bounds.origin.x - reset_bounds.size.width - 6) <= 1);
    assert (clear_options.sensitive);
    choice.selected = 0;
    clear_options.clicked ();
    assert (!clear_options.sensitive && reset.sensitive && apply.sensitive);
    reset.clicked ();
    assert (clear_options.sensitive && !reset.sensitive && !apply.sensitive);
    assert (((Models.CompatibilityTool) choice.get_selected_item ()).internal_title == "removed-proton");
    assert (find_widget (page, widget => widget is Gtk.Label &&
        ((Gtk.Label) widget).get_text () == "PROTON_ENABLE_HDR=1 ALPHA=1 %command%") != null);
    assert (original_arguments.equal (new Variant.strv (arguments.get_raw_arguments ())));
    var legacy = steam_editor_button (page, "Remove Legacy custom-Proton HDR");
    assert (legacy.get_mapped () && legacy.is_sensitive ());
    legacy.clicked ();
    assert (apply.sensitive && !preview.active);
    preview.active = true;
    assert (find_widget (page, widget => widget is Gtk.Label &&
        ((Gtk.Label) widget).get_text () == "ALPHA=1 %command%") != null);
    assert (apply.get_mapped () && apply.grab_focus () && page.get_width () == 850);
    for (uint index = 0; index < choice.model.get_n_items (); index++) {
        if (((Models.CompatibilityTool) choice.model.get_item (index)).internal_title == "fixture-proton")
            choice.selected = index;
    }
    assert (((Models.CompatibilityTool) choice.get_selected_item ()).internal_title == "fixture-proton");
    pick_launch_option (window, page, "Wine DLL overrides", "Wine DLL overrides", "Skip launcher");
    var dlls = find_widget (page, widget => widget is Adw.ExpanderRow && widget.get_mapped () &&
        ((Adw.ExpanderRow) widget).title == "Wine DLL overrides") as Adw.ExpanderRow;
    assert (dlls != null && !dlls.expanded && !dlls.show_enable_switch);
    assert (dlls.get_parent ().get_ancestor (typeof (Adw.ExpanderRow)) == null);
    assert (find_widget (dlls, widget => widget != dlls && widget is Adw.ExpanderRow) == null);
    var dll_remove = steam_editor_button (page, "Remove Wine DLL overrides");
    assert (dll_remove.get_ancestor (typeof (Adw.ExpanderRow)) == dlls);
    dlls.expanded = true;
    var dll_name = find_widget (dlls, widget => widget is Adw.EntryRow &&
        ((Adw.EntryRow) widget).title == "Custom DLL name") as Adw.EntryRow;
    assert (dll_name != null);
    dll_name.text = "fixture_dll";
    dlls.expanded = false;
    assert (find_widget (page, widget => widget is Gtk.Label && ((Gtk.Label) widget).get_text ().contains ("fixture_dll=")) != null);
    dll_remove.clicked ();
    assert (!dlls.visible);
    assert (arguments.get_mapped () && !arguments.expanded);
    var argument_add = steam_editor_button (page, "Add custom argument");
    var arguments_remove = steam_editor_button (page, "Remove Custom game arguments");
    assert (argument_add.get_parent () == arguments_remove.get_parent ());
    assert (find_widget (arguments, widget => widget is Adw.ActionRow
        && ((Adw.ActionRow) widget).title == "Add custom argument") == null);
    argument_add.clicked ();
    var argument = find_widget (arguments, widget => widget is Adw.EntryRow
        && ((Adw.EntryRow) widget).title == "Argument" && ((Adw.EntryRow) widget).text == "") as Adw.EntryRow;
    assert (arguments.expanded && argument != null);
    wait_for_layout (() => window.get_focus ()?.get_ancestor (typeof (Adw.EntryRow)) == argument);
    assert (window.get_focus ()?.get_ancestor (typeof (Adw.EntryRow)) == argument);
    var argument_remove = find_widget (argument, widget => widget is Gtk.Button
        && widget.get_tooltip_text () == "Remove argument") as Gtk.Button;
    assert (argument_remove != null);
    argument_remove.clicked ();
    arguments.expanded = false;
    assert (original_arguments.equal (new Variant.strv (arguments.get_raw_arguments ())));
    pick_launch_option (window, page, "PulseAudio latency", "PulseAudio latency", "Skip launcher");
    var latency = find_widget (page, widget => widget is Adw.ActionRow && widget.get_mapped () &&
        ((Adw.ActionRow) widget).title == "PulseAudio latency");
    assert (latency != null && latency.get_ancestor (typeof (Adw.ExpanderRow)) == null);
    var latency_entry = find_widget (latency, widget => widget is Gtk.Entry && widget.get_mapped ()) as Gtk.Entry;
    assert (latency_entry != null && latency_entry.text == "90");
    wait_for_layout (() => window.get_focus ()?.get_ancestor (typeof (Gtk.Entry)) == latency_entry);
    assert (window.get_focus ()?.get_ancestor (typeof (Gtk.Entry)) == latency_entry);
    assert (find_widget (latency, widget => widget is Gtk.Switch) == null);
    var latency_remove = steam_editor_button (page, "Remove PulseAudio latency");
    assert (latency_remove.get_ancestor (typeof (Adw.ActionRow)) == latency);
    latency_remove.clicked ();
    assert (!latency.visible);
    pick_launch_option (window, page, "DXVK_HDR", "DXVK HDR", "Skip launcher");
    var hdr_row = find_widget (page, widget => widget is Adw.ActionRow && widget.get_mapped () &&
        ((Adw.ActionRow) widget).title == "DXVK HDR");
    assert (hdr_row != null);
    var hdr_remove = steam_editor_button (page, "Remove DXVK HDR");
    assert (find_widget (hdr_row, widget => widget is Gtk.Switch && widget.get_mapped ()) == null);
    assert (hdr_remove.get_ancestor (typeof (Adw.ActionRow)) == hdr_row);
    assert (hdr_row.get_ancestor (typeof (Adw.ExpanderRow)) == null);
    assert (!current_options.has_css_class ("launch-options-empty"));
    var alpha_command = "ALPHA=1 DXVK_HDR=1 %command%";
    assert (find_widget (page, widget => widget is Gtk.Label && widget.get_mapped () &&
        ((Gtk.Label) widget).get_text () == alpha_command) != null);
    assert (apply.sensitive);
    apply.clicked ();
    wait_for_layout (() => page.get_header_presentation () == null);
    assert (alpha.compatibility_tool == "fixture-proton" && alpha.launch_options == alpha_command);
    assert (bravo.launch_options == bravo_source);
    var saved = restart_store.load ();
    assert (saved.error == null && saved.records.size == 2);
    var staged_command = false;
    foreach (var record in saved.records) {
        if (record.receipt.kind == Models.SteamChangeKind.STEAM_GAME_LAUNCH_OPTIONS_CHANGED) {
            var intent = record.receipt.configuration_intent;
            assert (intent != null && intent.field_id == "1" && intent.desired == alpha_command);
            staged_command = true;
        }
    }
    assert (staged_command);
    check_saved_launch_options (localconfig, "PROTON_ENABLE_HDR=1 ALPHA=1 %command%", bravo_source);

    viewport.maximum_size = 430;
    viewport.tightening_threshold = 430;
    viewport.width_request = 430;
    wait_for_layout (() => find_widget (page, widget => widget is GameRow && widget.get_mapped ()) != null);
    var row = find_widget (page, widget => widget is GameRow && widget.get_mapped () &&
        ((GameRow) widget).get_item ().game == alpha) as GameRow;
    assert (row != null && row.grab_focus ());
    assert (find_widget (row, widget => widget is Gtk.Label && ((Gtk.Label) widget).label == "1") == null);
    var bravo_row = find_widget (page, widget => widget is GameRow && widget.get_mapped () &&
        ((GameRow) widget).get_item ().game == bravo);
    assert (bravo_row != null);
    var bravo_title = find_widget (bravo_row, widget => widget is Gtk.Label &&
        ((Gtk.Label) widget).label == long_name) as Gtk.Label;
    assert (bravo_title != null && bravo_title.wrap && bravo_title.get_width () <= bravo_row.get_width ());
    compatibility = find_widget (row, compatibility_text);
    assert (compatibility != null && compatibility.get_first_child () is Gtk.Label);
    assert (!compatibility.get_focusable () && !compatibility.get_first_child ().get_focusable ());
    var title = find_widget (row, widget => widget is Gtk.Label && ((Gtk.Label) widget).label == alpha.name);
    var actions = find_widget (row, widget => widget is GameActions && widget.get_mapped ());
    assert (title != null && actions != null);
    Graphene.Rect title_bounds, compatibility_bounds_compact, action_bounds;
    assert (title.compute_bounds (row, out title_bounds));
    assert (compatibility.get_first_child ().compute_bounds (row, out compatibility_bounds_compact));
    assert (actions.compute_bounds (row, out action_bounds));
    assert (title_bounds.origin.x == compatibility_bounds_compact.origin.x);
    assert (title_bounds.origin.x == action_bounds.origin.x);
    assert (row.controller_activate (row));
    wait_for_layout (() => find_widget (page, picker) != null);
    choice = find_widget (page, picker) as CompatibilityToolRow;
    assert (choice != null);
    assert (find_widget (page, technical_details) == null);
    choice.selected = 0;
    steam_editor_button (page, "Apply Changes").clicked ();
    wait_for_layout (() => page.get_header_presentation () == null);
    assert (alpha.compatibility_tool == "Default" && alpha.launch_options == alpha_command);
    assert (bravo.launch_options == bravo_source);
    assert (lifecycle.restarts.pending_count () == 2);

    var collection = find_widget (page, widget => widget is GameRow && widget.get_mapped () &&
        ((GameRow) widget).get_item ().game == alpha) as GameRow;
    assert (collection != null);
    collection.get_item ().selected = true;
    var modify_one = find_widget (page, widget => widget is MassEditButton && widget.get_mapped ()) as MassEditButton;
    assert (modify_one != null);
    modify_one.clicked ();
    wait_for_layout (() => find_widget (page, bulk_switch) != null);
    assert (find_widget (page, picker) == null && find_widget (page, technical_details) == null);
    assert (find_widget (page.get_header_presentation ().title_widget, widget =>
        widget is Gtk.MenuButton && ((Gtk.MenuButton) widget).label == "1 game selected") != null);
    assert (page.controller_navigate_back ());
    wait_for_layout (() => page.get_header_presentation () == null);

    var target = launcher.get_steam_restart_target ();
    var alpha_batch_command = alpha_command + " -skip-launcher";
    var bravo_batch_command = bravo_source + " -skip-launcher";
    string contents;
    for (var opt_in = 0; opt_in < 3; opt_in++) {
        var select_all = find_widget (page, widget => widget is Gtk.CheckButton && widget.get_mapped () &&
            widget.get_tooltip_text () == "Select all visible games") as Gtk.CheckButton;
        assert (select_all != null);
        select_all.active = true;
        var modify = find_widget (page, widget => widget is MassEditButton && widget.get_mapped ()) as MassEditButton;
        assert (modify != null);
        modify.clicked ();
        wait_for_layout (() => find_widget (page, bulk_switch) != null);
        var change_tool = find_widget (page, bulk_switch) as Adw.SwitchRow;
        assert (change_tool != null && !change_tool.active && find_widget (page, picker) == null);
        assert (find_widget (page, technical_details) == null);
        assert (find_widget (page.get_header_presentation ().title_widget, widget =>
            widget is Gtk.MenuButton && ((Gtk.MenuButton) widget).label == "2 games selected") != null);
        apply = steam_editor_button (page, "Apply Changes");
        reset = steam_editor_button (page, "Reset Changes");
        clear_options = steam_editor_button (page, "Clear Launch Options");
        assert (!apply.sensitive && !reset.sensitive);
        if (opt_in == 0) {
            assert (find_widget (page, widget => widget.get_mapped () && widget is Gtk.Label &&
                ((Gtk.Label) widget).get_text () == "Launch option changes apply to 2 games.") != null);
            pick_launch_option (window, page, "Skip launcher", "Skip launcher", "Custom wrapper");
            assert (apply.sensitive && reset.sensitive);
            steam_editor_button (page, "Remove Skip launcher").clicked ();
            assert (!apply.sensitive && !reset.sensitive);
            pick_launch_option (window, page, "Skip launcher", "Skip launcher", "Custom wrapper");
            preview = steam_editor_button (page, "Command preview") as Gtk.ToggleButton;
            assert (preview != null && !preview.active);
            preview.active = true;
            var expected_preview = "Alpha\n" + alpha_batch_command + "\n\n" + long_name +
                "\n" + bravo_batch_command;
            WidgetMatches preview_text = widget => widget is Gtk.Label && widget.get_mapped ()
                && ((Gtk.Label) widget).get_text () == expected_preview;
            wait_for_layout (() => find_widget (page, preview_text) != null);
            var preview_label = find_widget (page, preview_text);
            assert (preview_label != null);
            var preview_scroll = preview_label.get_ancestor (typeof (Gtk.ScrolledWindow)) as Gtk.ScrolledWindow;
            assert (preview_scroll != null);
            var adjustment = preview_scroll.vadjustment;
            wait_for_layout (() => adjustment.upper > adjustment.page_size && adjustment.page_size > 0);
            assert (adjustment.upper > adjustment.page_size && adjustment.page_size > 0);
            assert (preview_scroll.get_height () <= 144);
            int minimum, natural;
            page.measure (Gtk.Orientation.HORIZONTAL, -1, out minimum, out natural, null, null);
            assert (minimum <= 430 && page.get_width () <= 430);
            assert (apply.get_mapped () && apply.grab_focus ());
        } else if (opt_in == 1) {
            clear_options.clicked ();
            assert (!clear_options.sensitive && reset.sensitive);
            reset.clicked ();
            assert (clear_options.sensitive && !apply.sensitive && !reset.sensitive);
            clear_options.clicked ();
        } else {
            assert (!clear_options.sensitive);
            var empty_options = find_widget (page, widget => widget.get_mapped () && widget is Gtk.Label &&
                ((Gtk.Label) widget).get_text () == "No launch options configured yet.");
            assert (empty_options != null);
            var options_group = empty_options.get_ancestor (typeof (Adw.PreferencesGroup));
            assert (options_group != null && options_group.has_css_class ("launch-options-empty"));
            assert (find_widget (options_group, widget => widget is Gtk.ListBox && widget.has_css_class ("boxed-list")) != null);
            change_tool.active = true;
            choice = find_widget (page, picker) as CompatibilityToolRow;
            assert (choice != null && choice.model.get_n_items () == 2);
            choice.selected = 1;
        }
        assert (apply.sensitive);
        apply.clicked ();
        wait_for_layout (() => page.get_header_presentation () == null);
        var expected = opt_in < 2 ? "Default" : "fixture-proton";
        assert (alpha.compatibility_tool == expected && bravo.compatibility_tool == expected);
        assert (alpha.launch_options == (opt_in == 0 ? alpha_batch_command : ""));
        assert (bravo.launch_options == (opt_in == 0 ? bravo_batch_command : ""));
        if (opt_in == 0) {
            assert (lifecycle.configuration.reconcile_target (target).result ==
                Services.SteamConfigurationMutationResult.STAGED);
            FileUtils.get_contents (config, out contents);
            assert (contents == config_contents);
            FileUtils.get_contents (localconfig, out contents);
            assert (contents == launch_contents);
            backend.running = false;
            assert (lifecycle.configuration.reconcile_target (target).result ==
                Services.SteamConfigurationMutationResult.CHANGED);
            check_saved_launch_options (localconfig, alpha_batch_command, bravo_batch_command);
            backend.running = true;
            assert (lifecycle.configuration.verify_target_after_session (target));
        }
    }

    check_saved_launch_options (localconfig, alpha_batch_command, bravo_batch_command);
    assert (lifecycle.restarts.pending_count () == 4);
    backend.running = false;
    assert (lifecycle.configuration.reconcile_target (target).result ==
        Services.SteamConfigurationMutationResult.CHANGED);
    FileUtils.get_contents (config, out contents);
    assert (contents.contains ("fixture-proton") && !contents.contains ("removed-proton"));
    FileUtils.get_contents (localconfig, out contents);
    assert (!contents.contains ("LaunchOptions"));
    window.destroy ();
    lifecycle.stop ();
    var cleanup = new MainLoop ();
    Utils.Filesystem.delete_directory.begin (root, (object, result) => {
        assert (Utils.Filesystem.delete_directory.end (result));
        cleanup.quit ();
    });
    cleanup.run ();
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
    var launcher = new Models.Launchers.ProtonAutogen (steam, root, true);
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
    assert (((Gtk.ColumnViewColumn) wide.get_columns ().get_item (2)).title == "Compatibility");
    WidgetMatches alpha_play_button = (widget) => widget is Gtk.Button && widget.get_mapped () &&
        ((Gtk.Button) widget).icon_name == "media-playback-start-symbolic" &&
        widget.get_tooltip_text () == "Launch Alpha";
    assert (find_widget (wide, alpha_play_button) != null);

    viewport.maximum_size = 430;
    viewport.tightening_threshold = 430;
    viewport.width_request = 430;
    Gtk.Widget? compact_row = null;
    wait_for_layout (() => {
        compact_row = find_widget (page, (widget) => widget is GameRow && widget.get_mapped ());
        return compact_row != null && find_widget (compact_row, alpha_play_button) != null;
    });
    assert (compact_row != null && find_widget (compact_row, alpha_play_button) != null);

    viewport.maximum_size = 850;
    viewport.tightening_threshold = 850;
    viewport.width_request = 850;
    wait_for_layout (() => wide.get_mapped () && page.get_width () >= 600);
    assert (wide.get_mapped () && page.get_width () >= 600);

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

    var profiles_only_launcher = new Models.Launchers.ProtonAutogen (steam, root, false);
    load_autogen_library (profiles_only_launcher);
    page.set_selected_launcher (profiles_only_launcher);
    settle ();
    assert (find_widget (page, alpha_play_button) == null);

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
    check_empty_wide_list (page, "No games found", { "Game", "Compatibility", "Actions" });
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

class PresentationLutrisBackend : Object, Services.LutrisBackend {
    public Services.LutrisSystemTools get_system_tools (bool flatpak) {
        return Services.LutrisSystemTools.CHECKED | Services.LutrisSystemTools.MANGOHUD;
    }

    public bool is_closed (bool flatpak) {
        return true;
    }

    public Gee.List<Models.CompatibilityTool> get_runners (bool flatpak, string? custom_path) {
        var tools = new Gee.ArrayList<Models.CompatibilityTool> ();
        tools.add (new Models.CompatibilityTool ("Fixture Wine", "wine-fixture", "", Models.CompatibilityToolRuntimeKind.WINE));
        tools.add (new Models.CompatibilityTool ("Fixture Proton", "proton-fixture", "", Models.CompatibilityToolRuntimeKind.PROTON));
        return tools;
    }

    public Subprocess? spawn (string[] argv) {
        return null;
    }
}

class DeferredLutrisLibrary : Models.Launchers.Lutris {
    SourceFunc? pending_callback;

    public DeferredLutrisLibrary (Services.LutrisConfigurationService service) {
        base (Models.Launcher.InstallationTypes.FLATPAK, service);
    }

    public override async bool load_game_library () {
        pending_callback = load_game_library.callback;
        yield;
        return yield base.load_game_library ();
    }

    public void complete () {
        Idle.add ((owned) pending_callback);
    }
}

void check_lutris_library_states (string root) throws Error {
    var data = Path.build_filename (root, ".var", "app", "net.lutris.Lutris", "data", "lutris");
    assert (DirUtils.create_with_parents (data, 0700) == 0);
    var db_file = Path.build_filename (data, "pga.db");
    FileUtils.set_contents (db_file, "invalid database");
    var service = new Services.LutrisConfigurationService (true, root, root, root, new PresentationLutrisBackend ());
    var launcher = new DeferredLutrisLibrary (service);
    var page = new ProtonPlus.Widgets.Games.Box ();
    var window = new Adw.Window () { default_width = 850, default_height = 650, content = page };
    page.set_selected_launcher (launcher);
    window.present ();
    settle ();
    var status = find_widget (page, (widget) => widget is Adw.StatusPage && widget.get_mapped ()) as Adw.StatusPage;
    assert (status != null && status.title == "Loading Lutris games");

    launcher.complete ();
    wait_for_layout (() => status.title == "Lutris games couldn’t be loaded");
    assert (status.description.contains ("Lutris (Flatpak)"));
    var retry = find_widget (status, (widget) =>
        widget is Gtk.Button && widget.get_mapped () && ((Gtk.Button) widget).label == "Retry") as Gtk.Button;
    assert (retry != null);
    assert (FileUtils.remove (db_file) == 0);
    Sqlite.Database db;
    assert (Sqlite.Database.open (db_file, out db) == Sqlite.OK);
    assert (db.exec ("CREATE TABLE games (id INTEGER, name TEXT, runner TEXT, directory TEXT, configpath TEXT, installed INTEGER, slug TEXT, installed_at INTEGER)") == Sqlite.OK);
    retry.clicked ();
    assert (status.title == "Loading Lutris games");
    launcher.complete ();
    wait_for_layout (() => find_widget (page, (widget) => widget is Adw.StatusPage && widget.get_mapped () &&
        ((Adw.StatusPage) widget).title == "No games found") != null);

    assert (db.exec ("INSERT INTO games (id, name, runner, directory, configpath, installed) VALUES (10, 'Read-only Wine game', 'wine', '', 'missing', 1)") == Sqlite.OK);
    launcher.load_profile_library.begin ();
    launcher.complete ();
    WidgetMatches configuration_unavailable = (widget) => widget is Gtk.Label && widget.get_mapped () &&
        ((Gtk.Label) widget).label == "Configuration unavailable";
    wait_for_layout (() => find_widget (page, configuration_unavailable) != null);
    var play = find_widget (page, (widget) => widget is Gtk.Button && widget.get_mapped () &&
        widget.get_tooltip_text () == "Launch Read-only Wine game");
    assert (play != null);
    assert (find_widget (page, (widget) => widget is Gtk.CheckButton && widget.get_mapped ()) == null);
    var table = find_widget (page, (widget) => widget is Gtk.ColumnView && widget.get_mapped ()) as Gtk.ColumnView;
    var list = find_widget (page, (widget) => widget is Gtk.ListView && widget.get_mapped ()) as Gtk.ListView;
    if (table != null)
        table.activate (0);
    else {
        assert (list != null);
        list.activate (0);
    }
    settle ();
    assert (page.get_header_presentation () == null);
    var games_dir = Path.build_filename (data, "games");
    var config = Path.build_filename (games_dir, "editable.yml");
    assert (DirUtils.create_with_parents (games_dir, 0700) == 0);
    var saved_config = "# Keep this comment in the game config\nwine:\n  version: missing\n  dxvk: false\n" +
        "system:\n  env: {EXISTING: \"  a=b # literal  \"}\n";
    FileUtils.set_contents (config, saved_config);
    assert (db.exec ("UPDATE games SET configpath = 'editable' WHERE id = 10") == Sqlite.OK);
    launcher.load_profile_library.begin ();
    launcher.complete ();
    wait_for_layout (() => !launcher.game_library_loading);
    settle ();
    if (table != null)
        table.activate (0);
    else
        list.activate (0);
    wait_for_layout (() => page.get_header_presentation () != null);
    var choice = find_widget (page, (widget) => widget is CompatibilityToolRow && widget.get_mapped ()) as CompatibilityToolRow;
    assert (choice != null && choice.title == "Wine or Proton version");
    assert (choice.model.get_n_items () == 4);
    assert (((Models.CompatibilityTool) choice.get_selected_item ()).internal_title == "missing");
    assert (find_widget (page, (widget) => widget is Adw.SwitchRow && widget.get_mapped () &&
        ((Adw.SwitchRow) widget).title == "Change compatibility tool") == null);
    assert (find_widget (page, (widget) => widget is Adw.SwitchRow && widget.get_mapped () &&
        ((Adw.SwitchRow) widget).title == "Override command prefix") != null);
    var apply = find_widget (page, (widget) => widget is Gtk.Button && widget.get_mapped () &&
        ((Gtk.Button) widget).label == "Apply Changes") as Gtk.Button;
    assert (apply != null && !apply.sensitive);
    var reset = find_widget (page, widget => widget is Gtk.Button &&
        widget.tooltip_text == "Reset Changes") as Gtk.Button;
    var clear = find_widget (page, widget => widget is Gtk.Button &&
        widget.tooltip_text == "Clear Environment Variables") as Gtk.Button;
    assert (clear.get_mapped () && reset.get_mapped () && clear.sensitive && !reset.sensitive);
    assert (find_widget (page, widget => widget is Gtk.ToggleButton && widget.get_mapped () &&
        ((Gtk.ToggleButton) widget).label == "Command preview") == null);
    clear.clicked ();
    assert (apply.sensitive && reset.sensitive && !clear.sensitive);
    string updated;
    FileUtils.get_contents (config, out updated);
    assert (updated == saved_config);
    reset.clicked ();
    assert (!apply.sensitive && clear.sensitive && !reset.sensitive);
    uint wine = Gtk.INVALID_LIST_POSITION;
    uint proton = Gtk.INVALID_LIST_POSITION;
    for (uint i = 0; i < choice.model.get_n_items (); i++) {
        var id = ((Models.CompatibilityTool) choice.model.get_item (i)).internal_title;
        if (id == "wine-fixture")
            wine = i;
        else if (id == "proton-fixture")
            proton = i;
    }
    assert (wine != Gtk.INVALID_LIST_POSITION && proton != Gtk.INVALID_LIST_POSITION);
    choice.selected = wine;
    var dxvk = find_widget (page, (widget) => widget is Adw.ComboRow &&
        ((Adw.ComboRow) widget).title == "Enable DXVK") as Adw.ComboRow;
    var vkd3d = find_widget (page, (widget) => widget is Adw.ComboRow &&
        ((Adw.ComboRow) widget).title == "Enable VKD3D") as Adw.ComboRow;
    var dxvk_version = find_widget (page, (widget) => widget is Adw.ComboRow &&
        ((Adw.ComboRow) widget).title == "DXVK version");
    var environment = find_widget (page, (widget) => widget is Adw.ExpanderRow &&
        ((Adw.ExpanderRow) widget).title == "Environment variables") as Adw.ExpanderRow;
    environment.expanded = true;
    var presets = find_widget (environment, widget => widget is Adw.ComboRow &&
        ((Adw.ComboRow) widget).title == "Add preset") as Adw.ComboRow;
    assert (presets.model.get_n_items () == 2);
    var runtime = find_widget (page, widget => widget is Adw.ComboRow &&
        ((Adw.ComboRow) widget).title == "Disable Lutris Runtime") as Adw.ComboRow;
    var libraries = find_widget (page, widget => widget is Adw.ComboRow &&
        ((Adw.ComboRow) widget).title == "Prefer system libraries");
    var mangohud = find_widget (page, widget => widget is Adw.ComboRow &&
        ((Adw.ComboRow) widget).title == "MangoHud") as Adw.ComboRow;
    var gamemode = find_widget (page, widget => widget is Adw.ComboRow &&
        ((Adw.ComboRow) widget).title == "Feral GameMode") as Adw.ComboRow;
    assert (mangohud.subtitle == "Available in this Lutris installation");
    assert (gamemode.subtitle == "Unavailable in this Lutris installation");
    assert (libraries.visible);
    runtime.selected = 1;
    assert (!libraries.visible);
    runtime.selected = 0;
    assert (libraries.visible);
    assert (dxvk.visible && vkd3d.visible && !dxvk_version.visible && environment.visible);
    dxvk.selected = 1;
    assert (dxvk_version.visible);
    choice.selected = proton;
    assert (dxvk.visible && !vkd3d.visible && !dxvk_version.visible && environment.visible);
    assert (runtime.visible && libraries.visible && mangohud.visible && gamemode.visible);
    assert (presets.model.get_n_items () == 3);
    choice.selected = wine;
    assert (vkd3d.visible && dxvk_version.visible);
    dxvk.selected = 2;
    assert (presets.model.get_n_items () == 2);
    presets.selected = 1;
    var insert_preset = find_widget (presets, widget => widget is Gtk.Button &&
        widget.tooltip_text == "Insert preset") as Gtk.Button;
    assert (insert_preset.sensitive);
    insert_preset.clicked ();
    assert (!presets.visible);
    var add_variable = find_widget (environment, widget => widget is Gtk.Button &&
        widget.tooltip_text == "Add variable") as Gtk.Button;
    add_variable.clicked ();
    assert (!apply.sensitive);
    var name = find_widget (environment, widget => widget is Gtk.Entry &&
        ((Gtk.Entry) widget).placeholder_text == "Name" && ((Gtk.Entry) widget).text == "") as Gtk.Entry;
    assert (name != null);
    name.text = "EXISTING";
    assert (!apply.sensitive);
    name.text = "EXTRA";
    var value = find_widget (name.get_parent (), widget => widget is Gtk.Entry &&
        ((Gtk.Entry) widget).placeholder_text == "Value") as Gtk.Entry;
    value.text = "word=two";
    assert (apply.sensitive);
    apply.clicked ();
    wait_for_layout (() => page.get_header_presentation () == null);
    FileUtils.get_contents (config, out updated);
    assert (updated.has_prefix ("# Keep this comment in the game config\nwine:\n  version: \"wine-fixture\"\n  dxvk: false\n"));
    assert (updated.contains ("\"EXISTING\":\"  a=b # literal  \""));
    assert (updated.contains ("\"DXVK_LOG_LEVEL\":\"none\""));
    assert (updated.contains ("\"EXTRA\":\"word=two\""));

    if (table != null)
        table.activate (0);
    else
        list.activate (0);
    wait_for_layout (() => page.get_header_presentation () != null);
    environment.expanded = true;
    assert (find_widget (environment, widget => widget is Gtk.Entry && ((Gtk.Entry) widget).text == "word=two") != null);
    var extra = find_widget (environment, widget => widget is Gtk.Entry && ((Gtk.Entry) widget).text == "EXTRA");
    var remove_variable = find_widget (extra.get_parent (), widget => widget is Gtk.Button &&
        widget.tooltip_text == "Remove environment variable") as Gtk.Button;
    remove_variable.clicked ();
    assert (find_widget (environment, widget => widget is Gtk.Entry && ((Gtk.Entry) widget).text == "EXTRA") == null);
    clear.clicked ();
    apply.clicked ();
    wait_for_layout (() => page.get_header_presentation () == null);
    FileUtils.get_contents (config, out updated);
    assert (updated.contains ("version: \"wine-fixture\"") && !updated.contains ("env:"));

    var empty_launcher = new Models.Launchers.HeroicGamesLauncher (
        Models.Launcher.InstallationTypes.SYSTEM, root, root);
    launcher.load_profile_library.begin ();
    page.set_selected_launcher (empty_launcher);
    page.set_selected_launcher (launcher);
    page.set_selected_launcher (empty_launcher);
    launcher.complete ();
    wait_for_layout (() => !launcher.game_library_loading && !empty_launcher.game_library_loading);
    assert (find_widget (page, widget => widget is Adw.StatusPage && widget.get_mapped () &&
        ((Adw.StatusPage) widget).title == "No games found") != null);
    assert (find_widget (page, configuration_unavailable) == null);

    page.set_selected_launcher (launcher);
    assert (launcher.game_library_loading);
    window.destroy ();
    launcher.complete ();
    wait_for_layout (() => !launcher.game_library_loading);
    assert (!page.get_mapped () && page.get_header_presentation () == null);
    assert (FileUtils.remove (config) == 0);
    assert (DirUtils.remove (games_dir) == 0);

    assert (FileUtils.remove (db_file) == 0);
    while (data != root) {
        assert (DirUtils.remove (data) == 0);
        data = Path.get_dirname (data);
    }
}

class PresentationFaugusBackend : Object, Services.FaugusBackend {
    public string[] command;
    public bool closed = true;

    public bool is_closed (bool flatpak) {
        return closed;
    }

    public bool host_path_exists (string path) {
        return false;
    }

    public Gee.List<Models.CompatibilityTool> installed_runners (bool flatpak) {
        return new Gee.ArrayList<Models.CompatibilityTool> ();
    }

    public Subprocess? spawn (string[] argv, string working_directory) {
        command = argv;
        return null;
    }
}

void check_faugus_library_and_editor (string root) throws Error {
    var data = Path.build_filename (root, "faugus-launcher");
    var flatpak_data = Path.build_filename (root, ".var", "app", Models.Launchers.FaugusLauncher.FLATPAK_ID,
        "data", "faugus-launcher");
    assert (DirUtils.create_with_parents (data, 0700) == 0);
    assert (DirUtils.create_with_parents (flatpak_data, 0700) == 0);
    var native_file = Path.build_filename (data, "games.json");
    var flatpak_file = Path.build_filename (flatpak_data, "games.json");
    FileUtils.set_contents (native_file, """[{"gameid":"native","title":"Native Fixture","runner":"Steam"}]""");
    FileUtils.set_contents (flatpak_file, "{malformed");
    var backend = new PresentationFaugusBackend ();
    var native_service = new Services.FaugusConfigurationService (false, root, root, root, backend);
    var flatpak_service = new Services.FaugusConfigurationService (true, root, root, root, backend);
    var native = new Models.Launchers.FaugusLauncher (Models.Launcher.InstallationTypes.SYSTEM,
        root, root, root, root, root, native_service);
    var flatpak = new Models.Launchers.FaugusLauncher (Models.Launcher.InstallationTypes.FLATPAK,
        root, root, root, root, root, flatpak_service);
    var page = new ProtonPlus.Widgets.Games.Box ();
    var window = new Adw.Window () { default_width = 850, default_height = 650, content = page };

    page.set_selected_launcher (native);
    window.present ();
    assert (native.game_library_loading);
    WidgetMatches native_row = (widget) => widget is Gtk.Button && widget.get_mapped () &&
        widget.get_tooltip_text () == "Launch Native Fixture";
    wait_for_layout (() => find_widget (page, native_row) != null);
    page.set_selected_launcher (flatpak);
    assert (flatpak.game_library_loading);
    var status = find_widget (page, (widget) => widget is Adw.StatusPage && widget.get_mapped ()) as Adw.StatusPage;
    assert (status != null && status.title == "Loading Faugus Launcher games");
    wait_for_layout (() => status.title == "Faugus Launcher games couldn’t be loaded");
    assert (status.description.contains ("Faugus Launcher (Flatpak)") && status.description.contains (flatpak_file));
    assert (find_widget (page, native_row) == null);

    var retry = find_widget (status, (widget) => widget is Gtk.Button && widget.get_mapped () &&
        ((Gtk.Button) widget).label == "Retry") as Gtk.Button;
    assert (retry != null);
    FileUtils.set_contents (flatpak_file, "[]");
    retry.clicked ();
    wait_for_layout (() => find_widget (page, (widget) => widget is Adw.StatusPage && widget.get_mapped () &&
        ((Adw.StatusPage) widget).title == "No games found") != null);

    FileUtils.set_contents (flatpak_file, """
[
    {"gameid":"other","title":"Another Fixture","runner":"Steam"},
    {"gameid":"selected","title":"Flatpak Fixture","runner":"Removed Runner"}
]
""");
    flatpak.load_profile_library.begin ();
    WidgetMatches flatpak_row = (widget) => widget is Gtk.Button && widget.get_mapped () &&
        widget.get_tooltip_text () == "Launch Flatpak Fixture";
    wait_for_layout (() => find_widget (page, flatpak_row) != null);
    var search = find_widget (page, (widget) => widget is Gtk.SearchEntry && widget.get_mapped ()) as Gtk.SearchEntry;
    assert (search != null);
    search.set_text ("flatpak");
    wait_for_layout (() => find_widget (page, (widget) => widget is Gtk.Button && widget.get_mapped () &&
        widget.get_tooltip_text () == "Launch Another Fixture") == null);
    assert (find_widget (page, (widget) => widget is Gtk.CheckButton && widget.get_mapped ()) == null);
    var play = find_widget (page, flatpak_row) as Gtk.Button;
    assert (play != null);
    play.clicked ();
    wait_for_layout (() => backend.command != null);
    assert (string.joinv (" ", backend.command) == "flatpak run io.github.Faugus.faugus-launcher --game selected");

    var table = find_widget (page, (widget) => widget is Gtk.ColumnView && widget.get_mapped ()) as Gtk.ColumnView;
    if (table != null)
        table.activate (0);
    else {
        var list = find_widget (page, (widget) => widget is Gtk.ListView && widget.get_mapped ()) as Gtk.ListView;
        assert (list != null);
        list.activate (0);
    }
    wait_for_layout (() => page.get_header_presentation () != null);
    var choice = find_widget (page, (widget) => widget is CompatibilityToolRow && widget.get_mapped ()) as CompatibilityToolRow;
    assert (choice != null);
    var saved = choice.get_selected_item () as Models.CompatibilityTool;
    assert (saved != null && !saved.is_assignable && saved.internal_title == "Removed Runner");
    assert (find_widget (page, widget => widget is Adw.ExpanderRow && widget.get_mapped () &&
        ((Adw.ExpanderRow) widget).title == "Technical details") == null);
    assert (find_widget (page, (widget) => widget is Adw.SwitchRow && widget.get_mapped ()) == null);
    var apply = find_widget (page.get_header_presentation ().end_actions[0], (widget) =>
        widget is Gtk.Button && ((Gtk.Button) widget).label == "Apply Changes") as Gtk.Button;
    assert (apply != null && !apply.sensitive);
    choice.selected = 0;
    assert (((Models.CompatibilityTool) choice.get_selected_item ()).internal_title == "Default");
    assert (apply.sensitive);
    backend.closed = false;
    apply.clicked ();
    wait_for_layout (() => window.get_visible_dialog () is ProtonPlus.Widgets.Main.ErrorDialog);
    var failed_save = window.get_visible_dialog () as ProtonPlus.Widgets.Main.ErrorDialog;
    assert (failed_save != null && failed_save.get_heading () == "Could Not Change the Runner");
    assert (page.get_header_presentation () != null && apply.sensitive);
    var parser = new Json.Parser ();
    parser.load_from_file (flatpak_file);
    assert (parser.get_root ().get_array ().get_object_element (1).get_string_member ("runner") == "Removed Runner");
    failed_save.force_close ();
    backend.closed = true;
    apply.clicked ();
    wait_for_layout (() => page.get_header_presentation () == null);

    parser.load_from_file (flatpak_file);
    assert (parser.get_root ().get_array ().get_object_element (1).get_string_member ("runner") == "Default");
    wait_for_layout (() => find_widget (page, (widget) => widget is Gtk.Label && widget.get_mapped () &&
        ((Gtk.Label) widget).label == "Inherited (Proton-CachyOS Latest)") != null);
    window.destroy ();
    assert (FileUtils.remove (native_file) == 0 && DirUtils.remove (data) == 0);
    assert (FileUtils.remove (flatpak_file) == 0);
    while (flatpak_data != root) {
        assert (DirUtils.remove (flatpak_data) == 0);
        flatpak_data = Path.get_dirname (flatpak_data);
    }
}

class PresentationHeroicBackend : Object {
    public string[] command;
    public bool fail;

    public Subprocess? spawn (string[] argv) throws Error {
        command = argv;
        if (fail)
            throw new IOError.FAILED ("Heroic launch fixture failed");
        return null;
    }
}

void check_heroic_library_states_and_actions (string home) throws Error {
    var app_id = Models.Launchers.HeroicGamesLauncher.FLATPAK_ID;
    var native_root = Path.build_filename (home, "heroic", "gog_store");
    var flatpak_root = Path.build_filename (home, ".var", "app", app_id, "config", "heroic");
    var flatpak_gog = Path.build_filename (flatpak_root, "gog_store");
    assert (DirUtils.create_with_parents (native_root, 0700) == 0);
    assert (DirUtils.create_with_parents (flatpak_gog, 0700) == 0);
    var native_file = Path.build_filename (native_root, "installed.json");
    var flatpak_file = Path.build_filename (flatpak_gog, "installed.json");
    FileUtils.set_contents (native_file, """{"installed":[{"appName":"shared", "title":"Native Heroic Fixture", "platform":"linux"}]}""");
    FileUtils.set_contents (flatpak_file, "{");

    var backend = new PresentationHeroicBackend ();
    var service = new Services.HeroicLaunchService (false, Path.build_filename (home, "applications"), backend.spawn);
    var native = new Models.Launchers.HeroicGamesLauncher (Models.Launcher.InstallationTypes.SYSTEM, home, home, service);
    var flatpak = new Models.Launchers.HeroicGamesLauncher (Models.Launcher.InstallationTypes.FLATPAK, home, home, service);
    var page = new ProtonPlus.Widgets.Games.Box ();
    var window = new Adw.Window () { default_width = 850, default_height = 650, content = page };
    window.present ();
    page.set_selected_launcher (flatpak);
    var status = find_widget (page, (widget) => widget is Adw.StatusPage &&
        widget.get_visible () && ((Adw.StatusPage) widget).title == "Loading Heroic Games Launcher games") as Adw.StatusPage;
    assert (status != null);
    wait_for_layout (() => status.get_mapped () && status.title == "Heroic Games Launcher games couldn’t be loaded");
    assert (status.get_mapped () && status.description.contains ("Heroic Games Launcher (Flatpak)"));
    var retry = find_widget (status, (widget) => widget is Gtk.Button && widget.get_mapped () &&
        ((Gtk.Button) widget).label == "Retry") as Gtk.Button;
    assert (retry != null);

    FileUtils.set_contents (flatpak_file, """{"installed":[]}""");
    retry.clicked ();
    WidgetMatches empty = (widget) => widget is Adw.StatusPage && widget.get_mapped () &&
        ((Adw.StatusPage) widget).title == "No games found";
    wait_for_layout (() => find_widget (page, empty) != null);
    assert (find_widget (page, empty) != null);

    FileUtils.set_contents (flatpak_file, """{"installed":[
        {"appName":"shared", "title":"Flatpak Heroic Fixture", "install_path":"%s", "platform":"windows"},
        {"appName":"other", "title":"Other Game", "platform":"linux"}
    ]}""".printf (flatpak_root));
    FileUtils.set_contents (Path.build_filename (flatpak_root, "config.json"), """{"defaultSettings":{
        "wineVersion":{"name":"Fixture Wine", "type":"wine"}, "winePrefix":"%s"
    }}""".printf (flatpak_root));

    WidgetMatches native_play = (widget) => widget is Gtk.Button && widget.get_mapped () &&
        widget.get_tooltip_text () == "Launch Native Heroic Fixture";
    WidgetMatches flatpak_play = (widget) => widget is Gtk.Button && widget.get_mapped () &&
        widget.get_tooltip_text () == "Launch Flatpak Heroic Fixture";
    WidgetMatches other_play = (widget) => widget is Gtk.Button && widget.get_mapped () &&
        widget.get_tooltip_text () == "Launch Other Game";
    page.set_selected_launcher (native);
    wait_for_layout (() => find_widget (page, native_play) != null);
    assert (find_widget (page, native_play) != null && find_widget (page, flatpak_play) == null);
    page.set_selected_launcher (flatpak);
    wait_for_layout (() => find_widget (page, flatpak_play) != null);
    assert (find_widget (page, flatpak_play) != null && find_widget (page, native_play) == null);
    assert (find_widget (page, other_play) != null);
    var search = find_widget (page, (widget) => widget is Gtk.SearchEntry && widget.get_mapped ()) as Gtk.SearchEntry;
    assert (search != null);
    search.set_text ("flatpak");
    wait_for_layout (() => find_widget (page, other_play) == null);
    assert (find_widget (page, other_play) == null);
    assert (find_widget (page, (widget) => widget is Gtk.CheckButton && widget.get_mapped ()) == null);
    var actions = find_widget (page, (widget) => widget is Gtk.MenuButton && widget.get_mapped () &&
        widget.get_tooltip_text () == "Game Actions") as Gtk.MenuButton;
    assert (actions != null);
    var menu = ((Gtk.PopoverMenu) actions.get_popover ()).get_menu_model ();
    assert (menu.get_n_items () == 2);
    assert (menu.get_item_attribute_value (0, Menu.ATTRIBUTE_ACTION, VariantType.STRING).get_string () ==
        "game.open-install-directory");
    assert (menu.get_item_attribute_value (1, Menu.ATTRIBUTE_ACTION, VariantType.STRING).get_string () ==
        "game.open-prefix-directory");

    var table = find_widget (page, (widget) => widget is Gtk.ColumnView && widget.get_mapped ()) as Gtk.ColumnView;
    if (table != null)
        table.activate (0);
    else {
        var list = find_widget (page, (widget) => widget is Gtk.ListView && widget.get_mapped ()) as Gtk.ListView;
        assert (list != null);
        list.activate (0);
    }
    settle ();
    assert (page.get_header_presentation () == null);
    var play = find_widget (page, flatpak_play) as Gtk.Button;
    assert (play != null);
    backend.fail = true;
    play.clicked ();
    wait_for_layout (() => window.get_visible_dialog () is ProtonPlus.Widgets.Main.ErrorDialog);
    var dialog = window.get_visible_dialog () as ProtonPlus.Widgets.Main.ErrorDialog;
    assert (dialog != null && dialog.get_heading () == "Game Launch Failed");
    assert (string.joinv (" ", backend.command) ==
        "flatpak run %s heroic://launch?appName=shared&runner=gog".printf (app_id));
    dialog.force_close ();
    window.destroy ();
}

class PresentationBottlesCli : Object, Services.BottlesCliBackend {
    public string bottles = "{";
    public string prefix;
    public string[] dispatched = {};
    public bool fail_launch;

    public PresentationBottlesCli (string prefix) {
        this.prefix = prefix;
    }

    public string query (string[] argv) throws Error {
        var command = string.joinv ("\n", argv);
        const string route = "flatpak\nrun\n--command=bottles-cli\ncom.usebottles.bottles\n";
        assert (command.has_prefix (route));
        switch (command.substring (route.length)) {
        case "--json\nlist\nbottles":
            return bottles;
        case "run\n--help":
            return "usage: bottles-cli run [--program-id PROGRAM_ID]";
        case "info\nbottles-path":
            return "";
        case "--json\nprograms\n--bottle=Fixture Bottle":
            return """[{"name":"Bottles Game","id":"stable-id","path":"C:\\Game Files\\Game.exe",
                "arguments":"--saved fixture"}]""";
        case "--json\nprograms\n--bottle=Second Bottle":
            return """[{"name":"Bottles Game","path":"C:\\Game.exe"},
                {"name":"Bottles Game","path":"C:\\Another.exe"}]""";
        default:
            throw new IOError.NOT_FOUND ("Fixture bottle unavailable");
        }
    }

    public Subprocess? launch (string[] argv) throws Error {
        dispatched = argv.copy ();
        if (fail_launch)
            throw new IOError.FAILED ("Bottles fixture dispatch failed");
        return null;
    }
}

void check_bottles_library_states_and_actions (string root) throws Error {
    var prefix = Path.build_filename (root, "bottles-fixture");
    var install = Path.build_filename (prefix, "drive_c", "Game Files");
    assert (DirUtils.create_with_parents (install, 0700) == 0);
    var backend = new PresentationBottlesCli (prefix);
    var launcher = new Models.Launchers.Bottles (Models.Launcher.InstallationTypes.FLATPAK,
        new Services.BottlesLibrary (true, false, backend));
    var page = new ProtonPlus.Widgets.Games.Box ();
    var viewport = new Adw.Clamp () { maximum_size = 1000, tightening_threshold = 1000, width_request = 1000, child = page };
    var window = new Adw.Window () { default_width = 1100, default_height = 650,
        content = new Gtk.ScrolledWindow () {
            hscrollbar_policy = Gtk.PolicyType.EXTERNAL, vscrollbar_policy = Gtk.PolicyType.NEVER, child = viewport
        } };
    window.present ();
    page.set_selected_launcher (launcher);
    var status = find_widget (page, widget => widget is Adw.StatusPage &&
        ((Adw.StatusPage) widget).title == "Loading Bottles games") as Adw.StatusPage;
    assert (status != null);
    wait_for_layout (() => status.get_mapped () && status.title == "Bottles games couldn’t be loaded");
    assert (status.get_mapped () && status.description.contains ("Bottles (Flatpak)"));
    var retry = find_widget (status, widget => widget is Gtk.Button && ((Gtk.Button) widget).label == "Retry") as Gtk.Button;
    assert (retry != null);

    backend.bottles = "{}";
    retry.clicked ();
    WidgetMatches empty = widget => widget is Adw.StatusPage && widget.get_mapped () &&
        ((Adw.StatusPage) widget).title == "No games found";
    wait_for_layout (() => find_widget (page, empty) != null);
    assert (find_widget (page, empty) != null);

    backend.bottles = """{
        "Fixture Bottle":{"Path":"%s","Custom_Path":true,"Runner":"soda-fixture"},
        "Second Bottle":{},
        "Unavailable Bottle":{}
    }""".printf (backend.prefix);
    launcher.load_profile_library.begin ();
    WidgetMatches play_button = widget => widget is Gtk.Button && widget.get_mapped () &&
        widget.get_tooltip_text () == "Launch Bottles Game (Fixture Bottle)";
    wait_for_layout (() => find_widget (page, play_button) != null);
    var banner = find_widget (page, widget => widget is Adw.Banner && ((Adw.Banner) widget).revealed) as Adw.Banner;
    assert (banner != null && banner.title == "Some Bottles programs couldn’t be loaded.");
    WidgetMatches second_bottle = widget => widget is Gtk.Label && widget.get_mapped () &&
        ((Gtk.Label) widget).label == "Second Bottle";
    assert (find_widget (page, second_bottle) != null);
    assert (find_widget (page, widget => widget is Gtk.Label && widget.get_mapped () &&
        ((Gtk.Label) widget).label == "soda-fixture") != null);
    assert (find_widget (page, widget => widget is Gtk.Button && widget.get_mapped () &&
        widget.get_tooltip_text () == "Launch Bottles Game (Second Bottle)") == null);
    assert (find_widget (page, widget => widget is Gtk.CheckButton && widget.get_mapped ()) == null);

    foreach (var width in new int[] { 1000, 500 }) {
        bool narrow = width < 700;
        viewport.maximum_size = width;
        viewport.tightening_threshold = width;
        viewport.width_request = width;
        WidgetMatches visible_view = widget => widget.get_mapped () &&
            (narrow ? widget is Gtk.ListView : widget is Gtk.ColumnView);
        wait_for_layout (() => find_widget (page, visible_view) != null);
        var view = find_widget (page, visible_view);
        assert (view != null);
        var launch = find_widget (view, play_button);
        assert (launch != null && launch.grab_focus ());
        var cell = launch.get_parent () as GameActions;
        assert (cell != null && cell.controller_focus_direction (launch, Utils.ControllerNavigationDirection.DOWN));
        LayoutReady second_has_focus = () => {
            var focused = window.get_focus ();
            if (narrow)
                return focused is GameRow && ((GameRow) focused).get_item ().game.library_context == "Second Bottle";
            return focused is GameTitleCell && ((GameTitleCell) focused).get_item ().game.library_context == "Second Bottle";
        };
        wait_for_layout (second_has_focus);
        assert (second_has_focus ());
    }

    var search = find_widget (page, widget => widget is Gtk.SearchEntry && widget.get_mapped ()) as Gtk.SearchEntry;
    assert (search != null);
    search.set_text ("second bottle");
    wait_for_layout (() => find_widget (page, play_button) == null);
    assert (find_widget (page, play_button) == null && find_widget (page, second_bottle) != null);
    assert (find_widget (page, widget => widget is Gtk.MenuButton && widget.get_mapped () &&
        widget.get_tooltip_text () == "Game Actions") == null);

    search.set_text ("fixture bottle");
    wait_for_layout (() => find_widget (page, play_button) != null);
    var actions = find_widget (page, widget => widget is Gtk.MenuButton && widget.get_mapped () &&
        widget.get_tooltip_text () == "Game Actions") as Gtk.MenuButton;
    assert (actions != null);
    var menu = ((Gtk.PopoverMenu) actions.get_popover ()).get_menu_model ();
    assert (menu.get_n_items () == 2);
    assert (menu.get_item_attribute_value (0, Menu.ATTRIBUTE_ACTION, VariantType.STRING).get_string () ==
        "game.open-install-directory");
    assert (menu.get_item_attribute_value (1, Menu.ATTRIBUTE_ACTION, VariantType.STRING).get_string () ==
        "game.open-prefix-directory");
    var table = find_widget (page, widget => widget is Gtk.ColumnView && widget.get_mapped ()) as Gtk.ColumnView;
    if (table != null)
        table.activate (0);
    else {
        var list = find_widget (page, widget => widget is Gtk.ListView && widget.get_mapped ()) as Gtk.ListView;
        assert (list != null);
        list.activate (0);
    }
    settle ();
    assert (page.get_header_presentation () == null);

    var play = find_widget (page, play_button) as Gtk.Button;
    assert (play != null);
    backend.fail_launch = true;
    play.clicked ();
    wait_for_layout (() => window.get_visible_dialog () is ProtonPlus.Widgets.Main.ErrorDialog);
    var dialog = window.get_visible_dialog () as ProtonPlus.Widgets.Main.ErrorDialog;
    assert (dialog != null && dialog.get_heading () == "Game Launch Failed");
    assert (string.joinv ("\n", backend.dispatched) ==
        "flatpak\nrun\n--command=bottles-cli\ncom.usebottles.bottles\nrun\n--bottle=Fixture Bottle\n--program-id=stable-id");
    dialog.force_close ();
    window.destroy ();
    assert (DirUtils.remove (install) == 0);
    assert (DirUtils.remove (Path.get_dirname (install)) == 0);
    assert (DirUtils.remove (prefix) == 0);
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
    if ("--lutris" in args) {
        try {
            check_lutris_library_states (root);
        } catch (Error error) {
            GLib.error ("%s", error.message);
        }
        assert (DirUtils.remove (root) == 0);
        return 0;
    }
    check_binding_selection_and_activation (root);
    check_pending_focus_cleanup (root);
    check_selection_scope_and_scoped_retry (root);
    try {
        check_steam_compatibility_editor (root);
        check_launch_option_runtime_switch (root);
        check_proton_autogen_game_edit (root);
        check_lutris_library_states (root);
        check_faugus_library_and_editor (root);
        check_bottles_library_states_and_actions (root);
        var heroic_home = Path.build_filename (root, "heroic-home");
        check_heroic_library_states_and_actions (heroic_home);
        var cleanup = new MainLoop ();
        Utils.Filesystem.delete_directory.begin (heroic_home, (object, result) => {
            assert (Utils.Filesystem.delete_directory.end (result));
            cleanup.quit ();
        });
        cleanup.run ();
    } catch (Error error) {
        GLib.error ("%s", error.message);
    }
    assert (DirUtils.remove (root) == 0);
    return 0;
}
