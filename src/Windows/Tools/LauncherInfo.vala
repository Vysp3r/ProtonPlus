namespace Windows.Tools {
    public class LauncherInfo : Gtk.Box {
        public Gtk.Button btnBack;

        Windows.Tools.ReleaseInstaller releaseInstaller;
        Windows.Tools.ReleaseInfo releaseInfo;
        Adw.ToastOverlay toastOverlay;
        Models.Launcher launcher;
        Gtk.Notebook notebook;
        Gtk.Notebook parentNotebook;
        Gtk.Spinner spinner;
        GLib.List<Adw.ExpanderRow> toolRows;
        bool loaded = false;
        bool done = false;
        bool error = false;
        int lastPage;

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
                if (notebook.get_current_page () == 0) leaflet.get_pages ().select_item (0, true);
                if (notebook.get_current_page () == 1) notebook.set_current_page (0);
                if (notebook.get_current_page () == 2) {
                    if (lastPage == 0) notebook.set_current_page (0);
                    if (lastPage == 1) notebook.set_current_page (1);
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
            var group = new Adw.PreferencesGroup ();
            group.set_title (launcher.Title);
            if (launcher.Title == "Steam (Flatpak)") group.set_description (_("If you're using gamescope with Steam (Flatpak), those tools will not work. Make sure to use the community builds from Flathub (Check for the add-ons section)"));
            content.append (group);

            //
            spinner = new Gtk.Spinner ();
            group.set_header_suffix (spinner);

            //
            foreach (var tool in launcher.Tools) {
                var row = CreateToolRow (tool);
                toolRows.append (row);
                group.add (row);
            }

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
        }

        Adw.ExpanderRow CreateToolRow (Models.Tool tool) {
            var row = new Adw.ExpanderRow ();
            row.set_title (tool.Title);

            return row;
        }

        Adw.ActionRow CreateReleaseRow (Models.Release release) {
            var row = new Adw.ActionRow ();
            row.set_title (release.Title);
            row.set_activatable (true);

            var actions = GetActionsBox (release, row);

            row.activated.connect (() => InfoRelease (release, row, actions));

            row.add_suffix (actions);

            return row;
        }

        Gtk.Box GetActionsBox (Models.Release release, Adw.ActionRow row) {
            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            actions.set_margin_end (10);
            actions.set_valign (Gtk.Align.CENTER);

            var btn = release.Installed ? GetDeleteButton (release, row, actions) : GetInstallButton (release, row, actions);
            actions.append (btn);

            var icon = new Gtk.Image.from_icon_name ("go-next-symbolic");
            actions.append (icon);

            return actions;
        }

        Gtk.Button GetDeleteButton (Models.Release release, Adw.ActionRow row, Gtk.Box actions) {
            var btnDelete = new Gtk.Button ();
            btnDelete.add_css_class ("flat");
            btnDelete.set_icon_name ("user-trash-symbolic");
            btnDelete.width_request = 25;
            btnDelete.height_request = 25;
            btnDelete.set_tooltip_text (_("Delete the tool"));
            btnDelete.clicked.connect (() => DeleteRelease (release, row, actions));
            return btnDelete;
        }

        Gtk.Button GetInstallButton (Models.Release release, Adw.ActionRow row, Gtk.Box actions) {
            var btnInstall = new Gtk.Button ();
            btnInstall.set_icon_name ("folder-download-symbolic");
            btnInstall.add_css_class ("flat");
            btnInstall.width_request = 25;
            btnInstall.height_request = 25;
            btnInstall.set_tooltip_text (_("Install the tool"));
            btnInstall.clicked.connect (() => InstallRelease (release, row, actions));
            return btnInstall;
        }

        void InfoRelease (Models.Release release, Adw.ActionRow row, Gtk.Box actions) {
            notebook.set_current_page (1);
            releaseInfo.Load (release, row, actions);
        }

        public void DeleteRelease (Models.Release release, Adw.ActionRow row, Gtk.Box actions) {
            //
            var toast = new Adw.Toast ("Deleted " + release.Title);
            toast.set_button_label ("Undo");

            //
            bool undo = false;

            //
            toast.button_clicked.connect (() => {
                undo = true;
                toast.dismiss ();
            });

            //
            toast.dismissed.connect (() => {
                if (!undo) {
                    release.Delete ();

                    GLib.Timeout.add (1000, () => {
                        if (!release.Installed) {
                            row.remove (actions);
                            row.add_suffix (GetActionsBox (release, row));

                            if (notebook.get_current_page () == 1) {
                                releaseInfo.Load (release, row, actions);
                            }

                            return false;
                        }

                        return true;
                    });
                }
            });

            //
            toastOverlay.add_toast (toast);
        }

        public void InstallRelease (Models.Release release, Adw.ActionRow row, Gtk.Box actions) {
            lastPage = notebook.get_current_page ();
            notebook.set_current_page (2);
            releaseInstaller.Download (release);


            GLib.Timeout.add (1000, () => {
                if (release.InstallCancelled) {
                    return false;
                }

                if (release.Installed) {
                    row.remove (actions);
                    row.add_suffix (GetActionsBox (release, row));

                    if (lastPage == 1) {
                        releaseInfo.Load (release, row, actions);
                    }

                    return false;
                }

                return true;
            });
        }

        public void Load () {
            if (!loaded) {
                loaded = true;

                spinner.start ();

                //
                new Thread<void> ("getReleases", () => {
                    foreach (var tool in launcher.Tools) {
                        tool.Releases = tool.GetReleases ();
                        if (tool.Releases.length () == 0) error = true;
                    }
                    done = true;
                });

                //
                GLib.Timeout.add (1000, () => {
                    if (error) {
                        spinner.stop ();
                        spinner.set_visible (false);

                        var toast = new Adw.Toast (_("There was an error while fetching data from the GitHub API."));
                        toast.set_button_label (_("Learn more"));
                        toast.set_timeout (15000);
                        toast.button_clicked.connect (() => {
                            parentNotebook.set_current_page (2);
                        });
                        toastOverlay.add_toast (toast);

                        return false;
                    } else if (done) {
                        for (int i = 0; i < toolRows.length (); i++) {
                            var tool = launcher.Tools.nth_data (i);
                            var row = toolRows.nth_data (i);

                            foreach (var release in tool.Releases) {
                                row.add_row (CreateReleaseRow (release));
                            }
                        }

                        spinner.stop ();
                        spinner.set_visible (false);

                        return false;
                    }

                    return true;
                });
            }
        }
    }
}
