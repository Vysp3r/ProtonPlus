namespace ProtonPlus.Widgets {
    public class Sidebar : Gtk.Box {
        Gee.HashMap<Models.Launcher, int> launchers_hashmap { get; set; }

        public Models.Launcher current_launcher { get; set; }
        public Gtk.Button sidebar_button { get; set; }
        public Adw.ToastOverlay toast_overlay { get; set; }
        Gtk.Popover launcher_selector_popover { get; set; }
        Gtk.Image launcher_selector_icon { get; set; }
        Adw.ActionRow launcher_selector_row { get; set; }
        Gtk.ListBox installed_release_list_box { get; set; }

        public Sidebar (Adw.ToastOverlay toast_overlay) {
            Object (toast_overlay: toast_overlay);
        }

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
            var launcher_selector_popover_button = new Gtk.Button.from_icon_name ("go-down-symbolic");
            launcher_selector_popover_button.add_css_class ("flat");
            launcher_selector_popover_button.width_request = 25;
            launcher_selector_popover_button.height_request = 25;
            launcher_selector_popover_button.clicked.connect (() => launcher_selector_popover.popup ());

            //
            launcher_selector_popover = new Gtk.Popover ();
            launcher_selector_popover.set_parent (launcher_selector_popover_button);

            //
            var launcher_selector_popover_button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            launcher_selector_popover_button_box.set_valign (Gtk.Align.CENTER);
            launcher_selector_popover_button_box.append (launcher_selector_popover_button);

            //
            launcher_selector_icon = new Gtk.Image ();
            launcher_selector_icon.set_pixel_size (48);

            //
            launcher_selector_row = new Adw.ActionRow ();
            launcher_selector_row.add_css_class ("sidebar-item");
            launcher_selector_row.add_suffix (launcher_selector_popover_button_box);
            launcher_selector_row.add_prefix (launcher_selector_icon);

            //
            var launchers_group = new Adw.PreferencesGroup ();
            launchers_group.set_margin_start (10);
            launchers_group.set_margin_end (10);
            launchers_group.add (launcher_selector_row);

            //
            var installed_label = new Gtk.Label (_("Installed"));
            installed_label.add_css_class ("bold");

            //
            installed_release_list_box = new Gtk.ListBox ();
            installed_release_list_box.set_activate_on_single_click (true);
            installed_release_list_box.set_selection_mode (Gtk.SelectionMode.SINGLE);
            installed_release_list_box.add_css_class ("navigation-sidebar");
            installed_release_list_box.set_hexpand (true);

            //
            var installed_releases_scrolled_window = new Gtk.ScrolledWindow ();
            installed_releases_scrolled_window.set_margin_start (5);
            installed_releases_scrolled_window.set_margin_end (5);
            installed_releases_scrolled_window.set_vexpand (true);
            installed_releases_scrolled_window.set_child (installed_release_list_box);

            //
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            content.append (launchers_group);
            content.append (installed_label);
            content.append (installed_releases_scrolled_window);

            //
            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header);
            toolbar_view.set_content (content);

            //
            this.notify["current-launcher"].connect (on_current_launcher_changed);

            //
            this.append (toolbar_view);
        }

        void on_current_launcher_changed () {
            if (current_launcher == null)return;

            launcher_selector_icon.set_from_resource (current_launcher.icon_path);

            launcher_selector_row.set_title (current_launcher.title);
            launcher_selector_row.set_subtitle (current_launcher.type);

            installed_release_list_box.remove_all ();

            foreach (var group in current_launcher.groups) {
                foreach (var runner in group.runners) {
                    runner.load (true);
                }
            }

            launcher_selector_popover.popdown ();

            this.activate_action_variant ("win.load-info-box", launchers_hashmap.get (current_launcher));
        }

        Gtk.Box create_installed_release_row (Models.Release release) {
            var title_label = new Gtk.Label (release.title);
            title_label.set_halign (Gtk.Align.START);
            title_label.set_hexpand (true);

            var delete_button = new Gtk.Button ();
            delete_button.add_css_class ("flat");
            delete_button.set_icon_name ("user-trash-symbolic");
            delete_button.width_request = 25;
            delete_button.height_request = 25;
            delete_button.set_tooltip_text (_("Delete the runner"));
            delete_button.clicked.connect (() => {
                var toast = new Adw.Toast (_("Are you sure you want to delete ") + release.title + "?");
                toast.set_timeout (30000);
                toast.set_button_label (_("Confirm"));

                toast.button_clicked.connect (() => {
                    release.delete ();

                    toast.dismiss ();
                });

                toast_overlay.add_toast (toast);
            });

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.add_css_class ("sidebar-item");
            box.append (title_label);
            box.append (delete_button);

            return box;
        }

        public void initialize (List<Models.Launcher> launchers) {
            //
            var launchers_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);

            //
            launchers_hashmap = new Gee.HashMap<Models.Launcher, int> ();

            //
            int counter = 0;

            //
            foreach (var launcher in launchers) {
                //
                launchers_hashmap.set (launcher, counter++);

                //
                foreach (var group in launcher.groups) {
                    foreach (var runner in group.runners) {
                        runner.notify["installed-loaded"].connect (() => {
                            if (runner.installed_loaded) {
                                foreach (var release in runner.installed_releases) {
                                    var row = create_installed_release_row (release);
                                    installed_release_list_box.append (row);
                                }
                            }
                        });
                    }
                }

                //
                var button = new Gtk.Button.with_label (launcher.title + " (" + launcher.type + ")");
                button.add_css_class ("flat");
                button.clicked.connect (() => current_launcher = launcher);

                //
                launchers_box.append (button);
            }

            //
            launcher_selector_popover.set_child (launchers_box);

            //
            if (launchers.length () > 0)current_launcher = launchers.nth_data (0);
        }
    }
}