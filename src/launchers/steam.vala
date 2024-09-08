namespace ProtonPlus.Launchers {
    public class Steam {
        static Models.Group[] get_groups (Models.Launcher launcher) {
            var groups = new Models.Group[1];

            groups[0] = new Models.Group (_("Runners"), "/compatibilitytools.d", launcher);
            groups[0].runners = get_runners (groups[0]);

            return groups;
        }

        public static Models.Launcher get_launcher () {
            var directories = new string[] { "/.local/share/Steam",
                                             "/.steam/root",
                                             "/.steam/steam",
                                             "/.steam/debian-installation" };

            var launcher = new Models.Launcher (
                                                "Steam",
                                                "System",
                                                Constants.RESOURCE_BASE + "/steam.png",
                                                directories
            );

            if (launcher.installed)launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static Models.Launcher get_flatpak_launcher () {
            var directories = new string[] { "/.var/app/com.valvesoftware.Steam/data/Steam" };

            var launcher = new Models.Launcher (
                                                "Steam",
                                                "Flatpak",
                                                Constants.RESOURCE_BASE + "/steam.png",
                                                directories
            );

            if (launcher.installed)launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static Models.Launcher get_snap_launcher () {
            var directories = new string[] { "/snap/steam/common/.steam/root" };

            var launcher = new Models.Launcher (
                                                "Steam",
                                                "Snap",
                                                Constants.RESOURCE_BASE + "/steam.png",
                                                directories
            );

            if (launcher.installed)launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static List<Models.Runner> get_runners (Models.Group group) {
            var runners = new List<Models.Runner> ();

            var proton_ge = new Models.Runner (group, "Proton-GE", _("Steam compatibility tool for running Windows games with improvements over Valve's default Proton."), "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1, Models.Runner.title_types.STEAM_PROTON_GE);
            proton_ge.old_asset_location = 95;
            proton_ge.old_asset_position = 0;

            var proton_tkg = new Models.Runner (group, "Proton-Tkg", _("Custom Proton build for running Windows games, built with the Wine-tkg build system."), "https://api.github.com/repos/Frogging-Family/wine-tkg-git/actions/workflows/29873769/runs", 0, Models.Runner.title_types.PROTON_TKG);
            proton_tkg.is_using_github_actions = true;

            runners.append (proton_ge);
            runners.append (new Models.Runner (group, "Luxtorpeda", _("Luxtorpeda provides Linux-native game engines for specific Windows-only games."), "https://api.github.com/repos/luxtorpeda-dev/luxtorpeda/releases", 0, Models.Runner.title_types.TOOL_NAME));
            runners.append (new Models.Runner (group, "Boxtron", _("Steam Play compatibility tool to run DOS games using native Linux DOSBox."), "https://api.github.com/repos/dreamer/boxtron/releases", 0, Models.Runner.title_types.TOOL_NAME));
            runners.append (new Models.Runner (group, "Roberta", _("Steam Play compatibility tool to run adventure games using native Linux ScummVM."), "https://api.github.com/repos/dreamer/roberta/releases", 0, Models.Runner.title_types.TOOL_NAME));
            runners.append (new Models.Runner (group, "NorthstarProton", _("Custom Proton build for running the Northstar client for Titanfall 2."), "https://api.github.com/repos/cyrv6737/NorthstarProton/releases", 0, Models.Runner.title_types.TOOL_NAME));
            runners.append (new Models.Runner (group, "Proton-GE RTSP", _("Compatibility tool for Steam Play based on Wine and additional components."), "https://api.github.com/repos/SpookySkeletons/proton-ge-rtsp/releases", 0, Models.Runner.title_types.TOOL_NAME));
            runners.append (proton_tkg);
            runners.append (new Models.Runner (group, "SteamTinkerLaunch", _("Linux wrapper tool for use with the Steam client which allows for easy graphical configuration of game tools for Proton and native Linux games."), "https://api.github.com/repos/sonic2kk/steamtinkerlaunch/releases", 0, Models.Runner.title_types.STEAM_TINKER_LAUNCH));

            return runners;
        }

        public class STL : Object {
            string home_location { get; set; }
            string compat_location { get; set; }
            string parent_location { get; set; }
            string base_location { get; set; }
            string binary_location { get; set; }
            string download_location { get; set; }
            string meta_location { get; set; }
            string link_parent_location { get; set; }
            string link_location { get; set; }
            string config_location { get; set; }
            List<string> external_locations;

            public bool installed { get; set; }
            public bool updated { get; set; }
            public bool cancelled { get; set; }

            string row_stl_title { get; set; }

            string? latest_date { get; set; }
            string? latest_hash { get; set; }
            string local_date { get; set; }
            string local_hash { get; set; }

            string title { get; set; }

            Gtk.Label progress_label { get; set; }
            Adw.ToastOverlay toast_overlay { get; set; }

            public STL (string compat_location, Adw.ToastOverlay toast_overlay) {
                this.compat_location = compat_location;
                this.toast_overlay = toast_overlay;

                home_location = Environment.get_home_dir ();
                parent_location = @"$home_location/.local/share";
                base_location = @"$parent_location/steamtinkerlaunch";
                binary_location = @"$base_location/steamtinkerlaunch";
                meta_location = @"$base_location/ProtonPlus.meta";
                download_location = @"$base_location/ProtonPlus.downloads";
                link_parent_location = @"$home_location/.local/bin";
                link_location = @"$link_parent_location/steamtinkerlaunch";
                config_location = @"$home_location/.config/steamtinkerlaunch";
                external_locations = new List<string> ();

                if (Utils.System.IS_STEAM_OS)
                    base_location = @"$home_location/stl/prefix";

                refresh_latest_stl_version ();
                refresh_installation_state ();

                title = "STL";
            }

            string get_download_url () {
                return @"https://github.com/sonic2kk/steamtinkerlaunch/archive/$latest_hash.zip";
            }

            void refresh_latest_stl_version () {
                latest_date = "";
                latest_hash = "";

                try {
                    var soup_session = new Soup.Session ();
                    soup_session.set_user_agent (Utils.Web.get_user_agent ());

                    var soup_message = new Soup.Message ("GET", "https://api.github.com/repos/sonic2kk/steamtinkerlaunch/commits?per_page=1");
                    soup_message.request_headers.append ("Accept", "application/vnd.github+json");
                    soup_message.request_headers.append ("X-GitHub-Api-Version", "2022-11-28");

                    var bytes = soup_session.send_and_read (soup_message, null);

                    var json = (string) bytes.get_data ();

                    var root_node = Utils.Parser.get_node_from_json (json);

                    if (root_node.get_node_type () != Json.NodeType.ARRAY)
                        return;

                    var root_array = root_node.get_array ();

                    if (root_array.get_length () < 1)
                        return;


                    // Get the first commit in the list.
                    var commit_node = root_array.get_element (0);

                    if (commit_node.get_node_type () != Json.NodeType.OBJECT)
                        return;

                    var commit_obj = commit_node.get_object ();


                    // Get metadata about the committer (not the author), since
                    // we want to know when it was committed to the repo.
                    if (!commit_obj.has_member ("commit"))
                        return;

                    var commit_metadata_node = commit_obj.get_member ("commit");

                    if (commit_metadata_node.get_node_type () != Json.NodeType.OBJECT)
                        return;

                    var commit_metadata_obj = commit_metadata_node.get_object ();


                    if (!commit_metadata_obj.has_member ("committer"))
                        return;

                    var committer_metadata_node = commit_metadata_obj.get_member ("committer");

                    if (committer_metadata_node.get_node_type () != Json.NodeType.OBJECT)
                        return;

                    var committer_metadata_obj = committer_metadata_node.get_object ();


                    // Extract the latest commit's date and SHA hash.
                    // NOTE: The date is in ISO 8601 format (UTC): `YYYY-MM-DDTHH:MM:SSZ`.
                    string raw_date = committer_metadata_obj.get_string_member_with_default ("date", "");
                    var date_parts = raw_date.split ("T");
                    if (date_parts.length > 0) {
                        latest_date = date_parts[0]; // "YYYY-MM-DD".
                    }

                    latest_hash = commit_obj.get_string_member_with_default ("sha", "");
                } catch (Error e) {
                    message (e.message);
                }
            }

            void refresh_installation_state () {
                // Update the ProtonPlus UI state variables.
                var base_location_exists = FileUtils.test (base_location, FileTest.EXISTS);
                var binary_location_exists = FileUtils.test (binary_location, FileTest.EXISTS);
                var meta_file_exists = FileUtils.test (meta_location, FileTest.EXISTS);

                var _installed = base_location_exists && binary_location_exists && meta_file_exists;
                var _updated = false;
                
                local_date = "";
                local_hash = "";

                if (_installed) {
                    var raw_metadata = Utils.Filesystem.get_file_content (meta_location);
                    var metadata_parts = raw_metadata.strip ().split (":");
                    if (metadata_parts.length >= 2) {
                        local_date = metadata_parts[0];
                        local_hash = metadata_parts[1];
                        if (local_date == "" || local_hash == "")
                            local_date = local_hash = "";
                    }

                    if (local_hash == "")
                        _installed = false;
                    else if (latest_hash != "")
                        _updated = latest_hash == local_hash;
                }


                // Generate a title for the installed (or latest) release.
                row_stl_title = "SteamTinkerLaunch"; // Default title/prefix.
                if (local_date != "")
                    row_stl_title = @"$row_stl_title ($local_date)";
                else if (latest_date != "")
                    row_stl_title = @"$row_stl_title ($latest_date)";


                // Update state to trigger the signals for UI refresh.
                // WARNING: We MUST do this LAST, after finishing ALL other vars
                // above, otherwise the UI redraw would happen with old values.
                installed = _installed;
                updated = _updated;
            }

            void write_installation_metadata (string meta_location) {
                Utils.Filesystem.create_file (meta_location, @"$latest_date:$latest_hash");
            }

            bool detect_external_locations () {
                if (external_locations.length () > 0)
                    external_locations = new List<string> ();

                var loc1 = @"$home_location/SteamTinkerLaunch";
                if (FileUtils.test (loc1, FileTest.EXISTS))
                    external_locations.append (loc1);

                var loc2 = Environment.get_home_dir () + "/stl";
                if (!Utils.System.IS_STEAM_OS && FileUtils.test (loc2, FileTest.EXISTS))
                    external_locations.append (loc2);

                // Disabled for now, since we always erase base_location before installs.
                //  if (FileUtils.test (base_location, FileTest.EXISTS) && !FileUtils.test (meta_location, FileTest.EXISTS))
                //      external_locations.append (base_location);

                return external_locations.length () > 0;
            }

            public async bool install () {
                var missing_dependencies = "";

                var yad_installed = false;
                if (Utils.System.check_dependency ("yad")) {
                    string stdout = Utils.System.run_command ("yad --version");
                    float version = float.parse (stdout.split (" ")[0]);
                    yad_installed = version >= 7.2;
                }
                if (!yad_installed)missing_dependencies += "yad >= 7.2\n";

                if (!Utils.System.check_dependency ("awk") && !Utils.System.check_dependency ("gawk"))missing_dependencies += "awk/gawk\n";
                if (!Utils.System.check_dependency ("git"))missing_dependencies += "git\n";
                if (!Utils.System.check_dependency ("pgrep"))missing_dependencies += "pgrep\n";
                if (!Utils.System.check_dependency ("unzip"))missing_dependencies += "unzip\n";
                if (!Utils.System.check_dependency ("wget"))missing_dependencies += "wget\n";
                if (!Utils.System.check_dependency ("xdotool"))missing_dependencies += "xdotool\n";
                if (!Utils.System.check_dependency ("xprop"))missing_dependencies += "xprop\n";
                if (!Utils.System.check_dependency ("xrandr"))missing_dependencies += "xrandr\n";
                if (!Utils.System.check_dependency ("xxd"))missing_dependencies += "xxd\n";
                if (!Utils.System.check_dependency ("xwininfo"))missing_dependencies += "xwininfo\n";

                if (missing_dependencies != "") {
                    var dialog = new Adw.MessageDialog (Application.window, _("Missing dependencies!"), _("You have unmet dependencies for SteamTinkerLaunch\n\n") + missing_dependencies + _("\nInstallation will be cancelled"));
                    dialog.add_response ("ok", _("OK"));
                    dialog.show ();
                    cancelled = true;
                    return false;
                }


                var has_external_install = detect_external_locations ();

                if (has_external_install) {
                    var dialog = new Adw.MessageDialog (Application.window, _("Existing installation of STL"), _("It looks like there's a version of STL currently installed which was not installed by ProtonPlus.\n\nDo you want to delete it and install STL with ProtonPlus?"));
                    dialog.add_response ("cancel", _("Cancel"));
                    dialog.add_response ("ok", _("OK"));
                    dialog.set_response_appearance ("cancel", Adw.ResponseAppearance.DEFAULT);
                    dialog.set_response_appearance ("ok", Adw.ResponseAppearance.DESTRUCTIVE);

                    string response = yield dialog.choose (null);

                    if (response != "ok") {
                        cancelled = true;
                        return false;
                    }

                    if (Utils.System.check_dependency ("steamtinkerlaunch"))
                        Utils.System.run_command ("steamtinkerlaunch compat del");

                    exec_stl_if_exists (@"$compat_location/SteamTinkerLaunch/steamtinkerlaunch", "compat del");

                    foreach (var location in external_locations) {
                        var deleted = yield Utils.Filesystem.delete_directory (location);

                        if (!deleted)
                            return false;
                    }
                }


                var install_success = yield _download_and_install ();

                if (!install_success) {
                    // Attempt to clean up any leftover files and symlinks,
                    // but don't erase the user's STL configuration files.
                    yield remove (false); // Refreshes install state too.

                    return false;
                }


                refresh_installation_state ();

                return true;
            }

            async bool _download_and_install () {
                // Always clean destination to avoid merging with existing files.
                var base_location_exists = FileUtils.test (base_location, FileTest.EXISTS);
                if (base_location_exists)
                    yield remove (false);


                // Download the source code archive.
                if (!FileUtils.test (download_location, FileTest.IS_DIR)) {
                    var success = yield Utils.Filesystem.create_directory (download_location);

                    if (!success)
                        return false;
                }

                string downloaded_file_location = @"$download_location/$title.zip";

                if (FileUtils.test (downloaded_file_location, FileTest.EXISTS)) {
                    var deleted = Utils.Filesystem.delete_file (downloaded_file_location);

                    if (!deleted)
                        return false;
                }

                var download_result = yield Utils.Web.Download (get_download_url (), downloaded_file_location, -1, () => cancelled, (is_percent, progress) => progress_label.set_text (is_percent ? @"$progress%" : Utils.Filesystem.convert_bytes_to_string (progress)));

                if (download_result != Utils.Web.DOWNLOAD_CODES.SUCCESS)
                    return false;


                // Extract archive and move its contents to the installation directory.
                string extracted_file_location = yield Utils.Filesystem.extract (@"$download_location/", title, ".zip", () => cancelled);

                if (extracted_file_location == "")
                    return false;

                var moved = yield Utils.Filesystem.move_dir_contents (extracted_file_location, base_location);

                if (!moved)
                    return false;


                // We don't need the download directory anymore.
                var download_deleted = yield Utils.Filesystem.delete_directory (download_location);

                if (!download_deleted)
                    return false;


                // Create a symlink for the steamtinkerlaunch binary.
                var link_parent_location_success = yield Utils.Filesystem.create_directory (link_parent_location);

                if (!link_parent_location_success)
                    return false;

                var link_created = yield Utils.Filesystem.make_symlink (link_location, binary_location);

                if (!link_created)
                    return false;


                // Trigger STL's dependency installer for Steam Deck, and register compat tool.
                if (Utils.System.IS_STEAM_OS)
                    exec_stl (binary_location, "");

                exec_stl (binary_location, "compat add");


                // Remember installed version.
                write_installation_metadata (meta_location);

                return true;
            }

            public async bool upgrade () {
                var remove_success = yield remove (false);

                if (!remove_success)
                    return false;

                var install_success = yield install ();

                if (!install_success)
                    return false;

                return true;
            }

            public async bool remove (bool delete_config) {
                var remove_success = yield _remove_installation (delete_config);

                refresh_installation_state ();

                return remove_success;
            }

            async bool _remove_installation (bool delete_config) {
                exec_stl_if_exists (binary_location, "compat del");

                if (FileUtils.test (link_location, FileTest.IS_SYMLINK)) {
                    var link_deleted = Utils.Filesystem.delete_file (link_location);

                    if (!link_deleted)
                        return false;
                }

                if (FileUtils.test (base_location, FileTest.IS_DIR)) {
                    var base_deleted = yield Utils.Filesystem.delete_directory (base_location);

                    if (!base_deleted)
                        return false;
                }

                if (delete_config && FileUtils.test (config_location, FileTest.IS_DIR)) {
                    var config_deleted = yield Utils.Filesystem.delete_directory (config_location);

                    if (!config_deleted)
                        return false;
                }

                return true;
            }

            void exec_stl_if_exists (string exec_location, string args) {
                if (FileUtils.test (exec_location, FileTest.IS_REGULAR))
                    exec_stl (exec_location, args);
            }

            void exec_stl (string exec_location, string args) {
                if (FileUtils.test (exec_location, FileTest.IS_REGULAR) && !FileUtils.test (exec_location, FileTest.IS_EXECUTABLE))
                    Utils.System.run_command (@"chmod +x $exec_location");
                Utils.System.run_command (@"$exec_location $args");
            }

            void send_toast (string content, int duration) {
                var toast = new Adw.Toast (content);
                toast.set_timeout (duration);

                toast_overlay.add_toast (toast);
            }

            Gtk.Button create_button (string icon_name, string tooltip_text) {
                var icon = new Gtk.Image.from_icon_name (icon_name);
                icon.set_pixel_size (20);

                var button = new Gtk.Button ();
                button.set_child (icon);
                button.set_tooltip_text (tooltip_text);
                button.add_css_class ("flat");
                button.width_request = 40;
                button.height_request = 40;

                return button;
            }

            public Adw.ActionRow create_action_row (string launcher_type) {
                progress_label = new Gtk.Label (null);
                var spinner = new Gtk.Spinner ();
                var btn_cancel = create_button ("x-symbolic", _("Cancel the installation"));
                var btn_delete = create_button ("trash-symbolic", _("Delete STL"));
                var icon_upgrade = new Gtk.Image ();
                var btn_upgrade = new Gtk.Button ();
                var btn_install = create_button ("download-symbolic", _("Install STL"));
                var btn_info = create_button ("info-circle-symbolic", _("Show more information"));
                var input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
                var row = new Adw.ActionRow ();

                progress_label.set_visible (false);

                spinner.set_visible (false);

                btn_cancel.set_visible (false);
                btn_cancel.clicked.connect (() => cancelled = true);

                btn_delete.clicked.connect (() => {
                    var delete_check = new Gtk.CheckButton.with_label (_("Check this to also delete your configuration files"));

                    var dialog = new Adw.MessageDialog (Application.window, _("Delete SteamTinkerLaunch"), _("You're about to delete STL from your system\nAre you sure you want this?"));
                    dialog.set_extra_child (delete_check);
                    dialog.add_response ("no", _("No"));
                    dialog.add_response ("yes", _("Yes"));
                    dialog.set_response_appearance ("no", Adw.ResponseAppearance.DEFAULT);
                    dialog.set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);
                    dialog.show ();
                    dialog.response.connect ((response) => {
                        if (response == "yes") {
                            row.activate_action_variant ("win.add-task", "");

                            spinner.start ();
                            spinner.set_visible (true);

                            btn_delete.set_visible (false);
                            btn_install.set_visible (false);
                            btn_upgrade.set_visible (false);

                            remove.begin (delete_check.get_active (), (obj, res) => {
                                var success = remove.end (res);

                                row.activate_action_variant ("win.remove-task", "");

                                spinner.stop ();
                                spinner.set_visible (false);

                                if (success) {
                                    send_toast (_("The deletion of ") + title + _(" is done"), 3);
                                } else {
                                    send_toast (_("An unexpected error occured while deleting ") + title, 5000);
                                }
                            });
                        }
                    });
                });

                icon_upgrade.set_pixel_size (20);

                btn_upgrade.set_child (icon_upgrade);
                btn_upgrade.add_css_class ("flat");
                btn_upgrade.width_request = 40;
                btn_upgrade.height_request = 40;
                btn_upgrade.clicked.connect (() => {
                    if (updated) {
                        send_toast (title + _(" is already up-to-date"), 3);
                    } else {
                        send_toast (_("The upgrade of ") + title + _(" was started"), 3);

                        row.activate_action_variant ("win.add-task", "");

                        spinner.start ();
                        spinner.set_visible (true);
                        progress_label.set_text (""); // Clear label to erase old progress.
                        progress_label.set_visible (true);

                        btn_cancel.set_visible (false);
                        btn_delete.set_visible (false);
                        btn_install.set_visible (false);
                        btn_upgrade.set_visible (false);

                        upgrade.begin ((obj, res) => {
                            var success = upgrade.end (res);

                            row.activate_action_variant ("win.remove-task", "");

                            spinner.stop ();
                            spinner.set_visible (false);
                            progress_label.set_visible (false);
                            btn_cancel.set_visible (false);

                            if (success) {
                                send_toast (_("The upgrade of ") + title + _(" is done"), 3);
                            } else {
                                send_toast (_("An unexpected error occured while upgrading ") + title, 5000);
                            }
                        });
                    }
                });

                btn_install.clicked.connect (() => {
                    send_toast (_("The installation of ") + title + _(" was started"), 3);

                    row.activate_action_variant ("win.add-task", "");

                    spinner.start ();
                    spinner.set_visible (true);
                    progress_label.set_text (""); // Clear label to erase old progress.
                    progress_label.set_visible (true);

                    btn_cancel.set_visible (true);
                    btn_delete.set_visible (false);
                    btn_install.set_visible (false);
                    btn_upgrade.set_visible (false);

                    install.begin ((obj, res) => {
                        var success = install.end (res);

                        row.activate_action_variant ("win.remove-task", "");

                        spinner.stop ();
                        spinner.set_visible (false);
                        progress_label.set_visible (false);
                        btn_cancel.set_visible (false);

                        if (success) {
                            send_toast (_("The installation of ") + title + _(" is done"), 3);
                        } else if (cancelled) {
                            send_toast (_("The installation of ") + title + _(" was cancelled"), 3);
                        } else {
                            send_toast (_("An unexpected error occured while installing ") + title, 5000);
                        }
                    });
                });

                btn_info.set_visible (launcher_type != "System");
                btn_info.clicked.connect (() => {
                    switch (launcher_type) {
                        case "Flatpak":
                            var dialog = new Adw.MessageDialog (Application.window, _("Steam Flatpak is not supported"), _("To install Steam Tinker Launch for Steam Flatpak, please run the following command:") + "\n\nflatpak install --user com.valvesoftware.Steam.Utility.steamtinkerlaunch");
                            dialog.add_response ("ok", _("OK"));
                            dialog.show ();
                            break;
                        case "Snap":
                            var dialog = new Adw.MessageDialog (Application.window, _("Steam Snap is not supported"), _("There's currently no known way to install STL for Steam Snap"));
                            dialog.add_response ("ok", _("OK"));
                            dialog.show ();
                            break;
                        default:
                            var dialog = new Adw.MessageDialog (Application.window, _("Steam Flatpak is not supported"), _("To install Steam Tinker Launch for Steam Flatpak, please run the following command:") + "\n\nflatpak install --user com.valvesoftware.Steam.Utility.steamtinkerlaunch");
                            dialog.add_response ("ok", _("OK"));
                            dialog.show ();
                            break;
                    }
                });

                input_box.set_margin_end (10);
                input_box.set_valign (Gtk.Align.CENTER);

                if (launcher_type == "System") {
                    input_box.append (progress_label);
                    input_box.append (spinner);
                    input_box.append (btn_cancel);
                    input_box.append (btn_delete);
                    input_box.append (btn_upgrade);
                    input_box.append (btn_install);
                } else {
                    input_box.append (btn_info);
                }

                row.set_title (row_stl_title);
                row.add_suffix (input_box);

                this.notify["installed"].connect (() => {
                    row.set_title (row_stl_title);
                    btn_delete.set_visible (installed);
                    btn_install.set_visible (!installed);
                    btn_upgrade.set_visible (installed);
                });

                this.notify["updated"].connect (() => {
                    row.set_title (row_stl_title);
                    if (updated) {
                        icon_upgrade.set_from_icon_name ("circle-check-symbolic");
                        btn_upgrade.set_tooltip_text (_("STL is up-to-date"));
                    } else {
                        icon_upgrade.set_from_icon_name ("circle-chevron-up-symbolic");
                        btn_upgrade.set_tooltip_text (_("Update STL to the latest version"));
                    }
                });

                this.notify_property ("installed");
                this.notify_property ("updated");

                return row;
            }
        }
    }
}