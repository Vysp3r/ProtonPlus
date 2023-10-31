namespace ProtonPlus.Widgets {
    public class InfoBox : Gtk.Box {
        public Gtk.Button sidebar_button { get; set; }
        public bool installedOnly { get; set; }
        public List<Container> containers;

        Adw.ToastOverlay toast_overlay { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Adw.HeaderBar header { get; set; }
        Gtk.Notebook notebook { get; set; }

        construct {
            //
            this.set_orientation (Gtk.Orientation.VERTICAL);

            //
            window_title = new Adw.WindowTitle ("", "");

            //
            sidebar_button = new Gtk.Button.from_icon_name ("view-dual-symbolic");
            sidebar_button.set_visible (false);

            //
            var menu_model = new GLib.Menu ();
            menu_model.append (_("About"), "app.about");
            
            //
            var menu_button = new Gtk.MenuButton ();
            menu_button.set_icon_name ("open-menu-symbolic");
            menu_button.set_menu_model (menu_model);

            //
            header = new Adw.HeaderBar ();
            header.add_css_class ("flat");
            header.set_title_widget (window_title);
            header.pack_start (sidebar_button);
            header.pack_end (menu_button);

            //
            notebook = new Gtk.Notebook ();
            notebook.set_show_border (false);
            notebook.set_show_tabs (false);

            //
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            content.append (notebook);
            content.set_margin_start (15);
            content.set_margin_end (15);
            content.set_margin_top (15);
            content.set_margin_bottom (15);

            //
            toast_overlay = new Adw.ToastOverlay ();
            toast_overlay.set_child (content);

            //
            append (header);
            append (toast_overlay);
        }

        public void initialize (List<Models.Launcher> launchers) {
            containers = new List<Container> ();
            foreach (var launcher in launchers) {
                var content_normal = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
                content_normal.set_visible (!installedOnly);

                foreach (var group in launcher.groups) {
                    var preferences_group = new Adw.PreferencesGroup ();
                    preferences_group.set_title (group.title);
                    preferences_group.set_description (group.description);

                    content_normal.append (preferences_group);

                    foreach (var runner in group.runners) {
                        var spinner = new Gtk.Spinner ();
                        spinner.set_visible (false);

                        var releasesRow = new Adw.ExpanderRow ();
                        releasesRow.set_title (runner.title);
                        releasesRow.set_subtitle (runner.description);
                        releasesRow.add_suffix (spinner);
                        releasesRow.notify.connect ((pspec) => {
                            if (pspec.get_name () == "expanded" && releasesRow.get_expanded () && !runner.loaded) load_releases (spinner, runner, releasesRow);
                        });

                        preferences_group.add (releasesRow);
                    }
                }

                var content_filtered = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
                content_filtered.set_visible (installedOnly);

                foreach (var group in launcher.groups) {
                    var preferences_group = new Adw.PreferencesGroup ();
                    preferences_group.set_title (group.title);
                    preferences_group.set_description (group.description);

                    content_filtered.append (preferences_group);

                    foreach (var runner in group.runners) {
                        var spinner = new Gtk.Spinner ();
                        spinner.set_visible (false);

                        var releasesRow = new Adw.ExpanderRow ();
                        releasesRow.set_title (runner.title);
                        releasesRow.set_subtitle (runner.description);
                        releasesRow.add_suffix (spinner);
                        releasesRow.notify.connect ((pspec) => {
                            if (pspec.get_name () == "expanded" && releasesRow.get_expanded ()) {
                                if (!installedOnly && runner.loaded) return;
                                if (installedOnly && runner.installed_loaded) return;
                                load_releases (spinner, runner, releasesRow);
                            }
                        });

                        preferences_group.add (releasesRow);
                    }
                }

                containers.append (new Container (content_normal, content_filtered));

                var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                content.append (content_normal);
                content.append (content_filtered);

                var clamp = new Adw.Clamp ();
                clamp.set_maximum_size (700);
                clamp.set_child (content);

                var scrolled_window = new Gtk.ScrolledWindow ();
                scrolled_window.set_vexpand (true);
                scrolled_window.set_child (clamp);

                notebook.append_page (scrolled_window);
            }
        }

        void load_releases (Gtk.Spinner spinner, Models.Runner runner, Adw.ExpanderRow releasesRow) {
            bool done = false;

            spinner.start ();
            spinner.set_visible (true);

            uint previous_count = installedOnly ? 0 : runner.releases.length ();

            //
            new Thread<void> ("load_releases", () => {
                runner.load (installedOnly);
                done = true;
            });

            //
            GLib.Timeout.add (1000, () => {
                if (done) {
                    var length = installedOnly ? runner.installed_releases.length () : runner.releases.length ();
                    for (var i = previous_count; i < length; i++) {
                        var release = installedOnly ? runner.installed_releases.nth_data (i) : runner.releases.nth_data (i);

                        if (release != null) {
                            releasesRow.add_row (create_release_row(release));
                        }
                    }

                    if (runner.releases_count == runner.page * 25 && !installedOnly) {
                        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
                        actions.set_margin_end (10);
                        actions.set_valign (Gtk.Align.CENTER);

                        var row = new Adw.ActionRow ();
                        row.set_title (_("Load more"));
                        row.add_suffix (actions);

                        var btn = new Gtk.Button ();
                        btn.set_icon_name ("content-loading-symbolic");
                        btn.add_css_class ("flat");
                        btn.width_request = 25;
                        btn.height_request = 25;
                        btn.set_tooltip_text (_("Load more"));
                        btn.clicked.connect (() => {
                            releasesRow.remove (row);
                            load_releases (spinner, runner, releasesRow);
                        });

                        actions.append (btn);

                        releasesRow.add_row (row);
                    }

                    spinner.stop ();
                    spinner.set_visible (false);

                    if (runner.api_error) {
                        var toast = new Adw.Toast (_("There was an error while fetching data from the GitHub API"));
                        toast.set_timeout (5000);

                        toast_overlay.add_toast (toast);
                    }

                    return false;
                }

                return true;
            });
        }

        Adw.ActionRow create_release_row (Models.Release release) {
            var label = new Gtk.Label (null);
            label.set_visible (false);

            var spinner = new Gtk.Spinner ();
            spinner.set_visible (false);

            var cancel = new Gtk.Button.from_icon_name ("process-stop-symbolic");
            cancel.set_visible (false);
            cancel.set_tooltip_text (_("Cancel the installation"));
            cancel.add_css_class ("flat");
            cancel.width_request = 25;
            cancel.height_request = 25;
            cancel.clicked.connect (() => release.cancel ());

            var btnDelete = new Gtk.Button ();
            btnDelete.add_css_class ("flat");
            btnDelete.set_icon_name ("user-trash-symbolic");
            btnDelete.width_request = 25;
            btnDelete.height_request = 25;
            btnDelete.set_tooltip_text (_("Delete the runner"));
            btnDelete.clicked.connect (() => {
                var toast = new Adw.Toast (_("Are you sure you want to delete ") + release.title + "?");
                toast.set_timeout (30000);
                toast.set_button_label (_("Confirm"));

                toast.button_clicked.connect (() => {
                    release.delete ();

                    toast.dismiss ();
                });

                toast_overlay.add_toast (toast);
            });

            var btnInstall = new Gtk.Button ();
            btnInstall.set_icon_name ("folder-download-symbolic");
            btnInstall.add_css_class ("flat");
            btnInstall.width_request = 25;
            btnInstall.height_request = 25;
            btnInstall.set_tooltip_text (_("Install the runner"));
            btnInstall.clicked.connect (() => release.install ());

            if (release.runner.api_error && !release.installed) {
                btnDelete.set_visible (false);
                btnInstall.set_visible (false);
            } else {
                btnDelete.set_visible (release.installed);
                btnInstall.set_visible (!release.installed);
            }

            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            actions.set_margin_end (10);
            actions.set_valign (Gtk.Align.CENTER);
            actions.append (label);
            actions.append (spinner);
            actions.append (cancel);
            actions.append (btnDelete);
            actions.append (btnInstall);

            release.notify["status"].connect(() => {
                switch(release.status) {
                    case Models.Release.STATUS.CANCELLED:
                        send_toast (_("The installation of ") + release.get_directory_name () + _(" was cancelled"), 3);

                        spinner.stop ();
                        spinner.set_visible (false);
                        label.set_visible (false);
                        cancel.set_visible (false);

                        btnDelete.set_visible (false);
                        btnInstall.set_visible (true);

                        break;
                    case Models.Release.STATUS.INSTALLING:
                        send_toast (_("The installation of ") + release.get_directory_name () + _(" was started"), 3);

                        this.activate_action_variant ("win.add-task", "");

                        GLib.Timeout.add (250, () => {
                            label.set_text (release.installation_progress.to_string () + "%");

                            return release.status == Models.Release.STATUS.INSTALLING;
                        });

                        spinner.start ();
                        spinner.set_visible (true);
                        label.set_visible (!release.runner.is_using_github_actions);
                        cancel.set_visible (!release.runner.is_using_github_actions);

                        btnDelete.set_visible (false);
                        btnInstall.set_visible (false);

                        break;
                    case Models.Release.STATUS.INSTALLED:
                        send_toast (_("The installation of ") + release.get_directory_name () + _(" is done"), 3);

                        this.activate_action_variant ("win.remove-task", "");

                        spinner.stop ();
                        spinner.set_visible (false);
                        label.set_visible (false);
                        cancel.set_visible (false);

                        btnDelete.set_visible (true);
                        btnInstall.set_visible (false);

                        break;
                    case Models.Release.STATUS.UNINSTALLING:
                        this.activate_action_variant ("win.add-task", "");

                        spinner.start ();
                        spinner.set_visible (true);

                        btnDelete.set_visible (false);
                        btnInstall.set_visible (false);

                        break;
                    case Models.Release.STATUS.UNINSTALLED:
                        if (release.previous_status != Models.Release.STATUS.CANCELLED && 
                            release.previous_status != Models.Release.STATUS.INSTALLING &&
                            release.error == Models.Release.ERRORS.NONE) {
                            send_toast (_("The deletion of ") + release.get_directory_name () + _(" is done"), 3);
                        }

                        this.activate_action_variant ("win.remove-task", "");

                        spinner.stop ();
                        spinner.set_visible (false);

                        btnDelete.set_visible (false);
                        btnInstall.set_visible (true);

                        break;
                }
            });

            release.notify["error"].connect(() => {
                switch(release.error) {
                    case Models.Release.ERRORS.API:
                        send_toast (_("There was an error while fetching data from the GitHub API"), 5000);
                        break;
                    case Models.Release.ERRORS.EXTRACT:
                        send_toast (_("An unexpected error occured while extracting ") + release.title, 5000);
                        break;
                    case Models.Release.ERRORS.UNEXPECTED:
                        send_toast (_("An unexpected error occured while installing ") + release.title, 5000);
                        break;
                    default:
                        break;
                }
            });

            var row = new Adw.ActionRow ();
            row.set_title (release.title);
            row.add_suffix (actions);

            return row;
        }

        void send_toast (string content, int duration) {
            var toast = new Adw.Toast (content);
            toast.set_timeout (duration);

            toast_overlay.add_toast (toast);
        }

        public void switch_launcher (string title, int position) {
            window_title.set_title (title);
            notebook.set_current_page (position);
        }
    }

    public class Container {
        public Gtk.Box box_normal;
        public Gtk.Box box_filtered;

        public Container (Gtk.Box box_normal, Gtk.Box box_filtered) {
            this.box_normal = box_normal;
            this.box_filtered = box_filtered;
        }
    }
}