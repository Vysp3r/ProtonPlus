namespace ProtonPlus.Services {
    /// Application-level coordinator for install, update, and removal jobs.
    /// Workflow selection and observable lifecycle ownership stay here; the
    /// detailed filesystem transactions live in dedicated workflows.
    public class InstallationService : Object, InstallationOperationCoordinator, InstallationLifecycleRecorder {
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
        private TinkerGameWorkflow tinker_game_workflow = new TinkerGameWorkflow ();

        public void configure_tinker_game_workflow (TinkerGameWorkflow workflow) {
            tinker_game_workflow = workflow;
        }
        private Gee.HashMap<string, InstallJob> active_operations = new Gee.HashMap<string, InstallJob> ();
        private Gee.HashSet<InstallJob> update_operations = new Gee.HashSet<InstallJob> ();
        private CompatibilityProcessGuard compatibility_process_guard = new CompatibilityProcessGuard ();
        private SteamChangeRecorder? steam_change_recorder = null;

        public signal void steam_restart_recording_failed (InstallJob job, string message);

        private InstallationService () {
            standard_archive_workflow = new StandardArchiveWorkflow ();
            steam_tinker_launch_workflow = new SteamTinkerLaunchWorkflow ();
        }

        private string operation_target (string path) {
            var canonical = Filename.canonicalize (path, null);
            var parent = Path.get_dirname (canonical);
            return Path.build_filename (Posix.realpath (parent) ?? parent, Path.get_basename (canonical));
        }

        private bool reserve_operation (InstallJob job) {
            var key = operation_target (job.install_location);
            if (active_operations.has_key (key) || Utils.DownloadManager.instance.has_active_installation_at (job.install_location))
                return false;
            active_operations.set (key, job);
            return true;
        }

        private void release_operation (InstallJob job, string key) {
            assert (active_operations.get (key) == job);
            var keys = new Gee.ArrayList<string> ();
            foreach (var entry in active_operations.entries)
                if (entry.value == job)
                    keys.add (entry.key);
            foreach (var owned_key in keys)
                active_operations.unset (owned_key);
        }

        private bool reserve_resolved_target (InstallJob job) {
            var key = operation_target (job.install_location);
            var owner = active_operations.get (key);
            if (owner != null)
                return owner == job;
            if (Utils.DownloadManager.instance.has_active_installation_at (job.install_location))
                return false;
            // Variant resolution may refine the destination. Retain both keys
            // until the outer operation, including rollback, has completed.
            active_operations.set (key, job);
            return true;
        }

        public async ReturnCode install (InstallJob job, bool replace_existing) {
            if (!reserve_operation (job))
                return ReturnCode.OPERATION_IN_PROGRESS;
            var key = operation_target (job.install_location);
            job.begin_operation ();
            try {
                return yield start_install (job, replace_existing, true);
            } finally {
                job.finish_operation ();
                release_operation (job, key);
            }
        }

        /* The singleton is configured by the process composition root.  Test
         * callers can replace either dependency and then reset it explicitly. */
        public void configure_steam_change_recorder (SteamChangeRecorder? recorder) {
            steam_change_recorder = recorder;
        }

        public void configure_compatibility_process_guard (CompatibilityProcessGuard? guard) {
            compatibility_process_guard = guard ?? new CompatibilityProcessGuard ();
        }

        public void reset_lifecycle_configuration () {
            steam_change_recorder = null;
            tinker_game_workflow = new TinkerGameWorkflow ();
            compatibility_process_guard = new CompatibilityProcessGuard ();
        }

        public static void reset_lifecycle_configuration_for_tests () {
            if (_instance != null)
                ((!) _instance).reset_lifecycle_configuration ();
        }

        public async ReturnCode remove (InstallJob job, bool notify_removal) {
            if (!reserve_operation (job))
                return ReturnCode.OPERATION_IN_PROGRESS;
            var key = operation_target (job.install_location);
            job.begin_operation ();
            job.state = InstallJob.State.BUSY_REMOVING;
            try {
                var workflow = select_workflow (job);
                var had_durable_state = has_removable_state (job);
                var operation_context = process_operation_context (
                    job, CompatibilityProcessOperationKind.REMOVAL, had_durable_state
                );
                var inspection = yield compatibility_process_guard.inspect (operation_context);
                var guard_code = process_inspection_return_code (inspection, operation_context);
                if (guard_code != ReturnCode.RUNNER_INSTALLED) {
                    report_process_inspection_result (inspection);
                    return guard_code;
                }
                if (job.canceled)
                    return ReturnCode.EXTRACTION_FAILED;
                var code = yield workflow.remove (job);
                job.tool.group.invalidate_installed_state ();
                if (code == ReturnCode.RUNNER_REMOVED) {
                    workflow.finalize_removal_success (job);
                    if (notify_removal)
                        Utils.DownloadManager.instance.tool_removed (job);
                    if (had_durable_state)
                        record_successful_change (job, removal_change_kind (job));
                }
                return code;
            } finally {
                job.finish_operation ();
                release_operation (job, key);
            }
        }

        public async ReturnCode update (InstallJob job) {
            if (!reserve_operation (job))
                return ReturnCode.OPERATION_IN_PROGRESS;
            var key = operation_target (job.install_location);
            update_operations.add (job);
            job.begin_operation ();
            job.state = InstallJob.State.BUSY_UPDATING;
            try {
                var code = yield select_workflow (job).update (job, this);
                complete_update (job, code);
                return code;
            } finally {
                job.finish_operation ();
                update_operations.remove (job);
                release_operation (job, key);
            }
        }

        // Bulk updates retain this service-level entry point while the
        // standard workflow owns legacy recovery and replacement mechanics.
        public async ReturnCode update_specific_runner (Models.Tools.ProviderTool runner) {
            runner.group.refresh_installed_state ();
            var found = false;
            var updated = false;
            var has_legacy_backup = false;
            foreach (var entry in runner.group.get_installed_tool_snapshot ()) {
                if (is_legacy_latest_backup (entry, runner))
                    has_legacy_backup = true;
                if (!is_latest_installation (entry, runner))
                    continue;
                found = true;
                var code = yield update_provider_at (runner, entry.path);
                if (code == ReturnCode.RUNNER_UPDATED)
                    updated = true;
                else if (code != ReturnCode.NOTHING_TO_UPDATE && code != ReturnCode.INCOMPATIBLE_VARIANT)
                    return code;
            }
            if (!found && has_legacy_backup) {
                var directory = Path.build_filename (runner.group.launcher.get_primary_managed_tool_directory (runner.group),
                    "%s Latest".printf (runner.title));
                return yield update_provider_at (runner, directory, true);
            }
            if (!found)
                return ReturnCode.RUNNER_NOT_INSTALLED;
            return updated ? ReturnCode.RUNNER_UPDATED : ReturnCode.NOTHING_TO_UPDATE;
        }

        private async ReturnCode update_provider_at (Models.Tools.ProviderTool runner, string directory, bool restore_backup = false) {
            var release = new Models.Release (runner.title, "", "", new Models.Assets.Asset ("", ""), "");
            var job = new InstallJob (release, runner, InstallJob.Mode.LATEST, directory);
            if (!reserve_operation (job))
                return ReturnCode.OPERATION_IN_PROGRESS;
            var key = operation_target (job.install_location);
            update_operations.add (job);
            job.begin_operation ();
            job.state = InstallJob.State.BUSY_UPDATING;
            try {
                if (restore_backup) {
                    var code = yield standard_archive_workflow.restore_legacy_latest_backup (runner);
                    if (code != ReturnCode.RUNNER_INSTALLED)
                        return code;
                    runner.group.invalidate_installed_state ();
                }
                var result = yield standard_archive_workflow.update_specific_runner (runner, this, directory, job);
                complete_update (job, result);
                return result;
            } finally {
                job.finish_operation ();
                update_operations.remove (job);
                release_operation (job, key);
            }
        }

        /// Used only by update workflows after they have made their own
        /// version decision.  The shared install lifecycle remains identical
        /// to a user-initiated replacement.
        public async ReturnCode install_for_update (InstallJob job) {
            if (update_operations.contains (job)) {
                if (Utils.DownloadManager.instance.is_downloading (job))
                    return ReturnCode.OPERATION_IN_PROGRESS;
                return yield start_install (job, true, false);
            }
            // Standalone coordinator callers still need a complete reservation.
            if (!reserve_operation (job))
                return ReturnCode.OPERATION_IN_PROGRESS;
            var key = operation_target (job.install_location);
            job.begin_operation ();
            try {
                return yield start_install (job, true, false);
            } finally {
                job.finish_operation ();
                release_operation (job, key);
            }
        }

        private void complete_update (InstallJob job, ReturnCode code) {
            // No-op and lookup failures never registered a download.
            if (!Utils.DownloadManager.instance.active_downloads.contains (job))
                return;
            complete_install (job, select_workflow (job),
                code == ReturnCode.RUNNER_UPDATED ? ReturnCode.RUNNER_INSTALLED : code);
        }

        private void complete_install (InstallJob job, InstallationWorkflow workflow, ReturnCode code) {
            job.tool.group.invalidate_installed_state ();
            var success = code == ReturnCode.RUNNER_INSTALLED;
            job.is_finished = true;
            job.install_success = success;
            if (success)
                workflow.finalize_install_success (job);
            Utils.DownloadManager.instance.remove_download (job);
            if (code != ReturnCode.RUNNERS_IN_USE && code != ReturnCode.PROCESS_INSPECTION_FAILED)
                Utils.DownloadManager.instance.add_to_history (job, success);
        }

        public void record_completed_update (InstallJob job) {
            record_successful_change (job, job.steam_tinker_launch_context != null
                ? Models.SteamChangeKind.STEAMTINKERLAUNCH_CHANGED
                : Models.SteamChangeKind.COMPATIBILITY_TOOL_UPDATED_OR_REPLACED);
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
            var updated = 0;
            var processed_tool_targets = new Gee.HashSet<string> ();
            foreach (var launcher in launchers) {
                foreach (var group in launcher.groups) {
                    group.refresh_installed_state ();
                    foreach (var tool in get_update_candidates (group)) {
                        if (!processed_tool_targets.add (tool.id))
                            continue;
                        var code = yield update_installed_tool (tool);
                        if (code == ReturnCode.RUNNER_UPDATED)
                            updated++;
                        else if (code != ReturnCode.NOTHING_TO_UPDATE && code != ReturnCode.INCOMPATIBLE_VARIANT)
                            return code;
                    }
                }
            }
            return updated > 0 ? ReturnCode.RUNNERS_UPDATED : ReturnCode.NOTHING_TO_UPDATE;
        }

        // Shared by GUI and CLI bulk updates; inventory is refreshed by the caller.
        public Gee.List<Models.Tool> get_update_candidates (Models.Group group) {
            var candidates = new Gee.ArrayList<Models.Tool> ();
            var entries = group.get_installed_tool_snapshot ();
            foreach (var tool in group.tools) {
                if (tool is Models.Tools.TinkerGame && tool.is_installed ()) {
                    candidates.add (tool);
                    continue;
                }
                var runner = tool as Models.Tools.ProviderTool;
                if (runner == null)
                    continue;
                foreach (var entry in entries) {
                    if (is_latest_installation (entry, runner) || is_legacy_latest_backup (entry, runner)) {
                        candidates.add (runner);
                        break;
                    }
                }
            }
            return candidates;
        }

        public async ReturnCode update_installed_tool (Models.Tool tool) {
            var runner = tool as Models.Tools.ProviderTool;
            if (runner != null)
                return yield update_specific_runner (runner);
            if (tool is Models.Tools.TinkerGame) {
                // The workflow discovers the latest release and verifies local ownership.
                var release = new Models.Release (tool.title, "", "", new Models.Assets.Asset ("", ""),
                    "", 0, "", "", Models.Release.Kind.TINKER_GAME);
                return yield new InstallJob (release, tool).update ();
            }
            return ReturnCode.UNSUPPORTED_OPERATION;
        }

        private bool is_latest_installation (
            Models.InstalledToolEntry entry,
            Models.Tools.ProviderTool runner
        ) {
            var latest = "%s Latest".printf (runner.title);
            if (entry.directory_name != latest && !entry.directory_name.has_prefix ("%s-".printf (latest)))
                return false;
            return installation_identity_matches_runner (entry, runner);
        }

        private bool is_legacy_latest_backup (
            Models.InstalledToolEntry entry,
            Models.Tools.ProviderTool runner
        ) {
            if (entry.directory_name != "%s Latest Backup".printf (runner.title))
                return false;
            return installation_identity_matches_runner (entry, runner);
        }

        private bool installation_identity_matches_runner (
            Models.InstalledToolEntry entry,
            Models.Tools.ProviderTool runner
        ) {
            if (entry.tool_id != "" && entry.tool_id != runner.id)
                return false;
            if (entry.provider_id != "" && entry.provider_id != runner.provider_id)
                return false;
            return entry.launcher_id == "" || entry.launcher_id == runner.group.launcher.tool_target_id;
        }

        private async ReturnCode start_install (InstallJob job, bool replace_existing, bool record_change) {
            bool missing_explicit_selection;
            var compatibility = resolve_provider_install_variant (job, out missing_explicit_selection);
            if (compatibility != ReturnCode.RUNNER_INSTALLED)
                return compatibility;
            if (!reserve_resolved_target (job))
                return ReturnCode.OPERATION_IN_PROGRESS;
            var workflow = select_workflow (job);
            var validation = workflow.validate_install (job, replace_existing);
            if (validation != ReturnCode.RUNNER_INSTALLED)
                return validation;
            return yield execute_install (job, workflow, replace_existing, record_change);
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

            var provider_tool = (Models.Tools.ProviderTool) job.tool;
            if (!configured_variant_is_compatible (
                    provider_tool, (!) resolution.variant, Globals.CPU_CAPABILITIES))
                return ReturnCode.INCOMPATIBLE_VARIANT;

            job.apply_selected_release_variant ((!) resolution.variant);
            return ReturnCode.RUNNER_INSTALLED;
        }

        private bool configured_variant_is_compatible (
            Models.Tools.ProviderTool tool,
            Models.Variant release_variant,
            Models.CpuCapabilities capabilities
        ) {
            Models.Variant? matching_name = null;
            foreach (var configured_variant in tool.variants) {
                if (configured_variant.id == release_variant.id)
                    return configured_variant.is_compatible_with (capabilities);
                if (matching_name == null && configured_variant.name == release_variant.name)
                    matching_name = configured_variant;
            }
            return matching_name == null || ((!) matching_name).is_compatible_with (capabilities);
        }

        private async ReturnCode execute_install (
            InstallJob job,
            InstallationWorkflow workflow,
            bool replace_existing,
            bool record_change
        ) {
            var operation_kind = updating_operation_kind (job, replace_existing);
            var operation_context = process_operation_context (
                job, operation_kind, mutates_existing_destination (job, workflow, replace_existing)
            );
            var inspection = yield compatibility_process_guard.inspect (operation_context);
            var guard_code = process_inspection_return_code (inspection, operation_context);
            if (guard_code != ReturnCode.RUNNER_INSTALLED) {
                report_process_inspection_result (inspection);
                return guard_code;
            }
            if (job.canceled)
                return ReturnCode.EXTRACTION_FAILED;
            var updating = update_operations.contains (job);
            if (!updating)
                job.state = InstallJob.State.BUSY_INSTALLING;
            Utils.DownloadManager.instance.add_download (job);

            var code = ReturnCode.FILESYSTEM_ERROR;
            Utils.CacheManager.Operation? cache_operation = null;
            try {
                cache_operation = yield Utils.CacheManager.begin_cache_operation (job.get_cancellable ());
                code = yield workflow.install (job, replace_existing);
            } catch (Error e) {
                job.error_message = e.message;
                if (e is IOError.CANCELLED)
                    code = ReturnCode.EXTRACTION_FAILED;
            } finally {
                if (cache_operation != null)
                    cache_operation.release ();
            }
            yield Utils.PartialDownloadCache.prune (Globals.CACHE_PATH);
            // The outer update owns completion through settings migration,
            // backup cleanup and rollback. Keep the job active until then.
            if (updating)
                return code;
            complete_install (job, workflow, code);
            job.finish_operation ();
            var success = code == ReturnCode.RUNNER_INSTALLED;
            if (success && record_change) {
                record_successful_change (job, job.steam_tinker_launch_context != null
                    ? Models.SteamChangeKind.STEAMTINKERLAUNCH_CHANGED
                    : replace_existing ? Models.SteamChangeKind.COMPATIBILITY_TOOL_UPDATED_OR_REPLACED
                    : Models.SteamChangeKind.COMPATIBILITY_TOOL_INSTALLED);
            }
            return code;
        }

        internal async ReturnCode check_final_process_state (
            InstallJob job,
            CompatibilityProcessOperationKind operation_kind,
            bool mutates_existing_destination
        ) {
            /* This closes the long download/extract/stage window.  It cannot
             * provide kernel-level locking against a process starting in the
             * final instructions between this snapshot and the mutation. */
            var context = process_operation_context (
                job, operation_kind, mutates_existing_destination
            );
            var inspection = yield compatibility_process_guard.inspect (context);
            var code = process_inspection_return_code (inspection, context);
            if (code != ReturnCode.RUNNER_INSTALLED)
                report_process_inspection_result (inspection);
            return code;
        }

        private ReturnCode process_inspection_return_code (
            CompatibilityProcessInspectionResult inspection,
            CompatibilityProcessOperationContext context
        ) {
            switch (inspection.status) {
            case CompatibilityProcessInspectionStatus.ACTIVE:
                return ReturnCode.RUNNERS_IN_USE;
            case CompatibilityProcessInspectionStatus.UNKNOWN:
                return context.mutates_existing_destination
                    ? ReturnCode.PROCESS_INSPECTION_FAILED : ReturnCode.RUNNER_INSTALLED;
            default:
                return ReturnCode.RUNNER_INSTALLED;
            }
        }

        private bool mutates_existing_destination (
            InstallJob job,
            InstallationWorkflow workflow,
            bool replace_existing
        ) {
            if (workflow != standard_archive_workflow)
                return true;
            return replace_existing && (
                FileUtils.test (job.install_location, FileTest.EXISTS) ||
                FileUtils.test (job.install_location, FileTest.IS_SYMLINK)
            );
        }

        private CompatibilityProcessOperationKind updating_operation_kind (
            InstallJob job,
            bool replace_existing
        ) {
            if (job.state == InstallJob.State.BUSY_UPDATING)
                return CompatibilityProcessOperationKind.UPDATE;
            return replace_existing
                ? CompatibilityProcessOperationKind.REPLACEMENT
                : CompatibilityProcessOperationKind.INSTALL;
        }

        private CompatibilityProcessOperationContext process_operation_context (
            InstallJob job,
            CompatibilityProcessOperationKind operation_kind,
            bool mutates_existing_destination
        ) {
            var launcher = job.tool.group.launcher;
            return new CompatibilityProcessOperationContext (
                operation_kind,
                job.install_location,
                launcher.family_id,
                launcher.instance_id,
                launcher.tool_target_family_id,
                launcher.tool_target_id,
                mutates_existing_destination
            );
        }

        private void report_process_inspection_result (
            CompatibilityProcessInspectionResult inspection,
            bool continuing = false
        ) {
            if (inspection.status == CompatibilityProcessInspectionStatus.ACTIVE &&
                inspection.blocker != null) {
                var blocker = (!) inspection.blocker;
                debug (
                    "Compatibility process %d blocks this operation: %s",
                    blocker.pid, "%s (%s)".printf (
                        blocker.executable_path,
                        inspection.blocker_reason.to_string ()
                    )
                );
                return;
            }
            if (inspection.status == CompatibilityProcessInspectionStatus.UNKNOWN) {
                debug (
                    "%s process inspection failure: %s",
                    continuing ? "Ignoring for a new destination" : "Blocking on",
                    inspection.inspection_error ?? "unknown error"
                );
            }
        }

        private bool has_removable_state (InstallJob job) {
            if (job.steam_tinker_launch_context == null)
                return FileUtils.test (job.install_location, FileTest.EXISTS);
            var context = (!) job.steam_tinker_launch_context;
            return FileUtils.test (context.base_location, FileTest.EXISTS)
                || FileUtils.test (context.link_location, FileTest.EXISTS)
                || FileUtils.test (context.config_location, FileTest.EXISTS)
                || FileUtils.test (context.manual_remove_location, FileTest.EXISTS);
        }

        private Models.SteamChangeKind removal_change_kind (InstallJob job) {
            return job.steam_tinker_launch_context != null
                ? Models.SteamChangeKind.STEAMTINKERLAUNCH_CHANGED
                : Models.SteamChangeKind.COMPATIBILITY_TOOL_REMOVED;
        }

        private void record_successful_change (InstallJob job, Models.SteamChangeKind kind) {
            var recorder = steam_change_recorder;
            var target = job.tool.group.launcher.get_steam_restart_target ();
            if (recorder == null || target == null || !job.mark_steam_change_recorded (kind))
                return;
            var resource_key = Filename.canonicalize (job.install_location, null);
            var receipt = new Models.SteamChangeReceipt (
                (!) target, kind, Models.SteamChangeReceipt.default_requirement_for_kind (kind),
                resource_key, job.tool.id, job.displayed_title
            );
            var result = recorder.record (receipt);
            job.has_steam_restart_record_result = true;
            job.steam_restart_record_result = result;
            if (result != SteamRestartRecordResult.PERSISTENCE_FAILED)
                return;
            job.steam_restart_warning = _ ("The compatibility tool changed, but the Steam restart reminder could not be saved.");
            steam_restart_recording_failed (job, (!) job.steam_restart_warning);
        }

        // This is the one workflow-selection point.  SteamTinkerLaunch is
        // identified by its composed context, never by provider or widget.
        private InstallationWorkflow select_workflow (InstallJob job) {
            if (job.tinker_game_context != null)
                return tinker_game_workflow;
            if (job.steam_tinker_launch_context != null)
                return steam_tinker_launch_workflow;
            return standard_archive_workflow;
        }
    }
}
