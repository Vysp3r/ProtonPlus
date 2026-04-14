namespace ProtonPlus.Widgets {
    public class RemoveDialog : Adw.AlertDialog {
        Models.BaseRelease release;
        Models.Parameters parameters;
        public signal void done (bool result);

        public RemoveDialog (Models.BaseRelease release, Models.Parameters parameters = new Models.Parameters ()) {
            this.release = release;
            this.parameters = parameters;

            set_heading (_ ("Delete %s?").printf (release.title));

            set_body (_ ("%s will be permanently deleted.").printf (release.title));

            if (release.runner.group.launcher is Models.Launchers.Steam) {
                var steam_launcher = (Models.Launchers.Steam) release.runner.group.launcher;

                var usage_count = steam_launcher.get_compatibility_tool_usage_count (release.title != "SteamTinkerLaunch" ? release.title : "Proton-stl");

                if (usage_count > 0) {
                    var body = _ ("Used by %i games.").printf (usage_count);

                    if (usage_count == 1)
                    body = _ ("Used by 1 game.");

                    set_body ("%s\n\n%s".printf (body, _ ("%s will be permanently deleted.").printf (release.title)));
                }
            }

            add_response ("cancel", _ ("Cancel"));
            add_response ("delete", _ ("Delete"));

            set_response_appearance ("cancel", Adw.ResponseAppearance.DEFAULT);
            set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);

            set_default_response ("cancel");
            set_close_response ("cancel");

            response.connect (response_changed);
        }

        void response_changed (string response) {
            if (response != "delete")
            return;

            release.remove.begin (parameters, (obj, res) => {
                var success = release.remove.end (res);

                done (success);

                if (!success) {
                    var dialog = new ErrorDialog (_ ("Couldn't delete %s").printf (release.title), _ ("Please report this issue on GitHub."));
                    dialog.present (Application.window);
                }
            });
        }
    }
}
