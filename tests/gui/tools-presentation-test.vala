using ProtonPlus;

class PresentationFixtureTool : Models.Tool {
    public PresentationFixtureTool (Models.Group group) {
        Object (group: group, title: "Fixture Tool", description: "Run Windows games on Linux");
        var newest = release ("3.0");
        var catalog = new Models.ReleaseCatalog.with_static_release (newest);
        catalog.releases.add (newest);
        catalog.releases.add (release ("2.0"));
        catalog.releases.add (release ("1.0"));
        initialize_release_catalog (catalog);
    }

    Models.Release release (string version) {
        return new Models.Release (version, "", "",
            new Models.Assets.Asset ("fixture.tar.gz", "https://example.test/fixture.tar.gz"), "");
    }
}

class PresentationProviderTool : Models.Tools.ProviderTool {
    public PresentationProviderTool (Models.Group group, Models.Providers.ProviderDefinition definition) {
        base.with_catalog (definition,
            Providers.Sources.ReleaseSourceRegistry.create (definition.source_type),
            group, definition.get_install_layout (group.launcher.tool_target_family_id));
        // Two compatible choices; the newest release has no downloadable asset.
        variants.clear ();
        variants.add (new Models.Variant ("default", "Standard", "", true));
        variants.add (new Models.Variant ("alternate", "Alternate", "", false));
        var missing = new Models.Release ("3.0", "", "",
            new Models.Assets.Asset ("missing.tar.gz", ""), "");
        var available = new Models.Release ("2.0", "", "",
            new Models.Assets.Asset ("fixture.tar.gz", "https://example.test/fixture.tar.gz"), "");
        available.variants.add (new Models.Variant ("default", "Standard", "", true,
            "https://example.test/fixture.tar.gz"));
        available.variants.add (new Models.Variant ("alternate", "Alternate", "", false,
            "https://example.test/alternate.tar.gz"));
        var catalog = new Models.ReleaseCatalog.with_static_release (missing);
        catalog.releases.add (missing);
        catalog.releases.add (available);
        initialize_release_catalog (catalog);
    }
}

class PresentationSarekTool : Models.Tools.ProviderTool {
    public PresentationSarekTool (Models.Group group) {
        var definition = new Models.Providers.ProviderRegistry ().get_by_id ("dxvk-sarek");
        base.with_catalog (definition, new Providers.Sources.GitHubReleaseSource (),
            group, definition.get_install_layout ("default"));
        var releases = new Providers.Sources.GitHubReleaseSource ().parse_response (definition,
            Utils.Filesystem.get_file_content (Path.build_filename (
                Environment.get_variable ("PROTONPLUS_TEST_FIXTURES") ?? "fixtures",
                "providers", "github", "sarek.json")), 1, 25).require_page ().releases;
        var catalog = new Models.ReleaseCatalog.with_static_release (releases[0]);
        catalog.releases.add_all (releases);
        initialize_release_catalog (catalog);
    }
}

class OfflineReleaseSource : Object, Providers.Sources.ReleaseSource {
    public uint requests { get; private set; }

    public async Models.Tools.ReleasePageResult fetch_page (
        Models.Providers.ProviderDefinition definition, int requested_page, int limit
    ) {
        requests++;
        return Models.Tools.ReleasePageResult.failure (ReturnCode.INVALID_DATA);
    }
}

class OfflineToolsLauncher : Models.Launcher {
    public string? used_tool_name { get; set; }

    public OfflineToolsLauncher (string root) {
        base ("Offline fixture", InstallationTypes.SYSTEM, "", { root }, "offline-fixture");
    }

    public override Models.SteamRestartTarget? get_steam_restart_target () {
        return Models.SteamRestartTarget.for_native (directory);
    }

    public override int get_compatibility_tool_usage_count (string compatibility_tool_name) {
        return used_tool_name == compatibility_tool_name ? 1 : 0;
    }
}

class OfflineToolsProcessQuery : Object, Services.CompatibilityProcessQueryBackend {
    public async Services.CompatibilityProcessInspectionResult inspect_processes () {
        return Services.CompatibilityProcessInspectionResult.clear ();
    }
}

class OfflineToolsReceiptRecorder : Object, Services.SteamChangeRecorder {
    public Models.SteamChangeReceipt? receipt { get; private set; }

    public Services.SteamRestartRecordResult record (Models.SteamChangeReceipt receipt) {
        this.receipt = receipt;
        return Services.SteamRestartRecordResult.ADDED;
    }
}

Gtk.MenuButton? find_release_actions (Gtk.Widget widget) {
    if (widget is Gtk.MenuButton && ((Gtk.MenuButton) widget).icon_name == "view-more-symbolic")
        return (Gtk.MenuButton) widget;
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var found = find_release_actions (child);
        if (found != null)
            return found;
    }
    return null;
}

