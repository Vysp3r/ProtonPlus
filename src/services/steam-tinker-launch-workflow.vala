namespace ProtonPlus.Services {
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
                return yield archive_support.complete_attempt (ReturnCode.EXTRACTION_FAILED, archive);
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
            Utils.Filesystem.create_file (
                Path.build_filename (staged, "ProtonPlus.meta"),
                "%s:%s".printf (context.latest_date, context.latest_hash)
            );
            foreach (var location in context.external_locations) {
                if (!yield Utils.Filesystem.delete_directory (location))
                    return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }

            var previous = "";
            if (exists) {
                previous = Path.build_filename (
                    parent, ".protonplus-stl-previous-%s".printf (Path.get_basename (archive.staging_root))
                );
                if (!yield Utils.Filesystem.move_directory_atomic (context.base_location, previous))
                    return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }
            job.step = InstallJob.Step.MOVING;
            if (!yield Utils.Filesystem.move_directory_atomic (staged, context.base_location)) {
                if (previous != "")
                    yield Utils.Filesystem.move_directory_atomic (previous, context.base_location);
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }
            if (!FileUtils.test (context.link_location, FileTest.EXISTS)) {
                var link_parent_created = yield Utils.Filesystem.create_directory_async (context.link_parent_location);
                var link_created = false;
                if (link_parent_created)
                    link_created = yield Utils.Filesystem.make_symlink (context.link_location, context.binary_location);
                if (!link_created) {
                    yield rollback_installation (context, previous);
                    return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
                }
            } else if (!FileUtils.test (context.link_location, FileTest.IS_SYMLINK)) {
                yield rollback_installation (context, previous);
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }
            if (yield Utils.System.check_dependency ("steamtinkerlaunch"))
                yield Utils.System.run_command ("steamtinkerlaunch compat del");
            yield execute_steam_tinker_launch (context.binary_location, "compat del");
            if (Globals.IS_STEAM_OS)
                yield execute_steam_tinker_launch (context.binary_location, "");
            yield execute_steam_tinker_launch (context.binary_location, "compat add");
            if (previous != "" && !yield Utils.Filesystem.delete_directory (previous))
                warning ("Could not remove the previous SteamTinkerLaunch installation: %s", previous);
            return yield archive_support.complete_attempt (ReturnCode.RUNNER_INSTALLED, archive);
        }

        public override async ReturnCode update (InstallJob job, InstallationOperationCoordinator coordinator) {
            job.state = InstallJob.State.BUSY_UPDATING;
            var code = yield coordinator.install_for_update (job);
            job.finish_operation ();
            return code == ReturnCode.RUNNER_INSTALLED ? ReturnCode.RUNNER_UPDATED : code;
        }

        public override async ReturnCode remove (InstallJob job) {
            var context = get_context (job);
            if (context == null)
                return ReturnCode.INVALID_CONFIGURATION;
            yield execute_steam_tinker_launch (context.binary_location, "compat del");
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
            location = Environment.get_home_dir () + "/stl";
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

        private async void rollback_installation (SteamTinkerLaunchContext context, string previous) {
            if (previous == "") {
                if (FileUtils.test (context.base_location, FileTest.IS_DIR))
                    yield Utils.Filesystem.delete_directory (context.base_location);
                return;
            }
            var failed = "%s.failed".printf (previous);
            if (!yield Utils.Filesystem.move_directory_atomic (context.base_location, failed))
                return;
            if (!yield Utils.Filesystem.move_directory_atomic (previous, context.base_location)) {
                yield Utils.Filesystem.move_directory_atomic (failed, context.base_location);
                return;
            }
            yield Utils.Filesystem.delete_directory (failed);
        }

        private async void execute_steam_tinker_launch (string executable, string args) {
            if (!FileUtils.test (executable, FileTest.IS_REGULAR))
                return;
            var quoted = Shell.quote (executable);
            if (!FileUtils.test (executable, FileTest.IS_EXECUTABLE))
                yield Utils.System.run_command ("chmod +x %s".printf (quoted));
            yield Utils.System.run_command ("%s %s".printf (quoted, args));
        }
    }
}
