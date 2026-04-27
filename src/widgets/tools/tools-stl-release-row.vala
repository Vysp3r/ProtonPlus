namespace ProtonPlus.Widgets.Tools {
    public class STLReleaseRow : ReleaseRow {
        public STLReleaseRow (Models.Releases.SteamTinkerLaunch release) {
            base (release);
        }

        protected override void install_button_clicked () {
        // Steam Deck doesn't need any external dependencies.
            if (!Globals.IS_STEAM_OS) {
                dependency_check.begin ((obj, res) => {
                    var missing_dependencies = dependency_check.end (res);

                    if (missing_dependencies != "") {
                        var alert_dialog = new Main.WarningDialog (_ ("Warning"), "%s\n\n%s\n%s".printf (_ ("You are missing the following dependencies for %s:").printf (title), missing_dependencies, _ ("Installation will be canceled.")));
                        alert_dialog.present ((Gtk.Window) this.get_root ());

                        return;
                    } else {
                        external_install_check ();
                    }
                });
            } else {
                external_install_check ();
            }
        }

        protected override void remove_button_clicked () {
            release.set_data ("delete-config", false);
            release.set_data ("user-request", true);

            var remove_config_check = new Gtk.CheckButton.with_label (_ ("Check this to also delete your configuration files."));
            remove_config_check.activate.connect (() => {
                release.set_data ("delete-config", remove_config_check.get_active ());
            });

            var remove_dialog = new RemoveDialog (release);
            remove_dialog.set_extra_child (remove_config_check);
            remove_dialog.present ((Gtk.Window) this.get_root ());
        }

        async string dependency_check () {
            var missing_dependencies = "";

            var yad_installed = false;
            if (yield Utils.System.check_dependency ("yad")) {
                string yad_version_output = yield Utils.System.run_command ("yad --version");

                float version = 0.0f;
                try {
                    var regex = new Regex ("""(\d+\.\d+)\s*\(GTK\+""");
                    MatchInfo match_info;
                    if (regex.match (yad_version_output, 0, out match_info)) {
                        version = float.parse (match_info.fetch (1));
                    }
                    yad_installed = version >= 7.2;
                } catch (Error e) {
                    return missing_dependencies;
                }
            }
            if (!yad_installed)missing_dependencies += "yad >= 7.2\n";

            if (!(yield Utils.System.check_dependency ("awk")) && !(yield Utils.System.check_dependency ("gawk")))missing_dependencies += "awk/gawk\n";
            if (!(yield Utils.System.check_dependency ("git")))missing_dependencies += "git\n";
            if (!(yield Utils.System.check_dependency ("pgrep")))missing_dependencies += "pgrep\n";
            if (!(yield Utils.System.check_dependency ("unzip")))missing_dependencies += "unzip\n";
            if (!(yield Utils.System.check_dependency ("wget")))missing_dependencies += "wget\n";
            if (!(yield Utils.System.check_dependency ("xdotool")))missing_dependencies += "xdotool\n";
            if (!(yield Utils.System.check_dependency ("xprop")))missing_dependencies += "xprop\n";
            if (!(yield Utils.System.check_dependency ("xrandr")))missing_dependencies += "xrandr\n";
            if (!(yield Utils.System.check_dependency ("xxd")))missing_dependencies += "xxd\n";
            if (!(yield Utils.System.check_dependency ("xwininfo")))missing_dependencies += "xwininfo\n";

            return missing_dependencies;
        }

        void external_install_check () {
            var has_external_install = ((Models.Releases.SteamTinkerLaunch)release).detect_external_locations ();

            if (has_external_install) {
                var alert_dialog = new Adw.AlertDialog (_ ("Warning"), "%s\n\n%s".printf (_ ("It looks like you currently have another version of %s which was not installed by ProtonPlus.").printf (title.split (" ")[0]), _ ("Do you want to reinstall it with ProtonPlus?")));

                alert_dialog.add_response ("no", _ ("No"));
                alert_dialog.add_response ("yes", _ ("Yes"));

                alert_dialog.set_response_appearance ("no", Adw.ResponseAppearance.DEFAULT);
                alert_dialog.set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);

                alert_dialog.choose.begin ((Gtk.Window) this.get_root (), null, (obj, res) => {
                    string response = alert_dialog.choose.end (res);

                    if (response == "yes")
                    start_install ();
                });
            } else {
                start_install ();
            }
        }

        void start_install () {
            release.install.begin ((obj, res) => {
                var success = release.install.end (res);
                if (!success && !release.canceled) {
                    var dialog = new Main.ErrorDialog (_ ("Couldn't install %s").printf (release.title), _ ("Please report this issue on GitHub."));
                    dialog.present ((Gtk.Window) this.get_root ());
                }
            });
        }
    }
}