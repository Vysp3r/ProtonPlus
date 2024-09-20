namespace ProtonPlus.Widgets.ReleaseRows {
    public class Basic : ReleaseRow {
        Models.Releases.Basic release { get; set; }

        public void initialize (Models.Releases.Basic release) {
            this.release = release;

            set_title (release.title);

            btn_remove.clicked.connect (btn_remove_clicked);
            btn_install.clicked.connect (btn_install_clicked);

            if (release.description == null || release.page_url == null)
                input_box.remove (btn_info);
            else
                btn_info.clicked.connect (btn_info_clicked);

            notify["ui-state"].connect (ui_state_changed);

            notify_property ("ui-state");
        }

        void btn_remove_clicked () {
            var message_dialog = new Adw.MessageDialog (Application.window, _("Delete %s").printf (title), "%s\n\n%s".printf (_("You're about to remove %s from your system.").printf (title), _("Are you sure you want this?")));

            message_dialog.add_response ("no", _("No"));
            message_dialog.add_response ("yes", _("Yes"));

            message_dialog.set_response_appearance ("no", Adw.ResponseAppearance.DEFAULT);
            message_dialog.set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);

            message_dialog.response.connect ((response) => {
                if (response != "yes")
                    return;

                remove_dialog.reset ();

                remove_dialog.present ();

                remove_dialog.add_text (_("The removal of %s has begun.").printf (title));

                activate_action_variant ("win.add-task", "");

                release.remove.begin ((obj, res) => {
                    var success = release.remove.end (res);

                    activate_action_variant ("win.remove-task", "");

                    if (success) {
                        remove_dialog.add_text (_("The removal of %s is complete.").printf (title));
                    } else {
                        remove_dialog.add_text (_("An unexpected error occurred while removing %s.").printf (title));
                    }

                    Utils.System.sleep.begin (5000, (obj, res) => {
                        Utils.System.sleep.end (res);

                        remove_dialog.hide ();
                    });
                });
            });

            message_dialog.present ();
        }

        void btn_install_clicked () {
            install_dialog.reset ();

            install_dialog.cancel_button.clicked.connect (() => release.canceled = true);

            install_dialog.present ();

            install_dialog.add_text (_("The installation of %s has begun.").printf (title));

            activate_action_variant ("win.add-task", "");

            release.install.begin ((obj, res) => {
                var success = release.install.end (res);

                activate_action_variant ("win.remove-task", "");

                if (success) {
                    install_dialog.add_text (_("The installation of %s is complete.").printf (title));
                } else if (release.canceled) {
                    install_dialog.add_text (_("The installation of %s was canceled.").printf (title));
                } else {
                    install_dialog.add_text (_("An unexpected error occurred while installing %s.").printf (title));
                }

                Utils.System.sleep.begin (5000, (obj, res) => {
                    Utils.System.sleep.end (res);

                    install_dialog.close ();
                });
            });
        }

        void btn_info_clicked () {
            var dialog = new Adw.MessageDialog (Application.window, "%s %s".printf (_("About"), release.title), release.description);
            dialog.add_response ("close", _("Close"));
            dialog.add_response ("open", _("Open in a browser"));
            dialog.set_response_appearance ("close", Adw.ResponseAppearance.DEFAULT);
            dialog.set_response_appearance ("open", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.present ();
            dialog.response.connect ((response) => {
                if (response == "open")
                    Utils.System.open_url (release.page_url);
            });
        }

        void ui_state_changed () {
            // Determine which UI widgets to show in each UI state.
            var show_install = false;
            var show_remove = false;
            var show_info = true;

            switch (ui_state) {
            case UIState.BUSY_INSTALLING:
            case UIState.BUSY_REMOVING:
                show_info = false;
                break;
            case UIState.INSTALLED:
                show_remove = true;
                break;
            case UIState.NOT_INSTALLED:
                show_install = true;
                break;
            default:
                // Everything will be hidden in unknown states.
                break;
            }

            // Configure UI widgets for the new state.
            btn_install.set_visible (show_install);
            btn_remove.set_visible (show_remove);
            btn_info.set_visible (show_info);
        }
    }
}