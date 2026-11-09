namespace ProtonPlus.Widgets.Main {
    /* Context only. Steam owns these installations; recovery instructions live
     * in documentation rather than an in-app depot/manifest editing wizard. */
    public class SteamRepairGuideDialog : Adw.AlertDialog {
        public const string GUIDE_URI = "https://github.com/Vysp3r/ProtonPlus/blob/main/docs/steam-tool-troubleshooting.md";

        public SteamRepairGuideDialog (Models.Launchers.Steam launcher) {
            Object (heading: _("Steam compatibility tool problem"));
            var description = new StringBuilder (
                _("Steam reported a compatibility tool failure, or a completed installation is missing required files. Games that depend on these tools may fail to start.")
            );
            description.append ("\n\n%s · %s\n%s".printf (
                launcher.title, launcher.get_installation_type_title (), launcher.directory
            ));
            foreach (var candidate in launcher.broken_compatibility_tools) {
                description.append ("\n\n%s".printf (
                    _("%s (Steam app %u)").printf (candidate.display_title, candidate.appid)
                ));
                if (candidate.install_path != "")
                    description.append ("\n" + candidate.install_path);
            }
            description.append ("\n\n" + _("Check this Steam installation and verify the affected tool in Steam. The recovery guide explains further checks and manual recovery options."));
            body = description.str;
            body_use_markup = false;
            add_response ("close", _("Close"));
            add_response ("guide", _("Open Recovery Guide"));
            default_response = "close";
            close_response = "close";
            response.connect ((id) => {
                if (id == "guide")
                    Utils.System.open_uri (GUIDE_URI);
            });
        }
    }
}
