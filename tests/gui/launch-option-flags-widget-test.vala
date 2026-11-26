using ProtonPlus.LaunchOptions;
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
    string[] headings = { "", "Game", "Compatibility" };
    string[] values = { "", "Fixture game", "Default" };
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
                cell = new ProtonPlus.Widgets.Games.GameCompatibilityCell ();
            }
            if (column_index > 0)
                ((Gtk.Label) cell.get_first_child ()).set_label (values[column_index]);
            ((Gtk.ListItem) object).set_child (cell);
        });
        var column = new Gtk.ColumnViewColumn (headings[i], factory);
        column.expand = i > 0;
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

delegate bool WidgetMatch (Gtk.Widget widget);

Gtk.Widget? find_widget (Gtk.Widget widget, WidgetMatch match) {
    if (match (widget))
        return widget;
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var found = find_widget (child, match);
        if (found != null)
            return found;
    }
    return null;
}

void check_runtime_control_values () {
    var editor = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.Box ();
    editor.set_capability_context (new LaunchCommandCapabilityContext ({
        LaunchOptionCapability.PROTON_OPTISCALER, LaunchOptionCapability.DXVK_FRAME_CONFIG,
        LaunchOptionCapability.AMD, LaunchOptionCapability.PROTON_FSR4, LaunchOptionCapability.PROTON_MLFG
    }));
    var source = "PROTON_USE_OPTISCALER='v0.9.0' PROTON_FSR4_UPGRADE=4.0.3 PROTON_MLFG_UPGRADE=0 "
        + "DXVK_CONFIG=\"dxvk.maxFrameRate=60\" %command% --custom";
    editor.set_text (source);
    var optiscaler = (Adw.EntryRow) find_widget (editor, widget => widget is Adw.EntryRow
        && ((Adw.EntryRow) widget).title == "OptiScaler integration");
    var fsr = (Adw.EntryRow) find_widget (editor, widget => widget is Adw.EntryRow
        && ((Adw.EntryRow) widget).title == "FSR 4 upgrade");
    var limit = (Adw.EntryRow) find_widget (editor, widget => widget is Adw.EntryRow
        && ((Adw.EntryRow) widget).title == "DXVK frame limiter");
    var mlfg = (LaunchOptionEnvCombo) find_widget (editor, widget => widget is LaunchOptionEnvCombo
        && ((LaunchOptionEnvCombo) widget).environment_variable == "PROTON_MLFG_UPGRADE");
    assert (optiscaler != null && optiscaler.text == "v0.9.0");
    assert (fsr != null && fsr.text == "4.0.3");
    assert (limit != null && limit.text == "60");
    assert (mlfg != null && mlfg.value == "0");
    assert (editor.prepare_write ().launch_line == source);
    limit.text = "-144";
    var written = editor.prepare_write ();
    assert (written.writing_allowed && written.launch_line.contains ("DXVK_CONFIG='dxvk.maxFrameRate = -144'"));
    assert (written.launch_line.contains ("PROTON_USE_OPTISCALER='v0.9.0' PROTON_FSR4_UPGRADE=4.0.3 PROTON_MLFG_UPGRADE=0"));
}

