namespace ProtonPlus.Widgets.ReleaseRows {
    public class Basic : ReleaseRow {
        Models.Releases.Basic release { get; set; }

        public Basic (Models.Releases.Basic release) {
            this.release = release;

            if (release.description == null || release.page_url == null)
                input_box.remove (info_button);

            release.notify["displayed-title"].connect (release_displayed_title_changed);

            release_displayed_title_changed ();

            release.notify["state"].connect (release_state_changed);

            release_state_changed ();
        }

        protected override void install_button_clicked () {
            var install_dialog = new Dialogs.InstallDialog (release);
            install_dialog.present (Application.window);

            release.send_message.connect (install_dialog.add_text);

            release.install.begin ((obj, res) => {
                var success = release.install.end (res);

                install_dialog.done (success || release.canceled);
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

                var remove_dialog = new Dialogs.RemoveDialog (release);
                remove_dialog.present (Application.window);

                release.send_message.connect (remove_dialog.add_text);

                release.remove.begin (new Models.Parameters (), (obj, res) => {
                    var success = release.remove.end (res);

                    remove_dialog.done (success);
                });
            });
        }

        protected override void info_button_clicked () {
            var description_dialog = new DescriptionDialog (release);
            description_dialog.present (Application.window);
        }

        void release_displayed_title_changed () {
            set_title (release.displayed_title);
        }

        void release_state_changed () {
            var installed = release.state == Models.Release.State.UP_TO_DATE;

            install_button.set_visible (!installed);
            remove_button.set_visible (installed);
        }
    }
}