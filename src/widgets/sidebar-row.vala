namespace ProtonPlus.Widgets {
    public class SidebarRow : Adw.ActionRow {
        Gtk.Image icon;

        public SidebarRow (string title, string type, string resource_path) {
            icon = new Gtk.Image.from_resource (resource_path);
            icon.set_pixel_size (48);

            add_prefix (icon);
            add_css_class ("sidebar-row");
            set_title (title);
            set_subtitle (type);
        }
    }
}