void check_sarek_build_choices (Models.Group group) {
    var tool = new PresentationSarekTool (group);
    group.tools = new Gee.LinkedList<Models.Tool> ();
    group.tools.add (tool);
    var box = new Widgets.Tools.ReleasesBox ();
    var group_box = new Widgets.Tools.GroupBox (group);
    group_box.expand_tool (tool);
    group_box.attach_release_section (tool, box);
    var window = group_fixture_window (group_box, 400, 500);
    window.present ();
    bool loaded = false;
    box.set_selected_tool.begin (tool, (obj, res) => { loaded = box.set_selected_tool.end (res); });
    settle ();
    var rows = new Gee.ArrayList<Widgets.Tools.ReleaseRow> ();
    collect_rows (box, rows);
    assert (loaded && rows.size == 6);
    assert (!find_build_selector (box).visible);
    assert (!box.variant_box.get_mapped ());
    assert (rows[1].subtitle.contains ("Default"));
    assert (rows[4].subtitle.contains ("dyasync"));
    assert (rows[5].subtitle.contains ("Async"));
    assert (!find_build_selector (rows[1]).get_mapped ());
    assert (!find_build_selector (rows[4]).get_mapped ());
    var builds = find_build_selector (rows[5]);
    assert (builds != null && builds.get_mapped () && builds.model.get_n_items () == 2);
    assert (((Gtk.StringObject) builds.model.get_item (0)).string == "Async");
    assert (((Gtk.StringObject) builds.model.get_item (1)).string == "Standard");
    var legacy = rows[5].get_data<Services.InstallJob> ("job");
    var original_path = legacy.install_location;
    assert (rows[5].grab_focus ());
    assert (rows[5].controller_focus_direction (rows[5], Utils.ControllerNavigationDirection.RIGHT));
    var focused = window.get_focus ();
    assert (focused == builds || (focused != null && focused.is_ancestor (builds)));
    assert (rows[5].controller_activate (focused));
    settle ();
    var async_description = find_label (builds, "Build with asynchronous shader compilation.");
    var standard_description = find_label (builds, "Standard build for this release.");
    assert (async_description != null && async_description.get_mapped () && standard_description != null);
    var async_check = async_description.get_parent ().get_next_sibling ();
    var standard_check = standard_description.get_parent ().get_next_sibling ();
    var popup_list = async_description.get_ancestor (typeof (Gtk.ListView)) as Gtk.ListView;
    assert (popup_list != null && async_check.visible && !standard_check.visible);
    assert (popup_list.model.select_item (1, true));
    assert (builds.selected == 0 && async_check.visible && !standard_check.visible);
    builds.activate ();
    builds.selected = 1;
    settle ();
    assert (legacy.selected_variant_id == "non-async");
    assert (legacy.install_location == original_path + "-Standard");
    assert (legacy.selected_asset.download_url == legacy.release.variants[1].download_url);
    assert (rows[5].controller_focus_direction (builds, Utils.ControllerNavigationDirection.RIGHT));
    assert (window.get_focus () == find_button (rows[5], "Install"));
    assert (rows[5].subtitle.contains ("Standard"));
    assert (rows[4].get_data<Services.InstallJob> ("job").selected_variant_name == "dyasync");
    assert (rows[0].get_data<Services.InstallJob> ("job").selected_variant_name == "Default");
    legacy.set ("state", Services.InstallJob.State.BUSY_INSTALLING);
    assert (!builds.get_mapped ());
    builds.selected = 0;
    assert (legacy.selected_variant_id == "non-async");
    legacy.set ("state", Services.InstallJob.State.NOT_INSTALLED);
    assert (tool.variants.size == 2 && tool.release_catalog.releases[4].variants.size == 2);
    int minimum_width;
    group_box.measure (Gtk.Orientation.HORIZONTAL, -1, out minimum_width, null, null, null);
    assert (minimum_width <= 400);
    settle ();
    snapshot (window, "sarek-release-variants");
    close_fixture_window (window);
}

Gtk.DropDown? find_build_selector (Gtk.Widget widget) {
    if (widget is Gtk.DropDown)
        return (Gtk.DropDown) widget;
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var found = find_build_selector (child);
        if (found != null)
            return found;
    }
    return null;
}

Adw.Window fixture_window (Gtk.Widget content, int width, int height) {
    // A compositor may tile or maximize the toplevel. Constrain the content
    // viewport so layout assertions still exercise the requested logical width.
    var viewport = new Adw.Clamp () {
        maximum_size = width,
        tightening_threshold = width,
        child = content
    };
    return new Adw.Window () {
        content = viewport, default_width = width, default_height = height
    };
}

Adw.Window group_fixture_window (Widgets.Tools.GroupBox group, int width, int height) {
    return fixture_window (new Gtk.ScrolledWindow () {
        child = new Gtk.Viewport (null, null) { child = group, scroll_to_focus = true },
        hscrollbar_policy = Gtk.PolicyType.NEVER
    }, width, height);
}

void close_fixture_window (Adw.Window window) {
    var clamp = (Adw.Clamp) window.content;
    var scroll = clamp.child as Gtk.ScrolledWindow;
    var viewport = scroll?.child as Gtk.Viewport;
    if (viewport != null)
        viewport.child = null;
    clamp.child = null;
    window.destroy ();
}

void remove_fixture_directory (string path) {
    var loop = new MainLoop ();
    bool removed = false;
    Utils.Filesystem.delete_directory.begin (path, (obj, result) => {
        removed = Utils.Filesystem.delete_directory.end (result);
        loop.quit ();
    });
    loop.run ();
    assert (removed);
}

void check_build_choices (Models.Group group) {
    Globals.CPU_CAPABILITIES = new Models.CpuCapabilities (Models.CpuArchitecture.X86_64);
    var definition = new Models.Providers.ProviderRegistry ().get_by_id ("proton-ge");
    var tool = new PresentationProviderTool (group, definition);
    group.tools = new Gee.LinkedList<Models.Tool> ();
    group.tools.add (tool);
    var box = new Widgets.Tools.ReleasesBox ();
    var group_box = new Widgets.Tools.GroupBox (group);
    group_box.expand_tool (tool);
    group_box.attach_release_section (tool, box);
    var window = group_fixture_window (group_box, 600, 400);
    window.present ();
    bool loaded = false;
    box.set_selected_tool.begin (tool, (obj, res) => { loaded = box.set_selected_tool.end (res); });
    settle ();
    var rows = new Gee.ArrayList<Widgets.Tools.ReleaseRow> ();
    collect_rows (box, rows);
    assert (loaded && rows.size == 3);
    assert (find_label (group_box, "Recommended") == null);
    assert (rows[0].get_child_visible () && rows[1].get_child_visible ());
    assert (rows[2].get_mapped ());
    assert (!find_button (rows[2], "Install").has_css_class ("suggested-action"));
    assert (!find_build_selector (rows[2]).get_mapped ());
    var build = find_build_selector (box);
    assert (build != null && build.visible);
    assert (build.get_mapped ());
    assert (box.variant_box.get_mapped ());
    build.selected = 1;
    settle ();
    var job = rows[2].get_data<Services.InstallJob> ("job");
    assert (job.selected_variant_id == "alternate");
    assert (tool.variants.size == 2 && tool.release_catalog.releases.size == 2);
    assert (tool.release_catalog.releases[1].variants.size == 2);
    close_fixture_window (window);
}

