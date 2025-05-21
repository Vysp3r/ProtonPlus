namespace ProtonPlus.Widgets.SidebarRows {
    public class SteamSidebarRow : SidebarRow {
        public SteamSidebarRow (string title, string type, string resource_path, string directory) {
            base (title, type, resource_path, directory);

            var button = new Gtk.Button.from_icon_name ("game-library");
            button.set_tooltip_text (_("Show game library"));

            var input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            input_box.set_valign (Gtk.Align.CENTER);
            input_box.append (button);

            add_suffix (input_box);


            button.clicked.connect (() => {
                var library_dialog = new LibraryDialog(title);
                library_dialog.present (Application.window);
            });
        }
    }
}