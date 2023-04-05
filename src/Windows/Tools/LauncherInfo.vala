namespace Windows.Tools {
    public class LauncherInfo : Gtk.Box {
        public Gtk.Button btnBack;
        public Gtk.Notebook notebook;
        public Gtk.Notebook parentNotebook;
        public Windows.Tools.ReleaseInstaller releaseInstaller;
        public Windows.Tools.ReleaseInfo releaseInfo;
        public Adw.ToastOverlay toastOverlay;
        public int lastPage;
        public bool installerStartedFromInfoPage;

        Models.Launcher launcher;
        Gtk.Spinner spinner;

        public LauncherInfo (Adw.Leaflet leaflet, Adw.ToastOverlay toastOverlay, Models.Launcher launcher, Gtk.Notebook parentNotebook) {
            //
            this.toastOverlay = toastOverlay;
            this.launcher = launcher;
            this.parentNotebook = parentNotebook;

            //
            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (0);

            //
            btnBack = new Gtk.Button ();
            btnBack.set_icon_name ("go-previous-symbolic");
            btnBack.clicked.connect (() => {
                if (notebook.get_current_page () == 0) {
                    leaflet.get_pages ().select_item (0, true);
                } else if (notebook.get_current_page () > 2) {
                    notebook.set_current_page (0);
                } else if (notebook.get_current_page () == 2 && installerStartedFromInfoPage) {
                    notebook.set_current_page (1);
                } else {
                    notebook.set_current_page (lastPage);
                }
            });

            //
            var headerBar = new Adw.HeaderBar ();
            headerBar.set_centering_policy (Adw.CenteringPolicy.STRICT);
            headerBar.pack_start (btnBack);
            append (headerBar);

            //
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            content.set_margin_bottom (15);
            content.set_margin_top (15);

            //
            var title = new Gtk.Label (launcher.Title);
            title.add_css_class ("title-1");
            content.append (title);

            //
            if (launcher.Description != null) {
                var description = new Gtk.Label (launcher.Description);
                description.set_margin_bottom (10);
                content.append (description);
            } else {
                title.set_margin_bottom (10);
            }

            //
            var group = new Adw.PreferencesGroup ();
            group.set_title (_("Tools"));
            group.set_description (_("Select a tool to proceed"));
            content.append (group);

            //
            spinner = new Gtk.Spinner ();
            group.set_header_suffix (spinner);

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
            notebook.append_page (releaseInfo = new Windows.Tools.ReleaseInfo (notebook), new Gtk.Label ("ReleaseInfo"));
            notebook.append_page (releaseInstaller = new Windows.Tools.ReleaseInstaller (notebook, btnBack), new Gtk.Label ("ReleaseInstaller"));
            append (notebook);

            //
            for (int i = 0; i < launcher.Tools.length (); i++) {
                var tool = launcher.Tools.nth_data (i);

                var position = i + 3;
                var toolInfo = new Windows.Tools.ToolInfo (tool, this);

                var row = new Adw.ActionRow ();
                row.set_title (tool.Title);
                row.set_activatable (true);
                row.activated.connect (() => {
                    notebook.set_current_page (position);
                    toolInfo.Load ();
                });

                notebook.append_page (toolInfo, new Gtk.Label ("ToolInfo_" + tool.Title));
                group.add (row);
            }
        }
    }
}
