namespace ProtonPlus.Widgets.ReleaseRows {
    public class SteamTinkerLaunch : ReleaseRow {
        public ReleaseRowButton btn_upgrade { get; set; }
        public ReleaseRowButton btn_info { get; set; }

        Models.Releases.SteamTinkerLaunch release;

        public SteamTinkerLaunch () {
            btn_upgrade = new ReleaseRowButton ();

            btn_info = new ReleaseRowButton ("info-circle-symbolic", _("Show more information"));

            input_box.append (btn_upgrade);
            input_box.append (btn_info);
        }

        public void initialize (Models.Releases.SteamTinkerLaunch release) {
            this.release = release;

            if (release.runner.group.launcher.installation_type != Models.Launcher.InstallationTypes.SYSTEM) {
                input_box.remove (progress_label);
                input_box.remove (spinner);
                input_box.remove (btn_cancel);
                input_box.remove (btn_remove);
                input_box.remove (btn_upgrade);
                input_box.remove (btn_install);

                btn_info.clicked.connect (btn_info_clicked);
            } else {
                input_box.remove (btn_info);

                btn_cancel.clicked.connect (btn_cancel_clicked);
                btn_remove.clicked.connect (btn_remove_clicked);
                btn_install.clicked.connect (btn_install_clicked);
                btn_upgrade.clicked.connect (btn_upgrade_clicked);
            }

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

                    release.remove.begin (remove_check.get_active (), true, (obj, res) => {
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

        void btn_upgrade_clicked () {
            if (release.updated) {
                // Utils.GUI.send_toast (toast_overlay, _("%s is already up-to-date.").printf (title), 3);
            } else {
                // Utils.GUI.send_toast (toast_overlay, _("The upgrade of %s has begun.").printf (title), 3);

                activate_action_variant ("win.add-task", "");

                release.upgrade.begin ((obj, res) => {
                    var success = release.upgrade.end (res);

                    activate_action_variant ("win.remove-task", "");

                    if (success) {
                        // Utils.GUI.send_toast (toast_overlay, _("The upgrade of %s is complete.").printf (title), 3);
                    } else {
                        // Utils.GUI.send_toast (toast_overlay, _("An unexpected error occurred while upgrading %s.").printf (title), 5000);
                    }
                });
            }
        }

        void btn_info_clicked () {
            Adw.MessageDialog? dialog = null;
            switch (release.runner.group.launcher.installation_type) {
            case Models.Launcher.InstallationTypes.FLATPAK :
                dialog = new Adw.MessageDialog (Application.window, _("%s is not supported").printf ("Steam Flatpak"), "%s\n\n%s".printf (_("To install %s for the %s, please run the following command:").printf (title, "Steam Flatpak"), "flatpak install com.valvesoftware.Steam.Utility.steamtinkerlaunch"));
                break;
            case Models.Launcher.InstallationTypes.SNAP:
                dialog = new Adw.MessageDialog (Application.window, _("%s is not supported").printf ("Steam Snap"), _("There's currently no known way for us to install %s for the %s.").printf (title, "Steam Snap"));
                break;
            default:
                break;
            }
            if (dialog != null) {
                dialog.add_response ("ok", _("OK"));
                dialog.show ();
            }
        }

        void ui_state_changed () {
            // Determine which UI widgets to show in each UI state.
            var show_install = false;
            var show_remove = false;
            var show_upgrade = false;
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
            case UIState.UP_TO_DATE:
            case UIState.UPDATE_AVAILABLE:
                show_remove = true;
                show_upgrade = true;
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


            // Use the correct icon and tooltip for the upgrade button.
            if (show_upgrade) {
                var icon_upgrade = (Gtk.Image) btn_upgrade.get_child ();
                icon_upgrade.set_from_icon_name (release.updated ? "circle-check-symbolic" : "circle-chevron-up-symbolic");
                btn_upgrade.set_tooltip_text (release.updated ? _("%s is up-to-date").printf (title) : _("Update %s to the latest version").printf (title));
            }


            // Configure UI widgets for the new state.
            btn_install.set_visible (show_install);
            btn_remove.set_visible (show_remove);
            btn_upgrade.set_visible (show_upgrade);
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
        }
    }
}