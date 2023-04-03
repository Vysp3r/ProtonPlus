namespace Windows.Tools {
    public class ReleaseInfo : Gtk.Widget {
        Gtk.Notebook notebook;
        Adw.Clamp clamp;
        Adw.StatusPage statusPage;
        Windows.Tools.LauncherInfo launcherInfo;

        public ReleaseInfo (Gtk.Notebook notebook, Windows.Tools.LauncherInfo launcherInfo) {
            //
            this.notebook = notebook;
            this.launcherInfo = launcherInfo;

            //
            var layout = new Gtk.BinLayout ();
            set_layout_manager (layout);

            //
            clamp = new Adw.Clamp ();
            clamp.set_maximum_size (700);

            //
            statusPage = new Adw.StatusPage ();
            statusPage.set_child (clamp);
            statusPage.set_parent (this);
        }

        Adw.PreferencesRow RowBuilder (string title, string text) {
            //
            var display = Gdk.Display.get_default ();
            var clipboard = display.get_clipboard ();

            //
            var btn = new Gtk.Button ();
            btn.width_request = 25;
            btn.height_request = 25;
            btn.add_css_class ("flat");
            btn.set_tooltip_text (_("Copy"));
            btn.set_icon_name ("edit-copy-symbolic");

            //
            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            actions.set_margin_end (10);
            actions.set_valign (Gtk.Align.CENTER);
            actions.append (btn);

            //
            var row = new Adw.EntryRow ();
            row.set_title (title);
            row.set_text (text);
            row.add_suffix (actions);
            row.set_editable (false);

            //
            btn.clicked.connect (() => clipboard.set_text (row.get_text ()));

            return row;
        }

        public void Load (Models.Release release, Adw.ActionRow row, Gtk.Box rowActions) {
            //
            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 15);

            //
            if (release.Installed) {
                var btnDelete = new Gtk.Button.with_label (_("Delete"));
                btnDelete.add_css_class ("destructive-action");
                btnDelete.set_hexpand (true);
                btnDelete.clicked.connect (() => launcherInfo.DeleteRelease (release, row, rowActions));
                actions.append (btnDelete);
            } else {
                var btnInstall = new Gtk.Button.with_label (_("Install"));
                btnInstall.add_css_class ("suggested-action");
                btnInstall.set_hexpand (true);
                btnInstall.clicked.connect (() => launcherInfo.InstallRelease (release, row, rowActions));
                actions.append (btnInstall);
            }

            //
            if (GLib.Environment.get_variable ("DESKTOP_SESSION") != "gamescope-wayland") {
                var btnWebsite = new Gtk.Button.with_label (_("Website"));
                btnWebsite.set_hexpand (true);
                btnWebsite.clicked.connect (() => Gtk.show_uri (null, release.PageURL, Gdk.CURRENT_TIME));
                actions.append (btnWebsite);
            }

            //
            var group = new Adw.PreferencesGroup ();

            if (release.Installed) {
                group.add (RowBuilder (_("Directory: "), release.Directory));
                group.add (RowBuilder (_("Size: "), release.GetFormattedSize ()));
            } else {
                group.add (RowBuilder (_("Download size (Compressed): "), release.GetFormattedDownloadSize ()));
            }
            group.add (RowBuilder (_("Release date: "), release.ReleaseDate));

            //
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            content.set_valign (Gtk.Align.CENTER);
            content.set_margin_bottom (15);
            content.set_margin_top (15);
            content.append (group);
            content.append (actions);

            //
            clamp.set_child (content);

            //
            statusPage.set_title (release.Title);
            statusPage.set_description (release.Tool.Title);
        }
    }
}
