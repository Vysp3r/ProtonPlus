namespace ProtonPlus.Widgets.ReleaseRows {
    public class Basic : ReleaseRow {
        Models.Releases.Basic release;

        public void initialize (Models.Releases.Basic release) {
            this.release = release;

            set_title (release.title);

            btn_cancel.clicked.connect (btn_cancel_clicked);
            btn_remove.clicked.connect (btn_remove_clicked);
            btn_install.clicked.connect (btn_install_clicked);

            notify["ui-state"].connect (ui_state_changed);

            notify_property ("ui-state");
        }

        void btn_cancel_clicked () {
            release.canceled = true;
        }

        void btn_remove_clicked () {
            var remove_check = new Gtk.CheckButton.with_label (_("Check this to also remove your configuration files."));

            var dialog = new Adw.MessageDialog (Application.window, _("Delete %s").printf (title), "%s\n\n%s".printf (_("You're about to remove %s from your system.").printf (title), _("Are you sure you want this?")));
            dialog.set_extra_child (remove_check);
            dialog.add_response ("no", _("No"));
            dialog.add_response ("yes", _("Yes"));
            dialog.set_response_appearance ("no", Adw.ResponseAppearance.DEFAULT);
            dialog.set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.show ();
            dialog.response.connect ((response) => {
                if (response == "yes") {
                    activate_action_variant ("win.add-task", "");

                    release.remove.begin ((obj, res) => {
                        var success = release.remove.end (res);

                        activate_action_variant ("win.remove-task", "");

                        if (success) {
                            // Utils.GUI.send_toast (toast_overlay, _("The removal of %s is complete.").printf (title), 3);
                        } else {
                            // Utils.GUI.send_toast (toast_overlay, _("An unexpected error occurred while removing %s.").printf (title), 5000);
                        }
                    });
                }
            });
        }

        void btn_install_clicked () {
// Utils.GUI.send_toast (toast_overlay, _("The installation of %s has begun.").printf (title), 3);

            activate_action_variant ("win.add-task", "");

            release.install.begin ((obj, res) => {
                var success = release.install.end (res);

                activate_action_variant ("win.remove-task", "");

                if (success) {
                    // Utils.GUI.send_toast (toast_overlay, _("The installation of %s is complete.").printf (title), 3);
                } else if (release.canceled) {
                    // Utils.GUI.send_toast (toast_overlay, _("The installation of %s was canceled.").printf (title), 3);
                } else {
                    // Utils.GUI.send_toast (toast_overlay, _("An unexpected error occurred while installing %s.").printf (title), 5000);
                }
            });
        }

        void ui_state_changed () {
            // Determine which UI widgets to show in each UI state.
            var show_install = false;
            var show_remove = false;
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
                show_remove = true;
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
                message (@"Unsupported UI State: $ui_state");
                break;
            }

            // Configure UI widgets for the new state.
            btn_install.set_visible (show_install);
            btn_remove.set_visible (show_remove);
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

            // message (@"UI State: $ui_state"); // For developers.
        }
    }
}