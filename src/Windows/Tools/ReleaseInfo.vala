namespace Windows.Tools {
    public class ReleaseInfo : Gtk.Box {
        Gtk.Notebook notebook;
        Adw.Clamp clamp;
        Adw.StatusPage statusPage;
        Windows.Tools.LauncherInfo launcherInfo;

        public ReleaseInfo (Gtk.Notebook notebook, Windows.Tools.LauncherInfo launcherInfo) {
            //
            this.notebook = notebook;
            this.launcherInfo = launcherInfo;

            //
            set_orientation (Gtk.Orientation.VERTICAL);
            set_valign (Gtk.Align.CENTER);
            set_spacing (0);

            //
            clamp = new Adw.Clamp ();
            clamp.set_maximum_size (700);

            //
            statusPage = new Adw.StatusPage ();
            statusPage.set_child (clamp);
            append (statusPage);
        }

        Adw.PreferencesRow RowBuilder (string title, string text, Gtk.Widget? extraSuffix = null) {
            //
            var display = Gdk.Display.get_default ();
            var clipboard = display.get_clipboard ();

            //
            var btn = new Gtk.Button ();
            btn.add_css_class ("flat");
            btn.set_tooltip_text (_("Copy"));
            btn.set_icon_name ("edit-copy-symbolic");

            //
            var row = new Adw.EntryRow ();
            row.set_title (title);
            row.set_text (text);
            row.add_suffix (btn);
            if (extraSuffix != null) row.add_suffix (extraSuffix);
            row.set_editable (false);

            //
            btn.clicked.connect (() => clipboard.set_text (row.get_text ()));

            return row;
        }

        public void Load (Models.Release release, Adw.ActionRow row, Gtk.Box rowActions) {
            //
            var btnOpenDirectory = new Gtk.Button ();

            //
            if (Stores.Main.get_instance ().Desktop == "gamescope-wayland") btnOpenDirectory = null;
            else {
                btnOpenDirectory.set_tooltip_text ("Open directory");
                btnOpenDirectory.set_icon_name ("folder-symbolic");
                btnOpenDirectory.add_css_class ("flat");
                // BIND ACTION TO OPENFOLDER
            }

            //
            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 15);

            //
            if (release.Installed) {
                var btnDelete = new Gtk.Button.with_label ("Delete");
                btnDelete.add_css_class ("destructive-action");
                btnDelete.set_hexpand (true);
                btnDelete.clicked.connect (() => launcherInfo.DeleteRelease (release, row, rowActions));
                actions.append (btnDelete);
            } else {
                var btnInstall = new Gtk.Button.with_label ("Install");
                btnInstall.add_css_class ("suggested-action");
                btnInstall.set_hexpand (true);
                btnInstall.clicked.connect (() => launcherInfo.InstallRelease (release, row, rowActions));
                actions.append (btnInstall);
            }

            //
            var btnWebsite = new Gtk.Button.with_label ("Website");
            btnWebsite.set_hexpand (true);
            btnWebsite.clicked.connect (() => Gtk.show_uri (null, release.PageURL, Gdk.CURRENT_TIME));
            actions.append (btnWebsite);

            //
            var group = new Adw.PreferencesGroup ();

            group.add (RowBuilder ("Directory: ", release.Directory, btnOpenDirectory)); // ONLY FOR DEBUG
            if (release.Installed) {
                // group.add (RowBuilder ("Directory: ", release.Directory, btnOpenDirectory));
                group.add (RowBuilder ("Size: ", release.GetFormattedSize ()));
            } else {
                group.add (RowBuilder ("Download size: ", release.GetFormattedDownloadSize ()));
            }
            group.add (RowBuilder ("Release date: ", release.ReleaseDate));

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
        }
    }
}
