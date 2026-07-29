namespace ProtonPlus.Services {
    /// Application-level coordinator for install, update, and removal jobs.
    /// Workflow selection and observable lifecycle ownership stay here; the
    /// detailed filesystem transactions live in dedicated workflows.
    public class InstallationService : Object, InstallationOperationCoordinator {
        private static InstallationService? _instance = null;
        public static InstallationService instance {
            get {
                if (_instance == null)
                    _instance = new InstallationService ();
                return _instance;
            }
        }

        private StandardArchiveWorkflow standard_archive_workflow;
        private SteamTinkerLaunchWorkflow steam_tinker_launch_workflow;
        private Gee.HashSet<string> active_removal_locations = new Gee.HashSet<string> ();

        private InstallationService () {
            standard_archive_workflow = new StandardArchiveWorkflow ();
            steam_tinker_launch_workflow = new SteamTinkerLaunchWorkflow ();
        }

        public async ReturnCode install (InstallJob job, bool replace_existing) {
            if (Utils.DownloadManager.instance.is_downloading (job))
                return ReturnCode.OPERATION_IN_PROGRESS;
            return yield start_install (job, replace_existing);
        }

        public async ReturnCode remove (InstallJob job, bool notify_removal) {
            if (Utils.DownloadManager.instance.has_active_installation_at (job.install_location) ||
                !active_removal_locations.add (job.install_location))
                return ReturnCode.OPERATION_IN_PROGRESS;

            var workflow = select_workflow (job);
            var busy = job.state == InstallJob.State.BUSY_UPDATING ||
                job.state == InstallJob.State.BUSY_INSTALLING;
            if (!busy) {
                job.canceled = false;
                job.state = InstallJob.State.BUSY_REMOVING;
            }

            var code = yield workflow.remove (job);
            job.tool.group.invalidate_installed_state ();
            if (!busy)
                job.finish_operation ();
            if (code == ReturnCode.RUNNER_REMOVED) {
                workflow.finalize_removal_success (job);
                if (notify_removal)
                    Utils.DownloadManager.instance.tool_removed (job);
            }
            active_removal_locations.remove (job.install_location);
            return code;
        }

        public async ReturnCode update (InstallJob job) {
            if (Utils.DownloadManager.instance.is_downloading (job))
                return ReturnCode.OPERATION_IN_PROGRESS;
            return yield select_workflow (job).update (job, this);
        }

        // CLI bulk updates retain this service-level entry point while the
        // standard workflow owns the discovery and replacement mechanics.
        public async ReturnCode update_specific_runner (Models.Tools.ProviderTool runner) {
            runner.group.refresh_installed_state ();
            var found = false;
            var updated = false;
            foreach (var entry in runner.group.get_installed_tool_snapshot ()) {
                if (!is_latest_installation (entry, runner))
                    continue;
                found = true;
                var code = yield standard_archive_workflow.update_specific_runner (runner, this, entry.path);
                if (code == ReturnCode.RUNNER_UPDATED)
                    updated = true;
                else if (code != ReturnCode.NOTHING_TO_UPDATE && code != ReturnCode.INCOMPATIBLE_VARIANT)
                    return code;
            }
            if (!found)
                return ReturnCode.RUNNER_NOT_INSTALLED;
            return updated ? ReturnCode.RUNNER_UPDATED : ReturnCode.NOTHING_TO_UPDATE;
        }

        /// Used only by update workflows after they have made their own
        /// version decision.  The shared install lifecycle remains identical
        /// to a user-initiated replacement.
        public async ReturnCode install_for_update (InstallJob job) {
            if (Utils.DownloadManager.instance.is_downloading (job))
                return ReturnCode.OPERATION_IN_PROGRESS;
            return yield start_install (job, true);
        }

        internal void refresh_job_state (InstallJob job) {
            select_workflow (job).refresh_state (job);
        }

        public async void refresh_steam_tinker_launch_release (InstallJob job) {
            var workflow = select_workflow (job) as SteamTinkerLaunchWorkflow;
            if (workflow != null)
                yield workflow.refresh_latest_release (job);
        }

        public bool detect_steam_tinker_launch_external_installations (InstallJob job) {
            var workflow = select_workflow (job) as SteamTinkerLaunchWorkflow;
            return workflow != null && workflow.detect_external_installations (job);
        }

        public async ReturnCode check_for_updates (List<Models.Launcher> launchers) {
            var processes = (yield Utils.System.run_command ("ps -eo args")).stdout.ascii_down ();
            if (has_running_compatibility_process (processes))
                return ReturnCode.RUNNERS_IN_USE;
            var updated = 0;
            var processed_tool_targets = new Gee.HashSet<string> ();
            foreach (var launcher in launchers) {
                foreach (var group in launcher.groups) {
                    group.refresh_installed_state ();
                    var entries = group.get_installed_tool_snapshot ();
                    foreach (var entry in entries) {
                        if (entry.directory_name.has_suffix (" Latest Backup")) {
                            if (!yield Utils.Filesystem.delete_directory (entry.path))
                                return ReturnCode.FILESYSTEM_ERROR;
                        }
                    }
                    foreach (var tool in group.tools) {
                        var runner = tool as Models.Tools.ProviderTool;
                        if (runner == null)
                            continue;
                        var has_latest = false;
                        foreach (var entry in entries) {
                            if (is_latest_installation (entry, runner)) {
                                has_latest = true;
                                break;
                            }
                        }
                        if (!has_latest)
                            continue;
                        if (!processed_tool_targets.add (runner.id))
                            continue;
                        var code = yield update_specific_runner (runner);
                        if (code == ReturnCode.RUNNER_UPDATED)
                            updated++;
                        else if (code != ReturnCode.NOTHING_TO_UPDATE && code != ReturnCode.INCOMPATIBLE_VARIANT)
                            return code;
                    }
                }
            }
            return updated > 0 ? ReturnCode.RUNNERS_UPDATED : ReturnCode.NOTHING_TO_UPDATE;
        }

        private bool has_running_compatibility_process (string processes) {
            try {
                return new Regex ("/(?:proton(?:[-_][^\\s/]*)?|umu(?:[-_][^\\s/]*)?|wine(?:64)?(?:[-_][^\\s/]*)?)(?:\\s|$)|\\.exe(?:\\s|$)")
                    .match (processes);
            } catch (RegexError e) {
                warning (e.message);
                return false;
            }
        }

        private bool is_latest_installation (
            Models.InstalledToolEntry entry,
            Models.Tools.ProviderTool runner
        ) {
            var latest = "%s Latest".printf (runner.title);
            if (entry.directory_name != latest && !entry.directory_name.has_prefix ("%s-".printf (latest)))
                return false;
            if (entry.tool_id != "" && entry.tool_id != runner.id)
                return false;
            if (entry.provider_id != "" && entry.provider_id != runner.provider_id)
                return false;
            return entry.launcher_id == "" || entry.launcher_id == runner.group.launcher.tool_target_id;
        }

        private async ReturnCode start_install (InstallJob job, bool replace_existing) {
            bool missing_explicit_selection;
            var compatibility = resolve_provider_install_variant (job, out missing_explicit_selection);
            if (compatibility != ReturnCode.RUNNER_INSTALLED)
                return compatibility;
            var workflow = select_workflow (job);
            var validation = workflow.validate_install (job, replace_existing);
            if (validation != ReturnCode.RUNNER_INSTALLED)
                return validation;
            return yield execute_install (job, workflow, replace_existing);
        }

        // Provider archives are the only jobs whose assets originate from a
        // release variant.  Resolve them once at this service boundary before
        // an operation, download, cache transaction, or filesystem change can
        // begin; SteamTinkerLaunch retains its independent workflow.
        internal ReturnCode resolve_provider_install_variant (
            InstallJob job,
            out bool missing_explicit_selection
        ) {
            missing_explicit_selection = false;
            if (!(job.tool is Models.Tools.ProviderTool) || job.steam_tinker_launch_context != null)
                return ReturnCode.RUNNER_INSTALLED;

            var resolution = Models.VariantSelector.resolve_installation_variant (
                job.release, job.selected_variant_id, job.selected_variant_name, Globals.CPU_CAPABILITIES
            );
            if (resolution.variant == null) {
                missing_explicit_selection = resolution.has_explicit_selection &&
                    resolution.matching_variant == null;
                return ReturnCode.INCOMPATIBLE_VARIANT;
            }

            job.apply_selected_release_variant ((!) resolution.variant);
            return ReturnCode.RUNNER_INSTALLED;
        }

        private async ReturnCode execute_install (
            InstallJob job,
            InstallationWorkflow workflow,
            bool replace_existing
        ) {
            var updating = job.state == InstallJob.State.BUSY_UPDATING;
            job.begin_operation ();
            if (!updating)
                job.state = InstallJob.State.BUSY_INSTALLING;
            Utils.DownloadManager.instance.add_download (job);

            yield Utils.CacheManager.begin_cache_operation ();
            var code = yield workflow.install (job, replace_existing);
            Utils.CacheManager.end_cache_operation ();
            job.tool.group.invalidate_installed_state ();

            var success = code == ReturnCode.RUNNER_INSTALLED;
            job.is_finished = true;
            job.install_success = success;
            if (success)
                workflow.finalize_install_success (job);
            Utils.DownloadManager.instance.remove_download (job);
            Utils.DownloadManager.instance.add_to_history (job, success);
            if (!updating)
                job.finish_operation ();
            return code;
        }

        // This is the one workflow-selection point.  SteamTinkerLaunch is
        // identified by its composed context, never by provider or widget.
        private InstallationWorkflow select_workflow (InstallJob job) {
            if (job.steam_tinker_launch_context != null)
                return steam_tinker_launch_workflow;
            return standard_archive_workflow;
        }
    }
}
