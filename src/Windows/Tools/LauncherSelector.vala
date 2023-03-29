namespace Windows.Tools {
    public class LauncherSelector : Gtk.Box {
        public LauncherSelector (Adw.Leaflet leaflet) {
            //
            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (15);
            set_margin_bottom (15);
            set_margin_top (15);

            //
            var group = new Adw.PreferencesGroup ();
            group.set_title ("Launchers");
            group.set_description ("Select a launcher to proceed");

            //
            var launchers = Models.Launcher.GetAll ();
            for (int i = 0; i < launchers.length (); i++) {
                var launcher = launchers.nth_data (i);

                var row = new Adw.ActionRow ();
                row.set_title (launcher.Title);
                row.set_activatable (true);
                row.activated.connect (() => {
                    leaflet.get_pages ().select_item (i, true);
                });

                var icon = new Gtk.Image.from_icon_name ("go-next-symbolic");
                row.add_suffix (icon);

                group.add (row);

                leaflet.append (new Windows.Tools.LauncherInfo (leaflet, launcher));
            }

            //
            var clamp = new Adw.Clamp ();
            clamp.set_maximum_size (700);
            clamp.set_child (group);
            append (clamp);
        }
    }
}