void collect_rows (Gtk.Widget widget, Gee.ArrayList<Widgets.Tools.ReleaseRow> rows) {
    if (widget is Widgets.Tools.ReleaseRow)
        rows.add ((Widgets.Tools.ReleaseRow) widget);
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ())
        collect_rows (child, rows);
}

Gtk.Button? find_button (Gtk.Widget widget, string label) {
    if (widget is Gtk.Button && ((Gtk.Button) widget).label == label)
        return (Gtk.Button) widget;
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var found = find_button (child, label);
        if (found != null)
            return found;
    }
    return null;
}

Gtk.ToggleButton? find_toggle (Gtk.Widget widget, string label) {
    if (widget is Gtk.ToggleButton && ((Gtk.ToggleButton) widget).label == label)
        return (Gtk.ToggleButton) widget;
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var found = find_toggle (child, label);
        if (found != null)
            return found;
    }
    return null;
}

Gtk.Label? find_label (Gtk.Widget widget, string text) {
    if (widget is Gtk.Label && ((Gtk.Label) widget).label == text)
        return (Gtk.Label) widget;
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var found = find_label (child, text);
        if (found != null)
            return found;
    }
    return null;
}

void check_tool_heading (Widgets.Tools.GroupBox group_box, Widgets.Tools.ReleasesBox box) {
    var row = group_box.get_expanded_row ();
    var actions = box.actions_button;
    assert (actions.is_ancestor (row) && !actions.is_ancestor (box));
    var state = row.get_data<Gtk.Label> ("state-label");
    // Exercise the layout of an installed status without touching tool storage.
    state.label = "Installed";
    state.visible = true;
    state.get_parent ().visible = true;
    settle ();
    assert (state.has_css_class ("tool-metadata-pill"));
    var description = find_label (row, "Run Windows games on Linux");
    Graphene.Rect description_bounds, state_bounds;
    assert (description.compute_bounds (row, out description_bounds));
    assert (state.compute_bounds (row, out state_bounds));
    assert (state_bounds.origin.y >= description_bounds.origin.y + description_bounds.size.height);
    assert (Math.fabs (state_bounds.origin.x - description_bounds.origin.x) < 1.0);
}

Widgets.Tools.GroupBox? find_group_box (Gtk.Widget widget, Models.Tool tool) {
    var group = widget as Widgets.Tools.GroupBox;
    if (group != null && group.contains_tool (tool))
        return group;
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var found = find_group_box (child, tool);
        if (found != null)
            return found;
    }
    return null;
}

void check_inline_transitions (Models.Launcher launcher, Models.Group group) {
    var first = new PresentationFixtureTool (group);
    var second = new PresentationFixtureTool (group);
    second.title = "Second Fixture";
    group.tools = new Gee.LinkedList<Models.Tool> ();
    group.tools.add (first);
    group.tools.add (second);
    launcher.groups = { group };
    var page = new Widgets.Tools.Box ();
    page.set_selected_launcher (launcher);
    var window = fixture_window (page, 600, 500);
    window.present ();
    var group_box = find_group_box (page, first);
    assert (group_box != null);
    assert (group_box.expand_tool (first));
    settle ();
    var first_row = (Adw.ExpanderRow) group_box.get_expanded_row ();
    var host = first_row.get_data<Gtk.Box> ("inline-release-host");
    var releases = (Widgets.Tools.ReleasesBox) host.get_first_child ();
    var menu = releases.actions_button;
    assert (menu.is_ancestor (first_row) && !menu.is_ancestor (releases));
    assert (releases.is_showing_tool (first));
    assert (page.get_controller_page_id () == "tools:groups");

    assert (group_box.expand_tool (second));
    settle ();
    assert (!first_row.expanded);
    assert (releases.is_showing_tool (second));
    assert (menu.is_ancestor (group_box.get_expanded_row ()) && menu.get_visible ());
    assert (page.controller_navigate_back ());
    settle ();
    assert (group_box.get_expanded_row () == null);
    assert (!menu.get_visible () && menu.get_parent () == null);

    assert (group_box.expand_tool (first));
    settle ();
    page.current_filter = Widgets.Tools.Filter.INSTALLED;
    settle ();
    assert (group_box.get_expanded_row () == null);
    assert (!releases.is_showing_tool (first));
    page.current_filter = Widgets.Tools.Filter.ALL;
    assert (group_box.expand_tool (second));
    settle ();
    page.set_selected_launcher (launcher);
    settle ();
    assert (!releases.is_showing_tool (second));
    close_fixture_window (window);
}

