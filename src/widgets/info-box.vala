namespace ProtonPlus.Widgets {
    public class InfoBox : Gtk.Box {
        public bool installed_only { get; set; }

        public Gtk.Button sidebar_button { get; set; }
        Menu menu_model { get; set; }
        Gtk.MenuButton menu_button { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Adw.HeaderBar header { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }

        List<LauncherBox> launcher_boxes;

        construct {
            set_orientation (Gtk.Orientation.VERTICAL);

            window_title = new Adw.WindowTitle ("", "");

            sidebar_button = new Gtk.Button.from_icon_name ("layout-sidebar-symbolic");
            sidebar_button.set_tooltip_text (_("Toggle Sidebar"));
            sidebar_button.set_visible (false);

            menu_model = new Menu ();
            menu_model.append (_("_About ProtonPlus"), "app.show-about");

            menu_button = new Gtk.MenuButton ();
            menu_button.set_tooltip_text (_("Main Menu"));
            menu_button.set_icon_name ("open-menu-symbolic");
            menu_button.set_menu_model (menu_model);

            header = new Adw.HeaderBar ();
            header.add_css_class ("flat");
            header.set_title_widget (window_title);
            header.pack_start (sidebar_button);
            header.pack_end (menu_button);

            toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header);

            launcher_boxes = new List<Widgets.LauncherBox> ();

            notify["installed-only"].connect (installed_only_changed);

            append (toolbar_view);
        }

        public void switch_launcher (string title, int position) {
            window_title.set_title (title);
            toolbar_view.set_content (launcher_boxes.nth_data (position));
        }

        public void initialize (List<Models.Launcher> launchers) {
            foreach (var launcher in launchers) {
                var launcher_box = new Widgets.LauncherBox (launcher);
                launcher_boxes.append (launcher_box);
            }
        }

        void installed_only_changed () {
            foreach (var box in launcher_boxes) {
                foreach (var group in box.group_rows) {
                    foreach (var runner in group.runner_rows) {
                        runner.load_more_row.set_visible (!installed_only);
                        foreach (var release in runner.release_rows) {
                            release.show_installed_only (installed_only);
                        }
                    }
                }
            }
        }
    }
}