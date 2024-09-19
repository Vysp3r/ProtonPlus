namespace ProtonPlus.Widgets {
    public class InfoBox : Gtk.Box {
        public Gtk.Button sidebar_button { get; set; }
        public bool installed_only { get; set; }

        Adw.ToastOverlay toast_overlay { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Adw.HeaderBar header { get; set; }
        Gtk.Notebook notebook { get; set; }

        construct {
            this.set_orientation (Gtk.Orientation.VERTICAL);

            window_title = new Adw.WindowTitle ("", "");

            sidebar_button = new Gtk.Button.from_icon_name ("view-dual-symbolic");
            sidebar_button.set_visible (false);

            var menu_model = new Menu ();
            menu_model.append (_("_About ProtonPlus"), "app.show-about");

            var menu_button = new Gtk.MenuButton ();
            menu_button.set_icon_name ("open-menu-symbolic");
            menu_button.set_menu_model (menu_model);

            header = new Adw.HeaderBar ();
            header.add_css_class ("flat");
            header.set_title_widget (window_title);
            header.pack_start (sidebar_button);
            header.pack_end (menu_button);

            notebook = new Gtk.Notebook ();
            notebook.set_show_border (false);
            notebook.set_show_tabs (false);

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            content.append (notebook);
            content.set_margin_start (15);
            content.set_margin_end (15);
            content.set_margin_top (15);
            content.set_margin_bottom (15);

            toast_overlay = new Adw.ToastOverlay ();
            toast_overlay.set_child (content);

            append (header);
            append (toast_overlay);
        }

        public void switch_launcher (string title, int position) {
            window_title.set_title (title);
            notebook.set_current_page (position);
        }

        public void initialize (List<Models.Launcher> launchers) {
            foreach (var launcher in launchers) {
                initalize_launcher (launcher);
            }
        }

        void initalize_launcher (Models.Launcher launcher) {
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);

            foreach (var group in launcher.groups) {
                initialize_group (group, content);
            }

            var clamp = new Adw.Clamp ();
            clamp.set_maximum_size (700);
            clamp.set_child (content);

            var scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_vexpand (true);
            scrolled_window.set_child (clamp);

            notebook.append_page (scrolled_window);
        }

        void initialize_group (Models.Group group, Gtk.Box content) {
            var preferences_group = new Adw.PreferencesGroup ();
            preferences_group.set_title (group.title);
            preferences_group.set_description (group.description);

            content.append (preferences_group);

            foreach (var runner in group.runners) {
                initialize_runner (runner, preferences_group);
            }
        }

        void initialize_runner (Models.Runner runner, Adw.PreferencesGroup preferences_group) {
            var spinner = new Gtk.Spinner ();
            spinner.set_visible (false);

            var row = new Adw.ExpanderRow ();
            row.set_title (runner.title);
            row.set_subtitle (runner.description);
            row.add_suffix (spinner);

            row.notify["expanded"].connect (() => {
                if (row.get_expanded () && runner.releases.length () == 0) {
                    spinner.start ();
                    spinner.set_visible (true);
                    runner.load.begin ((obj, res) => {
                        var releases = runner.load.end (res);

                        foreach (var release in releases) {
                            row.add_row (release.row);
                        }

                        // TODO Add a way to add the load more row if needed

                        spinner.stop ();
                        spinner.set_visible (false);
                    });
                }
            });

            preferences_group.add (row);
        }
    }
}