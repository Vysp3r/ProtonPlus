namespace Windows.Tools {
    public class LauncherInfo : Gtk.Box {
        public Gtk.Button btnBack;

        Windows.Tools.ReleaseInstaller releaseInstaller;
        Windows.Tools.ReleaseInfo releaseInfo;
        Models.Launcher launcher;
        Gtk.Box content;
        Gtk.Notebook notebook;
        bool done = false;

        public LauncherInfo (Adw.Leaflet leaflet, Models.Launcher launcher) {
            //
            this.launcher = launcher;

            //
            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (0);

            //
            btnBack = new Gtk.Button ();
            btnBack.set_icon_name ("go-previous-symbolic");
            btnBack.clicked.connect (() => {
                if (notebook.get_current_page () == 0) leaflet.get_pages ().select_item (0, true);
                if (notebook.get_current_page () == 1) notebook.set_current_page (0);
            });

            //
            var headerBar = new Adw.HeaderBar ();
            headerBar.set_centering_policy (Adw.CenteringPolicy.STRICT);
            headerBar.pack_start (btnBack);
            append (headerBar);

            //
            content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            content.set_margin_bottom (15);
            content.set_margin_top (15);

            // initializeContent ();

            //
            var clamp = new Adw.Clamp ();
            clamp.set_maximum_size (700);
            clamp.set_child (content);

            //
            var viewport = new Gtk.Viewport (null, null);
            viewport.set_child (clamp);

            //
            var scrolledWindow = new Gtk.ScrolledWindow ();
            scrolledWindow.set_child (viewport);
            scrolledWindow.set_vexpand (true);

            //
            notebook = new Gtk.Notebook ();
            notebook.set_show_tabs (false);
            notebook.append_page (scrolledWindow, new Gtk.Label ("Main"));
            notebook.append_page (releaseInfo = new Windows.Tools.ReleaseInfo (notebook, this), new Gtk.Label ("ReleaseInfo"));
            notebook.append_page (releaseInstaller = new Windows.Tools.ReleaseInstaller (notebook, btnBack), new Gtk.Label ("ReleaseInstaller"));
            append (notebook);

            //
            new Thread<void> ("getReleases", () => {
                foreach (var tool in launcher.Tools) {
                    // tool.Releases = tool.GetReleases ();
                }
                done = true;
            });

            //
            GLib.Timeout.add (1000, () => {
                if (done) {
                    initializeContent ();
                    return false;
                }

                return true;
            });
        }

        void initializeContent () {
            //
            var group = new Adw.PreferencesGroup ();
            group.set_title (launcher.Title);
            content.append (group);

            //
            foreach (var tool in launcher.Tools) {
                var row = new Adw.ExpanderRow ();
                row.set_title (tool.Title);

                foreach (var release in tool.Releases) {
                    var item = new Adw.ActionRow ();
                    item.set_title (release.Title);
                    item.set_activatable (true);
                    item.activated.connect (() => InfoRelease (release));

                    var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
                    actions.set_margin_end (10);
                    actions.set_valign (Gtk.Align.CENTER);

                    if (release.Installed) {
                        var btnDelete = new Gtk.Button ();
                        btnDelete.add_css_class ("flat");
                        btnDelete.set_icon_name ("user-trash-symbolic");
                        btnDelete.width_request = 25;
                        btnDelete.height_request = 25;
                        btnDelete.set_tooltip_text (_("Delete the tool"));
                        btnDelete.clicked.connect (DeleteRelease);
                        actions.append (btnDelete);
                    } else {
                        var btnInstall = new Gtk.Button ();
                        btnInstall.set_icon_name ("folder-download-symbolic");
                        btnInstall.add_css_class ("flat");
                        btnInstall.width_request = 25;
                        btnInstall.height_request = 25;
                        btnInstall.set_tooltip_text (_("Install the tool"));
                        btnInstall.clicked.connect (InstallRelease);
                        actions.append (btnInstall);
                    }

                    item.add_suffix (actions);

                    var icon = new Gtk.Image.from_icon_name ("go-next-symbolic");
                    item.add_suffix (icon);

                    row.add_row (item);
                }

                group.add (row);
            }
        }

        void InfoRelease (Models.Release release) {
            notebook.set_current_page (1);
            releaseInfo.Load (release);
        }

        public void DeleteRelease () {
        }

        public void InstallRelease () {
            int currentPage = notebook.get_current_page ();
            notebook.set_current_page (2);
            releaseInstaller.Download (currentPage);
        }
    }
}
