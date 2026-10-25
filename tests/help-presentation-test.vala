using ProtonPlus;

void settle () {
    var loop = new MainLoop ();
    Timeout.add (200, () => { loop.quit (); return Source.REMOVE; });
    loop.run ();
}

Gtk.Widget? find (Gtk.Widget root, string text) {
    if (root is Adw.ActionRow && ((Adw.ActionRow) root).title == text)
        return root;
    if (root is Gtk.Button && ((Gtk.Button) root).label == text)
        return root;
    for (var child = root.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var found = find (child, text);
        if (found != null)
            return found;
    }
    return null;
}

void check_read_only (Gtk.Widget root) {
    assert (!(root is Adw.Carousel));
    assert (!(root is Adw.SwitchRow));
    for (var child = root.get_first_child (); child != null; child = child.get_next_sibling ())
        check_read_only (child);
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
    if (!Gtk.init_check ())
        return 77;
    Adw.init ();
    Gtk.Settings.get_default ().gtk_enable_animations = false;
    var window = new Adw.Window () { default_width = 800, default_height = 700 };
    window.present ();
    var welcome = new Widgets.Introduction.Introduction ();
    welcome.present (window);
    settle ();
    check_read_only (welcome);
    assert (find (welcome, "Learn More") != null);
    snapshot (window, "welcome");
    bool welcome_closed = false;
    welcome.closed.connect (() => welcome_closed = true);
    var start = find (welcome, "Get Started") as Gtk.Button;
    assert (start != null);
    start.clicked ();
    settle ();
    assert (welcome_closed);

    var learn_welcome = new Widgets.Introduction.Introduction ();
    bool help_requested = false;
    learn_welcome.help_requested.connect (() => help_requested = true);
    learn_welcome.present (window);
    settle ();
    ((Gtk.Button) find (learn_welcome, "Learn More")).clicked ();
    settle ();
    assert (help_requested);

    var help = new Widgets.Introduction.HelpDialog ();
    help.present (window);
    settle ();
    snapshot (window, "help-topics");
    string[] topics = {
        "Install a Compatibility Tool", "Choose a Tool for a Game", "Update Tools",
        "Use a Controller", "Understand Wine and Proton", "Troubleshooting"
    };
    foreach (var title in topics) {
        var row = find (help, title) as Adw.ActionRow;
        assert (row != null);
        row.activate ();
        settle ();
        assert (help.controller_can_navigate_back ());
        assert (!help.controller_can_switch_page ());
        assert (help.get_controller_initial_focus () is Gtk.ScrolledWindow);
        check_read_only (help);
        if (title == "Install a Compatibility Tool")
            snapshot (window, "help-install");
        assert (help.controller_navigate_back ());
        settle ();
        assert (!help.controller_can_navigate_back ());
        assert (row.has_focus);
    }
    help.close ();
    settle ();

    // Follow each shortcut after the Help surface is dismissed.
    string[] action_topics = { "Update Tools", "Use a Controller", "Troubleshooting" };
    string[] buttons = { "Open Update Preferences", "Open Controller Preferences", "Open Advanced Preferences" };
    string[] pages = { "tools", "general", "advanced" };
    for (int i = 0; i < action_topics.length; i++) {
        var dialog = new Widgets.Introduction.HelpDialog ();
        string? requested = null;
        dialog.preferences_requested.connect ((page) => requested = page);
        dialog.present (window);
        settle ();
        ((Adw.ActionRow) find (dialog, action_topics[i])).activate ();
        settle ();
        ((Gtk.Button) find (dialog, buttons[i])).clicked ();
        settle ();
        assert (requested == pages[i]);
    }
    window.destroy ();

    var narrow = new Adw.Window () { default_width = 360, default_height = 640 };
    narrow.present ();
    var narrow_welcome = new Widgets.Introduction.Introduction ();
    narrow_welcome.present (narrow);
    settle ();
    snapshot (narrow, "welcome-narrow");
    narrow_welcome.close ();
    settle ();
    var narrow_help = new Widgets.Introduction.HelpDialog ();
    narrow_help.present (narrow);
    settle ();
    snapshot (narrow, "help-topics-narrow");
    ((Adw.ActionRow) find (narrow_help, "Choose a Tool for a Game")).activate ();
    settle ();
    snapshot (narrow, "help-topic-narrow");
    narrow_help.close ();
    narrow.destroy ();
    print ("Help navigation, preference shortcuts, and Welcome dismissal passed\n");
    return 0;
}
