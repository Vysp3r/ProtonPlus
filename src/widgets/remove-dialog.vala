namespace ProtonPlus.Widgets {
    public class RemoveDialog : Adw.AlertDialog {
        Models.Release<Models.Parameters> release;
        public signal void successful_removing_callback (); // TODO Find a way to remove that since other runner-row don't need to use it

        public RemoveDialog (Models.Release<Models.Parameters> release) {
            this.release = release;

            set_heading (_("Remove %s").printf (release.title));

            set_body (_("Are you sure you want this?"));

            if (release.runner.group.launcher is Models.Launchers.Steam) {
                var steam_launcher = (Models.Launchers.Steam) release.runner.group.launcher;
                
                var usage_count = steam_launcher.get_compatibility_tool_usage_count (release.title != "SteamTinkerLaunch" ? release.title : "Proton-stl");

                if (usage_count > 0) {
                    var body = _("Used by %i games.").printf (usage_count);

                    if (usage_count == 1)
                        body = _("Used by 1 game.");

                    set_body ("%s\n\n%s".printf (body, _("Are you sure you want to proceed?")));
                }
            }

            add_response ("no", _("No"));
            add_response ("yes", _("Yes"));

            set_response_appearance ("no", Adw.ResponseAppearance.DEFAULT);
            set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);
        }

        public void response_handler (string response, Models.Parameters parameters = new Models.Parameters ()) {
            if (response != "yes")
                return;

            release.remove.begin (parameters, (obj, res) => {
                var success = release.remove.end (res);

                if (success) {
                    successful_removing_callback ();
                    return;
                }

                var dialog = new Adw.AlertDialog (_("Error"), "%s\n%s".printf (_("When trying to remove %s an error occured.").printf (release.title), _("Please report this issue on GitHub.")));
                dialog.add_response ("ok", "OK");
                dialog.present (Application.window);
            });
        }
    }
}