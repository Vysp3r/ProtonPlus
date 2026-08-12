namespace ProtonPlus.Widgets.Tools {
    private class STLDependencyCheckResult : Object {
        public string missing_dependencies { get; set; default = ""; }
        public bool has_incompatible_yad { get; set; default = false; }
    }

    public class STLReleaseRow : ReleaseRow {
        public STLReleaseRow (Services.InstallJob job) {
            base (job);
        }

        protected override void install_button_clicked () {
            if (action_request_in_progress || row_disposed)
                return;
            update_action_request_state (true);
            run_dependency_check (this);
        }

        static void run_dependency_check (STLReleaseRow owner) {
            var owner_ref = WeakRef (owner);
            dependency_check.begin ((obj, res) => {
                var result = dependency_check.end (res);
                var row = owner_ref.get () as STLReleaseRow;
                if (row == null || ((!) row).row_disposed)
                    return;

                if (result.missing_dependencies != "") {
                    var alert_dialog = new Main.WarningDialog (
                        _ ("Warning"),
                        "%s\n\n%s\n%s".printf (
                            _ ("You are missing the following dependencies for %s:").printf (((!) row).title),
                            result.missing_dependencies,
                            _ ("Installation will be canceled.")
                        )
                    );
                    alert_dialog.closed.connect (() => {
                        var current = owner_ref.get () as STLReleaseRow;
                        if (current != null && !((!) current).row_disposed)
                            ((!) current).update_action_request_state (false);
                    });
                    ProtonPlus.Widgets.Window.present_dialog_for_controller (
                        alert_dialog, (Gtk.Window) ((!) row).get_root ()
                    );

                    return;
                }

                if (result.has_incompatible_yad) {
                    ((!) row).show_yad_compatibility_warning ();
                    return;
                }

                ((!) row).external_install_check ();
            });
        }

        protected override void customize_remove_dialog (RemoveDialog dialog) {
            var context = job.steam_tinker_launch_context;
            if (context == null)
                return;
            context.remove_config = false;
            context.user_requested_removal = true;

            var remove_config_check = new Gtk.CheckButton.with_label (_ ("Check this to also delete your configuration files."));
            bind_remove_config_check (context, remove_config_check);

            dialog.set_extra_child (remove_config_check);
        }

        static void bind_remove_config_check (
            Services.SteamTinkerLaunchContext context,
            Gtk.CheckButton remove_config_check
        ) {
            remove_config_check.activate.connect (() => {
                context.remove_config = remove_config_check.get_active ();
            });
        }

        static async STLDependencyCheckResult dependency_check () {
            var result = new STLDependencyCheckResult ();
            var yad_status = Services.SteamTinkerLaunchYadCompatibility.Status.UNKNOWN;
            if (yield Utils.System.check_dependency ("yad")) {
                var yad_version = yield Utils.System.run_command ("yad --version");
                yad_status = Services.SteamTinkerLaunchYadCompatibility.classify_version_result (yad_version);
            }

            result.has_incompatible_yad =
                yad_status == Services.SteamTinkerLaunchYadCompatibility.Status.INCOMPATIBLE_15;

            // SteamOS supplies SteamTinkerLaunch's runtime dependencies, but
            // its host YAD version still needs the compatibility warning.
            if (Globals.IS_STEAM_OS)
                return result;

            if (yad_status == Services.SteamTinkerLaunchYadCompatibility.Status.UNKNOWN ||
                yad_status == Services.SteamTinkerLaunchYadCompatibility.Status.TOO_OLD)
                result.missing_dependencies += "yad >= 7.2 (except 15.x)\n";

            if (!(yield Utils.System.check_dependency ("awk")) && !(yield Utils.System.check_dependency ("gawk")))
                result.missing_dependencies += "awk/gawk\n";

            string[] dependencies = { "git", "pgrep", "unzip", "wget", "xdotool", "xprop", "xrandr", "xxd", "xwininfo" };
            foreach (var dependency in dependencies) {
                if (!(yield Utils.System.check_dependency (dependency)))
                    result.missing_dependencies += "%s\n".printf (dependency);
            }

            return result;
        }

        void show_yad_compatibility_warning () {
            var alert_dialog = new Adw.AlertDialog (
                _ ("SteamTinkerLaunch may not work"),
                _ ("YAD 15 is currently incompatible with SteamTinkerLaunch. SteamTinkerLaunch may fail to start even if ProtonPlus installs it successfully.\n\nThis is a SteamTinkerLaunch compatibility issue, not a ProtonPlus installation problem.")
            );

            alert_dialog.add_response ("cancel", _ ("Cancel"));
            alert_dialog.add_response ("install", _ ("Install Anyway"));
            alert_dialog.set_default_response ("cancel");
            alert_dialog.set_close_response ("cancel");
            alert_dialog.set_response_appearance ("install", Adw.ResponseAppearance.SUGGESTED);
            track_yad_warning (alert_dialog, this);
            ProtonPlus.Widgets.Window.present_dialog_for_controller (
                alert_dialog, (Gtk.Window) get_root ()
            );
        }

        static void track_yad_warning (
            Adw.AlertDialog alert_dialog,
            STLReleaseRow owner
        ) {
            var installation_continued = false;
            var owner_ref = WeakRef (owner);
            alert_dialog.response.connect ((response) => {
                var row = owner_ref.get () as STLReleaseRow;
                if (row == null || ((!) row).row_disposed)
                    return;
                if (response != "install") {
                    ((!) row).update_action_request_state (false);
                    return;
                }
                if (installation_continued)
                    return;

                installation_continued = true;
                ((!) row).external_install_check ();
            });
            alert_dialog.closed.connect (() => {
                var row = owner_ref.get () as STLReleaseRow;
                if (!installation_continued && row != null &&
                    !((!) row).row_disposed)
                    ((!) row).update_action_request_state (false);
            });
        }

        void external_install_check () {
            var has_external_install = Services.InstallationService.instance
                .detect_steam_tinker_launch_external_installations (job);

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
                track_external_install_warning (alert_dialog, this);
                ProtonPlus.Widgets.Window.present_dialog_for_controller (
                    alert_dialog, (Gtk.Window) get_root ()
                );
            } else {
                update_action_request_state (false);
                base.install_button_clicked ();
            }
        }

        static void track_external_install_warning (
            Adw.AlertDialog alert_dialog,
            STLReleaseRow owner
        ) {
            var installation_started = false;
            var owner_ref = WeakRef (owner);
            alert_dialog.response.connect ((response) => {
                var row = owner_ref.get () as STLReleaseRow;
                if (row == null || ((!) row).row_disposed)
                    return;
                if (response != "yes") {
                    ((!) row).update_action_request_state (false);
                    return;
                }
                if (installation_started)
                    return;

                installation_started = true;
                ((!) row).update_action_request_state (false);
                ((!) row).install_after_external_check ();
            });
            alert_dialog.closed.connect (() => {
                var row = owner_ref.get () as STLReleaseRow;
                if (!installation_started && row != null &&
                    !((!) row).row_disposed)
                    ((!) row).update_action_request_state (false);
            });
        }

        void install_after_external_check () {
            base.install_button_clicked ();
        }
    }
}
