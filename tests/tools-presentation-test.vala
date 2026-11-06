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
    var window = new Adw.Window () { content = group_box, default_width = 600, default_height = 400 };
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
    var build = find_build_selector (box);
    assert (build != null && build.visible);
    assert (build.get_mapped ());
    build.selected = 1;
    settle ();
    var job = rows[2].get_data<Services.InstallJob> ("job");
    assert (job.selected_variant_id == "alternate");
    assert (tool.variants.size == 2 && tool.release_catalog.releases.size == 2);
    assert (tool.release_catalog.releases[1].variants.size == 2);
    window.destroy ();
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
    var actions = row.get_data<Gtk.MenuButton> ("tool-actions-button");
    assert (actions.get_parent () == box.variant_box);
    var state = row.get_data<Gtk.Label> ("state-label");
    // Exercise the layout of an installed status without touching tool storage.
    state.label = "Installed";
    state.visible = true;
    state.get_parent ().visible = true;
    settle ();
    var description = find_label (row, "Run Windows games on Linux");
    Graphene.Rect description_bounds, state_bounds;
    assert (description.compute_bounds (row, out description_bounds));
    assert (state.compute_bounds (row, out state_bounds));
    assert (state_bounds.origin.y >= description_bounds.origin.y + description_bounds.size.height);
    assert (Math.fabs (state_bounds.origin.x - description_bounds.origin.x) < 1.0);
}

void settle () {
    var loop = new MainLoop ();
    Timeout.add (350, () => { loop.quit (); return Source.REMOVE; });
    loop.run ();
}

void snapshot (Gtk.Window window, string name) {
    var directory = Environment.get_variable ("PROTONPLUS_UI_SNAPSHOTS");
    if (directory == null)
        return;
    var paintable = new Gtk.WidgetPaintable (window);
    var capture = new Gtk.Snapshot ();
    paintable.snapshot (capture, window.get_width (), window.get_height ());
    var node = capture.free_to_node ();
    assert (node != null);
    var texture = window.get_renderer ().render_texture (node, null);
    assert (texture.save_to_png (Path.build_filename (directory, name + ".png")));
}

int main (string[] args) {
    string root;
    try { root = DirUtils.make_tmp ("protonplus-presentation-XXXXXX"); }
    catch (Error e) { error ("%s", e.message); }
    Environment.set_variable ("XDG_CONFIG_HOME", root, true);
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);
    if (!Gtk.init_check ())
        return 77;
    Adw.init ();
    Gtk.Settings.get_default ().gtk_enable_animations = false;
    var launcher = new Models.Launcher ("Fixture", Models.Launcher.InstallationTypes.SYSTEM,
        "", { root }, "fixture");
    var group = new Models.Group ("Proton", "", "", launcher, "fixture");
    var tool = new PresentationFixtureTool (group);
    group.tools = new Gee.LinkedList<Models.Tool> ();
    group.tools.add (tool);
    var css = new Gtk.CssProvider ();
    css.load_from_resource ("/com/vysp3r/ProtonPlus/style.css");
    Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), css,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    var box = new Widgets.Tools.ReleasesBox ();
    var group_box = new Widgets.Tools.GroupBox (group);
    group_box.expand_tool (tool);
    group_box.attach_release_section (tool, box);
    var window = new Adw.Window () { content = group_box, default_width = 600, default_height = 400 };
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
    assert (!rows[0].get_child_visible ());
    assert (rows[1].get_child_visible ());
    assert (!rows[2].get_child_visible ());
    box.clear_selected_tool ();
    group_box.attach_release_section (tool, box);
    loaded = false;
    box.filter = Widgets.Tools.Filter.ALL;
    box.set_selected_tool.begin (tool, (obj, res) => { loaded = box.set_selected_tool.end (res); });
    settle ();
    rows.clear ();
    collect_rows (box, rows);
    assert (loaded && rows.size == 3 && rows[2].get_child_visible ());
    var breeze = new Gtk.CssProvider ();
    foreach (var theme in new string[] { "light", "dark" }) {
        Adw.StyleManager.get_default ().color_scheme = theme == "dark"
            ? Adw.ColorScheme.FORCE_DARK : Adw.ColorScheme.FORCE_LIGHT;
        window.content = null;
        window.destroy ();
        window = new Adw.Window () { content = group_box, default_width = 400, default_height = 500 };
        window.present ();
        settle ();
        snapshot (window, "adwaita-" + theme);
        breeze.load_from_resource ("/com/vysp3r/ProtonPlus/breeze-" + theme + ".css");
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), breeze,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1);
        window.content = null;
        window.destroy ();
        window = new Adw.Window () { content = group_box, default_width = 400, default_height = 500 };
        window.present ();
        settle ();
        snapshot (window, "breeze-" + theme);
        assert (window.get_width () <= 400 && window.get_width () >= 360);
        Gtk.StyleContext.remove_provider_for_display (Gdk.Display.get_default (), breeze);
    }
    window.destroy ();
    check_build_choices (group);
    assert (DirUtils.remove (root) == 0);
    return 0;
}