void check_niche_tool_visibility (string root, Models.Launcher launcher, Models.Group group) {
    try {
        var fixtures = Environment.get_variable ("PROTONPLUS_TEST_FIXTURES") ?? "fixtures";
        var data = Path.build_filename (fixtures, "..", "..", "data");
        var command = new Subprocess (SubprocessFlags.NONE, "glib-compile-schemas", "--targetdir", root, data);
        assert (command.wait_check ());
        var source = new SettingsSchemaSource.from_directory (root, null, false);
        Globals.SETTINGS = new Settings.full (source.lookup ("com.vysp3r.ProtonPlus.State", false), null, null);
    } catch (Error e) {
        error ("Could not load the preferences schema: %s", e.message);
    }

    var registry = new Models.Providers.ProviderRegistry ();
    var anime = Models.Providers.ProviderCatalog.create_tool (registry.get_by_id ("proton-anime"), group);
    var hevc = Models.Providers.ProviderCatalog.create_tool (registry.get_by_id ("proton-hevc"), group);
    var boxtron = Models.Providers.ProviderCatalog.create_tool (registry.get_by_id ("boxtron"), group);
    var tinkergame = new Models.Tools.TinkerGame (group, new OfflineReleaseSource ());
    group.tools = new Gee.LinkedList<Models.Tool> ();
    group.tools.add (new PresentationFixtureTool (group));
    group.tools.add (anime);
    group.tools.add (hevc);
    group.tools.add (boxtron);
    group.tools.add (tinkergame);
    launcher.groups = { group };

    var boxtron_path = Path.build_filename (launcher.get_primary_managed_tool_directory (group), "fixture-boxtron");
    assert (DirUtils.create (boxtron_path, 0700) == 0);
    var metadata = new Utils.Metadata ();
    metadata.provider_id = boxtron.provider_id;
    metadata.tool_id = boxtron.id;
    metadata.launcher_id = launcher.tool_target_id;
    assert (metadata.save (boxtron_path));

    var style_manager = Adw.StyleManager.get_default ();
    var color_scheme = style_manager.color_scheme;
    style_manager.color_scheme = Adw.ColorScheme.FORCE_LIGHT;
    var page = new Widgets.Tools.Box ();
    page.set_selected_launcher (launcher);
    var window = fixture_window (page, 600, 620);
    window.content.add_css_class ("background");
    window.present ();
    settle ();
    var anime_title = find_label (page, anime.title);
    var hevc_title = find_label (page, hevc.title);
    assert (anime_title != null && !anime_title.get_mapped ());
    assert (hevc_title != null && !hevc_title.get_mapped ());
    assert (find_label (page, "Fixture Tool").get_mapped ());
    assert (!find_group_box (page, anime).expand_tool (anime));
    var obsolete_pill = find_label (page, "Obsolete");
    assert (obsolete_pill != null && !obsolete_pill.get_mapped ());
    assert (boxtron.is_installed () && !tinkergame.is_installed ());

    assert (Globals.SETTINGS.set_boolean ("show-legacy-tools", true));
    assert (!anime_title.get_mapped () && !hevc_title.get_mapped ());
    assert (obsolete_pill.get_mapped () && obsolete_pill.has_css_class ("tool-metadata-obsolete"));
    assert (obsolete_pill.get_has_tooltip ());
    assert (Globals.SETTINGS.set_boolean ("show-niche-tools", true));
    settle ();
    assert (anime_title.get_mapped () && hevc_title.get_mapped ());
    var tinker_title = find_label (page, tinkergame.title);
    var tinker_row = (Adw.ExpanderRow) tinker_title.get_ancestor (typeof (Adw.ExpanderRow));
    var obsolete_row = (Adw.ExpanderRow) obsolete_pill.get_ancestor (typeof (Adw.ExpanderRow));
    foreach (var title in new Gtk.Label[] { anime_title, hevc_title }) {
        var tool_row = (Adw.ExpanderRow) title.get_ancestor (typeof (Adw.ExpanderRow));
        var niche_pill = find_label (tool_row, "Niche");
        assert (niche_pill != null && niche_pill.get_mapped () && niche_pill.has_css_class ("tool-metadata-pill"));
        assert (niche_pill.get_has_tooltip ());
        assert (tinker_row.get_index () < tool_row.get_index ());
        assert (tool_row.get_index () < obsolete_row.get_index ());
    }
    snapshot (window, "niche-and-obsolete-pills");
    assert (Globals.SETTINGS.set_boolean ("show-niche-tools", false));
    settle ();
    assert (!anime_title.get_mapped () && !hevc_title.get_mapped ());
    assert (obsolete_pill.get_mapped ());

    close_fixture_window (window);
    page.dispose ();
    style_manager.color_scheme = color_scheme;
    Globals.SETTINGS = null;
}

bool has_release_action (MenuModel menu, string action) {
    for (var index = 0; index < menu.get_n_items (); index++) {
        var item_action = menu.get_item_attribute_value (index, Menu.ATTRIBUTE_ACTION, VariantType.STRING);
        if (item_action != null && item_action.get_string () == action)
            return true;
        var section = menu.get_item_link (index, Menu.LINK_SECTION);
        if (section != null && has_release_action (section, action))
            return true;
    }
    return false;
}

