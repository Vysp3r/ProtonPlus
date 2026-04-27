namespace ProtonPlus.Widgets.Header {
    public class LaunchersButton : Gtk.Button {
        public signal void launcher_selected (Models.Launcher launcher);

        Models.Launcher previous_launcher;

        Gtk.Popover popover;
        Gtk.Image button_image;
        Gtk.Label button_label;
        Gtk.ListBox list_box;

        public LaunchersButton () {
            button_image = new Gtk.Image ();

            button_label = new Gtk.Label (null);

            var button_content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            button_content.append (button_image);
            button_content.append (button_label);

            list_box = new Gtk.ListBox ();
            list_box.set_activate_on_single_click (true);
            list_box.set_selection_mode (Gtk.SelectionMode.SINGLE);
            list_box.add_css_class ("navigation-sidebar");
            list_box.set_hexpand (true);
            list_box.set_vexpand (true);
            list_box.add_css_class ("launchers-popover-list");
            list_box.row_activated.connect (list_box_row_activated);

            popover = new Gtk.Popover ();
            popover.set_child (list_box);
            popover.set_parent (this);

            clicked.connect (button_clicked);

            set_child (button_content);
            add_css_class ("flat");
        }

        public void initialize (Gee.LinkedList<Models.Launcher> launchers) {
            list_box.remove_all ();

            foreach (var launcher in launchers) {
                list_box.append (create_row (launcher));
            }

            list_box.row_activated (list_box.get_row_at_index (0));
        }

        public void button_clicked () {
            if (popover.get_visible ())
            popover.popdown ();
            else
            popover.popup ();
        }

        void list_box_row_activated (Gtk.ListBoxRow? row) {
            var launcher = row.get_data<Models.Launcher> ("launcher");

            if (previous_launcher == launcher)
            return;

            previous_launcher = launcher;

            button_image.set_from_resource (launcher.icon_path);
            button_label.set_label (launcher.title);

            launcher_selected (launcher);

            popover.popdown ();
        }

        Gtk.ListBoxRow create_row (Models.Launcher launcher) {
            var icon = new Gtk.Image.from_resource (launcher.icon_path);
            icon.set_pixel_size (48);

            var title_label = new Gtk.Label (launcher.title);
            title_label.set_halign (Gtk.Align.START);

            var subtitle_label = new Gtk.Label (launcher.get_installation_type_title ());
            subtitle_label.add_css_class ("dimmed");
            subtitle_label.set_halign (Gtk.Align.START);

            var labels_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            labels_box.set_valign (Gtk.Align.CENTER);
            labels_box.set_hexpand (true);
            labels_box.append (title_label);
            labels_box.append (subtitle_label);

            var content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            content_box.append (icon);
            content_box.append (labels_box);
            content_box.add_css_class ("p-10");

            var row = new Gtk.ListBoxRow ();
            row.set_data ("launcher", launcher);
            row.add_css_class ("card");
            row.set_overflow (Gtk.Overflow.HIDDEN);
            row.set_tooltip_text (launcher.directory);
            row.set_activatable (true);
            row.set_child (content_box);

            return row;
        }
    }
}