namespace ProtonPlus.Widgets.Tools {
    public class STLReleaseRow : ReleaseRow {
        public STLReleaseRow (Models.Release release) {
            base (release);
        }

        protected override void install_button_clicked () {
            dependency_check.begin ((obj, res) => {
                var missing_dependencies = dependency_check.end (res);

                if (missing_dependencies != "") {
                    var alert_dialog = new Main.WarningDialog (
                        _ ("Warning"),
                        "%s\n\n%s\n%s".printf (
                            _ ("You are missing the following dependencies for %s:").printf (title),
                            missing_dependencies,
                            _ ("Installation will be canceled.")
                        )
                    );
                    ProtonPlus.Widgets.Window.present_dialog_for_controller (alert_dialog, (Gtk.Window) this.get_root ());

                    return;
                }

                external_install_check ();
            });
        }

        protected override void customize_remove_dialog (RemoveDialog dialog) {
            release.set_data ("delete-config", false);
            release.set_data ("user-request", true);

            var remove_config_check = new Gtk.CheckButton.with_label (_ ("Check this to also delete your configuration files."));
            remove_config_check.activate.connect (() => {
                release.set_data ("delete-config", remove_config_check.get_active ());
            });

            dialog.set_extra_child (remove_config_check);
        }

        async string dependency_check () {
            var missing_dependencies = "";

            if (Globals.IS_STEAM_OS)
                return missing_dependencies;

            var yad_installed = false;
            if (yield Utils.System.check_dependency ("yad")) {
                yad_installed = true;
                string yad_version_output = (yield Utils.System.run_command ("yad --version")).stdout;

                float version = 0.0f;
                try {
                    var regex = new Regex ("""(\d+[.,]\d+)\s*\(GTK\+""");
                    MatchInfo match_info;
                    if (regex.match (yad_version_output, 0, out match_info)) {
                        version = float.parse (match_info.fetch (1).replace (",", "."));
                    }
                    yad_installed = version >= 7.2;
                } catch (Error e) {
                    warning ("Could not determine the installed YAD version: %s", e.message);
                    yad_installed = false;
                }
            }

            if (!yad_installed)
                missing_dependencies += "yad >= 7.2\n";

            if (!(yield Utils.System.check_dependency ("awk")) && !(yield Utils.System.check_dependency ("gawk")))
                missing_dependencies += "awk/gawk\n";

            string[] dependencies = { "git", "pgrep", "unzip", "wget", "xdotool", "xprop", "xrandr", "xxd", "xwininfo" };
            foreach (var dependency in dependencies) {
                if (!(yield Utils.System.check_dependency (dependency)))
                    missing_dependencies += "%s\n".printf (dependency);
            }

            return missing_dependencies;
        }

        void external_install_check () {
            var has_external_install = ((Models.Releases.SteamTinkerLaunch)release).detect_external_locations ();

            if (has_external_install) {
                var alert_dialog = new Adw.AlertDialog (
                    _ ("Warning"),
                    "%s\n\n%s".printf (
                        _ ("It looks like you currently have another version of %s which was not installed by ProtonPlus.").printf (title.split (" ")[0]),
                        _ ("Do you want to reinstall it with ProtonPlus?")
                    )
                );

                alert_dialog.add_response ("no", _ ("No"));
                alert_dialog.add_response ("yes", _ ("Yes"));

                alert_dialog.set_response_appearance ("no", Adw.ResponseAppearance.DEFAULT);
                alert_dialog.set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);

                alert_dialog.choose.begin ((Gtk.Window) this.get_root (), null, (obj, res) => {
                    string response = alert_dialog.choose.end (res);

                    if (response == "yes")
                    base.install_button_clicked ();
                });
            } else {
                base.install_button_clicked ();
            }
        }
    }
}
