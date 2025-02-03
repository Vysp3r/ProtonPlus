namespace ProtonPlus.Widgets {
    public class Sidebar : Gtk.Box {
        Gtk.ListBox list_box { get; set; }

        construct {
            var window_title = new Adw.WindowTitle ("ProtonPlus", "");

            var header_bar = new Adw.HeaderBar ();
            header_bar.set_title_widget (window_title);

            list_box = new Gtk.ListBox ();
            list_box.set_activate_on_single_click (true);
            list_box.set_selection_mode (Gtk.SelectionMode.SINGLE);
            list_box.add_css_class ("navigation-sidebar");
            list_box.set_hexpand (true);
            list_box.set_vexpand (true);
            list_box.row_activated.connect (list_box_row_activated);
            list_box.row_selected.connect (list_box_row_selected);

            var show_installed_button = new Gtk.Button.with_label (_("Show Installed"));
            show_installed_button.set_margin_start (7);
            show_installed_button.set_margin_end (7);
            show_installed_button.set_margin_top (7);
            show_installed_button.set_margin_bottom (7);
            show_installed_button.set_hexpand (true);

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.append (list_box);
            content.append (show_installed_button);

            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_bar);
            toolbar_view.set_content (content);

            append (toolbar_view);
        }

        public void initialize (List<Models.Launcher> launchers) {
            list_box.remove_all ();

            foreach (var launcher in launchers) {
                var row = new SidebarRow (launcher.title, launcher.get_installation_type_title (), launcher.icon_path);
                list_box.append (row);
            }
        }

        void list_box_row_activated (Gtk.ListBoxRow? row) {
            activate_action_variant ("win.set-nav-view-active", true);
        }

        void list_box_row_selected (Gtk.ListBoxRow? row) {
            activate_action_variant ("win.load-info-box", row.get_index ());
        }
    }
}