namespace ProtonPlus.Widgets {
    public class InfoBox : Gtk.Box {
        Menu menu { get; set; }
        Gtk.MenuButton menu_button { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Adw.HeaderBar header { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }

        public List<LauncherBox> launcher_boxes;

        construct {
            set_orientation (Gtk.Orientation.VERTICAL);

            window_title = new Adw.WindowTitle ("", "");

            var item = new MenuItem ("_Installed Only", null);
            item.set_action_and_target ("win.set-installed-only", "b");

            var filters_section = new Menu ();
            filters_section.append_item (item);

            var other_section = new Menu ();
            other_section.append (_("_Keyboard Shortcuts"), "win.show-help-overlay");
            other_section.append (_("_About ProtonPlus"), "app.about");

            menu = new Menu ();
            menu.append_section (null, filters_section);
            menu.append_section (null, other_section);

            menu_button = new Gtk.MenuButton ();
            menu_button.set_tooltip_text (_("Main Menu"));
            menu_button.set_icon_name ("open-menu-symbolic");
            menu_button.set_menu_model (menu);

            header = new Adw.HeaderBar ();
            header.set_title_widget (window_title);
            header.pack_end (menu_button);

            toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header);

            launcher_boxes = new List<Widgets.LauncherBox> ();

            append (toolbar_view);
        }

        public void switch_mode (bool mode) {
            foreach (var box in launcher_boxes) {
                box.switch_mode (mode);
            }
        }

        public void switch_launcher (string title, int position) {
            window_title.set_title (title);

            var current_launcher_box = launcher_boxes.nth_data (position);

            if (current_launcher_box.get_parent () == null)
                toolbar_view.set_content (current_launcher_box);
        }

        public void initialize (List<Models.Launcher> launchers) {
            foreach (var launcher in launchers) {
                var launcher_box = new Widgets.LauncherBox (launcher);
                launcher_boxes.append (launcher_box);
            }
        }
    }
}