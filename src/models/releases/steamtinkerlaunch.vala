namespace ProtonPlus.Models.Releases {
    public class SteamTinkerLaunch : Release {
        public bool updated { get; set; }

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
        string manual_remove_location { get; set; }
        List<string> external_locations;

        string? latest_date { get; set; }
        string? latest_hash { get; set; }
        string local_date { get; set; }
        string local_hash { get; set; }

        public SteamTinkerLaunch (Runner runner) {
            Object (runner: runner,
                    title: "SteamTinkerLaunch");

            home_location = Environment.get_home_dir ();
            compat_location = runner.group.launcher.directory + "/" + runner.group.directory;
            if (Utils.System.IS_STEAM_OS) {
                // Steam Deck uses `~/stl/prefix` instead.
                parent_location = @"$home_location/stl";
                base_location = @"$parent_location/prefix";
                manual_remove_location = parent_location;
            } else {
                // Normal computers use `~/.local/share/steamtinkerlaunch`.
                parent_location = @"$home_location/.local/share";
                base_location = @"$parent_location/steamtinkerlaunch";
                manual_remove_location = base_location;
            }
            binary_location = @"$base_location/steamtinkerlaunch";
            meta_location = @"$base_location/ProtonPlus.meta";
            download_location = @"$base_location/ProtonPlus.downloads";
            link_parent_location = @"$home_location/.local/bin";
            link_location = @"$link_parent_location/steamtinkerlaunch";
            config_location = @"$home_location/.config/steamtinkerlaunch";
            external_locations = new List<string> ();

            var row = new Widgets.ReleaseRows.SteamTinkerLaunch ();
            row.initialize (this);

            this.row = row;

            refresh_latest_stl_version ();
            refresh_interface_state ();
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


                // Get the first (newest) commit in the list.
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

        internal override void refresh_interface_state (bool can_reset_processing = false) {
            // Update the ProtonPlus UI state variables.
            // NOTE: We treat a non-executable binary as a "broken installation".
            var base_location_exists = FileUtils.test (base_location, FileTest.IS_DIR);
            var binary_location_exists = FileUtils.test (binary_location, FileTest.IS_EXECUTABLE);
            var meta_file_exists = FileUtils.test (meta_location, FileTest.IS_REGULAR);

            installed = base_location_exists && binary_location_exists && meta_file_exists;
            updated = false;

            local_date = "";
            local_hash = "";

            if (installed) {
                var raw_metadata = Utils.Filesystem.get_file_content (meta_location);
                var metadata_parts = raw_metadata.strip ().split (":");
                if (metadata_parts.length >= 2) {
                    local_date = metadata_parts[0];
                    local_hash = metadata_parts[1];
                    // Ignore both values if either is missing.
                    if (local_date == "" || local_hash == "")
                        local_date = local_hash = "";
                }

                if (local_hash == "")
                    installed = false;
                else if (latest_hash != "")
                    updated = latest_hash == local_hash;
            }


            // Generate a title for the installed (or latest) release.
            var _row_title = title; // Default title/prefix.
            if (local_date != "")
                _row_title = @"$_row_title ($local_date)";
            else if (latest_date != "")
                _row_title = @"$_row_title ($latest_date)";


            // Update state to trigger the signals for UI refresh.
            // WARNING: We MUST do this LAST, after finishing ALL other vars
            // above, otherwise the UI redraw would happen with old values.
            // NOTE: We will NOT change UI state if the UI is "busy processing",
            // except when we're EXPLICITLY allowed to reset that state. This
            // avoids "flickering UI" issues during multi-step processes.
            // NOTE: We ALWAYS allow title change, to ensure the latest version's
            // title immediately appears during "upgrade" of an installation.
            row.set_title (_row_title);
            var change_state = (can_reset_processing
                                || (row.ui_state != Widgets.ReleaseRow.UIState.BUSY_INSTALLING
                                    && row.ui_state != Widgets.ReleaseRow.UIState.BUSY_REMOVING));
            if (change_state) {
                if (installed)
                    row.ui_state = updated ? Widgets.ReleaseRow.UIState.UP_TO_DATE : Widgets.ReleaseRow.UIState.UPDATE_AVAILABLE;
                else
                    row.ui_state = Widgets.ReleaseRow.UIState.NOT_INSTALLED;
            }
        }

        void write_installation_metadata (string meta_location) {
            Utils.Filesystem.create_file (meta_location, @"$latest_date:$latest_hash");
        }

        bool detect_external_locations () {
            if (external_locations.length () > 0)
                external_locations = new List<string> ();

            var location = @"$home_location/SteamTinkerLaunch";
            if (FileUtils.test (location, FileTest.IS_DIR))
                external_locations.append (location);

            location = Environment.get_home_dir () + "/stl";
            if (!Utils.System.IS_STEAM_OS && FileUtils.test (location, FileTest.IS_DIR))
                external_locations.append (location);

            // Disabled for now, since we always erase base_location before installs.
            // if (FileUtils.test (base_location, FileTest.IS_DIR) && !FileUtils.test (meta_location, FileTest.IS_REGULAR))
            // external_locations.append (base_location);

            return external_locations.length () > 0;
        }

        public async bool install () {
            // Steam Deck doesn't need any external dependencies.
            if (!Utils.System.IS_STEAM_OS) {
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
                    var dialog = new Adw.MessageDialog (Widgets.Application.window, _("Missing dependencies!"), "%s\n\n%s\n%s".printf (_("You are missing the following dependencies for %s:").printf (title), missing_dependencies, _("Installation will be canceled.")));
                    dialog.add_response ("ok", _("OK"));
                    dialog.show ();
                    canceled = true;
                    return false;
                }
            }

            var has_external_install = detect_external_locations ();

            if (has_external_install) {
                var dialog = new Adw.MessageDialog (Widgets.Application.window, _("Existing installation of %s").printf (title), "%s\n\n%s".printf (_("It looks like you currently have another version of %s which was not installed by ProtonPlus.").printf (title), _("Do you want to delete it and install %s with ProtonPlus?").printf (title)));
                dialog.add_response ("cancel", _("Cancel"));
                dialog.add_response ("ok", _("OK"));
                dialog.set_response_appearance ("cancel", Adw.ResponseAppearance.DEFAULT);
                dialog.set_response_appearance ("ok", Adw.ResponseAppearance.DESTRUCTIVE);

                string response = yield dialog.choose (null);

                if (response != "ok") {
                    canceled = true;
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


            // We have to force the GUI to show the "busy installing" state.
            row.ui_state = Widgets.ReleaseRow.UIState.BUSY_INSTALLING;


            // Attempt the installation.
            var install_success = yield _download_and_install ();

            if (!install_success) {
                // Attempt to clean up any leftover files and symlinks,
                // but don't erase the user's STL configuration files.
                yield remove (false); // Refreshes install state too.

                return false;
            }


            refresh_interface_state (true); // Force UI state refresh.

            return true;
        }

        async bool _download_and_install () {
            // Always clean destination to avoid merging with existing files.
            // NOTE: We check for ANY existing (conflicting) file, not just
            // dirs. The `remove` function then validates the actual types.
            var base_location_exists = FileUtils.test (base_location, FileTest.EXISTS);
            if (base_location_exists) {
                var deleted_old_files = yield remove (false);

                if (!deleted_old_files)
                    return false;
            }


            // Download the source code archive.
            // NOTE: We only create "downloads", since it's a subdir of `base_location`.
            if (!FileUtils.test (download_location, FileTest.IS_DIR)) {
                var download_dir_exists = yield Utils.Filesystem.create_directory (download_location);

                if (!download_dir_exists)
                    return false;
            }

            string downloaded_file_location = @"$download_location/$title.zip";

            if (FileUtils.test (downloaded_file_location, FileTest.EXISTS)) {
                var deleted = Utils.Filesystem.delete_file (downloaded_file_location);

                if (!deleted)
                    return false;
            }

            var download_result = yield Utils.Web.Download (get_download_url (), downloaded_file_location, () => canceled, (is_percent, progress) => row.progress_label.set_text (is_percent ? @"$progress%" : Utils.Filesystem.convert_bytes_to_string (progress)));

            if (download_result != Utils.Web.DOWNLOAD_CODES.SUCCESS)
                return false;


            // Extract archive and move its contents to the installation directory.
            string extracted_file_location = yield Utils.Filesystem.extract (@"$download_location/", title, ".zip", () => canceled);

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
            var link_parent_location_exists = yield Utils.Filesystem.create_directory (link_parent_location);

            if (!link_parent_location_exists)
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

        public async bool remove (bool delete_config, bool user_request = false) {
            // We have to force the GUI to show the "busy removing" state.
            row.ui_state = Widgets.ReleaseRow.UIState.BUSY_REMOVING;


            // Attempt the removal.
            var remove_success = yield _remove_installation (delete_config, user_request);

            refresh_interface_state (true); // Force UI state refresh.

            return remove_success;
        }

        async bool _remove_installation (bool delete_config, bool user_request = false) {
            exec_stl_if_exists (binary_location, "compat del");

            // NOTE: We check specific types to avoid deleting unexpected data.
            if (FileUtils.test (link_location, FileTest.EXISTS)) {
                if (!FileUtils.test (link_location, FileTest.IS_SYMLINK))
                    return false;

                var link_deleted = Utils.Filesystem.delete_file (link_location);

                if (!link_deleted)
                    return false;
            }

            var remove_location = user_request ? manual_remove_location : base_location;
            if (FileUtils.test (remove_location, FileTest.EXISTS)) {
                if (!FileUtils.test (remove_location, FileTest.IS_DIR))
                    return false;

                var base_deleted = yield Utils.Filesystem.delete_directory (remove_location);

                if (!base_deleted)
                    return false;
            }

            if (delete_config && FileUtils.test (config_location, FileTest.EXISTS)) {
                if (!FileUtils.test (config_location, FileTest.IS_DIR))
                    return false;

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
    }
}