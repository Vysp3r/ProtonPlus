namespace ProtonPlus.Models.Releases {
    public class SteamTinkerLaunch : Release {
        string home_location { get; set; }
        string compat_location { get; set; }
        string parent_location { get; set; }
        public string base_location { get; set; }
        string binary_location { get; set; }
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

        public override string usage_name {
            get { return "Proton-stl"; }
        }

        public SteamTinkerLaunch (Tool runner) {
            Object (runner: runner,
                    title: "Steam Tinker Launch");

            home_location = Environment.get_home_dir ();
            compat_location = runner.group.launcher.directory + runner.group.directory;
            if (Globals.IS_STEAM_OS) {
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
            link_parent_location = @"$home_location/.local/bin";
            link_location = @"$link_parent_location/steamtinkerlaunch";
            config_location = @"$home_location/.config/steamtinkerlaunch";
            external_locations = new List<string> ();

            refresh_latest_stl_version.begin ((obj, res) => {
                refresh_state ();
            });
        }

        string get_download_url () {
            return @"https://github.com/sonic2kk/steamtinkerlaunch/archive/$latest_hash.zip";
        }

        async void exec_stl (string exec_location, string args) {
            if (!FileUtils.test (exec_location, FileTest.IS_REGULAR))
                return;

            var quoted_exec_location = Shell.quote (exec_location);

            if (!FileUtils.test (exec_location, FileTest.IS_EXECUTABLE))
                yield Utils.System.run_command (@"chmod +x $quoted_exec_location");

            yield Utils.System.run_command (@"$quoted_exec_location $args");
        }

        async void refresh_latest_stl_version () {
            latest_date = "";
            latest_hash = "";

            var response = yield Utils.Web.get_request (
                "https://api.github.com/repos/sonic2kk/steamtinkerlaunch/commits?per_page=1",
                Utils.Web.GetRequestType.STEAMTINKERLAUNCH
            );

            if (response.code != ReturnCode.VALID_REQUEST)
                return;

            var root_node = Utils.Parser.get_node_from_json (response.body);

            if (root_node == null || root_node.get_node_type () != Json.NodeType.ARRAY)
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
                latest_date = date_parts[0];     // "YYYY-MM-DD".
            }

            latest_hash = commit_obj.get_string_member_with_default ("sha", "");
            download_url = get_download_url ();
        }

        void write_installation_metadata (string meta_location) {
            Utils.Filesystem.create_file (meta_location, @"$latest_date:$latest_hash");
        }

        public bool detect_external_locations () {
            external_locations = new List<string> ();

            var location = @"$home_location/SteamTinkerLaunch";
            if (FileUtils.test (location, FileTest.IS_DIR))
                external_locations.append (location);

            location = Environment.get_home_dir () + "/stl";
            if (!Globals.IS_STEAM_OS && FileUtils.test (location, FileTest.IS_DIR))
                external_locations.append (location);

            // Disabled for now, since we always erase base_location before installs.
            // if (FileUtils.test (base_location, FileTest.IS_DIR) && !FileUtils.test (meta_location, FileTest.IS_REGULAR))
            // external_locations.append (base_location);

            return external_locations.length () > 0;
        }

        protected override void refresh_state () {
            // Update the ProtonPlus UI state variables.
            // NOTE: We treat a non-executable binary as a "broken installation".
            var base_location_exists = FileUtils.test (base_location, FileTest.IS_DIR);
            var binary_location_exists = FileUtils.test (binary_location, FileTest.IS_EXECUTABLE);
            var meta_file_exists = FileUtils.test (meta_location, FileTest.IS_REGULAR);

            var installed = base_location_exists && binary_location_exists && meta_file_exists;
            var updated = false;

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

            step = Step.NOTHING;

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
            // title immediately appears during "update" of an installation.
            displayed_title = _row_title;

            state = !installed ? State.NOT_INSTALLED : updated ? State.UP_TO_DATE : State.UPDATE_AVAILABLE;
        }

        protected async override ReturnCode _start_install (bool replace_existing = false) {
            var base_location_exists = FileUtils.test (base_location, FileTest.EXISTS);
            if (base_location_exists && !replace_existing)
                return ReturnCode.RUNNER_ALREADY_INSTALLED;

            var archive_cache_path = Path.build_filename (Globals.CACHE_PATH, "archives");
            if (!yield Utils.Filesystem.create_directory_async (archive_cache_path))
                return ReturnCode.FILESYSTEM_ERROR;

            var operation_path = Utils.Filesystem.create_temporary_directory (Globals.CACHE_PATH, ".protonplus-stl-");
            if (operation_path == "")
                return ReturnCode.FILESYSTEM_ERROR;

            var staging_root = "";
            var url = get_download_url ();
            var archive_key = Checksum.compute_for_string (ChecksumType.SHA256, url);
            var cache_archive_path = Path.build_filename (archive_cache_path, @"$archive_key.zip");
            var operation_archive_path = Path.build_filename (operation_path, "archive.zip");

            step = Step.DOWNLOADING;
            if (!FileUtils.test (cache_archive_path, FileTest.IS_REGULAR)) {
                string? download_error;
                var download_valid = yield Utils.Web.download (
                    url,
                    operation_archive_path,
                    operation_cancellable,
                    on_download_progress,
                    out download_error
                );

                if (!download_valid) {
                    error_message = download_error;
                    return yield complete_install_attempt (ReturnCode.DOWNLOAD_FAILED, operation_path, staging_root);
                }

                var cached = yield Utils.Filesystem.move_file_atomic_if_absent (operation_archive_path, cache_archive_path);
                if (!cached && !FileUtils.test (cache_archive_path, FileTest.IS_REGULAR))
                    return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }

            if (!yield Utils.Filesystem.copy_file (cache_archive_path, operation_archive_path))
                return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);

            if (canceled)
                return yield complete_install_attempt (ReturnCode.EXTRACTION_FAILED, operation_path, staging_root);

            step = Step.EXTRACTING;
            string? source_path = yield Utils.Filesystem.extract (operation_path, "archive", ".zip", operation_cancellable);
            if (source_path == null || source_path == "") {
                if (!canceled)
                    error_message = _ ("Extraction failed");
                return yield complete_install_attempt (ReturnCode.EXTRACTION_FAILED, operation_path, staging_root);
            }

            var install_parent = Path.get_dirname (base_location);
            if (!yield Utils.Filesystem.create_directory_async (install_parent))
                return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);

            staging_root = Utils.Filesystem.create_temporary_directory (install_parent, ".protonplus-stl-stage-");
            if (staging_root == "")
                return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);

            var staged_base_location = Path.build_filename (staging_root, "installation");
            if (!yield Utils.Filesystem.copy_directory (source_path, staged_base_location)) {
                error_message = _ ("Moving failed");
                return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }

            write_installation_metadata (Path.build_filename (staged_base_location, "ProtonPlus.meta"));

            // External installations are only removed after the replacement is
            // complete and ready.  This list is populated after the user's
            // explicit reinstall confirmation.
            foreach (var location in external_locations) {
                var deleted = yield Utils.Filesystem.delete_directory (location);
                if (!deleted)
                    return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }

            var previous_base_location = "";
            if (base_location_exists) {
                previous_base_location = Path.build_filename (install_parent, ".protonplus-stl-previous-%s".printf (Path.get_basename (staging_root)));
                if (!yield Utils.Filesystem.move_directory_atomic (base_location, previous_base_location))
                    return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }

            step = Step.MOVING;
            if (!yield Utils.Filesystem.move_directory_atomic (staged_base_location, base_location)) {
                if (previous_base_location != "")
                    yield Utils.Filesystem.move_directory_atomic (previous_base_location, base_location);
                return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }

            if (!FileUtils.test (link_location, FileTest.EXISTS)) {
                if (!yield Utils.Filesystem.create_directory_async (link_parent_location)) {
                    yield rollback_installation (previous_base_location);
                    return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
                }

                if (!yield Utils.Filesystem.make_symlink (link_location, binary_location)) {
                    yield rollback_installation (previous_base_location);
                    return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
                }
            } else if (!FileUtils.test (link_location, FileTest.IS_SYMLINK)) {
                yield rollback_installation (previous_base_location);
                return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }

            // Do not unregister the working version until its replacement has
            // been atomically promoted.  Existing links point at base_location
            // and therefore automatically resolve to the new binary.
            if (yield Utils.System.check_dependency ("steamtinkerlaunch"))
                yield Utils.System.run_command ("steamtinkerlaunch compat del");
            yield exec_stl (binary_location, "compat del");

            if (Globals.IS_STEAM_OS)
                yield exec_stl (binary_location, "");
            yield exec_stl (binary_location, "compat add");

            if (previous_base_location != "") {
                if (!yield Utils.Filesystem.delete_directory (previous_base_location))
                    warning ("Could not remove the previous SteamTinkerLaunch installation: %s", previous_base_location);
            }

            var simple_runner = new Tools.Simple.from_path ("%s/SteamTinkerLaunch".printf (compat_location));
            var steam_launcher = runner.group.launcher as Models.Launchers.Steam;
            if (steam_launcher != null)
                steam_launcher.register_compatibility_tool (simple_runner);

            return yield complete_install_attempt (ReturnCode.RUNNER_INSTALLED, operation_path, staging_root);
        }

        private async void rollback_installation (string previous_base_location) {
            if (previous_base_location == "") {
                if (FileUtils.test (base_location, FileTest.IS_DIR))
                    yield Utils.Filesystem.delete_directory (base_location);
                return;
            }

            var failed_base_location = "%s.failed".printf (previous_base_location);
            if (!yield Utils.Filesystem.move_directory_atomic (base_location, failed_base_location))
                return;

            if (!yield Utils.Filesystem.move_directory_atomic (previous_base_location, base_location)) {
                yield Utils.Filesystem.move_directory_atomic (failed_base_location, base_location);
                return;
            }

            yield Utils.Filesystem.delete_directory (failed_base_location);
        }

        protected override async ReturnCode _start_remove () {
            yield exec_stl (binary_location, "compat del");

            // NOTE: We check specific types to avoid deleting unexpected data.
            if (FileUtils.test (link_location, FileTest.EXISTS)) {
                if (!FileUtils.test (link_location, FileTest.IS_SYMLINK))
                    return ReturnCode.FILESYSTEM_ERROR;

                var link_deleted = Utils.Filesystem.delete_file (link_location);

                if (!link_deleted)
                    return ReturnCode.FILESYSTEM_ERROR;
            }

            var remove_location = get_data<bool> ("user-request") ? manual_remove_location : base_location;
            if (FileUtils.test (remove_location, FileTest.EXISTS)) {
                if (!FileUtils.test (remove_location, FileTest.IS_DIR))
                    return ReturnCode.FILESYSTEM_ERROR;

                var base_deleted = yield Utils.Filesystem.delete_directory (remove_location);

                if (!base_deleted)
                    return ReturnCode.FILESYSTEM_ERROR;
            }

            if (get_data<bool> ("delete-config") && FileUtils.test (config_location, FileTest.EXISTS)) {
                if (!FileUtils.test (config_location, FileTest.IS_DIR))
                    return ReturnCode.FILESYSTEM_ERROR;

                var config_deleted = yield Utils.Filesystem.delete_directory (config_location);

                if (!config_deleted)
                    return ReturnCode.FILESYSTEM_ERROR;
            }

            var steam_launcher = runner.group.launcher as Models.Launchers.Steam;
            if (steam_launcher != null) {
                steam_launcher.unregister_compatibility_tool_by_path ("%s/SteamTinkerLaunch".printf (compat_location));
            }

            return ReturnCode.RUNNER_REMOVED;
        }

        protected override async ReturnCode _start_update () {
            var install_code = yield install_replacement ();
            if (install_code != ReturnCode.RUNNER_INSTALLED)
                return install_code;

            return ReturnCode.RUNNER_UPDATED;
        }
    }
}