void check_offline_installed_rows (string root) {
    var launcher = new OfflineToolsLauncher (root);
    var group = new Models.Group ("Proton", "", "", launcher, "proton");
    var definition = new Models.Providers.ProviderRegistry ().get_by_id ("proton-ge");
    var source = new OfflineReleaseSource ();
    var tool = new Models.Tools.ProviderTool.with_catalog (definition, source, group,
        definition.get_install_layout (launcher.tool_target_family_id));
    group.tools = new Gee.LinkedList<Models.Tool> ();
    group.tools.add (tool);
    launcher.groups = { group };

    var previous_cache = Globals.CACHE_PATH;
    Globals.CACHE_PATH = Path.build_filename (root, "installed-changelog-cache");
    var cached_release = new Models.Release ("v1", "Cached changelog fixture", "",
        new Models.Assets.Asset ("fixture.tar.gz", "https://example.test/fixture.tar.gz"),
        "https://example.test/releases/v1", null, "cached-upstream-release", "v1");
    var cached_releases = new Gee.LinkedList<Models.Release> ();
    cached_releases.add (cached_release);
    var cache = new Models.ReleaseCatalogCache (tool.id, tool.title);
    var saved = new MainLoop ();
    cache.save.begin (new Models.ReleaseCatalogSnapshot (
        cached_releases, 1, false, new DateTime.now_utc ().add_days (-2).format_iso8601 ()
    ), (object, result) => {
        assert (cache.save.end (result));
        saved.quit ();
    });
    saved.run ();

    var first_path = Path.build_filename (launcher.directory, "A legacy installation path");
    var second_path = Path.build_filename (launcher.directory, "Another installed build");
    foreach (var path in new string[] { first_path, second_path }) {
        assert (DirUtils.create (path, 0700) == 0);
        var metadata = new Utils.Metadata ();
        metadata.provider_id = tool.provider_id;
        metadata.tool_id = tool.id;
        metadata.launcher_id = launcher.tool_target_id;
        metadata.variant_id = path == first_path ? "x86" : "retired-build";
        metadata.release_id = path == first_path ? "cached-upstream-release" : "deleted-upstream-release";
        metadata.tag = "v1";
        metadata.install_mode = "versioned";
        assert (metadata.save (path));
    }

    var page = new Widgets.Tools.Box ();
    page.set_selected_launcher (launcher);
    page.current_filter = Widgets.Tools.Filter.INSTALLED;
    var window = fixture_window (page, 400, 500);
    window.present ();
    var group_box = find_group_box (page, tool);
    assert (group_box != null && group_box.get_expanded_row () == null);
    settle ();
    var installed = find_toggle (page, "Installed");
    var browse = find_toggle (page, "Browse");
    assert (browse != null && installed != null && installed.active && !browse.active);
    assert (installed.get_mapped () && find_button (page, "Update Tools").get_mapped ());

    var rows = new Gee.ArrayList<Widgets.Tools.ReleaseRow> ();
    collect_rows (page, rows);
    assert (source.requests == 0 && tool.release_catalog.releases.is_empty);
    assert (rows.size == 2 && rows[0].get_mapped () && rows[1].get_mapped ());
    var first_job = rows[0].get_data<Services.InstallJob> ("job");
    var second_job = rows[1].get_data<Services.InstallJob> ("job");
    assert (first_job.install_location == first_path && second_job.install_location == second_path);
    assert (rows[0].subtitle.contains ("v1") && rows[1].subtitle.contains ("v1"));
    assert (find_button (rows[0], "Update") == null && find_button (rows[1], "Update") == null);
    assert (first_job.selected_variant_id == "x86" && first_job.selected_variant_name == "x86_64");
    assert (second_job.selected_variant_id == "retired-build");
    assert (first_job.release.upstream_release_id == "cached-upstream-release");
    assert (first_job.release.description == "");
    assert (first_job.operation_id != second_job.operation_id);
    // The installed directory remains actionable even if the browse job
    // cannot describe it with today's release layout.
    second_job.set ("state", Services.InstallJob.State.NOT_INSTALLED);
    foreach (var row in rows) {
        var actions = find_release_actions (row);
        var menu = ((Gtk.PopoverMenu) actions.popover).menu_model;
        assert (has_release_action (menu, "release.open-folder"));
        assert (has_release_action (menu, "release.delete"));
        assert (!has_release_action (menu, "release.update"));
        assert (has_release_action (menu, "release.changelog") == (row == rows[0]));
        assert (has_release_action (menu, "release.open-release-page") == (row == rows[0]));
        assert (!find_build_selector (row).get_mapped ());
        assert (row.grab_focus () && row.controller_activate (row));
        settle ();
        if (row == rows[0]) {
            var dialog = window.get_visible_dialog () as Widgets.Tools.ReleaseChangelogDialog;
            assert (dialog != null && find_label (dialog, "Cached changelog fixture") != null);
            dialog.force_close ();
        } else {
            assert (actions.popover.get_mapped ());
            actions.popdown ();
        }
    }

    assert (rows[1].grab_focus ());
    var recorder = new OfflineToolsReceiptRecorder ();
    Services.InstallationService.instance.configure_steam_change_recorder (recorder);
    Services.InstallationService.instance.configure_compatibility_process_guard (
        new Services.CompatibilityProcessGuard (new OfflineToolsProcessQuery ())
    );
    var loop = new MainLoop ();
    first_job.remove.begin (true, (object, result) => {
        assert (first_job.remove.end (result) == ReturnCode.RUNNER_REMOVED);
        loop.quit ();
    });
    loop.run ();
    Services.InstallationService.reset_lifecycle_configuration_for_tests ();
    assert (!FileUtils.test (first_path, FileTest.EXISTS) && FileUtils.test (second_path, FileTest.IS_DIR));
    assert (recorder.receipt != null && recorder.receipt.kind == Models.SteamChangeKind.COMPATIBILITY_TOOL_REMOVED);
    assert (recorder.receipt.resource_key == first_path);
    settle ();
    rows.clear ();
    collect_rows (page, rows);
    assert (rows.size == 1);
    // Another GUI fixture may own global focus on a shared display.
    assert (rows[0].is_focus ());
    assert (rows[0].get_data<Services.InstallJob> ("job").install_location == second_path);
    remove_fixture_directory (second_path);
    rows[0].get_data<Services.InstallJob> ("job").set ("state", Services.InstallJob.State.NOT_INSTALLED);
    var stale_actions = find_release_actions (rows[0]);
    assert (!stale_actions.visible);
    close_fixture_window (window);
    remove_fixture_directory (Globals.CACHE_PATH);
    Globals.CACHE_PATH = previous_cache;
}

bool focus_is_within (Gtk.Widget widget) {
    var focus = widget.get_root ()?.get_focus ();
    return focus != null && (focus == widget || focus.is_ancestor (widget));
}

void check_tab_between_sections (Widgets.Tools.Box page, Gtk.Widget first, Gtk.Widget next) {
    assert (first.grab_focus ());
    for (var step = 0; step < 8 && !focus_is_within (next); step++)
        assert (page.child_focus (Gtk.DirectionType.TAB_FORWARD));
    assert (focus_is_within (next));
    for (var step = 0; step < 8 && !focus_is_within (first); step++)
        assert (page.child_focus (Gtk.DirectionType.TAB_BACKWARD));
    assert (focus_is_within (first));
}

