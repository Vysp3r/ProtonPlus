namespace ProtonPlus.Models {
    public class Release : Object {
        public Runner runner { get; set; }
        public string title { get; set; }
        public string description { get; set; }
        public string release_date { get; set; }
        public int64 download_size { get; set; }
        public string download_url { get; set; }
        public string page_url { get; set; }
        public string install_location { get; set; }
        public string artifacts_url { get; set; }

        internal bool installed { get; set; }
        internal bool canceled { get; set; }
        internal UIState ui_state { get; set; }
        internal Gtk.Label progress_label { get; set; }

        public enum UIState {
            // WARNING: `NO_STATE` *MUST* be FIRST entry in this list, to become
            // the "unitialized default value" for Gtk Object properties, since
            // nullable properties aren't allowed for Gtk Objects. You should
            // treat the `NO_STATE` value the same as you would treat `null`.
            NO_STATE,
            BUSY_INSTALLING,
            BUSY_REMOVING,
            UP_TO_DATE,
            UPDATE_AVAILABLE,
            NOT_INSTALLED,
            INSTALLED
        }

        public Release (Runner runner, string title) {
            this.runner = runner;
            this.title = title;
        }

        public Release.github (Runners.Basic runner, string title, string description, string release_date, int64 download_size, string download_url, string page_url) {
            this.runner = runner;
            this.title = title;
            this.description = description;
            this.release_date = release_date;
            this.download_size = download_size;
            this.download_url = download_url;
            this.page_url = page_url;

            install_location = runner.group.launcher.directory + runner.group.directory + "/" + runner.get_directory_name (title);

            refresh_interface_state ();
        }

        public Release.github_action (Runners.Basic runner, string title, string release_date, string download_url, string page_url, string artifacts_url) {
            this.runner = runner;
            this.title = title;
            this.release_date = release_date;
            this.download_url = download_url;
            this.page_url = page_url;
            this.artifacts_url = artifacts_url;

            install_location = runner.group.launcher.directory + runner.group.directory + "/" + runner.get_directory_name (title);

            refresh_interface_state ();
        }

        public Release.gitlab (Runners.Basic runner, string title, string description, string release_date, string download_url, string page_url) {
            this.runner = runner;
            this.title = title;
            this.description = description;
            this.release_date = release_date;
            this.download_url = download_url;
            this.page_url = page_url;

            install_location = runner.group.launcher.directory + runner.group.directory + "/" + runner.get_directory_name (title);

            refresh_interface_state ();
        }

        internal virtual void refresh_interface_state (bool can_reset_processing = false) {
            installed = FileUtils.test (install_location, FileTest.IS_DIR);

            var change_state = (can_reset_processing
                                || (ui_state != UIState.BUSY_INSTALLING
                                    && ui_state != UIState.BUSY_REMOVING));
            if (change_state)
                ui_state = installed ? UIState.INSTALLED : UIState.NOT_INSTALLED;
        }

        public virtual Adw.ActionRow create_row () {
            progress_label = new Gtk.Label (null);
            var spinner = new Gtk.Spinner ();
            var btn_cancel = Utils.GUI.create_button ("x-symbolic", _("Cancel the installation"));
            var btn_delete = Utils.GUI.create_button ("trash-symbolic", _("Delete %s").printf (title));
            var btn_install = Utils.GUI.create_button ("download-symbolic", _("Install %s").printf (title));
            var input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            var row = new Adw.ActionRow ();

            btn_cancel.clicked.connect (() => canceled = true);

            btn_delete.clicked.connect (() => {
                var delete_check = new Gtk.CheckButton.with_label (_("Check this to also delete your configuration files."));

                var dialog = new Adw.MessageDialog (Application.window, _("Delete %s").printf (title), "%s\n\n%s".printf (_("You're about to delete %s from your system.").printf (title), _("Are you sure you want this?")));
                dialog.set_extra_child (delete_check);
                dialog.add_response ("no", _("No"));
                dialog.add_response ("yes", _("Yes"));
                dialog.set_response_appearance ("no", Adw.ResponseAppearance.DEFAULT);
                dialog.set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);
                dialog.show ();
                dialog.response.connect ((response) => {
                    if (response == "yes") {
                        row.activate_action_variant ("win.add-task", "");

                        remove.begin ((obj, res) => {
                            var success = remove.end (res);

                            row.activate_action_variant ("win.remove-task", "");

                            if (success) {
                                // Utils.GUI.send_toast (toast_overlay, _("The removal of %s is complete.").printf (title), 3);
                            } else {
                                // Utils.GUI.send_toast (toast_overlay, _("An unexpected error occurred while removing %s.").printf (title), 5000);
                            }
                        });
                    }
                });
            });

            btn_install.clicked.connect (() => {
                // Utils.GUI.send_toast (toast_overlay, _("The installation of %s has begun.").printf (title), 3);

                row.activate_action_variant ("win.add-task", "");

                install.begin ((obj, res) => {
                    var success = install.end (res);

                    row.activate_action_variant ("win.remove-task", "");

                    if (success) {
                        // Utils.GUI.send_toast (toast_overlay, _("The installation of %s is complete.").printf (title), 3);
                    } else if (canceled) {
                        // Utils.GUI.send_toast (toast_overlay, _("The installation of %s was canceled.").printf (title), 3);
                    } else {
                        // Utils.GUI.send_toast (toast_overlay, _("An unexpected error occurred while installing %s.").printf (title), 5000);
                    }
                });
            });

            input_box.set_margin_end (10);
            input_box.set_valign (Gtk.Align.CENTER);
            input_box.append (progress_label);
            input_box.append (spinner);
            input_box.append (btn_cancel);
            input_box.append (btn_delete);
            input_box.append (btn_install);

            row.add_suffix (input_box);

            this.notify["title"].connect (() => {
                row.set_title (title);
            });

            this.notify["ui-state"].connect (() => {
                // Determine which UI widgets to show in each UI state.
                var show_install = false;
                var show_delete = false;
                var show_cancel = false;
                var show_progress_label = false;
                var show_spinner = false;

                switch (ui_state) {
                    case UIState.BUSY_INSTALLING:
                    case UIState.BUSY_REMOVING:
                        show_spinner = true;
                        if (ui_state == UIState.BUSY_INSTALLING) {
                            show_cancel = true;
                            show_progress_label = true;
                        }
                        break;
                    case UIState.INSTALLED:
                        show_delete = true;
                        break;
                    case UIState.NOT_INSTALLED:
                        show_install = true;
                        break;
                    case UIState.NO_STATE:
                        // The UI state is not known yet. This value only exists
                        // because Gtk doesn't allow nullable Object properties.
                        break;
                    default:
                        // Everything will be hidden in unknown states.
                        message (@"Unsupported UI State: $ui_state\n");
                        break;
                }

                // Configure UI widgets for the new state.
                btn_install.set_visible (show_install);
                btn_delete.set_visible (show_delete);
                btn_cancel.set_visible (show_cancel);

                if (show_progress_label)// Erase old progress text on state change.
                    progress_label.set_text ("");
                progress_label.set_visible (show_progress_label);

                if (show_spinner) {
                    spinner.start ();
                    spinner.set_visible (true);
                } else {
                    spinner.stop ();
                    spinner.set_visible (false);
                }

                // message (@"UI State: $ui_state\n"); // For developers.
            });

            this.notify_property ("title");
            this.notify_property ("ui-state");

            return row;
        }

        async bool install () {
            // error = ERRORS.NONE;
            // status = STATUS.INSTALLING;
            // installation_progress = 0;

            // string url = download_link;
            // string path = runner.group.launcher.directory + runner.group.directory + "/" + title + file_extension;

            //// TODO: Add support for `is_percent == false` raw byte formatting,
            //// which happens when size is unknown? See steam.vala for how to do that.
            // var result = yield Utils.Web.Download (url, path, () => {}, (is_percent, progress) => installation_progress = progress);

            // switch (result) {
            // case Utils.Web.DOWNLOAD_CODES.API_ERROR:
            // error = ERRORS.API;
            // break;
            // case Utils.Web.DOWNLOAD_CODES.UNEXPECTED_ERROR:
            // error = ERRORS.UNEXPECTED;
            // break;
            // case Utils.Web.DOWNLOAD_CODES.SUCCESS:
            // error = ERRORS.NONE;
            // break;
            // }

            // if (error != ERRORS.NONE || status == STATUS.CANCELED) {
            // status = STATUS.UNINSTALLED;
            // return;
            // }

            // string directory = runner.group.launcher.directory + "/" + runner.group.directory + "/";

            // string source_path = yield Utils.Filesystem.extract (directory, title, file_extension, () => status == STATUS.CANCELED);

            // if (source_path == "") {
            // error = ERRORS.EXTRACT;
            // status = STATUS.UNINSTALLED;
            // return;
            // }

            // if (runner.is_using_github_actions) {
            // source_path = yield Utils.Filesystem.extract (directory, source_path.substring (0, source_path.length - 4).replace (directory, ""), ".tar", () => status == STATUS.CANCELED);

            // if (error != ERRORS.NONE || status == STATUS.CANCELED) {
            // status = STATUS.UNINSTALLED;
            // return;
            // }

            // if (runner.title_type != Runner.title_types.NONE) {
            // yield Utils.Filesystem.rename (source_path, directory + get_directory_name ());
            // }

            // runner.group.launcher.install (this);

            // status = STATUS.INSTALLED;
            // } else {
            // if (error != ERRORS.NONE || status == STATUS.CANCELED) {
            // status = STATUS.UNINSTALLED;
            // return;
            // }

            // if (runner.title_type != Runner.title_types.NONE) {
            // yield Utils.Filesystem.rename (source_path, directory + get_directory_name ());
            // }

            // runner.group.launcher.install (this);

            // status = STATUS.INSTALLED;
            // }
            return false;
        }

        async bool remove () {
            // error = ERRORS.NONE;
            // status = STATUS.UNINSTALLING;

            // var deleted = yield Utils.Filesystem.delete_directory (directory);

            // if (deleted) {
            // runner.group.launcher.uninstall (this);
            // status = STATUS.UNINSTALLED;
            // } else {
            // error = ERRORS.DELETE;
            // status = STATUS.INSTALLED;
            // }
            return false;
        }
    }
}