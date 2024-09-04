namespace ProtonPlus.Releases {
    public class STLRelease : Models.Release {
        string STL_BASE_LOCATION = Environment.get_home_dir() + "/stl";
        string EXTERNAL_STL_LOCATION = Environment.get_home_dir() + "/SteamTinkerLaunch";
        string STL_CONFIG_LOCATION = Environment.get_home_dir() + "/.config/steamtinkerlaunch";
        public bool delete_config;

        public STLRelease(Models.Runner runner, string title, string download_url, string info_link, string release_date, string checksum_url, int64 download_size, string file_extension) {
            base(runner, title, download_url, info_link, release_date, checksum_url, download_size, file_extension);
            delete_config = false;
            directory = STL_BASE_LOCATION + "/prefix";
        }

        public override async void install() {
            var missing_dependencies = "";

            if (Utils.System.check_dependency("yad")) {
                string stdout = Utils.System.run_command("yad --version");
                float version = float.parse(stdout.split(" ")[0]);
                var yad_installed = version >= 7.2;
                if (!yad_installed)missing_dependencies += "yad >= 7.2\n";
            }

            if (!Utils.System.check_dependency("awk") && !Utils.System.check_dependency("gawk"))missing_dependencies += "awk-gawk\n";
            if (!Utils.System.check_dependency("git"))missing_dependencies += "git\n";
            if (!Utils.System.check_dependency("pgrep"))missing_dependencies += "pgrep\n";
            if (!Utils.System.check_dependency("unzip"))missing_dependencies += "unzip\n";
            if (!Utils.System.check_dependency("wget"))missing_dependencies += "wget\n";
            if (!Utils.System.check_dependency("xdotool"))missing_dependencies += "xdotool\n";
            if (!Utils.System.check_dependency("xprop"))missing_dependencies += "xprop\n";
            if (!Utils.System.check_dependency("xrandr"))missing_dependencies += "xrandr\n";
            if (!Utils.System.check_dependency("xxd"))missing_dependencies += "xxd\n";
            if (!Utils.System.check_dependency("xwininfo"))missing_dependencies += "xwininfo\n";

            if (missing_dependencies != "") {
                var dialog = new Adw.MessageDialog(Application.window, _("Missing dependencies!"), _("You have unmet dependencies for SteamTinkerLaunch\n\n") + missing_dependencies + _("\nInstallation will be cancelled"));
                dialog.add_response("ok", _("OK"));
                dialog.show();
                status = STATUS.CANCELLED;
                return;
            }

            var has_external_install = FileUtils.test(EXTERNAL_STL_LOCATION, FileTest.EXISTS);
            if (has_external_install) {
                var dialog = new Adw.MessageDialog(Application.window, _("Existing installation of STL"), _("It looks like there's a version of STL currently installed which was not installed by ProtonPlus.\n\nDo you wish to reinstall it with ProtonPlus?"));
                dialog.add_response("cancel", _("Cancel"));
                dialog.add_response("ok", _("OK"));
                dialog.set_response_appearance("cancel", Adw.ResponseAppearance.DEFAULT);
                dialog.set_response_appearance("ok", Adw.ResponseAppearance.DESTRUCTIVE);

                string response = yield dialog.choose(null);

                if (response != "ok") {
                    status = STATUS.CANCELLED;
                    return;
                }

                if (Utils.System.check_dependency("steamtinkerlaunch"))
                    Utils.System.run_command("steamtinkerlaunch compat del");

                var deleted = yield Utils.Filesystem.delete_directory(EXTERNAL_STL_LOCATION);

                if (!deleted) {
                    error = ERRORS.UNEXPECTED;
                    return;
                }
            }

            var has_existing_install = FileUtils.test(STL_BASE_LOCATION, FileTest.EXISTS);
            if (has_existing_install)yield remove();

            error = ERRORS.NONE;
            status = STATUS.INSTALLING;
            installation_progress = 0;

            if (!FileUtils.test(STL_BASE_LOCATION, FileTest.EXISTS))
                Utils.Filesystem.create_directory(STL_BASE_LOCATION);

            string path = STL_BASE_LOCATION + "/" + title + file_extension;

            yield get_artifact_download_size();

            var result = yield Utils.Web.Download(download_link, path, download_size, () => status == STATUS.CANCELLED, (progress) => {
                installation_progress = 5; // FIXME
            });

            switch (result) {
            case Utils.Web.DOWNLOAD_CODES.API_ERROR:
                error = ERRORS.API;
                break;
            case Utils.Web.DOWNLOAD_CODES.UNEXPECTED_ERROR:
                error = ERRORS.UNEXPECTED;
                break;
            case Utils.Web.DOWNLOAD_CODES.SUCCESS:
                error = ERRORS.NONE;
                break;
            }

            if (error != ERRORS.NONE || status == STATUS.CANCELLED) {
                status = STATUS.UNINSTALLED;
                return;
            }

            string source_path = yield Utils.Filesystem.extract(Environment.get_home_dir() + "/stl/", title, file_extension, () => status == STATUS.CANCELLED);

            if (source_path == "") {
                error = ERRORS.EXTRACT;
                status = STATUS.UNINSTALLED;
                return;
            }

            if (error != ERRORS.NONE || status == STATUS.CANCELLED) {
                status = STATUS.UNINSTALLED;
                return;
            }

            Utils.Filesystem.rename(source_path, directory);

            if (Utils.System.IS_STEAM_OS) {
                Utils.System.run_command(@"chmod +x $directory/steamtinkerlaunch");

                Utils.System.run_command(@"$directory/steamtinkerlaunch");
            }

            installation_progress = 99;

            Utils.System.run_command(@"$directory/steamtinkerlaunch compat add");

            installation_progress = 100;

            installed = true;

            status = STATUS.INSTALLED;
        }

        public override async void remove() {
            error = ERRORS.NONE;
            status = STATUS.UNINSTALLING;

            var stl = @"$directory/steamtinkerlaunch";
            if (FileUtils.test(stl, FileTest.IS_REGULAR))
                Utils.System.run_command(@"$stl compat del");

            yield Utils.Filesystem.delete_directory(STL_BASE_LOCATION);

            if (delete_config)
                yield Utils.Filesystem.delete_directory(STL_CONFIG_LOCATION);

            status = STATUS.UNINSTALLED;
        }
    }
}