using ProtonPlus.Widgets.Games.LaunchOptionsEditor;

void check_rows (Gtk.Widget widget, ref int count) {
    if (widget is Adw.ComboRow) {
        var row = (Adw.ComboRow) widget;
        assert (row.subtitle != null && row.subtitle != "");
        assert (row.tooltip_text == row.subtitle);
        count++;
    }
    assert (!(widget is Adw.EntryRow));
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ())
        check_rows (child, ref count);
}

class WidgetLifetimeProbe : Object {
    public WeakRef widget;
    public WidgetLifetimeProbe (Object widget) { this.widget = WeakRef (widget); }
}

WidgetLifetimeProbe detach_tool_group (ProtonPlus.Models.Group group) {
    var box = new ProtonPlus.Widgets.Tools.GroupBox (group);
    var reference = new WidgetLifetimeProbe (box);
    var parent = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    parent.append (box);
    parent.remove (box);
    return reference;
}

void check_tool_group_lifetime () {
    string root;
    try { root = DirUtils.make_tmp ("protonplus-widget-lifetime-XXXXXX"); }
    catch (Error e) { error ("%s", e.message); }
    var launcher = new ProtonPlus.Models.Launcher ("Fixture",
        ProtonPlus.Models.Launcher.InstallationTypes.SYSTEM, "", { root }, "steam");
    var group = new ProtonPlus.Models.Group ("Proton", "", "", launcher, "proton");
    group.tools = new Gee.LinkedList<ProtonPlus.Models.Tool> ();
    group.tools.add (new ProtonPlus.Models.Tools.TinkerGame (group));
    for (var i = 0; i < 3; i++) {
        var reference = detach_tool_group (group);
        assert (reference.widget.get () == null);
        // Retired views must no longer receive model invalidations.
        group.invalidate_installed_state ();
    }
    assert (DirUtils.remove (root) == 0);
}

Gtk.Label? find_layout_label (Gtk.Widget widget, string text) {
    var label = widget as Gtk.Label;
    if (label != null && label.get_label () == text)
        return label;
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var found = find_layout_label (child, text);
        if (found != null)
            return found;
    }
    return null;
}

void check_game_column_alignment () {
    var model = new Gtk.StringList ({ "fixture" });
    var view = new Gtk.ColumnView (new Gtk.NoSelection (model));
    string[] headings = { "", "Game", "Prefix", "Tool" };
    string[] values = { "", "Fixture game", "12345", "Default" };
    for (int i = 0; i < headings.length; i++) {
        int column_index = i;
        var factory = new Gtk.SignalListItemFactory ();
        factory.setup.connect ((object) => {
            Gtk.Widget cell;
            if (column_index == 0) {
                cell = new ProtonPlus.Widgets.Games.GameSelectionCell (
                    (item, delta, lane) => false, (item) => false
                );
            } else if (column_index == 1) {
                cell = new ProtonPlus.Widgets.Games.GameTitleCell (
                    (item, delta, lane) => false, (item) => false,
                    (item) => false, (item) => {}
                );
            } else {
                cell = new ProtonPlus.Widgets.Games.GameTextCell (
                    column_index == 2
                        ? ProtonPlus.Widgets.Games.GameTextCellKind.PREFIX
                        : ProtonPlus.Widgets.Games.GameTextCellKind.TOOL
                );
            }
            if (column_index > 0)
                ((Gtk.Label) cell.get_first_child ()).set_label (values[column_index]);
            ((Gtk.ListItem) object).set_child (cell);
        });
        var column = new Gtk.ColumnViewColumn (headings[i], factory);
        column.expand = i == 3;
        if (i > 0)
            column.sorter = new Gtk.StringSorter (null);
        view.append_column (column);
        if (i == 1)
            view.sort_by_column (column, Gtk.SortType.ASCENDING);
    }
    var window = new Gtk.Window () { default_width = 900, default_height = 240, child = view };
    window.present ();
    var loop = new MainLoop ();
    Timeout.add (200, () => { loop.quit (); return Source.REMOVE; });
    loop.run ();
    for (int i = 1; i < headings.length; i++) {
        var header = find_layout_label (view, headings[i]);
        var value = find_layout_label (view, values[i]);
        assert (header != null && value != null);
        Graphene.Rect header_bounds, value_bounds;
        assert (header.compute_bounds (view, out header_bounds));
        assert (value.compute_bounds (view, out value_bounds));
        assert (Math.fabs (header_bounds.origin.x - value_bounds.origin.x) <= 1.0);
    }
    window.destroy ();
}

