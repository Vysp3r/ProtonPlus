namespace ProtonPlus.Services {
    private class SteamTinkerLaunchDirectoryBackup : Object {
        public string original_path { get; private set; }
        public string backup_path { get; private set; }

        public SteamTinkerLaunchDirectoryBackup (string original_path, string backup_path) {
            this.original_path = original_path;
            this.backup_path = backup_path;
        }
    }

    /// SteamTinkerLaunch has its own installation layout, external commands,
    /// and Steam integration.  It intentionally remains independent of the
    /// ordinary provider catalog and archive workflow.
    public class SteamTinkerLaunchWorkflow : InstallationWorkflow {
        private ArchiveWorkflowSupport archive_support = new ArchiveWorkflowSupport ();

        public override ReturnCode validate_install (InstallJob job, bool replace_existing) {
            var context = get_context (job);
            if (context == null)
                return ReturnCode.INVALID_CONFIGURATION;
            if (FileUtils.test (context.base_location, FileTest.EXISTS) && !replace_existing)
                return ReturnCode.RUNNER_ALREADY_INSTALLED;
            return ReturnCode.RUNNER_INSTALLED;
        }

        public override async ReturnCode install (InstallJob job, bool replace_existing) {
            var context = get_context (job);
            if (context == null)
                return ReturnCode.INVALID_CONFIGURATION;
            var exists = FileUtils.test (context.base_location, FileTest.EXISTS);
            if (exists && !replace_existing)
                return ReturnCode.RUNNER_ALREADY_INSTALLED;

            ArchiveOperation? operation;
            var prepare_code = yield archive_support.prepare_archive (job, ".protonplus-stl-", out operation);
            if (prepare_code != ReturnCode.RUNNER_INSTALLED || operation == null)
                return prepare_code;
            var archive = (!) operation;

            job.step = InstallJob.Step.EXTRACTING;
            var source = yield Utils.Filesystem.extract (
                archive.operation_path, "archive", archive.extension, job.get_cancellable ()
            );
            if (source == null || source == "") {
                if (!job.canceled)
                    job.error_message = _ ("Extraction failed");
                return yield archive_support.complete_attempt (
                    ReturnCode.EXTRACTION_FAILED, archive, !job.canceled
                );
            }

            var parent = Path.get_dirname (context.base_location);
            if (!yield Utils.Filesystem.create_directory_async (parent))
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            archive.staging_root = Utils.Filesystem.create_temporary_directory (parent, ".protonplus-stl-stage-");
            if (archive.staging_root == "")
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            var staged = Path.build_filename (archive.staging_root, "installation");
            if (!yield Utils.Filesystem.copy_directory (source, staged)) {
                job.error_message = _ ("Moving failed");
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }
            var staged_binary = Path.build_filename (staged, "steamtinkerlaunch");
            var staged_meta = Path.build_filename (staged, "ProtonPlus.meta");
            var metadata = "%s:%s".printf (context.latest_date, context.latest_hash);
            if (!FileUtils.test (staged_binary, FileTest.IS_REGULAR) ||
                !Utils.Filesystem.modify_file (staged_meta, metadata) ||
                !FileUtils.test (staged_meta, FileTest.IS_REGULAR) ||
                Utils.Filesystem.get_file_content (staged_meta) != metadata) {
                job.error_message = _ ("The SteamTinkerLaunch archive is invalid or incomplete");
                return yield archive_support.complete_attempt (ReturnCode.INVALID_DATA, archive, true);
            }
            if (!yield archive_support.publish_archive (archive))
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            var preparation = yield prepare_executable (staged_binary);
            if (!command_succeeded (preparation)) {
                report_command_failure ("prepare executable", preparation);
                job.error_message = _ ("Failed to prepare the SteamTinkerLaunch executable");
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }

            var previous_registration_removed = false;
            if (yield system_installation_available ()) {
                var unregister_previous = yield run_command ("steamtinkerlaunch compat del");
                if (!command_succeeded (unregister_previous)) {
                    report_command_failure ("unregister previous compatibility tool", unregister_previous);
                    job.error_message = _ ("Failed to update SteamTinkerLaunch compatibility registration");
                    yield restore_previous_registration (true);
                    return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
                }
                previous_registration_removed = true;
            }

            Gee.ArrayList<SteamTinkerLaunchDirectoryBackup> external_backups;
            if (!yield backup_external_installations (context, archive, out external_backups)) {
                job.error_message = _ ("Moving failed");
                yield rollback_transaction (
                    context, "", external_backups, false, false, previous_registration_removed
                );
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }

            var previous = "";
            if (exists) {
                previous = Path.build_filename (
                    parent, ".protonplus-stl-previous-%s".printf (Path.get_basename (archive.staging_root))
                );
                if (!yield Utils.Filesystem.move_directory_atomic (context.base_location, previous)) {
                    yield rollback_transaction (
                        context, previous, external_backups, false, false, previous_registration_removed
                    );
                    return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
                }
            }
            job.step = InstallJob.Step.MOVING;
            if (!yield Utils.Filesystem.move_directory_atomic (staged, context.base_location)) {
                yield rollback_transaction (
                    context, previous, external_backups, false, false, previous_registration_removed
                );
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }
            var link_created = false;
            if (!FileUtils.test (context.link_location, FileTest.EXISTS)) {
                var link_parent_created = yield Utils.Filesystem.create_directory_async (context.link_parent_location);
                if (link_parent_created)
                    link_created = yield Utils.Filesystem.make_symlink (context.link_location, context.binary_location);
                if (!link_created) {
                    yield rollback_transaction (
                        context, previous, external_backups, false, true, previous_registration_removed
                    );
                    return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
                }
            } else if (!FileUtils.test (context.link_location, FileTest.IS_SYMLINK)) {
                yield rollback_transaction (
                    context, previous, external_backups, false, true, previous_registration_removed
                );
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }

            var unregister_replacement = yield execute_steam_tinker_launch (context.binary_location, "compat del");
            if (!command_succeeded (unregister_replacement)) {
                report_command_failure ("unregister replacement compatibility tool", unregister_replacement);
                job.error_message = _ ("Failed to update SteamTinkerLaunch compatibility registration");
                yield rollback_transaction (
                    context, previous, external_backups, link_created, true,
                    previous_registration_removed || exists || external_backups.size > 0
                );
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }
            if (Globals.IS_STEAM_OS) {
                var initialization = yield execute_steam_tinker_launch (context.binary_location, "");
                if (!command_succeeded (initialization)) {
                    report_command_failure ("initialize SteamTinkerLaunch", initialization);
                    job.error_message = _ ("Failed to initialize SteamTinkerLaunch");
                    yield rollback_transaction (
                        context, previous, external_backups, link_created, true,
                        previous_registration_removed || exists || external_backups.size > 0
                    );
                    return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
                }
            }
            var register_replacement = yield execute_steam_tinker_launch (context.binary_location, "compat add");
            if (!command_succeeded (register_replacement)) {
                report_command_failure ("register replacement compatibility tool", register_replacement);
                job.error_message = _ ("Failed to update SteamTinkerLaunch compatibility registration");
                var remove_partial_registration = yield execute_steam_tinker_launch (
                    context.binary_location, "compat del"
                );
                if (!command_succeeded (remove_partial_registration))
                    report_command_failure ("remove a partial replacement registration", remove_partial_registration);
                yield rollback_transaction (
                    context, previous, external_backups, link_created, true,
                    previous_registration_removed || exists || external_backups.size > 0
                );
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }

            if (previous != "" && !yield Utils.Filesystem.delete_directory (previous))
                warning ("Could not remove the previous SteamTinkerLaunch installation: %s", previous);
            foreach (var backup in external_backups) {
                if (FileUtils.test (backup.backup_path, FileTest.EXISTS) &&
                    !yield Utils.Filesystem.delete_directory (backup.backup_path))
                    warning ("Could not remove the previous external SteamTinkerLaunch installation: %s", backup.backup_path);
            }
            return yield archive_support.complete_attempt (ReturnCode.RUNNER_INSTALLED, archive);
        }

        public override async ReturnCode update (InstallJob job, InstallationOperationCoordinator coordinator) {
            job.state = InstallJob.State.BUSY_UPDATING;
            var code = yield coordinator.install_for_update (job);
            job.finish_operation ();
            if (code != ReturnCode.RUNNER_INSTALLED)
                return code;
            var lifecycle = coordinator as InstallationLifecycleRecorder;
            if (lifecycle != null)
                lifecycle.record_completed_update (job);
            return ReturnCode.RUNNER_UPDATED;
        }

        public override async ReturnCode remove (InstallJob job) {
            var context = get_context (job);
            if (context == null)
                return ReturnCode.INVALID_CONFIGURATION;
            if (FileUtils.test (context.binary_location, FileTest.IS_REGULAR)) {
                var unregister = yield execute_steam_tinker_launch (context.binary_location, "compat del");
                if (!command_succeeded (unregister)) {
                    report_command_failure ("unregister compatibility tool before removal", unregister);
                    job.error_message = _ ("Failed to update SteamTinkerLaunch compatibility registration");
                    var restore_registration = yield execute_steam_tinker_launch (
                        context.binary_location, "compat add"
                    );
                    if (!command_succeeded (restore_registration))
                        report_command_failure ("compensate a failed compatibility removal", restore_registration);
                    return ReturnCode.FILESYSTEM_ERROR;
                }
            }
            if (FileUtils.test (context.link_location, FileTest.EXISTS)) {
                if (!FileUtils.test (context.link_location, FileTest.IS_SYMLINK) ||
                    !Utils.Filesystem.delete_file (context.link_location))
                    return ReturnCode.FILESYSTEM_ERROR;
            }
            var remove_location = context.user_requested_removal
                ? context.manual_remove_location : context.base_location;
            if (FileUtils.test (remove_location, FileTest.EXISTS)) {
                if (!FileUtils.test (remove_location, FileTest.IS_DIR) ||
                    !yield Utils.Filesystem.delete_directory (remove_location))
                    return ReturnCode.FILESYSTEM_ERROR;
            }
            if (context.remove_config && FileUtils.test (context.config_location, FileTest.EXISTS)) {
                if (!FileUtils.test (context.config_location, FileTest.IS_DIR) ||
                    !yield Utils.Filesystem.delete_directory (context.config_location))
                    return ReturnCode.FILESYSTEM_ERROR;
            }
            return ReturnCode.RUNNER_REMOVED;
        }

        public override void refresh_state (InstallJob job) {
            var context = get_context (job);
            if (context == null) {
                job.state = InstallJob.State.NOT_INSTALLED;
                return;
            }
            var installed = FileUtils.test (context.base_location, FileTest.IS_DIR)
                && FileUtils.test (context.binary_location, FileTest.IS_EXECUTABLE)
                && FileUtils.test (context.meta_location, FileTest.IS_REGULAR);
            var updated = false;
            context.local_date = "";
            context.local_hash = "";

            if (installed) {
                var parts = Utils.Filesystem.get_file_content (context.meta_location).strip ().split (":");
                if (parts.length >= 2) {
                    context.local_date = parts[0];
                    context.local_hash = parts[1];
                    if (context.local_date == "" || context.local_hash == "")
                        context.local_date = context.local_hash = "";
                }
                if (context.local_hash == "")
                    installed = false;
                else if (context.latest_hash != "")
                    updated = context.latest_hash == context.local_hash;
            }
            job.state = !installed ? InstallJob.State.NOT_INSTALLED
                : updated ? InstallJob.State.UP_TO_DATE : InstallJob.State.UPDATE_AVAILABLE;
            job.step = InstallJob.Step.NOTHING;
        }

        public override void finalize_install_success (InstallJob job) {
            var context = get_context (job);
            if (context == null)
                return;
            job.tool.group.launcher.register_compatibility_tool_from_path (
                "%s/SteamTinkerLaunch".printf (context.compat_location)
            );
        }

        public override void finalize_removal_success (InstallJob job) {
            var context = get_context (job);
            if (context == null)
                return;
            job.tool.group.launcher.unregister_compatibility_tool_by_path (
                "%s/SteamTinkerLaunch".printf (context.compat_location)
            );
        }

        public bool detect_external_installations (InstallJob job) {
            var context = get_context (job);
            if (context == null)
                return false;
            context.external_locations = new List<string> ();
            var location = "%s/SteamTinkerLaunch".printf (context.home_location);
            if (FileUtils.test (location, FileTest.IS_DIR))
                context.external_locations.append (location);
            location = context.home_location + "/stl";
            if (!Globals.IS_STEAM_OS && FileUtils.test (location, FileTest.IS_DIR))
                context.external_locations.append (location);
            return context.external_locations.length () > 0;
        }

        public async void refresh_latest_release (InstallJob job) {
            var context = get_context (job);
            if (context == null)
                return;
            context.latest_date = "";
            context.latest_hash = "";
            var response = yield Utils.Web.get_request (
                "https://api.github.com/repos/sonic2kk/steamtinkerlaunch/commits?per_page=1",
                Utils.Web.GetRequestType.STEAMTINKERLAUNCH
            );
            if (response.code != ReturnCode.VALID_REQUEST)
                return;
            var node = Utils.Parser.get_node_from_json (response.body);
            if (node == null || node.get_node_type () != Json.NodeType.ARRAY || node.get_array ().get_length () < 1)
                return;
            var commit = node.get_array ().get_element (0);
            if (commit.get_node_type () != Json.NodeType.OBJECT)
                return;
            var commit_obj = commit.get_object ();
            var metadata_node = commit_obj.get_member ("commit");
            if (metadata_node == null || metadata_node.get_node_type () != Json.NodeType.OBJECT)
                return;
            var committer_node = metadata_node.get_object ().get_member ("committer");
            if (committer_node == null || committer_node.get_node_type () != Json.NodeType.OBJECT)
                return;
            var date = committer_node.get_object ().get_string_member_with_default ("date", "").split ("T");
            if (date.length > 0)
                context.latest_date = date[0];
            context.latest_hash = commit_obj.get_string_member_with_default ("sha", "");
            if (context.latest_hash == "")
                return;
            var url = "https://github.com/sonic2kk/steamtinkerlaunch/archive/%s.zip".printf (context.latest_hash);
            job.set_release_for_update (new Models.Release (
                job.release.title, job.release.description, context.latest_date,
                Models.Assets.Asset.from_download_url (url), job.release.page_url, 0,
                context.latest_hash, context.latest_hash, Models.Release.Kind.STEAM_TINKER_LAUNCH
            ));
            refresh_state (job);
        }

        private SteamTinkerLaunchContext? get_context (InstallJob job) {
            return job.steam_tinker_launch_context;
        }

        protected virtual async Utils.CommandResult run_command (string command) {
            return yield Utils.System.run_command (command);
        }

        protected virtual async bool system_installation_available () {
            return yield Utils.System.check_dependency ("steamtinkerlaunch");
        }

        private bool command_succeeded (Utils.CommandResult result) {
            return result.exit_status == 0;
        }

        private void report_command_failure (string operation, Utils.CommandResult result) {
            var diagnostic = result.stderr.strip ();
            warning (
                "SteamTinkerLaunch command failed while attempting to %s (exit status %d)%s%s",
                operation, result.exit_status, diagnostic == "" ? "" : ": ", diagnostic
            );
        }

        private async Utils.CommandResult prepare_executable (string executable) {
            if (!FileUtils.test (executable, FileTest.IS_REGULAR))
                return new Utils.CommandResult ("", "The executable is missing or is not a regular file.", -1);
            if (FileUtils.test (executable, FileTest.IS_EXECUTABLE))
                return new Utils.CommandResult ("", "", 0);

            var result = yield run_command ("chmod +x %s".printf (Shell.quote (executable)));
            if (!command_succeeded (result) || FileUtils.test (executable, FileTest.IS_EXECUTABLE))
                return result;
            return new Utils.CommandResult (result.stdout, "The executable permission was not applied.", -1);
        }

        private async bool backup_external_installations (
            SteamTinkerLaunchContext context,
            ArchiveOperation archive,
            out Gee.ArrayList<SteamTinkerLaunchDirectoryBackup> backups
        ) {
            backups = new Gee.ArrayList<SteamTinkerLaunchDirectoryBackup> ();
            var seen = new Gee.HashSet<string> ();
            var transaction_id = Path.get_basename (archive.staging_root);
            foreach (var location in context.external_locations) {
                var canonical = Filename.canonicalize (location, null);
                if (!seen.add (canonical) || canonical == Filename.canonicalize (context.base_location, null) ||
                    !FileUtils.test (location, FileTest.EXISTS))
                    continue;
                var backup_path = Path.build_filename (
                    Path.get_dirname (location),
                    ".protonplus-stl-external-%s-%s".printf (Path.get_basename (location), transaction_id)
                );
                var backup = new SteamTinkerLaunchDirectoryBackup (location, backup_path);
                if (!yield Utils.Filesystem.move_directory_atomic (location, backup_path))
                    return false;
                backups.add (backup);
            }
            return true;
        }

        private async bool rollback_transaction (
            SteamTinkerLaunchContext context,
            string previous,
            Gee.ArrayList<SteamTinkerLaunchDirectoryBackup> external_backups,
            bool link_created,
            bool installation_promoted,
            bool restore_compatibility_registration
        ) {
            var restored = true;
            if (link_created && FileUtils.test (context.link_location, FileTest.IS_SYMLINK) &&
                !Utils.Filesystem.delete_file (context.link_location)) {
                warning ("Could not remove the failed SteamTinkerLaunch link: %s", context.link_location);
                restored = false;
            }
            if (!yield rollback_installation (context, previous, installation_promoted))
                restored = false;
            for (var index = external_backups.size - 1; index >= 0; index--) {
                var backup = external_backups[index];
                if (!yield restore_directory_backup (backup.original_path, backup.backup_path))
                    restored = false;
            }
            if (restore_compatibility_registration &&
                !yield restore_previous_registration_from_context (context))
                restored = false;
            if (!restored)
                warning ("SteamTinkerLaunch rollback was incomplete; transaction backups were retained where possible.");
            return restored;
        }

        private async bool restore_previous_registration (bool compensate_failed_removal) {
            var result = yield run_command ("steamtinkerlaunch compat add");
            if (command_succeeded (result))
                return true;
            report_command_failure (
                compensate_failed_removal ? "compensate a failed compatibility removal" : "restore previous compatibility registration",
                result
            );
            return false;
        }

        private async bool restore_previous_registration_from_context (SteamTinkerLaunchContext context) {
            Utils.CommandResult result;
            if (FileUtils.test (context.binary_location, FileTest.IS_REGULAR))
                result = yield execute_steam_tinker_launch (context.binary_location, "compat add");
            else
                result = yield run_command ("steamtinkerlaunch compat add");
            if (command_succeeded (result))
                return true;
            report_command_failure ("restore previous compatibility registration", result);
            return false;
        }

        private async bool restore_directory_backup (string original, string backup) {
            if (!FileUtils.test (backup, FileTest.EXISTS))
                return FileUtils.test (original, FileTest.EXISTS);
            if (!FileUtils.test (original, FileTest.EXISTS))
                return yield Utils.Filesystem.move_directory_atomic (backup, original);

            var failed = "%s.failed".printf (backup);
            if (!yield Utils.Filesystem.move_directory_atomic (original, failed))
                return false;
            if (!yield Utils.Filesystem.move_directory_atomic (backup, original)) {
                yield Utils.Filesystem.move_directory_atomic (failed, original);
                return false;
            }
            if (!yield Utils.Filesystem.delete_directory (failed))
                warning ("Could not remove the failed SteamTinkerLaunch directory: %s", failed);
            return true;
        }

        private async bool rollback_installation (
            SteamTinkerLaunchContext context,
            string previous,
            bool installation_promoted
        ) {
            if (!installation_promoted) {
                if (previous == "")
                    return true;
                if (FileUtils.test (context.base_location, FileTest.EXISTS))
                    return !FileUtils.test (previous, FileTest.EXISTS);
                return yield Utils.Filesystem.move_directory_atomic (previous, context.base_location);
            }
            if (previous == "") {
                if (FileUtils.test (context.base_location, FileTest.IS_DIR))
                    return yield Utils.Filesystem.delete_directory (context.base_location);
                return true;
            }
            if (!FileUtils.test (context.base_location, FileTest.EXISTS))
                return yield Utils.Filesystem.move_directory_atomic (previous, context.base_location);
            var failed = "%s.failed".printf (previous);
            if (!yield Utils.Filesystem.move_directory_atomic (context.base_location, failed))
                return false;
            if (!yield Utils.Filesystem.move_directory_atomic (previous, context.base_location)) {
                yield Utils.Filesystem.move_directory_atomic (failed, context.base_location);
                return false;
            }
            if (!yield Utils.Filesystem.delete_directory (failed))
                warning ("Could not remove the failed SteamTinkerLaunch installation: %s", failed);
            return true;
        }

        private async Utils.CommandResult execute_steam_tinker_launch (string executable, string args) {
            var preparation = yield prepare_executable (executable);
            if (!command_succeeded (preparation))
                return preparation;
            var quoted = Shell.quote (executable);
            return yield run_command (args == "" ? quoted : "%s %s".printf (quoted, args));
        }
    }
}