void check_inline_combo () {
    var editor = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.Box ();
    var supported = new LaunchCommandCapabilityContext ({ LaunchOptionCapability.PROTON_WOW64 });
    var first = "PROTON_USE_WOW64='1' %command% --first";
    var second = "OTHER='keep spacing' %command% --second";
    editor.set_capability_context (supported);
    editor.set_text (first);
    var window = new Adw.Window () { content = editor };
    window.present ();

    var combo = find_widget (editor, widget => widget is LaunchOptionEnvCombo
        && ((LaunchOptionEnvCombo) widget).environment_variable == "PROTON_USE_WOW64") as LaunchOptionEnvCombo;
    assert (combo != null && combo.get_mapped () && combo.activatable && combo.value == "1");
    assert (combo.get_ancestor (typeof (Adw.ExpanderRow)) == null);
    assert (editor.prepare_write ().launch_line == first);
    var remove = find_widget (combo, widget => widget is Gtk.Button
        && widget.tooltip_text == "Remove WoW64 mode") as Gtk.Button;
    assert (remove != null && remove.get_mapped ());

    var popover = find_widget (combo, widget => widget is Gtk.Popover) as Gtk.Popover;
    assert (popover != null);
    combo.activate ();
    assert (popover.visible);
    editor.set_capability_context (new LaunchCommandCapabilityContext ({ LaunchOptionCapability.PROTON }));
    assert (!combo.activatable && !popover.visible && remove.is_sensitive ());
    combo.activate ();
    assert (!popover.visible && editor.prepare_write ().launch_line == first);
    remove.clicked ();
    assert (!combo.visible && editor.prepare_write ().launch_line == "--first");

    editor.set_capability_context (supported);
    editor.set_text ("");
    editor.set_preview_sources ({ "First", "Second" }, { first, second });
    assert (combo.visible && combo.activatable && combo.subtitle.contains ("Varies by game"));
    combo.value = "0";
    assert (editor.prepare_write_for_source (first).launch_line == "PROTON_USE_WOW64=0 %command% --first");
    assert (editor.prepare_write_for_source (second).launch_line == "OTHER='keep spacing' PROTON_USE_WOW64=0 %command% --second");
    window.destroy ();
}

