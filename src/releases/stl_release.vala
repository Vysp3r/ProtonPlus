namespace ProtonPlus.Releases {
    public class STLRelease : Models.Release {
        string STL_PARENT_LOCATION = Environment.get_home_dir() + "/.local/share";
        string STL_BASE_LOCATION = Environment.get_home_dir() + "/.local/share/steamtinkerlaunch";
        string STL_CONFIG_LOCATION = Environment.get_home_dir() + "/.config/steamtinkerlaunch";
        List<string> STL_EXTERNAL_LOCATIONS = new List<string> ();

        public bool delete_config;
        public bool need_upgrade;
        string? last_version;

        public STLRelease(Models.Runner runner) {
            base(runner, "SteamTinkerLaunch", "", "", "", "", 0, "");

            STL_EXTERNAL_LOCATIONS.append(Environment.get_home_dir() + "/SteamTinkerLaunch");
            if (Utils.System.IS_STEAM_OS)
                STL_BASE_LOCATION = Environment.get_home_dir() + "/stl/prefix";
            else
                STL_EXTERNAL_LOCATIONS.append(Environment.get_home_dir() + "/stl");

            delete_config = false;
            need_upgrade = false;
            installed = FileUtils.test(STL_BASE_LOCATION, FileTest.EXISTS) && FileUtils.test(@"$STL_BASE_LOCATION/VERSION.txt", FileTest.EXISTS);

            var soup_session = new Soup.Session();
            soup_session.set_user_agent(Utils.Web.get_user_agent());

            var soup_message = new Soup.Message("GET", "https://api.github.com/repos/sonic2kk/steamtinkerlaunch/commits?per_page=1");
            soup_message.response_headers.append("Accept", "application/vnd.github+json");
            soup_message.response_headers.append("X-GitHub-Api-Version", "2022-11-28");

            var bytes = soup_session.send_and_read(soup_message, null);

            var json = (string) bytes.get_data();

            var root_node = Utils.Parser.get_node_from_json(json);

            var root_array = root_node.get_array();

            var temp_node = root_array.get_element(0);
            var temp_obj = temp_node.get_object();

            last_version = temp_obj.get_string_member("sha");

            download_link = @"https://github.com/sonic2kk/steamtinkerlaunch/archive/$last_version.tar.gz";

            if (installed) {
                var local_version = Utils.Filesystem.get_file_content(@"$STL_BASE_LOCATION/VERSION.txt");

                need_upgrade = last_version != local_version;
            }
        }

        public override async void install() {
            error = ERRORS.NONE;
            status = STATUS.INSTALLING;
            installation_progress = 0;

            if (runner.group.launcher.type == "Flatpak") {
                var dialog = new Adw.MessageDialog(Application.window, _("Steam Flatpak is not supported"), _("To install Steam Tinker Launch for Steam Flatpak, please run the following command:") + "\n\nflatpak install --user com.valvesoftware.Steam.Utility.steamtinkerlaunch");
                dialog.add_response("ok", _("OK"));
                dialog.show();
                return;
            }

            if (runner.group.launcher.type == "Snap") {
                var dialog = new Adw.MessageDialog(Application.window, _("Steam Snap is not supported"), _("There's currently no known way to install STL for Steam Snap"));
                dialog.add_response("ok", _("OK"));
                dialog.show();
                return;
            }

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

            var has_external_install = false;

            foreach (var location in STL_EXTERNAL_LOCATIONS) {
                if (FileUtils.test(location, FileTest.EXISTS))
                    has_external_install = true;
            }

            if (has_external_install) {
                var dialog = new Adw.MessageDialog(Application.window, _("Existing installation of STL"), _("It looks like there's a version of STL currently installed which was not installed by ProtonPlus.\n\nDo you want to delete it and install STL with ProtonPlus?"));
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

                var path = runner.group.launcher.directory + "/" + runner.group.directory + "/SteamTinkerLaunch/steamtinkerlaunch";
                if (FileUtils.test(path, FileTest.EXISTS))
                    Utils.System.run_command(@"$path compat del");

                foreach (var location in STL_EXTERNAL_LOCATIONS) {
                    var deleted = yield Utils.Filesystem.delete_directory(location);

                    if (!deleted) {
                        error = ERRORS.UNEXPECTED;
                        return;
                    }
                }
            }

            var has_existing_install = FileUtils.test(STL_BASE_LOCATION, FileTest.EXISTS);
            if (has_existing_install) {
                delete_config = false;

                yield remove_top();
            }

            if (!FileUtils.test(STL_BASE_LOCATION, FileTest.EXISTS))
                Utils.Filesystem.create_directory(STL_BASE_LOCATION);

            string path = STL_PARENT_LOCATION + "/" + title + file_extension;

            yield get_artifact_download_size();

            var result = yield Utils.Web.Download(download_link, path, download_size, () => status == STATUS.CANCELLED, (progress) => installation_progress = progress);

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

            installation_progress = 99;

            string source_path = yield Utils.Filesystem.extract(@"$STL_PARENT_LOCATION/", title, file_extension, () => status == STATUS.CANCELLED);

            if (source_path == "") {
                error = ERRORS.EXTRACT;
                status = STATUS.UNINSTALLED;
                return;
            }

            if (error != ERRORS.NONE || status == STATUS.CANCELLED) {
                status = STATUS.UNINSTALLED;
                return;
            }

            Utils.Filesystem.rename(source_path, STL_BASE_LOCATION);

            if (Utils.System.IS_STEAM_OS) {
                Utils.System.run_command(@"chmod +x $STL_BASE_LOCATION/steamtinkerlaunch");

                Utils.System.run_command(@"$STL_BASE_LOCATION/steamtinkerlaunch");
            }

            Utils.System.run_command(@"$STL_BASE_LOCATION/steamtinkerlaunch compat add");

            Utils.Filesystem.create_file(@"$STL_BASE_LOCATION/VERSION.txt", last_version);

            installed = true;

            status = STATUS.INSTALLED;
        }

        public async void upgrade() {
        }

        async void remove_top() {
            var stl = @"$STL_BASE_LOCATION/steamtinkerlaunch";
            if (FileUtils.test(stl, FileTest.IS_REGULAR))
                Utils.System.run_command(@"$stl compat del");

            yield Utils.Filesystem.delete_directory(STL_BASE_LOCATION);

            if (delete_config)
                yield Utils.Filesystem.delete_directory(STL_CONFIG_LOCATION);
        }

        public override async void remove() {
            error = ERRORS.NONE;
            status = STATUS.UNINSTALLING;

            yield remove_top();

            status = STATUS.UNINSTALLED;
        }
    }
}