void check_release_install_button () {
    string root;
    try { root = DirUtils.make_tmp ("protonplus-release-widget-XXXXXX"); }
    catch (Error e) { error ("%s", e.message); }
    var launcher = new ProtonPlus.Models.Launcher ("Fixture",
        ProtonPlus.Models.Launcher.InstallationTypes.SYSTEM, "", { root }, "fixture");
    var group = new ProtonPlus.Models.Group ("Fixture", "", "", launcher, "fixture");
    var tool = new ProtonPlus.Models.Tools.SteamTinkerLaunch (group);
    var release = new ProtonPlus.Models.Release ("Fixture release", "", "",
        new ProtonPlus.Models.Assets.Asset ("fixture.zip", "https://example.test/fixture.zip"),
        "https://example.test/release");
    var job = new ProtonPlus.Services.InstallJob (release, tool,
        ProtonPlus.Services.InstallJob.Mode.VERSIONED, Path.build_filename (root, "tool"));
    var row = new ProtonPlus.Widgets.Tools.ReleaseRow (job);
    var label = find_layout_label (row, "Install");
    assert (label != null);
    // Text-only actions must not retain an image showing a missing-icon fallback.
    var button = label.get_parent () as Gtk.Button;
    assert (button != null && button.get_child () == label);
    assert (DirUtils.remove (root) == 0);
}

void check_catalog_driven_controls () {
    var defaults = new LaunchOptionCatalog ();
    var definitions = new Gee.ArrayList<LaunchOptionMetadata> ();
    var wrappers = new Gee.ArrayList<LaunchWrapperDefinition> ();
    // A definition change must reach the real control without duplicating it
    // in a group constructor. This fixture changes text, tokens and line type.
    foreach (var metadata in defaults.get_ordered ()) {
        if (metadata.id != "desktop-game-profile") {
            definitions.add (metadata);
            continue;
        }
        definitions.add (new LaunchOptionMetadata (
            metadata.id, "Fixture profile", "Fixture profile details",
            metadata.category, metadata.subsection, metadata.display_rank,
            metadata.quick_setting, metadata.expertise, metadata.applicability,
            metadata.unavailable_reason, metadata.dependencies, metadata.aliases,
            { "--fixture-profile" }, LaunchLineType.ARGUMENT, metadata.command_order_rank,
            new LaunchOptionSemantics (
                LaunchOptionSemanticKind.GAME_ARGUMENT, LaunchPlaceholderPolicy.OPTIONAL,
                LaunchOptionEmissionMode.FIXED_TOKENS, "", "", { "--fixture-profile" },
                {}, "", {}, {}, {}, LaunchOptionApplicability.GENERIC, {}, false,
                LaunchOptionSupport.VERIFIED_CURRENT, true
            )
        ));
    }
    foreach (var wrapper in defaults.get_wrappers ())
        wrappers.add (wrapper);
    var catalog = new LaunchOptionCatalog.with_definitions (
        definitions.to_array (), wrappers.to_array ()
    );
    var presentations = new LaunchOptionPresentationRegistry (catalog);
    var handlers = new LaunchOptionsList ();
    var common = new Groups.CommonOptionsGroup (handlers, presentations);
    var profile = presentations.lookup ("desktop-game-profile");
    var row = profile.widgets[0] as Adw.ActionRow;
    assert (row != null && row.title == "Fixture profile");
    assert (row.subtitle == "Fixture profile details");
    assert (row.tooltip_text == row.subtitle);
    assert (profile.option.line_type == LaunchLineType.ARGUMENT);
    handlers.load_from_string ("%command% --fixture-profile");
    assert (profile.option.is_active ());
    var selection = profile.selection_sources[0].get_selection ();
    assert (selection != null && selection.option_id == "desktop-game-profile");
    var written = new LaunchCommandWriter (catalog).prepare_source (
        "%command%", { selection }, { "desktop-game-profile" }, {},
        new LaunchCommandCapabilityContext ()
    );
    assert (written.writing_allowed && written.launch_line == "%command% --fixture-profile");

    // Off/on recognition remains separate from the writer's one canonical
    // assignment. Loading the historical off token must not activate it.
    var amd = new Groups.GpuVendorAmdOptionsGroup (handlers, presentations);
    var shader_cache = presentations.lookup ("amd-shader-cache");
    handlers.load_from_string ("MESA_SHADER_CACHE_DISABLE=0 %command%");
    assert (!shader_cache.option.is_active ());
    handlers.load_from_string ("MESA_SHADER_CACHE_DISABLE=1 %command%");
    assert (shader_cache.option.is_active ());
    written = new LaunchCommandWriter (catalog).prepare_source (
        "%command%", { shader_cache.selection_sources[0].get_selection () },
        { "amd-shader-cache" }, {},
        new LaunchCommandCapabilityContext ({ LaunchOptionCapability.AMD })
    );
    assert (written.writing_allowed && written.launch_line == "MESA_SHADER_CACHE_DISABLE=1 %command%");

    var gamescope = new Wrappers.Gamescope (handlers, presentations);
    var wrapper_page = gamescope.create_page ();
    var fullscreen = presentations.lookup ("gamescope-fullscreen");
    row = fullscreen.widgets[0] as Adw.ActionRow;
    assert (row != null && row.title == catalog.lookup ("gamescope-fullscreen").title);
    assert (row.tooltip_text == catalog.lookup ("gamescope-fullscreen").description);
    assert (fullscreen.option.line_type == LaunchLineType.WRAPPER_ARGUMENT);
    handlers.load_from_string ("gamescope -f -- %command%");
    assert (fullscreen.option.is_active ());
    written = new LaunchCommandWriter (catalog).prepare_source (
        "%command%", {
            new LaunchCommandSelection ("launch-backend", {}, "gamescope"),
            fullscreen.selection_sources[0].get_selection ()
        }, { "launch-backend", "gamescope-fullscreen" }, {},
        new LaunchCommandCapabilityContext ({ LaunchOptionCapability.GAMESCOPE })
    );
    assert (written.writing_allowed && written.launch_line == "gamescope -f -- %command%");

    // Keep the owners alive until all unowned control adapters have been used.
    assert (common != null && amd != null && wrapper_page != null);
}