void check_launch_options_draft () {
    var steam = new ProtonPlus.Models.Launchers.Steam (ProtonPlus.Models.Launcher.InstallationTypes.SYSTEM);
    var first = new ProtonPlus.Models.Games.Steam.non_steam (100, "First <fixture>",
        "FIRST='quoted one' %command% --first --first", "Default", steam);
    var second = new ProtonPlus.Models.Games.Steam.non_steam (200, "Second fixture",
        "SECOND=\"quoted two\" %command% --second", "Default", steam);
    var model = new ListStore (typeof (ProtonPlus.Models.CompatibilityTool));
    model.append (new ProtonPlus.Models.CompatibilityTool ("Default", "Default", "",
        ProtonPlus.Models.CompatibilityToolRuntimeKind.PROTON));
    var expression = new Gtk.PropertyExpression (typeof (ProtonPlus.Models.CompatibilityTool), null, "display-title");
    var view = new ProtonPlus.Widgets.Games.MassEditView (new Gtk.MenuButton ());
    view.load ({
        new ProtonPlus.Widgets.Games.GameListItem (first),
        new ProtonPlus.Widgets.Games.GameListItem (second)
    }, model, expression, false, true);
    var window = new Adw.Window () { content = view };
    window.present ();

    var apply = (Gtk.Button) find_widget (view, (widget) => widget is Gtk.Button
        && ((Gtk.Button) widget).label == "Apply Changes");
    var clear = (Gtk.Button) find_widget (view, (widget) => widget is Gtk.Button
        && widget.tooltip_text == "Clear Launch Options");
    assert (apply != null && clear != null);
    assert (!apply.sensitive && clear.sensitive);
    var editor = (ProtonPlus.Widgets.Games.LaunchOptionsEditor.Box)
        find_widget (view, (widget) => widget is ProtonPlus.Widgets.Games.LaunchOptionsEditor.Box);
    assert (editor != null);
    var latency = (Adw.ActionRow) find_widget (editor, (widget) => widget is Adw.ActionRow
        && ((Adw.ActionRow) widget).title == "PulseAudio latency"
        && find_widget (widget, child => child is Gtk.Entry) != null);
    assert (latency != null);
    var latency_entry = (Gtk.Entry) find_widget (latency, (widget) => widget is Gtk.Entry);
    assert (latency_entry != null && find_widget (latency, widget => widget is Gtk.Switch) == null);
    var remove_latency = find_widget (latency, widget => widget is Gtk.Button
        && widget.get_tooltip_text () == "Remove PulseAudio latency") as Gtk.Button;
    assert (remove_latency != null);

    latency_entry.text = "123";
    assert (apply.sensitive);
    var first_write = editor.prepare_write_for_source (first.launch_options);
    var second_write = editor.prepare_write_for_source (second.launch_options);
    assert (first_write.launch_line == "FIRST='quoted one' PULSE_LATENCY_MSEC=123 %command% --first --first");
    assert (second_write.launch_line == "SECOND=\"quoted two\" PULSE_LATENCY_MSEC=123 %command% --second");
    var preview = (Gtk.ToggleButton) find_widget (view, widget => widget is Gtk.ToggleButton
        && ((Gtk.ToggleButton) widget).label == "Command preview");
    assert (preview != null && !preview.active);
    assert (find_widget (view, widget => widget is Gtk.Label
        && ((Gtk.Label) widget).get_text ().contains (first_write.launch_line)
        && ((Gtk.Label) widget).get_text ().contains (second_write.launch_line)) != null);

    latency_entry.text = "";
    assert (latency_entry.has_css_class ("error"));
    assert (latency.subtitle.contains ("30") && latency.subtitle.contains ("360"));
    assert (!apply.sensitive && !editor.writing_allowed && !preview.active);
    var blocker = find_widget (view, widget => widget.has_css_class ("launch-options-blocker"));
    var blocker_message = blocker?.get_first_child () as Gtk.Label;
    assert (blocker_message != null && blocker.visible && blocker_message.label.contains ("First <fixture>"));
    assert (!blocker_message.use_markup && !blocker.is_ancestor (editor));
    var tool_switch = (Adw.SwitchRow) find_widget (view, (widget) => widget is Adw.SwitchRow
        && ((Adw.SwitchRow) widget).title == "Change compatibility tool");
    var tool_row = (ProtonPlus.Widgets.Games.CompatibilityToolRow) find_widget (view,
        (widget) => widget is ProtonPlus.Widgets.Games.CompatibilityToolRow);
    assert (tool_switch != null && tool_row != null);
    tool_switch.active = true;
    tool_row.selected = 0;
    assert (!apply.sensitive);
    remove_latency.clicked ();
    assert (!latency.visible && !latency_entry.has_css_class ("error"));
    assert (apply.sensitive);
    tool_switch.active = false;
    assert (!apply.sensitive);

    clear.clicked ();
    assert (apply.sensitive && editor.writing_allowed);
    var cleared = editor.prepare_write_for_source (first.launch_options);
    assert (cleared.requires_persistence && cleared.launch_line == "");
    assert (first.launch_options == "FIRST='quoted one' %command% --first --first");
    assert (second.launch_options == "SECOND=\"quoted two\" %command% --second");
    latency_entry.text = "101";
    assert (editor.prepare_write_for_source (first.launch_options).launch_line == "PULSE_LATENCY_MSEC=101 %command%");

    var saved = "FIRST='quoted one' PULSE_LATENCY_MSEC='90' %command% --first --first";
    editor.set_text (saved);
    assert (latency.visible && latency_entry.text == "90");
    assert (editor.prepare_write ().launch_line == saved);
    remove_latency.clicked ();
    assert (editor.prepare_write ().launch_line == first.launch_options);

    editor.set_capability_context (new LaunchCommandCapabilityContext ({
        LaunchOptionCapability.AMD, LaunchOptionCapability.LOW_LATENCY_LAYER
    }));
    editor.set_text (first.launch_options);
    editor.set_preview_sources ({ "First <fixture>", "Second fixture" },
        { first.launch_options, second.launch_options });
    var add_option = find_widget (view, widget => widget is Gtk.Button
        && ((Gtk.Button) widget).label == "Add launch option") as Gtk.Button;
    assert (add_option != null);
    add_option.clicked ();
    assert (window.visible_dialog != null);
    var reflex_option = find_widget (window.visible_dialog, widget => widget is Adw.ActionRow
        && ((Adw.ActionRow) widget).title == "AMD Reflex preset: allow DXVK-NVAPI");
    assert (reflex_option != null && reflex_option.activate ());
    assert (!apply.sensitive && !editor.writing_allowed);
    var message = "“AMD Reflex preset: allow DXVK-NVAPI” requires “Use Reflex in the Vulkan low-latency layer”.";
    assert (blocker.visible && blocker_message.label.contains (message));
    var add_dependencies = find_widget (blocker, widget => widget is Gtk.Button
        && ((Gtk.Button) widget).label == "Add required options") as Gtk.Button;
    assert (add_dependencies != null && add_dependencies.visible);
    add_dependencies.clicked ();
    assert (!blocker.visible && !add_dependencies.visible && apply.sensitive && editor.writing_allowed);
    first_write = editor.prepare_write_for_source (first.launch_options);
    second_write = editor.prepare_write_for_source (second.launch_options);
    foreach (var result in new LaunchCommandWriteResult[] { first_write, second_write }) {
        assert (result.writing_allowed && result.launch_line.contains ("LOW_LATENCY_LAYER=1")
            && result.launch_line.contains ("LOW_LATENCY_LAYER_REFLEX=1")
            && result.launch_line.contains ("DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1"));
    }
    assert (first_write.launch_line.has_prefix ("FIRST='quoted one' ")
        && first_write.launch_line.has_suffix (" %command% --first --first"));
    assert (second_write.launch_line.has_prefix ("SECOND=\"quoted two\" ")
        && second_write.launch_line.has_suffix (" %command% --second"));

    editor.set_capability_context (new LaunchCommandCapabilityContext ({
        LaunchOptionCapability.AMD, LaunchOptionCapability.LOW_LATENCY_LAYER,
        LaunchOptionCapability.GAME_PERFORMANCE
    }));
    var grouped_options = "DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 PROTON_FORCE_NVAPI=1 GAME_PERFORMANCE_SCREENSAVER_ON=1 ";
    var first_grouped = grouped_options + first.launch_options;
    var second_grouped = grouped_options + second.launch_options;
    editor.set_text (first_grouped);
    editor.set_preview_sources ({ "First <fixture>", "Second fixture" }, { first_grouped, second_grouped });
    latency_entry.text = "120";
    assert (blocker.visible && blocker_message.label == "3 launch options have unmet requirements.");
    assert (add_dependencies.visible && add_dependencies.label == "Add required options");
    add_dependencies.clicked ();
    assert (!blocker.visible && apply.sensitive);
    foreach (var source in new string[] { first_grouped, second_grouped }) {
        var result = editor.prepare_write_for_source (source);
        assert (result.writing_allowed && result.launch_line.contains ("game-performance %command%"));
        assert (result.launch_line.split ("LOW_LATENCY_LAYER=1").length == 2);
        assert (result.launch_line.split ("LOW_LATENCY_LAYER_REFLEX=1").length == 2);
        assert (result.launch_line.contains ("PULSE_LATENCY_MSEC=120"));
    }

    editor.set_capability_context (new LaunchCommandCapabilityContext ({
        LaunchOptionCapability.AMD, LaunchOptionCapability.PROTON_FSR4, LaunchOptionCapability.PROTON_MLFG,
        LaunchOptionCapability.GAME_PERFORMANCE
    }));
    editor.set_text ("GAME_PERFORMANCE_SCREENSAVER_ON=1 " + first.launch_options);
    var mlfg = find_widget (view, widget => widget is LaunchOptionEnvCombo
        && ((LaunchOptionEnvCombo) widget).environment_variable == "PROTON_MLFG_UPGRADE") as LaunchOptionEnvCombo;
    var fsr = find_widget (view, widget => widget is Adw.EntryRow
        && ((Adw.EntryRow) widget).title == "FSR 4 upgrade") as Adw.EntryRow;
    assert (mlfg != null && fsr != null);
    mlfg.value = "1";
    assert (blocker.visible && blocker_message.label == "2 launch options have unmet requirements.");
    assert (add_dependencies.visible && add_dependencies.label == "Add required options");
    add_dependencies.clicked ();
    assert (add_dependencies.visible && add_dependencies.label == "Configure FSR 4 upgrade");
    add_dependencies.clicked ();
    var fsr_row = fsr.get_ancestor (typeof (Adw.ExpanderRow)) as Adw.ExpanderRow;
    assert (fsr_row != null && fsr_row.visible && fsr_row.expanded);
    assert (fsr.text == "" && !apply.sensitive);
    fsr.text = "1";
    assert (!add_dependencies.visible && apply.sensitive);
    window.destroy ();
}

