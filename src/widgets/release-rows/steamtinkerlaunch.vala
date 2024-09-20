namespace ProtonPlus.Widgets.ReleaseRows {
    public class SteamTinkerLaunch : ReleaseRow {
        public Gtk.Button btn_upgrade { get; set; }
        public Dialogs.UpgradeDialog upgrade_dialog { get; set; }

        Models.Releases.SteamTinkerLaunch release;

        construct {
            upgrade_dialog = new Dialogs.UpgradeDialog ();

            btn_upgrade = new Gtk.Button ();
            btn_upgrade.add_css_class ("flat");

            input_box.append (btn_upgrade);
        }

        public void initialize (Models.Releases.SteamTinkerLaunch release) {
            this.release = release;

            if (release.runner.group.launcher.installation_type != Models.Launcher.InstallationTypes.SYSTEM) {
                input_box.remove (btn_remove);
                input_box.remove (btn_upgrade);
                input_box.remove (btn_install);

                btn_info.clicked.connect (btn_info_clicked);
            } else {
                input_box.remove (btn_info);

                btn_remove.clicked.connect (btn_remove_clicked);
                btn_install.clicked.connect (btn_install_clicked);
                btn_upgrade.clicked.connect (btn_upgrade_clicked);
            }

            notify["ui-state"].connect (ui_state_changed);

            notify_property ("ui-state");
        }

        void btn_remove_clicked () {
            var remove_check = new Gtk.CheckButton.with_label (_("Check this to also remove your configuration files."));

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

                release.remove.begin (remove_check.get_active (), true, (obj, res) => {
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

                    install_dialog.hide ();
                });
            });
        }

        void btn_upgrade_clicked () {
            if (release.updated)
                return;

            upgrade_dialog.reset ();

            upgrade_dialog.present ();

            upgrade_dialog.add_text (_("The upgrade of %s has begun.").printf (title));

            activate_action_variant ("win.add-task", "");

            release.upgrade.begin ((obj, res) => {
                var success = release.upgrade.end (res);

                activate_action_variant ("win.remove-task", "");

                if (success) {
                    upgrade_dialog.add_text (_("The upgrade of %s is complete.").printf (title));
                } else {
                    upgrade_dialog.add_text (_("An unexpected error occurred while upgrading %s.").printf (title));
                }

                Utils.System.sleep.begin (5000, (obj, res) => {
                    Utils.System.sleep.end (res);

                    upgrade_dialog.hide ();
                });
            });
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
                dialog.present ();
            }
        }

        void ui_state_changed () {
            // Determine which UI widgets to show in each UI state.
            var show_install = false;
            var show_remove = false;
            var show_upgrade = false;
            var show_info = true;

            switch (ui_state) {
            case UIState.BUSY_INSTALLING:
            case UIState.BUSY_REMOVING:
                show_info = false;
                break;
            case UIState.UP_TO_DATE:
            case UIState.UPDATE_AVAILABLE:
                show_remove = true;
                show_upgrade = true;
                break;
            case UIState.NOT_INSTALLED:
                show_install = true;
                break;
            default:
                // Everything will be hidden in unknown states.
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
            btn_info.set_visible (show_info);
        }
    }
}