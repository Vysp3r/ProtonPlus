namespace ProtonPlus.Widgets {
    public class Sidebar : Gtk.Box {
        public Gtk.Button sidebar_button { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Adw.HeaderBar header_bar { get; set; }
        Gtk.ListBox list_box { get; set; }

        construct {
            sidebar_button = new Gtk.Button.from_icon_name ("layout-sidebar-symbolic");
            sidebar_button.set_tooltip_text (_("Toggle Sidebar"));

            window_title = new Adw.WindowTitle ("ProtonPlus", "");

            header_bar = new Adw.HeaderBar ();
            header_bar.set_title_widget (window_title);
            header_bar.pack_start (sidebar_button);

            list_box = new Gtk.ListBox ();
            list_box.set_activate_on_single_click (true);
            list_box.set_selection_mode (Gtk.SelectionMode.SINGLE);
            list_box.add_css_class ("navigation-sidebar");
            list_box.set_hexpand (true);
            list_box.row_selected.connect (list_box_row_selected);

            toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_bar);
            toolbar_view.set_content (list_box);

            append (toolbar_view);
        }

        public void initialize (List<Models.Launcher> launchers) {
            list_box.remove_all ();

            foreach (var launcher in launchers) {
                var row = new SidebarRow (launcher.title, launcher.get_installation_type_title (), launcher.icon_path);
                list_box.append (row);
            }

            if (launchers.length () > 0) {
                list_box.select_row (list_box.get_row_at_index (0));
            }
        }

        void list_box_row_selected (Gtk.ListBoxRow? row) {
            activate_action_variant ("win.load-info-box", row.get_index ());
        }
    }
}