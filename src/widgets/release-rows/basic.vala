namespace ProtonPlus.Widgets.ReleaseRows {
    public class Basic : ReleaseRow {
        Models.Releases.Basic release { get; set; }

        public Basic (Models.Releases.Basic release) {
            this.release = release;

            if (release.description == null || release.page_url == null)
                input_box.remove (info_button);

            release.send_message.connect (dialog_message_received);

            release.notify["displayed-title"].connect (release_displayed_title_changed);

            release_displayed_title_changed ();

            release.notify["state"].connect (release_state_changed);

            release_state_changed ();
        }

        protected override void install_button_clicked () {
            activate_action_variant ("win.add-task", "");

            install_dialog = new Dialogs.InstallDialog ();
            install_dialog.initialize (release);
            install_dialog.present ();

            release.install.begin ((obj, res) => {
                var success = release.install.end (res);

                install_dialog.done (success || release.canceled);

                activate_action_variant ("win.remove-task", "");
            });
        }

        protected override void remove_button_clicked () {
            var alert_dialog = new Adw.AlertDialog (_("Delete %s").printf (release.title), "%s\n\n%s".printf (_("You're about to remove %s from your system.").printf (release.title), _("Are you sure you want this?")));

            alert_dialog.add_response ("no", _("No"));
            alert_dialog.add_response ("yes", _("Yes"));

            alert_dialog.set_response_appearance ("no", Adw.ResponseAppearance.DEFAULT);
            alert_dialog.set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);

            alert_dialog.choose.begin (Application.window, null, (obj, res) => {
                var response = alert_dialog.choose.end (res);

                if (response != "yes")
                    return;

                activate_action_variant ("win.add-task", "");

                remove_dialog = new Dialogs.RemoveDialog ();
                remove_dialog.initialize (release);
                remove_dialog.present ();

                var parameters = new Models.Releases.SteamTinkerLaunch.STL_Remove_Parameters ();

                release.remove.begin (parameters, (obj, res) => {
                    var success = release.remove.end (res);

                    remove_dialog.done (success);

                    activate_action_variant ("win.remove-task", "");
                });
            });
        }

        protected override void info_button_clicked () {
            var description_dialog = new DescriptionDialog (release);
            description_dialog.present ();
        }

        void release_displayed_title_changed () {
            set_title (release.displayed_title);
        }

        void release_state_changed () {
            var installed = release.state == Models.Release.State.UP_TO_DATE;

            install_button.set_visible (!installed);
            remove_button.set_visible (installed);
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