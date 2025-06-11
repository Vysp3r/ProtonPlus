namespace ProtonPlus.Widgets {
    public class SidebarRow : Gtk.ListBoxRow {
        Gtk.Image icon { get; set; }
        Gtk.Button library_button { get; set; }
        Gtk.Label title_label { get; set; }
        Gtk.Label subtitle_label { get; set; }
        Gtk.Box labels_box { get; set; }
        Gtk.Box content_box { get; set; }

        public SidebarRow (Models.Launcher launcher) {
            icon = new Gtk.Image.from_resource (launcher.icon_path);
            icon.set_pixel_size (48);

            library_button = new Gtk.Button.from_icon_name ("game-library");
            library_button.set_tooltip_text (_("Show game library"));
            library_button.set_valign (Gtk.Align.CENTER);
            library_button.set_visible (launcher.has_library_support);
            library_button.clicked.connect (library_button_clicked);

            title_label = new Gtk.Label (launcher.title);
            title_label.set_halign (Gtk.Align.START);

            subtitle_label = new Gtk.Label (launcher.get_installation_type_title ());
            subtitle_label.set_halign (Gtk.Align.START);
            subtitle_label.add_css_class ("subtitle");

            labels_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            labels_box.set_valign (Gtk.Align.CENTER);
            labels_box.set_hexpand (true);
            labels_box.append (title_label);
            labels_box.append (subtitle_label);

            content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            content_box.append (icon);
            content_box.append (labels_box);
            content_box.append (library_button);
            content_box.add_css_class ("p-10");

            set_tooltip_text (launcher.directory);
            set_activatable (true);
            set_child (content_box);
        }

        void library_button_clicked () {
            activate_action_variant ("win.set-library-active", get_index ());
        }
    }
}