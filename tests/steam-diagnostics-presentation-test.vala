using ProtonPlus;

class OfflineAwacySource : Object, Models.Games.AwacyGameSource {
    public async Gee.HashMap<uint, Models.Games.Steam.AwacyGame?>? load (Cancellable? cancellable) {
        return new Gee.HashMap<uint, Models.Games.Steam.AwacyGame?> ();
    }
}

class SteamFixture : Object {
    public string root;
    public Models.Launchers.Steam steam;

    public SteamFixture (Models.Launcher.InstallationTypes type, bool broken) {
        try {
            root = DirUtils.make_tmp ("protonplus-steam-presentation-XXXXXX");
            assert (DirUtils.create_with_parents (Path.build_filename (root, "config"), 0700) == 0);
            assert (DirUtils.create_with_parents (Path.build_filename (root, "steamapps"), 0700) == 0);
            FileUtils.set_contents (Path.build_filename (root, "config/config.vdf"),
                "\"InstallConfigStore\" { \"Software\" { \"Valve\" { \"Steam\" { } } } }");
            FileUtils.set_contents (Path.build_filename (root, "steamapps/libraryfolders.vdf"),
                "\"libraryfolders\" { \"0\" { \"path\" \"%s\" \"apps\" { } } }".printf (root));
            var absent = Path.build_filename (root, "absent-tools");
            steam = new Models.Launchers.Steam (type,
                new Models.Games.AwacyGameCatalog (new OfflineAwacySource (), 0),
                new Models.SteamCompatibilityToolDiscovery (type, false, absent, absent, {}));
            steam.directory = root;
            if (broken)
                fail ();
            reload ();
        } catch (FileError error) {
            assert_not_reached ();
        }
    }

    public void fail (bool multiple = false) {
        try {
            assert (DirUtils.create_with_parents (Path.build_filename (root, "logs"), 0700) == 0);
            var prefix = new DateTime.now_local ().format ("[%Y-%m-%d %H:%M:%S] ");
            FileUtils.set_contents (Path.build_filename (root, "logs/compat_log.txt"),
                prefix + "Tool 4183110 \"Runtime <test>&\" unsupported version 0.\n"
                + (multiple ? prefix + "Failed to load manifest for tool 1493710!\n" : ""));
        } catch (FileError error) {
            assert_not_reached ();
        }
    }

    public void recover () {
        assert (FileUtils.remove (Path.build_filename (root, "logs/compat_log.txt")) == 0);
        reload ();
    }

    public void reload () {
        var loop = new MainLoop ();
        var completed = false;
        steam.load_game_library.begin ((obj, result) => {
            assert (steam.load_game_library.end (result));
            completed = true;
            if (loop.is_running ())
                loop.quit ();
        });
        if (!completed)
            loop.run ();
    }

    public void clear () {
        var loop = new MainLoop ();
        Utils.Filesystem.delete_directory.begin (root, (obj, result) => {
            assert (Utils.Filesystem.delete_directory.end (result));
            loop.quit ();
        });
        loop.run ();
    }
}

void settle () {
    var loop = new MainLoop ();
    Timeout.add (100, () => { loop.quit (); return Source.REMOVE; });
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
    if (!Gtk.init_check ())
        return 77;
    Adw.init ();
    Gtk.Settings.get_default ().gtk_enable_animations = false;
    var native = new SteamFixture (Models.Launcher.InstallationTypes.SYSTEM, false);
    var flatpak = new SteamFixture (Models.Launcher.InstallationTypes.FLATPAK, true);
    var snap = new SteamFixture (Models.Launcher.InstallationTypes.SNAP, true);
    var warning = new Widgets.Main.SteamRepairBanner ();
    var banner = (Adw.Banner) warning.get_first_child ();
    var dismiss = (Gtk.Button) warning.get_last_child ();
    var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    content.append (new Adw.HeaderBar ());
    content.append (warning);
    content.append (new Gtk.Box (Gtk.Orientation.VERTICAL, 0) { vexpand = true });
    var window = new Adw.Window () { default_width = 800, default_height = 600, content = content };
    window.present ();

    warning.set_launcher (native.steam);
    assert (!warning.visible);
    warning.set_launcher (flatpak.steam);
    assert (warning.visible);
    assert (banner.title.contains ("Flatpak"));
    assert (banner.title.contains ("Runtime <test>&"));
    assert (!banner.use_markup);
    Models.Launchers.Steam? requested = null;
    warning.guidance_requested.connect ((steam) => requested = steam);
    banner.button_clicked ();
    assert (requested == flatpak.steam);

    dismiss.clicked ();
    assert (!warning.visible);
    warning.set_launcher (snap.steam);
    assert (warning.visible);
    assert (banner.title.contains ("Snap"));
    snap.fail (true);
    snap.reload ();
    assert (banner.title.contains ("2 tools"));
    warning.set_launcher (flatpak.steam);
    assert (!warning.visible);
    flatpak.recover ();
    assert (!warning.visible);
    flatpak.fail ();
    flatpak.reload ();
    assert (warning.visible);

    var dialog = new Widgets.Main.SteamRepairGuideDialog (flatpak.steam);
    assert (dialog.body.contains (flatpak.root));
    assert (!dialog.body.contains (snap.root));
    assert (dialog.body.contains ("Runtime <test>&"));
    assert (!dialog.body_use_markup);
    assert (dialog.has_response ("guide"));
    assert (dialog.default_response == "close");
    dialog.present (window);
    settle ();
    snapshot (window, "steam-diagnostics");
    dialog.close ();
    settle ();
    // The banner's requested width must fit the supported narrow viewport.
    int minimum;
    int natural;
    warning.measure (Gtk.Orientation.HORIZONTAL, -1, out minimum, out natural, null, null);
    assert (minimum <= 360);
    window.default_width = 360;
    dialog = new Widgets.Main.SteamRepairGuideDialog (flatpak.steam);
    dialog.present (window);
    settle ();
    snapshot (window, "steam-diagnostics-narrow");
    dialog.close ();
    warning.set_launcher (native.steam);
    assert (!warning.visible);
    // An old launcher's update must not change the newly selected banner.
    flatpak.reload ();
    assert (!warning.visible);
    warning.set_launcher (null);
    assert (!warning.visible);
    warning.detach ();
    window.destroy ();
    native.clear ();
    flatpak.clear ();
    snap.clear ();
    print ("Steam diagnostic selection, dismissal, refresh, plain text, and read-only explanation passed\n");
    return 0;
}