int main (string[] args) {
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);
    if (!Gtk.init_check ())
        return 77;
    Adw.init ();
    check_tool_group_lifetime ();
    check_game_column_alignment ();
    check_release_install_button ();
    check_catalog_driven_controls ();
    string[] ids = { "vkd3d-config", "amd-radv-perftest", "amd-radv-debug", "amd-aco-debug" };
    LaunchOptionCustomPairs[] editors = {
        new LaunchOptionVKD3DConfig (), new LaunchOptionRadvPerftest (),
        new LaunchOptionRadvDebug (), new LaunchOptionAcoDebug ()
    };
    for (int i = 0; i < ids.length; i++) {
        var editor = editors[i];
        var values = LaunchOptionFlags.values (ids[i]);
        var source = LaunchCommandSelectionAdapterFactory.create (ids[i], editor, editor);
        assert (source != null);
        editor.enable_expansion = true;
        assert (source.get_selection () == null);
        int count = 0;
        check_rows (editor, ref count);
        assert (count == values.length);
        foreach (var key in values) {
            editor.value = key;
            assert (editor.value == key);
            var selection = source.get_selection ();
            assert (selection != null);
            var result = new LaunchCommandComposer ().compose (new LaunchCommandCompositionRequest (
                { selection }, new LaunchCommandCapabilityContext ({
                    LaunchOptionCapability.AMD, LaunchOptionCapability.VKD3D_PROTON
                })
            ));
            assert (result.is_valid);
        }
        editor.value = string.joinv (",", values);
        assert (editor.value == string.joinv (",", values));
        editor.value = "legacy_flag";
        assert (editor.value == "legacy_flag");
        editor.value = values[0];
        assert (editor.value == values[0]);
        editor.clear ();
        assert (editor.value == "");
        assert (!editor.is_active ());
        count = 0;
        check_rows (editor, ref count);
        assert (count == values.length);
    }
    var dlls = new LaunchOptionDllOverrides ();
    dlls.value = "custom_mod=n;dxgi=n,b";
    assert (dlls.value.contains ("custom_mod=n"));
    dlls.value = "d3d11=b";
    assert (dlls.value == "d3d11=b");
    return 0;
}