void check_tools_views_and_latest (string root) {
    var launcher = new OfflineToolsLauncher (root);
    const string proton_description = "Compatibility tools by Valve for running Windows software on Linux.";
    const string dxvk_description = "Direct3D 8, 9, 10 and 11 translation to Vulkan.";
    var proton = new Models.Group ("Proton", proton_description, "", launcher, "proton");
    var wine = new Models.Group ("Wine", "Windows compatibility layer.", "", launcher, "wine");
    var dxvk = new Models.Group ("DXVK", dxvk_description, "", launcher, "dxvk");
    var registry = new Models.Providers.ProviderRegistry ();
    var tool = new PresentationProviderTool (proton, registry.get_by_id ("proton-ge"));
    var newest = tool.release_catalog.releases[0];
    newest.variants.add (new Models.Variant ("default", "Standard", "", true,
        "https://example.test/newest.tar.gz"));
    var wine_tool = new PresentationFixtureTool (wine);
    var dxvk_tool = new PresentationProviderTool (dxvk, registry.get_by_id ("dxvk-doitsujin"));
    proton.tools = new Gee.LinkedList<Models.Tool> ();
    proton.tools.add (tool);
    wine.tools = new Gee.LinkedList<Models.Tool> ();
    wine.tools.add (wine_tool);
    dxvk.tools = new Gee.LinkedList<Models.Tool> ();
    dxvk.tools.add (dxvk_tool);
    launcher.groups = { proton, wine, dxvk };

    var slot = Path.build_filename (root, tool.get_directory_name (tool.title + " Latest", tool.variants[0]));
    assert (DirUtils.create (slot, 0700) == 0);
    var metadata = new Utils.Metadata ();
    metadata.provider_id = tool.provider_id;
    metadata.tool_id = tool.id;
    metadata.launcher_id = launcher.tool_target_id;
    metadata.variant_id = "default";
    metadata.tag = "1.0";
    metadata.install_mode = "latest";
    assert (metadata.save (slot));

    var page = new Widgets.Tools.Box ();
    page.set_selected_launcher (launcher);
    var window = fixture_window (page, 384, 400);
    window.present ();
    settle ();
    var proton_box = find_group_box (page, tool);
    var wine_box = find_group_box (page, wine_tool);
    var dxvk_box = find_group_box (page, dxvk_tool);
    assert (proton_box != null && wine_box != null && dxvk_box != null);
    assert (proton_box.get_next_sibling () == wine_box && wine_box.get_next_sibling () == dxvk_box);
    var scroll = proton_box.get_ancestor (typeof (Gtk.ScrolledWindow)) as Gtk.ScrolledWindow;
    assert (scroll != null && dxvk_box.get_ancestor (typeof (Gtk.ScrolledWindow)) == scroll);

    var browse = find_toggle (page, "Browse");
    var installed = find_toggle (page, "Installed");
    var update_all = find_button (page, "Update Tools");
    assert (browse != null && installed != null && update_all != null);
    assert (browse.active && browse.get_mapped () && installed.get_mapped () && update_all.get_mapped ());
    assert (browse.get_ancestor (typeof (Gtk.ScrolledWindow)) == null);
    foreach (var section in new Gtk.Widget[] { proton_box, wine_box, dxvk_box })
        assert (section.get_mapped ());
    var title = find_label (proton_box, "Proton");
    var subtitle = find_label (proton_box, proton_description);
    assert (title != null && subtitle != null && title.get_mapped () && subtitle.get_mapped ());
    assert (find_label (dxvk_box, dxvk_description).get_mapped ());
    var icon = title.get_parent ().get_prev_sibling () as Gtk.Image;
    assert (icon != null && icon.icon_name == "view-grid-symbolic" && icon.get_mapped ());

    Graphene.Rect title_bounds, browse_bounds, installed_bounds, update_bounds;
    assert (title.compute_bounds (page, out title_bounds));
    assert (browse.compute_bounds (page, out browse_bounds));
    assert (installed.compute_bounds (page, out installed_bounds));
    assert (update_all.compute_bounds (page, out update_bounds));
    assert (update_bounds.origin.y + update_bounds.size.height < title_bounds.origin.y);
    assert (browse_bounds.origin.y == update_bounds.origin.y && installed_bounds.origin.y == update_bounds.origin.y);
    assert (update_bounds.origin.x >= installed_bounds.origin.x + installed_bounds.size.width);
    int minimum_width;
    page.measure (Gtk.Orientation.HORIZONTAL, -1, out minimum_width, null, null, null);
    assert (minimum_width <= 384 && page.get_width () <= 384);
    assert (update_bounds.origin.x + update_bounds.size.width <= page.get_width ());

    assert (page.controller_focus_direction (browse, Utils.ControllerNavigationDirection.RIGHT));
    assert (installed.is_focus ());
    assert (page.controller_focus_direction (installed, Utils.ControllerNavigationDirection.RIGHT));
    assert (update_all.is_focus ());
    var proton_row = proton_box.get_section_focus () as Adw.ExpanderRow;
    var wine_row = wine_box.get_section_focus () as Adw.ExpanderRow;
    var dxvk_row = dxvk_box.get_section_focus () as Adw.ExpanderRow;
    assert (proton_row != null && wine_row != null && dxvk_row != null);
    assert (!proton_row.expanded && !wine_row.expanded && !dxvk_row.expanded);
    settle ();
    snapshot (window, "tools-browse-categories");
    assert (page.controller_focus_direction (update_all, Utils.ControllerNavigationDirection.DOWN));
    assert (focus_is_within (proton_row));
    assert (proton_box.controller_focus_direction (proton_row, Utils.ControllerNavigationDirection.DOWN));
    assert (focus_is_within (wine_row));
    assert (wine_box.controller_focus_direction (wine_row, Utils.ControllerNavigationDirection.DOWN));
    assert (focus_is_within (dxvk_row));
    assert (dxvk_box.controller_focus_direction (dxvk_row, Utils.ControllerNavigationDirection.UP));
    assert (focus_is_within (wine_row));
    check_tab_between_sections (page, proton_row, wine_row);

    // Force the responsive layout at a width below the controls' combined minimum.
    var viewport = (Adw.Clamp) window.content;
    int options_width, update_width;
    browse.get_parent ().measure (Gtk.Orientation.HORIZONTAL, -1, out options_width, null, null, null);
    update_all.measure (Gtk.Orientation.HORIZONTAL, -1, out update_width, null, null, null);
    var wrapped_width = int.max (options_width, update_width) + 32;
    viewport.tightening_threshold = wrapped_width;
    viewport.maximum_size = wrapped_width;
    settle ();
    assert (browse.compute_bounds (page, out browse_bounds));
    assert (update_all.compute_bounds (page, out update_bounds));
    assert (update_bounds.origin.y >= browse_bounds.origin.y + browse_bounds.size.height);
    assert (update_bounds.origin.x + update_bounds.size.width <= page.get_width ());
    assert (page.controller_focus_direction (browse, Utils.ControllerNavigationDirection.DOWN));
    assert (update_all.is_focus ());
    assert (page.controller_focus_direction (update_all, Utils.ControllerNavigationDirection.DOWN));
    assert (focus_is_within (proton_row));
    assert (proton_box.controller_focus_direction (proton_row, Utils.ControllerNavigationDirection.UP));
    assert (update_all.is_focus ());
    viewport.maximum_size = 384;
    viewport.tightening_threshold = 384;
    settle ();

    installed.active = true;
    settle ();
    assert (!wine_box.get_mapped () && !dxvk_box.get_mapped ());
    assert (installed.active && proton_box.get_expanded_row () == null);
    var rows = new Gee.ArrayList<Widgets.Tools.ReleaseRow> ();
    collect_rows (proton_box, rows);
    assert (rows.size == 1 && rows[0].get_mapped ());
    assert (rows[0].title.contains ("Latest (1.0)") && rows[0].subtitle.contains ("Update available: 3.0"));
    assert (find_button (rows[0], "Update").get_mapped ());

    var dxvk_slot = Path.build_filename (root, "Fixture DXVK 2.0");
    assert (DirUtils.create (dxvk_slot, 0700) == 0);
    metadata.provider_id = dxvk_tool.provider_id;
    metadata.tool_id = dxvk_tool.id;
    metadata.tag = "2.0";
    metadata.install_mode = "versioned";
    assert (metadata.save (dxvk_slot));
    dxvk.invalidate_installed_state ();
    settle ();
    assert (proton_box.get_mapped () && dxvk_box.get_mapped () && !wine_box.get_mapped ());
    var proton_build = rows[0];
    var dxvk_build = dxvk_box.get_section_focus () as Widgets.Tools.ReleaseRow;
    assert (dxvk_build != null && dxvk_build.get_mapped () && dxvk_build.subtitle.contains ("2.0"));
    snapshot (window, "tools-installed-categories");
    assert (proton_build.controller_focus_direction (proton_build, Utils.ControllerNavigationDirection.DOWN));
    assert (focus_is_within (dxvk_build));
    assert (dxvk_build.controller_focus_direction (dxvk_build, Utils.ControllerNavigationDirection.UP));
    assert (focus_is_within (proton_build));
    check_tab_between_sections (page, proton_build, dxvk_build);

    browse.active = true;
    assert (proton_box.expand_tool (tool));
    settle ();
    rows.clear ();
    collect_rows (proton_box.get_expanded_row (), rows);
    assert (rows.size == 3);
    assert (rows[0].title == "Latest (1.0)" && rows[0].subtitle.contains ("Update available: 3.0"));
    assert (rows[1].title == "3.0" && rows[1].subtitle.contains ("Stays on this version."));
    assert (!find_build_selector (rows[1]).get_mapped ());
    assert (!find_build_selector (rows[2]).get_mapped ());

    remove_fixture_directory (slot);
    remove_fixture_directory (dxvk_slot);
    proton.invalidate_installed_state ();
    dxvk.invalidate_installed_state ();
    installed.active = true;
    settle ();
    assert (!proton_box.get_mapped () && !wine_box.get_mapped () && !dxvk_box.get_mapped ());
    assert (find_label (page, "No installed tools").get_mapped ());
    var browse_tools = find_button (page, "Browse Tools");
    assert (browse_tools != null && browse_tools.get_mapped ());
    assert (page.controller_focus_direction (installed, Utils.ControllerNavigationDirection.DOWN));
    assert (browse_tools.is_focus ());
    browse_tools.clicked ();
    assert (browse.active && browse.is_focus ());
    page.show_groups_page ();
    assert (proton_box.expand_tool (tool));
    settle ();
    rows.clear ();
    collect_rows (proton_box.get_expanded_row (), rows);
    assert (rows[0].title == "Latest (3.0)");
    assert (rows[0].subtitle.contains ("Eligible for ProtonPlus updates."));
    close_fixture_window (window);
}

