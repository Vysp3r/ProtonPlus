namespace Windows.Preferences {
    public class Main : Gtk.Box {
        Settings settings;
        Adw.ActionRow currentStyleRow;
        Gtk.Image currentStyleRowImage;
        GLib.List<Models.Preferences.Style> styles;


        public Main (Gtk.Notebook notebook) {
            //
            set_spacing (0);
            set_orientation (Gtk.Orientation.VERTICAL);
            set_vexpand (true);
            set_hexpand (true);

            //
            settings = new Settings ("com.vysp3r.ProtonPlus");

            //
            if (GLib.Environment.get_variable ("DESKTOP_SESSION") != "gamescope-wayland") {
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
            }

            //
            var mainPage = new Adw.PreferencesPage ();
            mainPage.set_name (_("Main"));
            mainPage.set_title (_("Main"));
            append (mainPage);

            //
            var group = new Adw.PreferencesGroup ();
            mainPage.add (group);

            //
            if (Adw.StyleManager.get_default ().get_system_supports_color_schemes ()) {
                //
                var stylesRow = new Adw.ExpanderRow ();
                stylesRow.set_title (_("Styles"));

                //
                styles = Models.Preferences.Style.GetAll ();

                //
                foreach (var style in styles) {
                    var row = new Adw.ActionRow ();
                    row.set_activatable (true);
                    row.activated.connect (() => StyleRowActivated (style, row));
                    row.set_title (style.Title);

                    if (style.Position == settings.get_value ("window-style").get_int32 ()) {
                        style.SetActive (false);
                        StyleRowActivated (style, row);
                    }

                    stylesRow.add_row (row);
                }
                group.add (stylesRow);
            }
        }

        void StyleRowActivated (Models.Preferences.Style style, Adw.ActionRow row) {
            var icon = new Gtk.Image.from_icon_name ("object-select-symbolic");
            icon.width_request = 25;
            icon.height_request = 25;

            if (currentStyleRow != null && currentStyleRowImage != null) currentStyleRow.remove (currentStyleRowImage);

            currentStyleRow = row;
            currentStyleRowImage = icon;

            row.add_suffix (icon);
            style.SetActive (true);
        }
    }
}
