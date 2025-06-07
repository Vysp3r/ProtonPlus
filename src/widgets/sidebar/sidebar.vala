namespace ProtonPlus.Widgets {
    public class Sidebar : Gtk.Box {
        Gtk.ListBox list_box { get; set; }
        unowned List<Models.Launcher> launchers;

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

            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_bar);
            toolbar_view.set_content (list_box);

            append (toolbar_view);
        }

        public void initialize (List<Models.Launcher> launchers) {
            list_box.remove_all ();

            this.launchers = launchers;

            foreach (var launcher in launchers) {
                var row = new SidebarRow (launcher);
                list_box.append (row);
            }
        }

        void list_box_row_activated (Gtk.ListBoxRow? row) {
            activate_action_variant ("win.set-nav-view-active", true);
        }

        void list_box_row_selected (Gtk.ListBoxRow? row) {
            activate_action_variant ("win.set-selected-launcher", row.get_index ());
        }
    }
}