namespace ProtonPlus.Widgets.Tools {
    public class RemoveDialog : Adw.AlertDialog {
        Services.InstallJob job;
        Services.LutrisRemovalReview? review;
        bool dismissed;

        public RemoveDialog (Services.InstallJob job) {
            this.job = job;

            set_heading (_ ("Delete %s?").printf (job.title));

            var body = _ ("It will be permanently deleted.");

            if (job.tool.group.launcher is Models.Launchers.Steam) {
                var steam_launcher = (Models.Launchers.Steam) job.tool.group.launcher;
                var tool_name = job.get_usage_identifier ();

                var usage_count = steam_launcher.get_compatibility_tool_usage_count (tool_name);

                if (usage_count > 0) {
                    var usage_text = ngettext ("Used by %i game.", "Used by %i games.", usage_count).printf (usage_count);
                    body = "%s\n\n%s".printf (usage_text, body);
                }
            }

            set_body (body);

            add_response ("cancel", _ ("Cancel"));
            add_response ("delete", _ ("Delete"));

            set_response_appearance ("cancel", Adw.ResponseAppearance.DEFAULT);
            set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);

            set_default_response ("cancel");
            set_close_response ("cancel");

            response.connect (response_changed);
            closed.connect (() => { dismissed = true; });
            inspect_dependencies.begin ();
        }

        async void inspect_dependencies () {
            if (!Services.InstallationService.has_lutris_removal_scope (job))
                return;
            var body = get_body ();
            set_response_enabled ("delete", false);
            set_body (_("Checking Lutris runner usage…"));
            review = yield Services.InstallationService.instance.inspect_lutris_removal (job);
            if (dismissed)
                return;
            var affected = review.affected_games;
            var failure = review.error;
            if (failure != null) {
                set_body (failure);
                return;
            }
            if (affected != null)
                body = _("%s\n\nThese Lutris games use this runner. Choose a different runner for them before playing again.\n%s")
                    .printf (body, affected);
            set_body (body);
            set_response_enabled ("delete", true);
        }

        void response_changed (string response) {
            if (response != "delete")
                return;

            job.remove_with_lutris_review.begin (review, (obj, res) => {
                var code = job.remove_with_lutris_review.end (res);
                if (code != ReturnCode.RUNNER_REMOVED) {
                    var dialog = new Main.ErrorDialog (
                        _ ("Failed to Delete %s").printf (job.title),
                        _ ("ProtonPlus encountered an issue while trying to remove this compatibility tool from your system."),
                        job.error_message ?? get_return_code_message (code)
                    );
                    ProtonPlus.Widgets.Window.present_dialog_for_controller (
                        dialog,
                        ((Gtk.Application) GLib.Application.get_default ()).active_window
                    );
                }
            });
        }
    }
}
