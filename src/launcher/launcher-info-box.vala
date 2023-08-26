namespace ProtonPlus.Launcher {
    public class LauncherInfoBox : Gtk.Box {
        Adw.ToastOverlay toast_overlay;
        Adw.WindowTitle window_title;
        Adw.HeaderBar header;
        Gtk.Notebook notebook;
        Gtk.Button back_btn;
        Gtk.Switch installedOnlySwitch;
        bool installedOnly;
        List<Container> containers;

        construct {
            //
            this.set_orientation (Gtk.Orientation.VERTICAL);

            //
            window_title = new Adw.WindowTitle ("", "");

            //
            back_btn = new Gtk.Button.from_icon_name ("go-previous-symbolic");
            back_btn.set_visible (false);
            back_btn.clicked.connect (() => this.activate_action_variant ("win.switch-content-page", 0));

            //
            header = new Adw.HeaderBar ();
            header.set_show_start_title_buttons (false);
            header.set_title_widget (window_title);
            header.pack_start (back_btn);

            //
            installedOnlySwitch = new Gtk.Switch ();
            installedOnlySwitch.set_active (installedOnly);
            installedOnlySwitch.notify.connect (installedOnlySwitch_Notify);

            //
            var installedOnlyLabel = new Gtk.Label ("Installed only");
            installedOnlyLabel.add_css_class ("bold");

            //
            var installedOnlySpacer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            installedOnlySpacer.set_hexpand (true);

            //
            var installedOnlyBox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
            installedOnlyBox.append (installedOnlyLabel);
            installedOnlyBox.append (installedOnlySpacer);
            installedOnlyBox.append (installedOnlySwitch);

            //
            var clamp = new Adw.Clamp ();
            clamp.set_maximum_size (700);
            clamp.set_child (installedOnlyBox);

            //
            notebook = new Gtk.Notebook ();
            notebook.set_show_border (false);
            notebook.set_show_tabs (false);

            //
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            content.append (clamp);
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

        public void initialize (List<Shared.Models.Launcher> launchers) {
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
                        releasesRow.add_action (spinner);
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
                        releasesRow.add_action (spinner);
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

        void load_releases (Gtk.Spinner spinner, Shared.Models.Runner runner, Adw.ExpanderRow releasesRow) {
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
                    message ("Installed only: " + installedOnly.to_string ());

                    var length = installedOnly ? runner.installed_releases.length () : runner.releases.length ();
                    for (var i = previous_count; i < length; i++) {
                        var release = installedOnly ? runner.installed_releases.nth_data (i) : runner.releases.nth_data (i);

                        if (release != null) {
                            var row = new Launcher.ActionRow ();
                            row.set_title (release.title);
                            row.Actions = get_actions_box (release, row);
                            row.add_suffix (row.Actions);

                            releasesRow.add_row (row);
                        }
                    }

                    if (runner.releases_count == runner.page * 25 && !installedOnly) {
                        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
                        actions.set_margin_end (10);
                        actions.set_valign (Gtk.Align.CENTER);

                        var row = new Launcher.ActionRow ();
                        row.set_title (_("Load more"));
                        row.Actions = actions;
                        row.add_suffix (row.Actions);

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

        void delete_release (Shared.Models.Release release, Launcher.ActionRow widget) {
            this.activate_action_variant ("win.add-task", "");

            var toast = new Adw.Toast (_("Are you sure you want to delete ") + release.title + "?");
            toast.set_timeout (30000);
            toast.set_button_label (_("Confirm"));

            toast.button_clicked.connect (() => {
                release.delete (false);

                GLib.Timeout.add (1000, () => {
                    if (!release.installed) {
                        widget.remove (widget.Actions);

                        widget.Actions = get_actions_box (release, widget);
                        widget.add_suffix (widget.Actions);

                        this.activate_action_variant ("win.remove-task", "");

                        return false;
                    }

                    return true;
                });

                toast.dismiss ();
            });

            toast_overlay.add_toast (toast);
        }

        void install_release (Shared.Models.Release release, Launcher.ActionRow widget) {
            this.activate_action_variant ("win.add-task", "");

            widget.remove (widget.Actions);

            var spinner = new Gtk.Spinner ();
            spinner.set_visible (false);

            var label = new Gtk.Label ("0%");

            var cancel = new Gtk.Button.from_icon_name ("process-stop-symbolic");
            cancel.set_tooltip_text (_("Cancel the installation"));
            cancel.add_css_class ("flat");
            cancel.width_request = 25;
            cancel.height_request = 25;
            cancel.clicked.connect (() => {
                release.installation_cancelled = true;
            });

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.set_margin_end (10);
            box.set_valign (Gtk.Align.CENTER);
            box.append (label);
            box.append (spinner);
            box.append (cancel);

            widget.Actions = box;
            widget.add_suffix (widget.Actions);

            release.install ();

            if (release.runner.is_using_github_actions) {
                label.set_visible (false);
                spinner.set_visible (true);
                spinner.start ();
            }

            GLib.Timeout.add (250, () => {
                if (release.installation_cancelled) send_toast ("The installation of " + release.get_directory_name () + " was cancelled", 5000);

                if (release.installation_error && !release.installation_cancelled) send_toast ("There was an error while installing " + release.get_directory_name (), 5000);

                if (release.installation_api_error && !release.installation_error && !release.installation_cancelled) send_toast ("There was an error while fetching data from the GitHub API", 5000);

                if (!release.runner.is_using_github_actions && !release.installation_api_error && !release.installation_error && !release.installation_cancelled) label.set_text (release.installation_progress.to_string () + "%");

                if (release.installed || release.installation_cancelled || release.installation_error || release.installation_api_error) {
                    label.set_text ("");

                    spinner.stop ();

                    widget.remove (widget.Actions);

                    widget.Actions = get_actions_box (release, widget);
                    widget.add_suffix (widget.Actions);

                    this.activate_action_variant ("win.remove-task", "");

                    return false;
                }

                return true;
            });
        }

        Gtk.Box get_actions_box (Shared.Models.Release release, Launcher.ActionRow widget) {
            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            actions.set_margin_end (10);
            actions.set_valign (Gtk.Align.CENTER);

            var btn = release.installed ? get_delete_button (release, widget) : get_install_button (release, widget);
            if (release.runner.api_error && !release.installed) btn.set_visible (false);
            actions.append (btn);

            return actions;
        }

        Gtk.Button get_delete_button (Shared.Models.Release release, Launcher.ActionRow widget) {
            var btnDelete = new Gtk.Button ();

            btnDelete.add_css_class ("flat");
            btnDelete.set_icon_name ("user-trash-symbolic");
            btnDelete.width_request = 25;
            btnDelete.height_request = 25;
            btnDelete.set_tooltip_text (_("Delete the runner"));
            btnDelete.clicked.connect (() => delete_release (release, widget));

            return btnDelete;
        }

        Gtk.Button get_install_button (Shared.Models.Release release, Launcher.ActionRow widget) {
            var btnInstall = new Gtk.Button ();

            btnInstall.set_icon_name ("folder-download-symbolic");
            btnInstall.add_css_class ("flat");
            btnInstall.width_request = 25;
            btnInstall.height_request = 25;
            btnInstall.set_tooltip_text (_("Install the runner"));
            btnInstall.clicked.connect (() => install_release (release, widget));

            return btnInstall;
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

        public void set_back_btn_visible (bool visible) {
            back_btn.set_visible (visible);
        }

        void installedOnlySwitch_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "active") {
                installedOnly = !installedOnly;

                foreach (var container in containers) {
                    container.box_normal.set_visible (!installedOnly);
                    container.box_filtered.set_visible (installedOnly);
                }
            }
        }
    }

    public class ActionRow : Adw.ActionRow {
        public Gtk.Box Actions;
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