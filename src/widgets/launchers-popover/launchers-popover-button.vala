namespace ProtonPlus.Widgets {
	public class LaunchersPopoverButton : Gtk.Button {
        Models.Launcher selected_launcher;

        Gtk.Popover popover;
        Gtk.Image button_image;
        Gtk.Label button_label;
        Gtk.Box button_content;
        Gtk.ListBox list_box;
        
        public LaunchersPopoverButton () {
            button_image = new Gtk.Image ();

            button_label = new Gtk.Label (null);

            button_content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
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
			
            clicked.connect (popover_button_clicked);

            add_css_class ("flat");
            set_child (button_content);
        }

        void popover_button_clicked () {
			popover.popup ();
		}

        void list_box_row_activated (Gtk.ListBoxRow? row) {
            if (row == null || row.get_type () != typeof(LaunchersPopoverListRow))
                return;

            var launchers_popover_list_row = row as LaunchersPopoverListRow;

            if (selected_launcher == launchers_popover_list_row.launcher)
                return;

            selected_launcher = launchers_popover_list_row.launcher;

            button_image.set_from_resource (selected_launcher.icon_path);
            button_label.set_label (selected_launcher.title);

            activate_action_variant ("win.set-selected-launcher", row.get_index ());

            popover.popdown ();
        }

        public void initialize (List<Models.Launcher> launchers) {
            list_box.remove_all ();

            foreach (var launcher in launchers) {
                var launchers_popover_list_row = new LaunchersPopoverListRow (launcher);

                list_box.append (launchers_popover_list_row);
            }

            list_box.row_activated (list_box.get_row_at_index (0));
        }
    }
}