void settle () {
    var loop = new MainLoop ();
    Timeout.add (350, () => { loop.quit (); return Source.REMOVE; });
    loop.run ();
}

void check_theme_palettes () {
    var display = Gdk.Display.get_default ();
    var label = new Gtk.Label ("Palette");
    label.add_css_class ("palette-probe");
    var window = fixture_window (label, 360, 200);
    var color_probe = new Gtk.CssProvider ();
    var custom_properties = Gtk.check_version (4, 16, 0) == null && Adw.get_minor_version () >= 6;
    Gtk.StyleContext.add_provider_for_display (display, color_probe, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 2);
    window.present ();

    string[] themes = { "steamos", "oled", "breeze-dark", "breeze-light" };
    string[] colors = { "#171a21", "#000000", "#202326", "#eff0f1" };
    for (var index = 0; index < themes.length; index++) {
        var provider = Utils.ThemeManager.load_stylesheet (themes[index]);
        Gtk.StyleContext.add_provider_for_display (display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1);
        color_probe.load_from_string (custom_properties
            ? ".palette-probe { color: var(--window-bg-color); }"
            : ".palette-probe { color: @window_bg_color; }");
        settle ();
        Gdk.RGBA expected = {};
        assert (expected.parse (colors[index]) && label.get_color ().equal (expected));

        if (custom_properties && themes[index].has_prefix ("breeze-")) {
            color_probe.load_from_string (".palette-probe { color: var(--success-bg-color); }");
            settle ();
            assert (expected.parse ("#27ae60") && label.get_color ().equal (expected));
        }
        Gtk.StyleContext.remove_provider_for_display (display, provider);
    }
    Gtk.StyleContext.remove_provider_for_display (display, color_probe);
    close_fixture_window (window);
}

