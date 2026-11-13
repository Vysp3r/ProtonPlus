using ProtonPlus;

class DownloadFixtureTool : Models.Tool {
    public DownloadFixtureTool (Models.Group group) {
        Object (group: group, title: "Proton-GE with a long compatibility tool name");
    }
}

void settle () {
    var loop = new MainLoop ();
    Timeout.add (200, () => { loop.quit (); return Source.REMOVE; });
    loop.run ();
}

void remove_fixture (string root) {
    var loop = new MainLoop ();
    Utils.Filesystem.delete_directory.begin (root, (obj, result) => {
        assert (Utils.Filesystem.delete_directory.end (result));
        loop.quit ();
    });
    loop.run ();
}

Gtk.Label? find_label (Gtk.Widget widget, string text) {
    if (widget is Gtk.Label && ((Gtk.Label) widget).label.contains (text))
        return (Gtk.Label) widget;
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var found = find_label (child, text);
        if (found != null)
            return found;
    }
    return null;
}

Gtk.Button? find_cancel (Gtk.Widget widget) {
    if (widget is Gtk.Button && ((Gtk.Button) widget).icon_name == "process-stop-symbolic")
        return (Gtk.Button) widget;
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var found = find_cancel (child);
        if (found != null)
            return found;
    }
    return null;
}

Gtk.ProgressBar? find_progress (Gtk.Widget widget) {
    if (widget is Gtk.ProgressBar)
        return (Gtk.ProgressBar) widget;
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var found = find_progress (child);
        if (found != null)
            return found;
    }
    return null;
}

Graphene.Rect bounds_of (Gtk.Widget widget, Gtk.Widget relative_to) {
    Graphene.Rect bounds;
    assert (widget.compute_bounds (relative_to, out bounds));
    return bounds;
}

void check_stacked_layout (Gtk.Widget content, Services.InstallJob job) {
    var title = find_label (content, job.tool.title);
    var version = find_label (content, job.displayed_title);
    assert (title != null && version != null);
    var row = title.get_ancestor (typeof (Gtk.ListBoxRow));
    var cancel = find_cancel (row);
    var progress = find_progress (row);
    assert (cancel != null && progress != null);
    var title_bounds = bounds_of (title, content);
    var version_bounds = bounds_of (version, content);
    var cancel_bounds = bounds_of (cancel, content);
    var progress_bounds = bounds_of (progress, content);
    assert (progress_bounds.size.width >= content.get_width () * 0.85);
    assert (title_bounds.size.width >= progress_bounds.size.width * 0.7);
    assert (Math.fabs (title_bounds.origin.x - progress_bounds.origin.x) < 1);
    assert (Math.fabs (version_bounds.origin.x - title_bounds.origin.x) < 1);
    assert (version_bounds.origin.y >= title_bounds.origin.y + title_bounds.size.height);
    assert (progress_bounds.origin.y >= version_bounds.origin.y + version_bounds.size.height);
    assert (progress_bounds.origin.y >= cancel_bounds.origin.y + cancel_bounds.size.height);
    assert (Math.fabs (cancel_bounds.origin.y - title_bounds.origin.y) < 1);
    assert (Math.fabs (cancel_bounds.origin.x + cancel_bounds.size.width
        - progress_bounds.origin.x - progress_bounds.size.width) < 1);
    assert (title.get_layout ().get_line_count () <= 2);
    assert (version.get_layout ().get_line_count () == 1);
    assert (title.tooltip_text == job.tool.title);
    assert (version.tooltip_text == job.displayed_title);
}

Gtk.Label check_complete_label (Gtk.Widget content, string text) {
    var label = find_label (content, text);
    assert (label != null && label.get_mapped ());
    var layout = label.get_layout ();
    assert (!layout.is_ellipsized ());
    int text_width, text_height;
    layout.get_pixel_size (out text_width, out text_height);
    if (text_width > label.get_width () || text_height > label.get_height ())
        printerr ("Label '%s': text %dx%d, allocation %dx%d\n", label.label,
            text_width, text_height, label.get_width (), label.get_height ());
    assert (text_width <= label.get_width ());
    assert (text_height <= label.get_height ());
    Graphene.Rect bounds;
    assert (label.compute_bounds (content, out bounds));
    assert (bounds.origin.x >= 0 && bounds.origin.y >= 0);
    assert (bounds.origin.x + bounds.size.width <= content.get_width ());
    assert (bounds.origin.y + bounds.size.height <= content.get_height ());
    return label;
}

