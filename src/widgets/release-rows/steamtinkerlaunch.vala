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

            install_dialog.initialize (release);
            remove_dialog.initialize (release);
            upgrade_dialog.initialize (release);

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

            release.send_message.connect (dialog_message_received);

            release.notify["displayed-title"].connect (release_displayed_title_changed);

            release_displayed_title_changed ();

            release.notify["state"].connect (release_state_changed);

            release_state_changed ();
        }

        void btn_remove_clicked () {
            var remove_check = new Gtk.CheckButton.with_label (_("Check this to also remove your configuration files."));

            var message_dialog = new Adw.MessageDialog (Application.window, _("Delete %s").printf (release.title), "%s\n\n%s".printf (_("You're about to remove %s from your system.").printf (release.title), _("Are you sure you want this?")));

            message_dialog.set_extra_child (remove_check);

            message_dialog.add_response ("no", _("No"));
            message_dialog.add_response ("yes", _("Yes"));

            message_dialog.set_response_appearance ("no", Adw.ResponseAppearance.DEFAULT);
            message_dialog.set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);

            message_dialog.response.connect ((response) => {
                if (response != "yes")
                    return;

                activate_action_variant ("win.add-task", "");

                remove_dialog.reset ();

                remove_dialog.present ();

                var parameters = new Models.Releases.SteamTinkerLaunch.STL_Remove_Parameters ();
                parameters.delete_config = remove_check.get_active ();
                parameters.user_request = true;

                release.remove.begin (parameters, (obj, res) => {
                    var success = release.remove.end (res);

                    remove_dialog.done (success);

                    activate_action_variant ("win.remove-task", "");
                });
            });

            message_dialog.present ();
        }

        void btn_install_clicked () {
            // Steam Deck doesn't need any external dependencies.
            if (!Utils.System.IS_STEAM_OS) {
                var missing_dependencies = "";

                var yad_installed = false;
                if (Utils.System.check_dependency ("yad")) {
                    string stdout = Utils.System.run_command ("yad --version");
                    float version = float.parse (stdout.split (" ")[0]);
                    yad_installed = version >= 7.2;
                }
                if (!yad_installed)missing_dependencies += "yad >= 7.2\n";

                if (!Utils.System.check_dependency ("awk") && !Utils.System.check_dependency ("gawk"))missing_dependencies += "awk/gawk\n";
                if (!Utils.System.check_dependency ("git"))missing_dependencies += "git\n";
                if (!Utils.System.check_dependency ("pgrep"))missing_dependencies += "pgrep\n";
                if (!Utils.System.check_dependency ("unzip"))missing_dependencies += "unzip\n";
                if (!Utils.System.check_dependency ("wget"))missing_dependencies += "wget\n";
                if (!Utils.System.check_dependency ("xdotool"))missing_dependencies += "xdotool\n";
                if (!Utils.System.check_dependency ("xprop"))missing_dependencies += "xprop\n";
                if (!Utils.System.check_dependency ("xrandr"))missing_dependencies += "xrandr\n";
                if (!Utils.System.check_dependency ("xxd"))missing_dependencies += "xxd\n";
                if (!Utils.System.check_dependency ("xwininfo"))missing_dependencies += "xwininfo\n";

                if (missing_dependencies != "") {
                    var dialog = new Adw.MessageDialog (Widgets.Application.window, _("Missing dependencies!"), "%s\n\n%s\n%s".printf (_("You are missing the following dependencies for %s:").printf (title), missing_dependencies, _("Installation will be canceled.")));

                    dialog.add_response ("ok", _("OK"));

                    dialog.present ();

                    return;
                }
            }

            var has_external_install = release.detect_external_locations ();

            if (has_external_install) {
                var dialog = new Adw.MessageDialog (Widgets.Application.window, _("Existing installation of %s").printf (title), "%s\n\n%s".printf (_("It looks like you currently have another version of %s which was not installed by ProtonPlus.").printf (title), _("Do you want to delete it and install %s with ProtonPlus?").printf (title)));

                dialog.add_response ("cancel", _("Cancel"));
                dialog.add_response ("ok", _("OK"));

                dialog.set_response_appearance ("cancel", Adw.ResponseAppearance.DEFAULT);
                dialog.set_response_appearance ("ok", Adw.ResponseAppearance.DESTRUCTIVE);

                dialog.choose.begin (null, (obj, res) => {
                    string response = dialog.choose.end (res);

                    if (response != "ok")
                        return;

                    start_install ();
                });
            } else {
                start_install ();
            }
        }

        void start_install () {
            activate_action_variant ("win.add-task", "");

            install_dialog.reset ();

            install_dialog.present ();

            release.install.begin ((obj, res) => {
                var success = release.install.end (res);

                install_dialog.done (success);

                activate_action_variant ("win.remove-task", "");
            });
        }

        void btn_upgrade_clicked () {
            if (release.state == Models.Release.State.UP_TO_DATE)
                return;

            activate_action_variant ("win.add-task", "");

            upgrade_dialog.reset ();

            upgrade_dialog.show ();

            release.upgrade.begin ((obj, res) => {
                var success = release.upgrade.end (res);

                upgrade_dialog.done (success);

                activate_action_variant ("win.remove-task", "");
            });
        }

        void btn_info_clicked () {
            Adw.MessageDialog? dialog = null;
            switch (release.runner.group.launcher.installation_type) {
            case Models.Launcher.InstallationTypes.FLATPAK :
                var command_label = new Gtk.Label ("flatpak install com.valvesoftware.Steam.Utility.steamtinkerlaunch");
                command_label.set_selectable (true);
                dialog = new Adw.MessageDialog (Application.window, _("%s is not supported").printf ("Steam Flatpak"), _("To install %s for the %s, please run the following command:").printf (release.title, "Steam Flatpak"));
                dialog.set_extra_child (command_label);
                break;
            case Models.Launcher.InstallationTypes.SNAP:
                dialog = new Adw.MessageDialog (Application.window, _("%s is not supported").printf ("Steam Snap"), _("There's currently no known way for us to install %s for the %s.").printf (release.title, "Steam Snap"));
                break;
            default:
                break;
            }
            if (dialog != null) {
                dialog.add_response ("ok", _("OK"));

                dialog.present ();
            }
        }

        void release_displayed_title_changed () {
            set_title (release.displayed_title);
        }

        void release_state_changed () {
            var installed = release.state == Models.Release.State.UP_TO_DATE || release.state == Models.Release.State.UPDATE_AVAILABLE;
            var updated = release.state == Models.Release.State.UP_TO_DATE;

            btn_install.set_visible (!installed);
            btn_remove.set_visible (installed);
            btn_upgrade.set_visible (installed);

            if (btn_upgrade.get_visible ()) {
                btn_upgrade.set_icon_name (updated ? "circle-check-symbolic" : "circle-chevron-up-symbolic");
                btn_upgrade.set_tooltip_text (updated ? _("%s is up-to-date").printf (release.title) : _("Update %s to the latest version").printf (release.title));
            }
        }

        void dialog_message_received (string message) {
            switch (release.state) {
            case Models.Release.State.BUSY_INSTALLING:
                install_dialog.add_text (message);
                break;
            case Models.Release.State.BUSY_REMOVING:
                remove_dialog.add_text (message);
                break;
            case Models.Release.State.BUSY_UPGRADING:
                upgrade_dialog.add_text (message);
                break;
            default:
                break;
            }
        }
    }
}