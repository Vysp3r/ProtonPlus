namespace Windows.Tools {
    public class ToolInfo : Gtk.Widget {
        Gtk.Spinner spinner;
        Adw.ExpanderRow releasesRow;
        bool loaded = false;
        bool done = false;
        bool error = false;
        Models.Tool tool;
        Windows.Tools.LauncherInfo launcherInfo;

        public ToolInfo (Models.Tool tool, Windows.Tools.LauncherInfo launcherInfo) {
            //
            this.tool = tool;
            this.launcherInfo = launcherInfo;

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
            releasesRow.set_title ("Releases");

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
                    } else if (done) {
                        foreach (var release in tool.Releases) {
                            releasesRow.add_row (launcherInfo.CreateReleaseRow (release));
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
