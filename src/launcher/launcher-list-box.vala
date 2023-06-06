namespace ProtonPlus.Launcher {
    public class LauncherListBox : Gtk.Box {
        Gtk.ListBox list;
        Adw.HeaderBar header;

        construct {
            //
            this.set_orientation (Gtk.Orientation.VERTICAL);
            this.set_size_request (280, 0);

            //
            var menu_model = new Menu ();
            // menu_model.append (_("Preferences"), "app.preferences"); // TODO
            // menu_model.append (_("Keyboard Shortcuts"), "app.shortcuts"); // TODO
            menu_model.append (_("About"), "app.about");

            //
            var menu = new Gtk.MenuButton ();
            menu.set_icon_name ("open-menu-symbolic");
            menu.set_menu_model (menu_model);

            //
            header = new Adw.HeaderBar ();
            header.set_show_end_title_buttons (false);
            header.pack_end (menu);

            //
            list = new Gtk.ListBox ();
            list.set_selection_mode (Gtk.SelectionMode.BROWSE);
            list.set_activate_on_single_click (true);
            list.add_css_class ("navigation-sidebar");
            list.set_margin_start (5);
            list.set_margin_end (5);
            list.set_margin_top (5);
            list.set_margin_bottom (5);

            //
            var scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_vexpand (true);
            scrolled_window.set_child (list);

            //
            append (header);
            append (scrolled_window);
        }

        public void initialize (List<Shared.Models.Launcher> launchers) {
            //
            for (var i = 0; i < launchers.length (); i++) {
                int temp = i;

                var item = new Launcher.LauncherListItem (launchers.nth_data (temp));
                item.set_activatable (true);
                item.activated.connect (() => this.activate_action_variant ("win.load-info-box", temp));

                list.append (item);
            }

            //
            if (launchers.length () > 0) {
                var row = list.get_row_at_index (0);
                list.select_row (row);
                list.row_activated (row);
            }
        }

        public void set_header_controls_visible (bool visible) {
            header.set_show_end_title_buttons (visible);
        }
    }

    public class LauncherListItem : Adw.ActionRow {
        public Shared.Models.Launcher launcher { get; construct; }

        public LauncherListItem (Shared.Models.Launcher launcher) {
            Object (launcher: launcher);
        }

        construct {
            //
            this.add_css_class ("launcher-list-item");

            //
            var image = new Gtk.Image.from_resource (launcher.icon_path);
            image.set_pixel_size (48);

            //
            this.add_prefix (image);

            //
            this.set_title (launcher.title);

            //
            this.set_subtitle (launcher.type);
        }
    }
}