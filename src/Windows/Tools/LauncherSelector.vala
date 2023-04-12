namespace Windows.Tools {
    public class LauncherSelector : Gtk.Box {
        public LauncherSelector (Windows.Main mainWindow) {
            //
            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (15);
            set_margin_bottom (15);
            set_margin_top (15);

            //
            var group = new Adw.PreferencesGroup ();
            group.set_title (_("Launchers"));
            group.set_description (_("Select a launcher to proceed"));

            //
            for (int i = 0; i < mainWindow.Launchers.length (); i++) {
                var launcher = mainWindow.Launchers.nth_data (i);
                int counter = i + 1;

                var launcherInfo = new Windows.Tools.LauncherInfo (mainWindow, launcher);

                var row = new Adw.ActionRow ();
                row.set_title (launcher.Title);
                row.set_activatable (true);
                row.activated.connect (() => {
                    launcherInfo.LastPage = 0;
                    mainWindow.Leaflet.get_pages ().select_item (counter, true);
                });

                var icon = new Gtk.Image.from_icon_name ("go-next-symbolic");
                row.add_suffix (icon);

                group.add (row);

                mainWindow.Leaflet.append (launcherInfo);
            }

            //
            var clamp = new Adw.Clamp ();
            clamp.set_maximum_size (700);
            clamp.set_child (group);
            append (clamp);
        }
    }
}
