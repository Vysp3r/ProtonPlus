namespace ProtonPlus.Widgets.ReleaseRows {
    public class Basic : ReleaseRow {
        Models.Releases.Basic release { get; set; }

        construct {
            btn_remove.clicked.connect (btn_remove_clicked);
            btn_install.clicked.connect (btn_install_clicked);
            btn_info.clicked.connect (btn_info_clicked);
        }

        public void initialize (Models.Releases.Basic release) {
            this.release = release;

            install_dialog.initialize (release);
            remove_dialog.initialize (release);

            if (release.description == null || release.page_url == null)
                input_box.remove (btn_info);

            release.send_message.connect (dialog_message_received);

            release.notify["displayed-title"].connect (release_displayed_title_changed);

            release_displayed_title_changed ();

            release.notify["state"].connect (release_state_changed);

            release_state_changed ();
        }

        void btn_remove_clicked () {
            var message_dialog = new Adw.MessageDialog (Application.window, _("Delete %s").printf (release.title), "%s\n\n%s".printf (_("You're about to remove %s from your system.").printf (release.title), _("Are you sure you want this?")));

            message_dialog.add_response ("no", _("No"));
            message_dialog.add_response ("yes", _("Yes"));

            message_dialog.set_response_appearance ("no", Adw.ResponseAppearance.DEFAULT);
            message_dialog.set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);

            message_dialog.choose.begin (null, (obj, res) => {
                var response = message_dialog.choose.end (res);

                if (response != "yes")
                    return;

                activate_action_variant ("win.add-task", "");

                remove_dialog.reset ();

                remove_dialog.present ();

                release.remove.begin ((obj, res) => {
                    var success = release.remove.end (res);

                    remove_dialog.done (success);

                    activate_action_variant ("win.remove-task", "");
                });
            });
        }

        void btn_install_clicked () {
            activate_action_variant ("win.add-task", "");

            install_dialog.reset ();

            install_dialog.present ();

            release.install.begin ((obj, res) => {
                var success = release.install.end (res);

                install_dialog.done (success || release.canceled);

                activate_action_variant ("win.remove-task", "");
            });
        }

        void btn_info_clicked () {
            var info_dialog = new Adw.MessageDialog (Application.window, "%s %s".printf (_("About"), release.title), release.description);

            info_dialog.add_response ("close", _("Close"));
            info_dialog.add_response ("open", _("Open in a browser"));

            info_dialog.set_response_appearance ("close", Adw.ResponseAppearance.DEFAULT);
            info_dialog.set_response_appearance ("open", Adw.ResponseAppearance.DESTRUCTIVE);

            info_dialog.choose.begin (null, (obj, res) => {
                var response = info_dialog.choose.end (res);

                if (response == "open")
                    Utils.System.open_url (release.page_url);
            });
        }

        void release_displayed_title_changed () {
            set_title (release.displayed_title);
        }

        void release_state_changed () {
            var installed = release.state == Models.Release.State.UP_TO_DATE;

            btn_install.set_visible (!installed);
            btn_remove.set_visible (installed);
        }

        void dialog_message_received (string message) {
            switch (release.state) {
            case Models.Release.State.BUSY_INSTALLING:
                install_dialog.add_text (message);
                break;
            case Models.Release.State.BUSY_REMOVING:
                remove_dialog.add_text (message);
                break;
            default:
                break;
            }
        }
    }
}