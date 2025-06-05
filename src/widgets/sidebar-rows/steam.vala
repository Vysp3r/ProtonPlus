namespace ProtonPlus.Widgets.SidebarRows {
    public class SteamSidebarRow : SidebarRow {
        Models.Launchers.Steam launcher;

        public SteamSidebarRow (Models.Launchers.Steam launcher) {
            base (launcher.title, launcher.get_installation_type_title (), launcher.icon_path, launcher.directory);

            this.launcher = launcher;

            var library_button = new Gtk.Button.from_icon_name ("game-library");
            library_button.set_tooltip_text (_("Show game library"));
            library_button.clicked.connect (library_button_clicked);

            var input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            input_box.set_valign (Gtk.Align.CENTER);
            input_box.append (library_button);

            add_suffix (input_box);
        }
        
        void library_button_clicked() {
            activate_action_variant ("win.set-library-active", true);
        }
    }
}