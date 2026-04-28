namespace ProtonPlus.Widgets.Tools {
    public class RemoveDialog : Adw.AlertDialog {
        Models.Release release;

        public RemoveDialog (Models.Release release) {
            this.release = release;

            set_heading (_ ("Delete %s?").printf (release.title));

            var body = _ ("It will be permanently deleted.");

            if (release.runner.group.launcher is Models.Launchers.Steam) {
                var steam_launcher = (Models.Launchers.Steam) release.runner.group.launcher;
                var tool_name = (release.runner is Models.Tools.SteamTinkerLaunch) ? "Proton-stl" : release.title;

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
        }

        void response_changed (string response) {
            if (response != "delete")
            return;

            release.remove.begin ((obj, res) => {
                var success = release.remove.end (res);

                if (!success) {
                    var dialog = new Main.ErrorDialog (_ ("Couldn't delete %s").printf (release.title), _ ("Please report this issue on GitHub."));
                    dialog.present (((Gtk.Application) GLib.Application.get_default ()).active_window);
                }
            });
        }
    }
}
