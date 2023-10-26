namespace ProtonPlus.Widgets {
    public class Sidebar : Gtk.Box {
        public Gtk.Button sidebar_button;
        public Gtk.Switch installed_only_switch;

        Gtk.ListBox list_box;

        construct {
            //
            sidebar_button = new Gtk.Button.from_icon_name ("view-dual-symbolic");

            //
            var window_title = new Adw.WindowTitle ("ProtonPlus", "");

            //
            var header = new Adw.HeaderBar ();
            header.set_title_widget (window_title);
            header.pack_start (sidebar_button);

            //
            list_box = new Gtk.ListBox ();
            list_box.set_activate_on_single_click (true);
            list_box.set_selection_mode (Gtk.SelectionMode.SINGLE);
            list_box.add_css_class ("navigation-sidebar");
            list_box.set_hexpand (true);
            list_box.row_selected.connect ((row) => {
                this.activate_action_variant ("win.load-info-box", row.get_index ());
            });

            //
            installed_only_switch = new Gtk.Switch ();
            
            //
            var installed_only_label = new Gtk.Label (_("Installed only"));
            installed_only_label.set_hexpand (true);
            installed_only_label.set_halign (Gtk.Align.START);

            //
            var installed_only_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
            installed_only_box.set_margin_bottom (15);
            installed_only_box.set_margin_top (15);
            installed_only_box.set_margin_start (20);
            installed_only_box.set_margin_end (20);
            installed_only_box.set_vexpand (true);
            installed_only_box.set_valign (Gtk.Align.END);
            installed_only_box.append (installed_only_label);
            installed_only_box.append (installed_only_switch);
            
            //
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
            content.append (list_box);
            content.append (installed_only_box);

            //
            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header);
            toolbar_view.set_content (content);

            //
            this.append (toolbar_view);
        }

        Adw.ActionRow create_row (string title, string type, string icon_name) {
            //
            var icon = new Gtk.Image.from_resource (icon_name);
            icon.set_pixel_size (48);

            //
            var action_row = new Adw.ActionRow ();
            action_row.add_css_class ("sidebar-item");
            action_row.add_prefix (icon);
            action_row.set_title (title);
            action_row.set_subtitle (type);

            return action_row;
        }

        public void initialize (List<Shared.Models.Launcher> launchers) {
            list_box.remove_all ();

            foreach (var launcher in launchers) {
                list_box.append (create_row (launcher.title, launcher.type, launcher.icon_path));
            }

            if (launchers.length () > 0) {
                list_box.select_row (list_box.get_row_at_index (0));
            }
        }
    }
}