void snapshot (Gtk.Window window, Gtk.Widget content, string name) {
    var directory = Environment.get_variable ("PROTONPLUS_UI_SNAPSHOTS");
    if (directory == null)
        return;
    var paintable = new Gtk.WidgetPaintable (content);
    var capture = new Gtk.Snapshot ();
    paintable.snapshot (capture, content.get_width (), content.get_height ());
    var node = capture.free_to_node ();
    assert (node != null);
    var texture = window.get_renderer ().render_texture (node, null);
    assert (texture.save_to_png (Path.build_filename (directory, name + ".png")));
}

int main (string[] args) {
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);
    // GNU gettext ignores LANGUAGE in the C locale, including C.UTF-8.
    // Select a supported locale before GTK initializes translation caches.
    string? locale = null;
    foreach (var candidate in new string[] { "de_DE.UTF-8", "en_US.UTF-8", "en_GB.UTF-8" }) {
        locale = Intl.setlocale (LocaleCategory.ALL, candidate);
        if (locale != null)
            break;
    }
    if (locale == null) {
        printerr ("Downloads presentation needs a locale that supports LANGUAGE\n");
        return 77;
    }
    Environment.set_variable ("LC_ALL", locale, true);
    Intl.bindtextdomain (Config.APP_ID, Environment.get_variable ("PROTONPLUS_TEST_LOCALES"));
    Intl.bind_textdomain_codeset (Config.APP_ID, "UTF-8");
    Intl.textdomain (Config.APP_ID);
    // LANGUAGE=de selects the actual catalog, including localized time units.
    assert (_("Remaining time: %s") == "Verbleibende Zeit: %s");
    string root;
    try { root = DirUtils.make_tmp ("protonplus-downloads-presentation-XXXXXX"); }
    catch (FileError e) { error ("%s", e.message); }
    Environment.set_variable ("XDG_CONFIG_HOME", root, true);
    if (!Gtk.init_check ()) {
        remove_fixture (root);
        return 77;
    }
    Adw.init ();
    Gtk.Settings.get_default ().gtk_enable_animations = false;
    var css = new Gtk.CssProvider ();
    css.load_from_resource ("/com/vysp3r/ProtonPlus/style.css");
    Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), css,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

    var launcher = new Models.Launcher ("Fixture", Models.Launcher.InstallationTypes.SYSTEM,
        "", {}, "fixture");
    var group = new Models.Group ("Proton", "", "", launcher, "fixture");
    var tool = new DownloadFixtureTool (group);
    var release = new Models.Release ("GE-Proton11-12 with a long release name", "", "",
        new Models.Assets.Asset ("fixture.tar.gz", "https://example.test/fixture.tar.gz"), "");
    var job = new Services.InstallJob (release, tool);
    job.set ("step", Services.InstallJob.Step.DOWNLOADING);
    var manager = Utils.DownloadManager.instance;
    manager.add_download (job);
    var indicator = new Widgets.Header.DownloadsIndicator ();
    var button = (Gtk.MenuButton) indicator.get_first_child ();
    // Other GUI fixtures may open windows on the same display.
    button.popover.autohide = false;
    var content = button.popover.child;
    var window = new Adw.Window () {
        default_width = 384, default_height = 480,
        content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0)
    };
    ((Gtk.Box) window.content).append (indicator);
    window.present ();
    settle ();

    double[] durations = { -1, 34, 754, 45240, 444445140 };
    string[] etas = { "--", "34 s", "12 min 34 s", "12 h 34 min 0 s", "123456 h 59 min 0 s" };
    var style_manager = Adw.StyleManager.get_for_display (window.get_display ());
    foreach (var theme in new string[] { "light", "dark" }) {
        style_manager.color_scheme = theme == "dark"
            ? Adw.ColorScheme.FORCE_DARK : Adw.ColorScheme.FORCE_LIGHT;
        assert (style_manager.dark == (theme == "dark"));
        foreach (var width in new int[] { 300, 360, 480 }) {
            content.width_request = width;
            button.popup ();
            for (int i = 0; i < durations.length; i++) {
                job.set ("seconds-remaining", durations[i], "speed-kbps", 126361.6,
                    "progress", "63%", "is-percent", true);
                job.progress_updated ();
                settle ();
                assert (content.get_width () <= width);
                check_stacked_layout (content, job);
                var status = check_complete_label (content, "63%");
                var speed = "%s/s".printf (
                    Utils.Filesystem.convert_bytes_to_string ((int64) (job.speed_kbps * 1024)));
                var metrics_text = "%s · %s".printf (speed, etas[i]);
                var metrics = check_complete_label (content, metrics_text);
                assert (metrics.label == metrics_text);
                assert (metrics.tooltip_text == (i == 0 ? "Verbleibende Zeit: --"
                    : "Verbleibende Zeit: %s".printf (etas[i])));
                Graphene.Rect status_bounds, metrics_bounds;
                assert (status.compute_bounds (content, out status_bounds));
                assert (metrics.compute_bounds (content, out metrics_bounds));
                var progress_bounds = bounds_of (find_progress (content), content);
                assert (status_bounds.origin.y >= progress_bounds.origin.y + progress_bounds.size.height);
                assert (Math.fabs (status_bounds.origin.x - progress_bounds.origin.x) < 1);
                assert (metrics_bounds.origin.y >= status_bounds.origin.y + status_bounds.size.height);
                if (i == 2)
                    snapshot (window, button.popover, "downloads-" + theme + "-" + width.to_string ());
            }
            button.popdown ();
            settle ();
        }
    }

    // Very long, literal titles must stay bounded with multiple active jobs.
    var second_tool = new DownloadFixtureTool (group);
    second_tool.title = "A very long compatibility tool name with <literal> & characters "
        + "and enough extra words to exceed two lines even in the wider popover";
    var second_release = new Models.Release ("Another very long release version with <literal> & characters",
        "", "", release.asset, "", 0, "second-release");
    var second_job = new Services.InstallJob (second_release, second_tool);
    second_job.set ("step", Services.InstallJob.Step.DOWNLOADING, "progress", "24%",
        "is-percent", true, "speed-kbps", 2048.0, "seconds-remaining", 934.0);
    job.set ("seconds-remaining", 754.0);
    job.progress_updated ();
    manager.add_download (second_job);
    content.width_request = 360;
    button.popup ();
    settle ();
    check_stacked_layout (content, job);
    check_stacked_layout (content, second_job);
    var long_title = find_label (content, second_tool.title);
    assert (!long_title.use_markup && long_title.get_layout ().is_ellipsized ());
    assert (long_title.get_layout ().get_line_count () == 2);
    snapshot (window, button.popover, "downloads-multiple");
    manager.remove_download (second_job);

    button.popup ();
    job.set ("step", Services.InstallJob.Step.EXTRACTING);
    settle ();
    var unknown_metrics = check_complete_label (content, "-- · --");
    assert (unknown_metrics.tooltip_text == "Verbleibende Zeit: --");

    // Keep the row's navigation and cancellation behavior intact.
    Services.InstallJob? selected = null;
    indicator.download_selected.connect ((selected_job) => selected = selected_job);
    var cancel = find_cancel (content);
    assert (cancel != null && cancel.sensitive);
    var row = (Gtk.ListBoxRow) cancel.get_ancestor (typeof (Gtk.ListBoxRow));
    assert (row.grab_focus ());
    assert (row.is_focus ());
    assert (((Gtk.Widget) row).activate ());
    settle ();
    assert (selected == job && !button.popover.visible);
    selected = null;
    button.popup ();
    settle ();
    // Pointer activation is emitted by the list, while keyboard/controller
    // confirmation activates the focused row through Gtk.Widget.activate().
    ((Gtk.ListBox) row.get_parent ()).row_activated (row);
    settle ();
    assert (selected == job && !button.popover.visible);
    selected = null;
    button.popup ();
    settle ();
    assert (cancel.grab_focus ());
    assert (cancel.is_focus ());
    cancel.clicked ();
    assert (job.canceled && !cancel.sensitive);
    assert (selected == null && button.popover.visible);
    manager.remove_download (job);
    settle ();
    assert (!indicator.visible && !button.popover.visible);
    job.progress_updated ();
    window.destroy ();
    remove_fixture (root);
    print ("Stacked download titles, full-width progress, localized estimates, and row actions passed\n");
    return 0;
}
