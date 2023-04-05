namespace Windows.Tools {
    public class ToolInfo : Gtk.Widget {
        Gtk.Spinner spinner;
        Adw.ExpanderRow releasesRow;
        bool loaded;
        Models.Tool tool;
        Windows.Tools.LauncherInfo launcherInfo;

        public ToolInfo (Models.Tool tool, Windows.Tools.LauncherInfo launcherInfo) {
            //
            this.tool = tool;
            this.launcherInfo = launcherInfo;
            this.loaded = false;

            //
            var layout = new Gtk.BinLayout ();
            set_layout_manager (layout);

            //
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            content.set_margin_bottom (15);
            content.set_margin_top (15);

            //
            spinner = new Gtk.Spinner ();

            //
            releasesRow = new Adw.ExpanderRow ();
            releasesRow.set_title (_("Releases"));

            //
            var group = new Adw.PreferencesGroup ();
            group.set_title (tool.Title);
            group.set_description (tool.Description);
            group.set_header_suffix (spinner);
            group.add (releasesRow);
            content.append (group);

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
            scrolledWindow.set_parent (this);
        }

        //

        public void Load () {
            if (!loaded) {
                bool done = false;
                bool error = false;
                loaded = true;

                spinner.start ();

                //
                new Thread<void> ("getReleases", () => {
                    tool.Releases = tool.GetReleases ();
                    if (tool.Releases.length () == 0) error = true;
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
                            launcherInfo.parentNotebook.set_current_page (2);
                        });
                        launcherInfo.toastOverlay.add_toast (toast);

                        return false;
                    }
                    if (done) {
                        foreach (var release in tool.Releases) {
                            releasesRow.add_row (CreateReleaseRow (release));
                        }

                        spinner.stop ();
                        spinner.set_visible (false);

                        return false;
                    }

                    return true;
                });
            }
        }

        void InfoRelease (Models.Release release, Widgets.ProtonActionRow row) {
            launcherInfo.lastPage = launcherInfo.notebook.get_current_page ();
            launcherInfo.notebook.set_current_page (1);
            launcherInfo.releaseInfo.Load (release, row, this);
        }

        public void DeleteRelease (Models.Release release, Widgets.ProtonActionRow widget) {
            var toast = new Adw.Toast (_("Deleted ") + release.Title);
            toast.set_button_label (_("Undo"));

            bool undo = false;

            toast.button_clicked.connect (() => {
                undo = true;
                toast.dismiss ();
            });

            toast.dismissed.connect (() => {
                if (!undo) {
                    release.Delete ();

                    GLib.Timeout.add (1000, () => {
                        if (!release.Installed) {
                            widget.remove (widget.Actions);

                            widget.Actions = GetActionsBox (release, widget);
                            widget.add_suffix (widget.Actions);

                            if (launcherInfo.notebook.get_current_page () == 1) {
                                launcherInfo.releaseInfo.Load (release, widget, this);
                            }

                            return false;
                        }

                        return true;
                    });
                }
            });


            launcherInfo.toastOverlay.add_toast (toast);
        }

        public void InstallRelease (Models.Release release, Widgets.ProtonActionRow widget, bool installerStartedFromInfoPage) {
            launcherInfo.installerStartedFromInfoPage = installerStartedFromInfoPage;
            if (!installerStartedFromInfoPage) launcherInfo.lastPage = launcherInfo.notebook.get_current_page ();
            launcherInfo.notebook.set_current_page (2);
            launcherInfo.releaseInstaller.Download (release);

            GLib.Timeout.add (1000, () => {
                if (release.InstallCancelled) {
                    return false;
                }

                if (release.Installed) {
                    widget.remove (widget.Actions);

                    widget.Actions = GetActionsBox (release, widget);
                    widget.add_suffix (widget.Actions);

                    if (launcherInfo.notebook.get_current_page () == 2 && installerStartedFromInfoPage) {
                        launcherInfo.releaseInfo.Load (release, widget, this);
                    }

                    return false;
                }

                return true;
            });
        }

        Widgets.ProtonActionRow CreateReleaseRow (Models.Release release) {
            var widget = new Widgets.ProtonActionRow ();
            widget.set_title (release.Title);
            widget.set_activatable (true);

            widget.Actions = GetActionsBox (release, widget);
            widget.add_suffix (widget.Actions);

            widget.activated.connect (() => InfoRelease (release, widget));

            return widget;
        }

        Gtk.Box GetActionsBox (Models.Release release, Widgets.ProtonActionRow widget) {
            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            actions.set_margin_end (10);
            actions.set_valign (Gtk.Align.CENTER);

            var btn = release.Installed ? GetDeleteButton (release, widget) : GetInstallButton (release, widget);
            actions.append (btn);

            var icon = new Gtk.Image.from_icon_name ("go-next-symbolic");
            actions.append (icon);

            return actions;
        }

        Gtk.Button GetDeleteButton (Models.Release release, Widgets.ProtonActionRow widget) {
            var btnDelete = new Gtk.Button ();

            btnDelete.add_css_class ("flat");
            btnDelete.set_icon_name ("user-trash-symbolic");
            btnDelete.width_request = 25;
            btnDelete.height_request = 25;
            btnDelete.set_tooltip_text (_("Delete the tool"));
            btnDelete.clicked.connect (() => DeleteRelease (release, widget));

            return btnDelete;
        }

        Gtk.Button GetInstallButton (Models.Release release, Widgets.ProtonActionRow widget) {
            var btnInstall = new Gtk.Button ();

            btnInstall.set_icon_name ("folder-download-symbolic");
            btnInstall.add_css_class ("flat");
            btnInstall.width_request = 25;
            btnInstall.height_request = 25;
            btnInstall.set_tooltip_text (_("Install the tool"));
            btnInstall.clicked.connect (() => InstallRelease (release, widget, false));

            return btnInstall;
        }
    }
}