void check_launch_option_blocker_layout () {
    var display = Gdk.Display.get_default ();
    var css = ProtonPlus.Utils.ThemeManager.load_stylesheet ("style");
    Gtk.StyleContext.add_provider_for_display (display, css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

    var view = new ProtonPlus.Widgets.Games.MassEditView (new Gtk.MenuButton ());
    var blocker = find_widget (view, widget => widget.has_css_class ("launch-options-blocker"));
    assert (blocker != null && !blocker.visible);
    var message = blocker.get_first_child () as Gtk.Label;
    var action = message?.get_next_sibling () as Gtk.Button;
    assert (message != null && message.xalign == 0 && action != null);
    action.label = "Add required options";
    action.visible = true;
    blocker.visible = true;

    var viewport = new Adw.Clamp () {
        maximum_size = 1500, tightening_threshold = 1500, width_request = 1500, child = view
    };
    var window = new Adw.Window () { default_width = 1500, default_height = 640, content = viewport };
    window.present ();
    foreach (int width in new int[] { 1500, 430 }) {
        viewport.maximum_size = width;
        viewport.tightening_threshold = width;
        viewport.width_request = width;
        float left_edge = -1;
        foreach (var text in new string[] { "2 launch options have unmet requirements.",
            "“AMD Reflex preset: allow DXVK-NVAPI” requires “Use Reflex in the Vulkan low-latency layer”." }) {
            message.label = text;
            var loop = new MainLoop ();
            Timeout.add (200, () => { loop.quit (); return Source.REMOVE; });
            loop.run ();
            Graphene.Rect message_bounds, action_bounds;
            assert (message.get_mapped () && action.get_mapped ());
            assert (message.compute_bounds (blocker, out message_bounds));
            assert (action.compute_bounds (blocker, out action_bounds));
            if (left_edge < 0)
                left_edge = message_bounds.origin.x;
            assert (message_bounds.origin.x == left_edge);
            if (width == 1500)
                assert (message_bounds.origin.x + message_bounds.size.width <= action_bounds.origin.x);
            else {
                assert (blocker.get_width () <= width);
                assert (message_bounds.origin.y + message_bounds.size.height <= action_bounds.origin.y);
            }
        }
    }
    assert (blocker.child_focus (Gtk.DirectionType.TAB_FORWARD));
    window.destroy ();
    Gtk.StyleContext.remove_provider_for_display (display, css);
}

void check_typed_arguments_and_resolution () {
    ProtonPlus.Globals.GAMESCOPE_INSTALLED = true;
    var editor = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.Box ();
    editor.set_capability_context (new LaunchCommandCapabilityContext ({ LaunchOptionCapability.GAMESCOPE }));
    editor.set_text ("gamescope -W 1700 -H 1000 -- %command% --game");
    var additional = (Adw.EntryRow) find_widget (editor, (widget) => widget is Adw.EntryRow
        && ((Adw.EntryRow) widget).title == "Additional Gamescope arguments");
    var width = (Gtk.Entry) find_widget (editor, (widget) => widget is Gtk.Entry && widget.tooltip_text == "Width");
    assert (additional != null && width != null);

    width.text = "1800";
    additional.text = "--output 'space name'";
    var write = editor.prepare_write ();
    assert (editor.writing_allowed && write.requires_persistence);
    assert (write.launch_line == "gamescope -W 1800 -H 1000 --output 'space name' -- %command% --game");
    width.text = "3";
    assert (width.has_css_class ("error") && !editor.writing_allowed);
    width.text = "1800";
    additional.text = "--output 'unclosed";
    assert (additional.has_css_class ("error") && !editor.writing_allowed);
    additional.text = "--output 'space name'";
    assert (editor.writing_allowed);

    editor.set_text ("gamescope --custom 'value' -r '120' --framerate-limit='60' -- %command%");
    var refresh = find_widget (editor, widget => widget is Adw.ActionRow
        && ((Adw.ActionRow) widget).title == "Nested refresh rate"
        && find_widget (widget, child => child is Gtk.Entry) != null);
    var fps = find_widget (editor, widget => widget is Adw.ActionRow
        && ((Adw.ActionRow) widget).title == "Frame limit"
        && find_widget (widget, child => child is Gtk.Entry) != null);
    assert (refresh != null && fps != null);
    var refresh_input = (Gtk.Entry) find_widget (refresh, widget => widget is Gtk.Entry);
    var fps_input = (Gtk.Entry) find_widget (fps, widget => widget is Gtk.Entry);
    assert (refresh_input != null && refresh_input.text == "120");
    assert (fps_input != null && fps_input.text == "60");
    assert (find_widget (refresh, widget => widget is Gtk.Switch) == null);
    assert (refresh.get_ancestor (typeof (Adw.ExpanderRow)) == null);
    fps_input.text = "45";
    assert (editor.prepare_write ().launch_line
        == "gamescope --custom 'value' -r '120' --framerate-limit 45 -- %command%");

    editor.set_text ("");
    assert (!editor.can_clear);
    editor.set_preview_sources ({ "First", "Second" }, { "--first --first", "%command% '--second value'" });
    assert (editor.can_clear);
    var add_argument = (Gtk.Button) find_widget (editor, (widget) => widget is Gtk.Button
        && widget.tooltip_text == "Add custom argument");
    assert (add_argument != null);
    add_argument.clicked ();
    var argument = (Adw.EntryRow) find_widget (editor, (widget) => widget is Adw.EntryRow
        && ((Adw.EntryRow) widget).title == "Argument");
    assert (argument != null);
    argument.text = "--new 'two words'";
    assert (argument.has_css_class ("error") && !editor.writing_allowed);
    argument.text = "--new='two words'";
    assert (editor.writing_allowed && editor.has_changes_to_write);
    assert (editor.prepare_write_for_source ("--first --first").launch_line == "--first --first --new='two words'");
    assert (editor.prepare_write_for_source ("%command% '--second value'").launch_line
        == "%command% '--second value' --new='two words'");
    ProtonPlus.Globals.GAMESCOPE_INSTALLED = false;
}

void check_scopebuddy_controls () {
    ProtonPlus.Globals.SCOPEBUDDY_INSTALLED = true;
    var editor = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.Box ();
    editor.set_capability_context (new LaunchCommandCapabilityContext ({ LaunchOptionCapability.SCOPEBUDDY }));
    editor.set_text ("SCB_CONF=\"Desk Mode.conf\" SCB_APPENDMODE=1 SCB_DEBUG=1 scb --example='keep me' -- %command%");

    var profile = (Adw.EntryRow) find_widget (editor, widget => widget is Adw.EntryRow
        && ((Adw.EntryRow) widget).title == "Configuration profile");
    var merge = (Adw.ComboRow) find_widget (editor, widget => widget is Adw.ComboRow
        && ((Adw.ComboRow) widget).title == "Config argument merge");
    var extra = (Adw.EntryRow) find_widget (editor, widget => widget is Adw.EntryRow
        && ((Adw.EntryRow) widget).title == "Additional ScopeBuddy arguments");
    assert (profile != null && profile.text == "Desk Mode.conf");
    assert (merge != null && merge.selected == 2);
    assert (extra != null && extra.text == "--example='keep me'");
    assert (!editor.is_dirty);

    profile.text = "Monitor.conf";
    merge.selected = 1;
    assert (editor.prepare_write ().launch_line
        == "SCB_DEBUG=1 SCB_CONF=Monitor.conf SCB_APPENDMODE=0 scb --example='keep me' -- %command%");
    extra.text = "--";
    assert (!editor.writing_allowed);
    ProtonPlus.Globals.SCOPEBUDDY_INSTALLED = false;
}

void check_custom_wrapper_draft () {
    ProtonPlus.Globals.GAMESCOPE_INSTALLED = true;
    var editor = new ProtonPlus.Widgets.Games.LaunchOptionsEditor.Box ();
    editor.set_capability_context (new LaunchCommandCapabilityContext ({ LaunchOptionCapability.GAMESCOPE }));
    var field = (Adw.EntryRow) find_widget (editor, (widget) => widget is Adw.EntryRow
        && ((Adw.EntryRow) widget).title == "Custom wrapper");
    assert (field != null && field.visible);

    string program = "\"/tmp/Goverlay Config/bgmod\"";
    editor.set_text ("");
    editor.set_preview_sources ({ "First", "Second <fixture>" }, { "--tag --tag", "LOCAL=1 %command% --second" });
    field.text = program + " %command% %command%";
    assert (field.has_css_class ("error") && !editor.writing_allowed);
    field.text = program + " %command%";
    assert (!field.has_css_class ("error") && editor.writing_allowed);
    var first = editor.prepare_write_for_source ("--tag --tag");
    var second = editor.prepare_write_for_source ("LOCAL=1 %command% --second");
    assert (first.launch_line == program + " %command% --tag --tag");
    assert (second.launch_line == "LOCAL=1 " + program + " %command% --second");

    editor.set_preview_sources ({ "First", "Conflicting <fixture>" }, { "--tag --tag", "/tmp/different %command%" });
    assert (!editor.writing_allowed);
    assert (editor.prepare_write_for_source ("/tmp/different %command%").status
        == LaunchCommandWriteStatus.BLOCKED_CUSTOM_WRAPPER_CONFLICT);

    var nested = "gamescope -r 60 -- " + program + " %command% -r 75";
    editor.set_text (nested);
    assert (field.text == program && !editor.is_dirty);
    var refresh_rate = (Adw.ActionRow) find_widget (editor, (widget) => widget is Adw.ActionRow
        && ((Adw.ActionRow) widget).title == "Nested refresh rate"
        && ((Adw.ActionRow) widget).subtitle.contains ("Gamescope — "));
    assert (refresh_rate != null);
    var rate_entry = (Gtk.Entry) find_widget (refresh_rate, (widget) => widget is Gtk.Entry);
    assert (rate_entry != null && rate_entry.text == "60");
    rate_entry.text = "90";
    assert (editor.prepare_write ().launch_line == nested.replace ("-r 60", "-r 90"));
    field.text = "";
    assert (editor.prepare_write ().launch_line == "gamescope -r 90 -- %command% -r 75");
    editor.clear ();
    field.text = program;
    assert (editor.prepare_write ().launch_line == program + " %command%");

    editor.set_capability_context (new LaunchCommandCapabilityContext ({ LaunchOptionCapability.GAME_PERFORMANCE }));
    editor.set_text ("/tmp/wrapper --label game-performance %command%");
    var performance = (Adw.ActionRow) find_widget (editor, (widget) => widget is Adw.ActionRow
        && ((Adw.ActionRow) widget).title == "CachyOS game-performance");
    assert (performance != null && !performance.visible);
    var performance_command = "GAME_PERFORMANCE_SCREENSAVER_ON=1 game-performance %command%";
    editor.set_text (performance_command);
    var screensaver = (Adw.ActionRow) find_widget (editor, widget => widget is Adw.ActionRow
        && ((Adw.ActionRow) widget).title == "Allow the screensaver during play");
    assert (performance.visible && screensaver != null && screensaver.visible);
    assert (performance.subtitle.has_prefix ("Temporarily requests the performance power profile"));
    assert (screensaver.subtitle == "Allows the screensaver to activate normally during play. Requires CachyOS game-performance.");
    assert (screensaver.tooltip_text == screensaver.subtitle);
    assert (editor.prepare_write ().launch_line == performance_command);
    ProtonPlus.Globals.GAMESCOPE_INSTALLED = false;

    editor.set_text ("PROTON_PRIORITY_HIGH='1' TEST_ENV=original %command% --custom");
    var priority = (Adw.ActionRow) find_widget (editor, (widget) => widget is Adw.ActionRow
        && ((Adw.ActionRow) widget).title == "High process priority");
    assert (priority != null && priority.visible);
    var remove = find_widget (priority, widget => widget is Gtk.Button && widget.tooltip_text == "Remove High process priority") as Gtk.Button;
    assert (remove != null);
    var window = new Adw.Window () { content = editor };
    window.present ();
    remove.clicked ();
    assert (!priority.visible);
    assert (editor.prepare_write ().launch_line == "TEST_ENV=original %command% --custom");
    window.destroy ();
}

void check_command_preview_height () {
    var display = Gdk.Display.get_default ();
    var css = ProtonPlus.Utils.ThemeManager.load_stylesheet ("style");
    Gtk.StyleContext.add_provider_for_display (display, css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    var view = new ProtonPlus.Widgets.Games.MassEditView (new Gtk.MenuButton ());
    var scroller = find_widget (view, widget => widget.has_css_class ("launch-options-preview-surface")) as Gtk.ScrolledWindow;
    assert (scroller != null);
    var label = find_widget (scroller, widget => widget is Gtk.Label) as Gtk.Label;
    assert (label != null);

    label.set_markup (LaunchOptionsList.build_command_preview_markup ("game-performance %command%"));
    int label_height, preview_height;
    label.measure (Gtk.Orientation.VERTICAL, 360, null, out label_height, null, null);
    scroller.measure (Gtk.Orientation.VERTICAL, 360, null, out preview_height, null, null);
    assert (preview_height == label_height);

    label.set_text (string.nfill (1500, 'x'));
    label.measure (Gtk.Orientation.VERTICAL, 360, null, out label_height, null, null);
    scroller.measure (Gtk.Orientation.VERTICAL, 360, null, out preview_height, null, null);
    assert (preview_height == scroller.max_content_height && preview_height < label_height);
    Gtk.StyleContext.remove_provider_for_display (display, css);
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
    check_launch_options_draft ();
    check_launch_option_blocker_layout ();
    check_runtime_control_values ();
    check_inline_combo ();
    check_typed_arguments_and_resolution ();
    check_scopebuddy_controls ();
    check_custom_wrapper_draft ();
    check_command_preview_height ();
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
    var dll_name = (Adw.EntryRow) find_widget (dlls, (widget) => widget is Adw.EntryRow
        && ((Adw.EntryRow) widget).title == "Custom DLL name");
    assert (dll_name != null);
    dll_name.text = "fixture_dll";
    assert (dlls.value.contains ("fixture_dll="));
    dll_name.text = "fixture;dll";
    assert (dll_name.has_css_class ("error") && dlls.get_validation_diagnostic () != null);
    dlls.clear ();
    assert (dll_name.text == "" && dlls.get_validation_diagnostic () == null);
    return 0;
}
