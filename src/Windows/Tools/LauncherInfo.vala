namespace Windows.Tools {
    public class LauncherInfo : Gtk.Box {
        public Gtk.Button BtnBack;
        public Gtk.Notebook Notebook;
        public Windows.Tools.ReleaseInstaller ReleaseInstaller;
        public Windows.Tools.ReleaseInfo ReleaseInfo;
        public int LastPage;
        public bool InstallerStartedFromInfoPage;

        Gtk.Spinner spinner;

        public LauncherInfo (Windows.Main mainWindow, Models.Launcher launcher) {
            //
            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (0);

            //
            BtnBack = new Gtk.Button ();
            BtnBack.set_icon_name ("go-previous-symbolic");
            BtnBack.clicked.connect (() => {
                if (Notebook.get_current_page () == 0) {
                    mainWindow.Leaflet.get_pages ().select_item (0, true);
                } else if (Notebook.get_current_page () > 2) {
                    Notebook.set_current_page (0);
                } else if (Notebook.get_current_page () == 2 && InstallerStartedFromInfoPage) {
                    Notebook.set_current_page (1);
                } else {
                    Notebook.set_current_page (LastPage);
                }
            });

            //
            var headerBar = new Adw.HeaderBar ();
            headerBar.set_centering_policy (Adw.CenteringPolicy.STRICT);
            headerBar.pack_start (BtnBack);
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
            Notebook = new Gtk.Notebook ();
            Notebook.set_show_tabs (false);
            Notebook.append_page (scrolledWindow, new Gtk.Label ("Main"));
            Notebook.append_page (ReleaseInfo = new Windows.Tools.ReleaseInfo (), new Gtk.Label ("ReleaseInfo"));
            Notebook.append_page (ReleaseInstaller = new Windows.Tools.ReleaseInstaller (this), new Gtk.Label ("ReleaseInstaller"));
            append (Notebook);

            //
            for (int i = 0; i < launcher.Tools.length (); i++) {
                var tool = launcher.Tools.nth_data (i);

                var position = i + 3;
                var toolInfo = new Windows.Tools.ToolInfo (this, mainWindow, tool);

                var row = new Adw.ActionRow ();
                row.set_title (tool.Title);
                row.set_activatable (true);
                row.activated.connect (() => {
                    Notebook.set_current_page (position);
                    toolInfo.Load ();
                });

                var icon = new Gtk.Image.from_icon_name ("go-next-symbolic");
                row.add_suffix (icon);

                Notebook.append_page (toolInfo, new Gtk.Label ("ToolInfo_" + tool.Title));
                group.add (row);
            }
        }
    }
}
