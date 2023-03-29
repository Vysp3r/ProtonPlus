namespace Windows {
    public class Preferences : Gtk.Box {
        GLib.Settings settings;

        public Preferences (Gtk.Notebook notebook) {
            //
            set_spacing (0);
            set_orientation (Gtk.Orientation.VERTICAL);
            set_vexpand (true);
            set_hexpand (true);

            //
            settings = new Settings ("com.vysp3r.ProtonPlus");

            //
            var btnBack = new Gtk.Button ();
            btnBack.set_icon_name ("go-previous-symbolic");
            btnBack.clicked.connect (() => {
                notebook.set_current_page (0);
            });

            //
            var headerBar = new Adw.HeaderBar ();
            headerBar.set_centering_policy (Adw.CenteringPolicy.STRICT);
            headerBar.pack_start (btnBack);
            append (headerBar);

            //
            var mainPage = new Adw.PreferencesPage ();
            mainPage.set_name (_("Main"));
            mainPage.set_title (_("Main"));
            append (mainPage);

            //
            var rememberLastLauncherSwitch = new Gtk.Switch ();
            settings.bind ("remember-last-launcher", rememberLastLauncherSwitch, "active", GLib.SettingsBindFlags.DEFAULT);

            //
            var showGamescopeWarningSwitch = new Gtk.Switch ();
            settings.bind ("show-gamescope-warning", showGamescopeWarningSwitch, "active", GLib.SettingsBindFlags.DEFAULT);

            //
            var otherGroup = new Adw.PreferencesGroup ();
            otherGroup.add (CreateRow (rememberLastLauncherSwitch, _("Remember last launcher")));
            otherGroup.add (CreateRow (showGamescopeWarningSwitch, _("Show gamescope warning")));
            mainPage.add (otherGroup);
        }

        Adw.ActionRow CreateRow (Gtk.Widget widget, string row_title) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.set_valign (Gtk.Align.CENTER);
            box.append (widget);

            var row = new Adw.ActionRow ();
            row.set_title (row_title);
            row.add_suffix (box);

            return row;
        }
    }
}