void snapshot (Gtk.Window window, string name) {
    var directory = Environment.get_variable ("PROTONPLUS_UI_SNAPSHOTS");
    if (directory == null)
        return;
    var content = ((Adw.Clamp) ((Adw.Window) window).content).child;
    var paintable = new Gtk.WidgetPaintable (content);
    var capture = new Gtk.Snapshot ();
    paintable.snapshot (capture, content.get_width (), content.get_height ());
    var node = capture.free_to_node ();
    assert (node != null);
    var texture = window.get_renderer ().render_texture (node, null);
    assert (texture.save_to_png (Path.build_filename (directory, name + ".png")));
}

void check_deferred_controller_popover_registration () {
    var button = new Gtk.MenuButton ();
    Gtk.Popover? popover = new Gtk.Popover ();
    var lifetime = WeakRef (popover);
    button.set_popover (popover);
    assert (!popover.get_visible () && !popover.get_mapped ());

    Widgets.Window.register_popover_for_controller (popover, button);
    uint map_signal = Signal.lookup ("map", typeof (Gtk.Widget));
    assert (Signal.has_handler_pending (popover, map_signal, 0, false));

    button.set_popover (null);
    popover = null;
    assert (lifetime.get () == null);
}

int main (string[] args) {
    string root;
    try { root = DirUtils.make_tmp ("protonplus-presentation-XXXXXX"); }
    catch (Error e) { error ("%s", e.message); }
    // GTK input methods may create their own config files, especially on X11.
    // Keep them inside the fixture and exercise cleanup with a nonempty root.
    var config_root = Path.build_filename (root, "config");
    assert (DirUtils.create_with_parents (config_root, 0700) == 0);
    Environment.set_variable ("XDG_CONFIG_HOME", config_root, true);
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);
    if (!Gtk.init_check ()) {
        remove_fixture_directory (root);
        return 77;
    }
    Adw.init ();
    Gtk.Settings.get_default ().gtk_enable_animations = false;
    check_deferred_controller_popover_registration ();
    check_theme_palettes ();
    var launcher = new Models.Launcher ("Fixture", Models.Launcher.InstallationTypes.SYSTEM,
        "", { root }, "fixture");
    var group = new Models.Group ("Proton", "", "", launcher, "fixture");
    var tool = new PresentationFixtureTool (group);
    group.tools = new Gee.LinkedList<Models.Tool> ();
    group.tools.add (tool);
    var css = Utils.ThemeManager.load_stylesheet ("style");
    Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), css,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    var box = new Widgets.Tools.ReleasesBox ();
    var group_box = new Widgets.Tools.GroupBox (group);
    group_box.expand_tool (tool);
    group_box.attach_release_section (tool, box);
    var window = group_fixture_window (group_box, 600, 400);
    window.present ();
    bool loaded = false;
    box.set_selected_tool.begin (tool, (obj, res) => { loaded = box.set_selected_tool.end (res); });
    settle ();
    assert (loaded);
    assert (box.get_height () < 350);
    check_tool_heading (group_box, box);
    snapshot (window, "adwaita-releases");
    var rows = new Gee.ArrayList<Widgets.Tools.ReleaseRow> ();
    collect_rows (box, rows);
    assert (rows.size == 3);
    assert (rows[0].get_mapped ());
    assert (rows[1].get_child_visible ());
    assert (rows[2].get_child_visible ());
    var install = find_button (rows[0], "Install");
    assert (install != null && !install.has_css_class ("suggested-action"));
    // Every version is visible immediately, including during operations.
    var older_job = rows[1].get_data<Services.InstallJob> ("job");
    older_job.set ("state", Services.InstallJob.State.BUSY_INSTALLING);
    older_job.set ("state", Services.InstallJob.State.NOT_INSTALLED);
    settle ();
    // A failed or canceled operation must not disappear before Retry is usable.
    assert (rows[1].get_child_visible ());
    older_job.set ("state", Services.InstallJob.State.UP_TO_DATE);
    settle ();
    assert (rows[1].get_child_visible ());
    assert (find_button (box, "Other Versions") == null);
    assert (find_button (box, "Load More").get_mapped () == false);
    snapshot (window, "adwaita-expanded");
    assert (tool.release_catalog.releases.size == 3);
    box.filter = Widgets.Tools.Filter.INSTALLED;
    settle ();
    rows.clear ();
    collect_rows (box, rows);
    assert (rows.size == 0);
    box.clear_selected_tool ();
    group_box.attach_release_section (tool, box);
    loaded = false;
    box.filter = Widgets.Tools.Filter.ALL;
    box.set_selected_tool.begin (tool, (obj, res) => { loaded = box.set_selected_tool.end (res); });
    settle ();
    rows.clear ();
    collect_rows (box, rows);
    assert (loaded && rows.size == 3 && rows[2].get_child_visible ());
    foreach (var theme in new string[] { "light", "dark" }) {
        Adw.StyleManager.get_default ().color_scheme = theme == "dark"
            ? Adw.ColorScheme.FORCE_DARK : Adw.ColorScheme.FORCE_LIGHT;
        close_fixture_window (window);
        window = group_fixture_window (group_box, 400, 500);
        window.present ();
        settle ();
        snapshot (window, "adwaita-" + theme);
        var breeze = Utils.ThemeManager.load_stylesheet ("breeze-" + theme);
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), breeze,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1);
        close_fixture_window (window);
        window = group_fixture_window (group_box, 400, 500);
        window.present ();
        settle ();
        snapshot (window, "breeze-" + theme);
        int minimum_width;
        group_box.measure (Gtk.Orientation.HORIZONTAL, -1, out minimum_width, null, null, null);
        assert (minimum_width <= 400);
        assert (group_box.get_width () <= 400 && group_box.get_width () >= 360);
        Gtk.StyleContext.remove_provider_for_display (Gdk.Display.get_default (), breeze);
    }
    close_fixture_window (window);
    check_build_choices (group);
    check_sarek_build_choices (group);
    check_inline_transitions (launcher, group);
    check_offline_installed_rows (root);
    check_tools_views_and_latest (root);
    check_niche_tool_visibility (root, launcher, group);
    remove_fixture_directory (root);
    return 0;
}
