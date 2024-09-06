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

        public class STL {
            static string home_location;
            static string compat_location;
            static string parent_location;
            static string base_location;
            static string binary_location;
            static string meta_location;
            static string link_parent_location;
            static string link_location;
            static string config_location;
            static List<string> external_locations;

            static bool installed;
            static bool updated;
            static bool cancelled;

            static string? latest_hash;
            static string local_hash;

            static string title;

            static Gtk.Label progress_label;
            static Adw.ToastOverlay toast_overlay;

            public static bool init (string compat_location, Adw.ToastOverlay toast_overlay) {
                STL.toast_overlay = toast_overlay;

                home_location = Environment.get_home_dir ();
                STL.compat_location = compat_location;
                parent_location = @"$home_location/.local/share";
                base_location = @"$parent_location/steamtinkerlaunch";
                binary_location = @"$base_location/steamtinkerlaunch";
                meta_location = @"$base_location/ProtonPlus.meta";
                link_parent_location = @"$home_location/.local/bin";
                link_location = @"$link_parent_location/steamtinkerlaunch";
                config_location = @"$home_location/.config/steamtinkerlaunch";
                external_locations = new List<string> ();
                external_locations.append (@"$home_location/SteamTinkerLaunch");

                if (Utils.System.IS_STEAM_OS)
                    base_location = @"$home_location/stl/prefix";
                else
                    external_locations.append (Environment.get_home_dir () + "/stl");

                var base_location_exists = FileUtils.test (base_location, FileTest.EXISTS);
                var meta_file_exists = FileUtils.test (meta_location, FileTest.EXISTS);

                installed = base_location_exists && meta_file_exists;
                updated = false;

                latest_hash = get_latest_hash ();
                if (latest_hash == "")
                    return false;

                if (installed) {
                    local_hash = Utils.Filesystem.get_file_content (meta_location);
                    if (local_hash == "") {
                        installed = false;
                    } else {
                        updated = latest_hash == local_hash;
                    }
                }

                if (base_location_exists && !meta_file_exists) {
                    external_locations.append (base_location);
                }

                title = "STL";

                return true;
            }

            static string get_download_url () {
                return @"https://github.com/sonic2kk/steamtinkerlaunch/archive/$latest_hash.zip";
            }

            static string get_latest_hash () {
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
                        return "";

                    var root_array = root_node.get_array ();

                    if (root_array.get_length () < 1)
                        return "";

                    var temp_node = root_array.get_element (0);

                    if (temp_node.get_node_type () != Json.NodeType.OBJECT)
                        return "";

                    var temp_obj = temp_node.get_object ();

                    return temp_obj.get_string_member_with_default ("sha", "");
                } catch (Error e) {
                    message (e.message);
                    return "";
                }
            }

            public static async bool install () {
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

                var has_external_install = false;

                foreach (var location in external_locations) {
                    if (FileUtils.test (location, FileTest.EXISTS))
                        has_external_install = true;
                }

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
                        else if (base_location.contains (location))
                            external_locations.remove (location);
                    }
                }

                var has_existing_install = FileUtils.test (base_location, FileTest.EXISTS) && FileUtils.test (meta_location, FileTest.EXISTS);
                if (has_existing_install)
                    yield remove (false);

                if (!FileUtils.test (base_location, FileTest.IS_DIR))
                    if (!Utils.Filesystem.create_directory (base_location))
                        return false;

                string download_path = parent_location + "/" + title + ".zip";

                var download_result = yield Utils.Web.Download (get_download_url (), download_path, -1, () => cancelled, (download_progress) => progress_label.set_text (download_progress.to_string () + "%"));

                if (download_result != Utils.Web.DOWNLOAD_CODES.SUCCESS)
                    return false;

                string source_path = yield Utils.Filesystem.extract (@"$parent_location/", title, ".zip", () => cancelled);

                if (source_path == "")
                    return false;

                Utils.Filesystem.rename (source_path, base_location);

                if (!Utils.Filesystem.create_directory (link_parent_location))
                    return false;

                var file = File.new_for_path (link_location);
                if (file.query_exists (null)) {
                    // Only attempt to delete the file if it's already a symlink.
                    if (FileUtils.test (link_location, FileTest.IS_SYMLINK)) {
                        var link_deleted = Utils.Filesystem.delete_file (link_location);
                        if (!link_deleted)
                            return false;
                    }
                }

                try {
                    // Try to create the symlink (will fail if file exists or no permission)
                    yield file.make_symbolic_link_async (binary_location, Priority.DEFAULT, null);
                } catch (Error e) {
                    return false;
                }


                // Trigger STL's dependency installer for Steam Deck users.
                if (Utils.System.IS_STEAM_OS)
                    exec_stl (@"$base_location/steamtinkerlaunch", "");

                exec_stl (binary_location, "compat add");

                Utils.Filesystem.create_file (meta_location, latest_hash);

                return true;
            }

            public static async bool upgrade () {
                return true;
            }

            public static async bool remove (bool delete_config) {
                exec_stl_if_exists (binary_location, "compat del");

                if (FileUtils.test (link_location, GLib.FileTest.IS_SYMLINK)) {
                    var link_deleted = Utils.Filesystem.delete_file (link_location);

                    if (!link_deleted)
                        return false;
                }

                if (FileUtils.test (base_location, GLib.FileTest.IS_DIR)) {
                    var base_deleted = yield Utils.Filesystem.delete_directory (base_location);

                    if (!base_deleted)
                        return false;
                }


                if (delete_config && FileUtils.test (config_location, GLib.FileTest.IS_DIR)) {
                    var config_deleted = yield Utils.Filesystem.delete_directory (config_location);

                    if (!config_deleted)
                        return false;
                }

                return true;
            }

            static void exec_stl_if_exists (string exec_location, string args) {
                if (FileUtils.test (exec_location, FileTest.IS_REGULAR))
                    exec_stl (exec_location, args);
            }

            static void exec_stl (string exec_location, string args) {
                if (FileUtils.test (exec_location, FileTest.IS_REGULAR) && !FileUtils.test (exec_location, FileTest.IS_EXECUTABLE))
                    Utils.System.run_command (@"chmod +x $exec_location");
                Utils.System.run_command (@"$exec_location $args");
            }

            static void send_toast (string content, int duration) {
                var toast = new Adw.Toast (content);
                toast.set_timeout (duration);

                toast_overlay.add_toast (toast);
            }

            static Gtk.Button create_button (string icon_name, string tooltip_text) {
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

            public static Adw.ActionRow create_action_row (string launcher_type) {
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

                btn_delete.set_visible (installed);
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
                                btn_delete.set_visible (false);
                                btn_install.set_visible (true);
                                btn_upgrade.set_visible (false);

                                if (success) {
                                    installed = false;
                                    send_toast (_("The deletion of ") + title + _(" is done"), 3);
                                } else {
                                    send_toast (_("An unexpected error occured while deleting ") + title, 5000);
                                }
                            });
                        }
                    });
                });

                icon_upgrade.set_pixel_size (20);

                btn_upgrade.set_visible (installed);
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
                            btn_delete.set_visible (true);
                            btn_install.set_visible (false);
                            btn_upgrade.set_visible (true);

                            if (success) {
                                updated = true;
                                send_toast (_("The upgrade of ") + title + _(" is done"), 3);
                            } else {
                                send_toast (_("An unexpected error occured while upgrading ") + title, 5000);
                            }
                        });
                    }
                });

                if (updated) {
                    icon_upgrade.set_from_icon_name ("circle-check-symbolic");
                    btn_upgrade.set_tooltip_text (_("STL is up-to-date"));
                } else {
                    icon_upgrade.set_from_icon_name ("circle-chevron-up-symbolic");
                    btn_upgrade.set_tooltip_text (_("Update STL to the latest version"));
                }

                btn_install.set_visible (!installed);
                btn_install.clicked.connect (() => {
                    send_toast (_("The installation of ") + title + _(" was started"), 3);

                    row.activate_action_variant ("win.add-task", "");

                    spinner.start ();
                    spinner.set_visible (true);
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
                        btn_delete.set_visible (success);
                        btn_install.set_visible (cancelled);
                        btn_upgrade.set_visible (success);

                        if (success) {
                            installed = true;
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

                row.set_title ("SteamTinkerLaunch");
                row.add_suffix (input_box);

                return row;
            }
        }
    }
}