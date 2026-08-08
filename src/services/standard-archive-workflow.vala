namespace ProtonPlus.Services {
    /// The one archive transaction used by every ordinary compatibility-tool
    /// provider.  Provider source and hosting details remain catalog concerns.
    public class StandardArchiveWorkflow : InstallationWorkflow {
        private ArchiveWorkflowSupport archive_support = new ArchiveWorkflowSupport ();

        public override ReturnCode validate_install (InstallJob job, bool replace_existing) {
            if (FileUtils.test (job.install_location, FileTest.EXISTS) && !replace_existing)
                return ReturnCode.RUNNER_ALREADY_INSTALLED;
            return ReturnCode.RUNNER_INSTALLED;
        }

        public override async ReturnCode install (InstallJob job, bool replace_existing) {
            ArchiveOperation? operation;
            var prepare_code = yield archive_support.prepare_archive (job, ".protonplus-install-", out operation);
            if (prepare_code != ReturnCode.RUNNER_INSTALLED || operation == null)
                return prepare_code;
            var archive = (!) operation;

            job.step = InstallJob.Step.EXTRACTING;
            string? source_path = yield Utils.Filesystem.extract (
                archive.operation_path, "archive", archive.extension, job.get_cancellable ()
            );
            if (source_path == null || source_path == "") {
                if (!job.canceled)
                    job.error_message = _ ("Extraction failed");
                return yield archive_support.complete_attempt (ReturnCode.EXTRACTION_FAILED, archive);
            }
            if (requires_nested_archive (job)) {
                source_path = yield extract_nested_archive (job, source_path, archive.operation_path);
                if (source_path == null || source_path == "") {
                    if (!job.canceled)
                        job.error_message = _ ("Extraction failed");
                    return yield archive_support.complete_attempt (ReturnCode.EXTRACTION_FAILED, archive);
                }
            }

            job.step = InstallJob.Step.MOVING;
            var install_parent = Path.get_dirname (job.install_location);
            if (!yield Utils.Filesystem.create_directory_async (install_parent))
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            archive.staging_root = Utils.Filesystem.create_temporary_directory (install_parent, ".protonplus-stage-");
            if (archive.staging_root == "")
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            var staged_install_path = Path.build_filename (archive.staging_root, "installation");
            if (!yield Utils.Filesystem.move_directory (source_path, staged_install_path)) {
                job.error_message = _ ("Moving failed");
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }
            if (job.mode == InstallJob.Mode.LATEST) {
                var manifest_code = rewrite_compatibility_tool_vdf (job, staged_install_path);
                if (manifest_code != ReturnCode.RUNNER_INSTALLED)
                    return yield archive_support.complete_attempt (manifest_code, archive);
            }
            if (!persist_runner_install_metadata (job, staged_install_path)) {
                job.error_message = _ ("Failed to save compatibility tool metadata");
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }

            if (FileUtils.test (job.install_location, FileTest.EXISTS)) {
                if (!replace_existing)
                    return yield archive_support.complete_attempt (ReturnCode.RUNNER_ALREADY_INSTALLED, archive);
                var backup_path = Path.build_filename (
                    install_parent, ".protonplus-previous-%s".printf (Path.get_basename (archive.staging_root))
                );
                if (!yield Utils.Filesystem.move_directory_atomic (job.install_location, backup_path))
                    return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
                if (!yield job.promote_staged_installation (staged_install_path)) {
                    yield Utils.Filesystem.move_directory_atomic (backup_path, job.install_location);
                    return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
                }
                job.replacement_backup_path = backup_path;
            } else if (!yield job.promote_staged_installation (staged_install_path)) {
                job.error_message = _ ("Moving failed");
                return yield archive_support.complete_attempt (ReturnCode.FILESYSTEM_ERROR, archive);
            }
            return yield archive_support.complete_attempt (ReturnCode.RUNNER_INSTALLED, archive);
        }

        public override async ReturnCode update (InstallJob job, InstallationOperationCoordinator coordinator) {
            if (job.mode != InstallJob.Mode.LATEST)
                return ReturnCode.UNSUPPORTED_OPERATION;
            var runner = job.tool as Models.Tools.ProviderTool;
            if (runner == null || runner.release_catalog == null)
                return ReturnCode.INVALID_CONFIGURATION;
            var lookup = yield runner.release_catalog.fetch_latest_eligible_release ();
            if (!lookup.succeeded)
                return lookup.code;
            if (!lookup.has_release)
                return ReturnCode.NOTHING_TO_UPDATE;
            job.set_release_for_update (lookup.require_release ());
            bool missing_explicit_selection;
            var compatibility = InstallationService.instance.resolve_provider_install_variant (
                job, out missing_explicit_selection
            );
            if (missing_explicit_selection)
                return ReturnCode.INVALID_DATA;
            if (compatibility != ReturnCode.RUNNER_INSTALLED)
                return compatibility;
            return yield update_latest_job (job, coordinator);
        }

        public override async ReturnCode remove (InstallJob job) {
            job.step = InstallJob.Step.REMOVING;
            if (!FileUtils.test (job.install_location, FileTest.IS_DIR))
                return ReturnCode.RUNNER_REMOVED;
            return (yield Utils.Filesystem.delete_directory (job.install_location))
                ? ReturnCode.RUNNER_REMOVED : ReturnCode.FILESYSTEM_ERROR;
        }

        public override void refresh_state (InstallJob job) {
            job.step = InstallJob.Step.NOTHING;
            var provider_tool = job.tool as Models.Tools.ProviderTool;
            var directory_valid = provider_tool != null && job.effective_directory_name_for_state () != "";
            var installed = job.install_location != "" && FileUtils.test (job.install_location, FileTest.IS_DIR);
            if (job.mode == InstallJob.Mode.LATEST && provider_tool != null) {
                var backup = "%s%s/%s Latest Backup".printf (
                    job.tool.group.launcher.directory, job.tool.group.directory, job.tool.title
                );
                installed = installed || FileUtils.test (backup, FileTest.IS_DIR);
            }
            job.state = directory_valid && installed ? InstallJob.State.UP_TO_DATE : InstallJob.State.NOT_INSTALLED;
        }

        public override void finalize_install_success (InstallJob job) {
            job.tool.group.launcher.register_compatibility_tool_from_path (job.install_location);
        }

        public override void finalize_removal_success (InstallJob job) {
            job.tool.group.launcher.unregister_compatibility_tool_by_path (job.install_location);
        }

        public async ReturnCode update_specific_runner (
            Models.Tools.ProviderTool runner,
            InstallationOperationCoordinator coordinator,
            string? installation_location = null
        ) {
            var directory = installation_location ?? "%s%s/%s Latest".printf (
                runner.group.launcher.directory, runner.group.directory, runner.title
            );
            if (!FileUtils.test (directory, FileTest.IS_DIR))
                return ReturnCode.RUNNER_NOT_INSTALLED;
            var metadata = Utils.Metadata.load (directory);
            if (runner.release_catalog == null)
                return ReturnCode.INVALID_CONFIGURATION;
            var lookup = yield runner.release_catalog.fetch_latest_eligible_release ();
            if (!lookup.succeeded) {
                if (runner.archive_install_requirement == Models.Providers.ArchiveInstallRequirement.STANDARD &&
                    metadata.tag != "" && is_request_failure (lookup.code))
                    return ReturnCode.NOTHING_TO_UPDATE;
                return lookup.code;
            }
            if (!lookup.has_release)
                return ReturnCode.NOTHING_TO_UPDATE;
            var job = new InstallJob (
                lookup.require_release (), runner, InstallJob.Mode.LATEST, directory
            );
            var restored_variant = restore_installed_variant (job, metadata.variant_id);
            if (restored_variant != ReturnCode.RUNNER_INSTALLED)
                return restored_variant;
            bool missing_explicit_selection;
            var compatibility = InstallationService.instance.resolve_provider_install_variant (
                job, out missing_explicit_selection
            );
            if (compatibility != ReturnCode.RUNNER_INSTALLED)
                return compatibility;
            return yield update_latest_job (job, coordinator);
        }

        // The older updater moved Latest to this visible backup name before
        // installing.  Restore it only when no primary exists; a coexisting
        // backup remains recovery state until another path proves it obsolete.
        internal async ReturnCode restore_legacy_latest_backup (Models.Tools.ProviderTool runner) {
            var directory = "%s%s/%s Latest".printf (
                runner.group.launcher.directory, runner.group.directory, runner.title
            );
            var backup = "%s Backup".printf (directory);
            if (FileUtils.test (directory, FileTest.EXISTS))
                return ReturnCode.RUNNER_ALREADY_INSTALLED;
            if (!FileUtils.test (backup, FileTest.IS_DIR))
                return ReturnCode.RUNNER_NOT_INSTALLED;
            return (yield Utils.Filesystem.move_directory_atomic (backup, directory))
                ? ReturnCode.RUNNER_INSTALLED : ReturnCode.FILESYSTEM_ERROR;
        }

        public async ReturnCode finalize_replaced_runner (string directory, string backup, bool migrate_prefix) {
            var backup_settings = "%s/user_settings.py".printf (backup);
            if (FileUtils.test (backup_settings, FileTest.IS_REGULAR)) {
                var settings = "%s/user_settings.py".printf (directory);
                var copied = true;
                if (FileUtils.test (backup_settings, FileTest.IS_SYMLINK))
                    copied = Utils.Filesystem.copy_symlink (backup_settings, settings);
                else
                    copied = yield Utils.Filesystem.copy_file_verified (backup_settings, settings);
                if (!copied) {
                    yield rollback_replaced_runner (directory, backup);
                    return ReturnCode.FILESYSTEM_ERROR;
                }
            }
            var backup_prefix = "%s/files/share/default_pfx".printf (backup);
            if (migrate_prefix && FileUtils.test (backup_prefix, FileTest.IS_DIR)) {
                var prefix = "%s/files/share/default_pfx".printf (directory);
                if (FileUtils.test (prefix, FileTest.IS_DIR) && !yield Utils.Filesystem.delete_directory (prefix)) {
                    yield rollback_replaced_runner (directory, backup);
                    return ReturnCode.FILESYSTEM_ERROR;
                }
                if (!yield Utils.Filesystem.copy_directory (backup_prefix, prefix)) {
                    yield rollback_replaced_runner (directory, backup);
                    return ReturnCode.FILESYSTEM_ERROR;
                }
            }
            return (yield Utils.Filesystem.delete_directory (backup))
                ? ReturnCode.RUNNER_UPDATED : ReturnCode.FILESYSTEM_ERROR;
        }

        private async ReturnCode update_latest_job (InstallJob job, InstallationOperationCoordinator coordinator) {
            var runner = job.tool as Models.Tools.ProviderTool;
            if (runner == null || !FileUtils.test (job.install_location, FileTest.IS_DIR)) {
                job.refresh_state ();
                return ReturnCode.RUNNER_NOT_INSTALLED;
            }
            var metadata = Utils.Metadata.load (job.install_location);
            var release = job.release;
            if (release.source_tag != "" && metadata.tag == release.source_tag)
                return ReturnCode.NOTHING_TO_UPDATE;
            var version_path = "%s/version".printf (job.install_location);
            var proton_path = "%s/proton".printf (job.install_location);
            var version_content = FileUtils.test (version_path, FileTest.IS_REGULAR)
                ? Utils.Filesystem.get_file_content (version_path) : "";
            var proton_content = FileUtils.test (proton_path, FileTest.IS_REGULAR)
                ? Utils.Filesystem.get_file_content (proton_path) : "";
            if (version_content != "" && proton_content != "" && release_matches_installed_version (release, version_content, proton_content)) {
                if (!persist_runner_identity (
                    metadata, runner, job.install_location,
                    release.source_tag != "" ? release.source_tag : release.title,
                    release.upstream_release_id
                ))
                    return ReturnCode.FILESYSTEM_ERROR;
                return ReturnCode.NOTHING_TO_UPDATE;
            }
            if (!job.selected_asset.is_archive ())
                return ReturnCode.INVALID_DATA;

            job.state = InstallJob.State.BUSY_UPDATING;
            var install_code = yield coordinator.install_for_update (job);
            if (install_code != ReturnCode.RUNNER_INSTALLED) {
                job.finish_operation ();
                return install_code;
            }
            var backup = job.replacement_backup_path;
            if (backup == null || !FileUtils.test (backup, FileTest.IS_DIR)) {
                job.finish_operation ();
                return ReturnCode.FILESYSTEM_ERROR;
            }
            var migrate_prefix = Globals.SETTINGS != null && Globals.SETTINGS.get_boolean ("migrate-default-prefix");
            var code = yield finalize_replaced_runner (job.install_location, backup, migrate_prefix);
            job.finish_operation ();
            if (code == ReturnCode.RUNNER_UPDATED) {
                var lifecycle = coordinator as InstallationLifecycleRecorder;
                if (lifecycle != null)
                    lifecycle.record_completed_update (job);
            }
            return code;
        }

        private bool requires_nested_archive (InstallJob job) {
            return job.archive_install_requirement == Models.Providers.ArchiveInstallRequirement.NESTED_ARCHIVE;
        }

        private ReturnCode restore_installed_variant (InstallJob job, string variant_id) {
            if (variant_id == "")
                return ReturnCode.RUNNER_INSTALLED;

            foreach (var variant in job.release.variants) {
                if (variant.id != variant_id)
                    continue;
                if (variant.download_url == null || variant.download_url == "") {
                    warning ("Latest release for %s has no download URL for installed variant %s", job.tool.title, variant_id);
                    return ReturnCode.INVALID_DATA;
                }
                job.set_selected_variant (
                    variant.name,
                    Models.Assets.Asset.from_download_url ((!) variant.download_url),
                    variant.id
                );
                return ReturnCode.RUNNER_INSTALLED;
            }

            warning ("Latest release for %s does not contain installed variant %s", job.tool.title, variant_id);
            return ReturnCode.INVALID_DATA;
        }

        private async string? extract_nested_archive (InstallJob job, string source_path, string extract_path) {
            var extension = Utils.ArchiveHelper.get_archive_extension (source_path, true);
            if (extension == null)
                return "";
            var archive_name = Path.get_basename (source_path);
            archive_name = archive_name.substring (0, archive_name.length - extension.length);
            return yield Utils.Filesystem.extract (extract_path, archive_name, extension, job.get_cancellable ());
        }

        private ReturnCode rewrite_compatibility_tool_vdf (InstallJob job, string staged_install_path) {
            var path = "%s/compatibilitytool.vdf".printf (staged_install_path);
            if (!FileUtils.test (path, FileTest.IS_REGULAR))
                return ReturnCode.RUNNER_INSTALLED;
            var content = Utils.Filesystem.get_file_content (path);
            if (content == "")
                return manifest_failure (job, path, "manifest is empty or unreadable");
            var document = Utils.VDF.VdfParser.parse_document (content);
            if (document == null)
                return manifest_failure (job, path, "manifest is not valid text VDF");
            var compat_tools = find_compat_tools (document);
            if (compat_tools == null || compat_tools.children.size != 1)
                return manifest_failure (job, path, "expected exactly one compat_tools entry");
            var tool = compat_tools.children.get (0);
            if (tool.key == "" || tool.key_start < 0 || tool.key_end < tool.key_start)
                return manifest_failure (job, path, "compatibility tool name is missing or invalid");
            content = document.replace_key (tool, job.title);
            document = Utils.VDF.VdfParser.parse_document (content);
            if (document == null)
                return manifest_failure (job, path, "renamed manifest is not valid text VDF");
            compat_tools = find_compat_tools (document);
            if (compat_tools == null || compat_tools.children.size != 1)
                return manifest_failure (job, path, "renamed manifest lost its compat_tools entry");
            tool = compat_tools.children.get (0);
            var display_name = tool.get_child ("display_name");
            if (display_name == null || display_name.value == null ||
                display_name.value_start < 0 || display_name.value_end < display_name.value_start)
                return manifest_failure (job, path, "display_name is missing or invalid");
            content = document.replace_value (display_name, job.title);
            if (!Utils.Filesystem.modify_file (path, content)) {
                warning ("Could not rewrite Latest compatibility manifest for %s at %s: file write failed", job.title, path);
                job.error_message = _ ("Failed to update compatibilitytool.vdf");
                return ReturnCode.FILESYSTEM_ERROR;
            }
            return ReturnCode.RUNNER_INSTALLED;
        }

        private Utils.VDF.VdfEntry? find_compat_tools (Utils.VDF.VdfDocument document) {
            var compat_tools = document.root.get_child ("compat_tools");
            if (compat_tools != null)
                return compat_tools;

            var compatibility_tools = document.root.get_child ("compatibilitytools");
            return compatibility_tools?.get_child ("compat_tools");
        }

        private ReturnCode manifest_failure (InstallJob job, string path, string reason) {
            warning ("Could not rewrite Latest compatibility manifest for %s at %s: %s", job.title, path, reason);
            job.error_message = _ ("The compatibility tool manifest is invalid or incomplete");
            return ReturnCode.INVALID_DATA;
        }

        private bool persist_runner_install_metadata (InstallJob job, string path) {
            var runner = job.tool as Models.Tools.ProviderTool;
            if (runner == null)
                return false;
            var metadata = Utils.Metadata.load (path);
            metadata.runner_endpoint = runner.endpoint;
            metadata.runner_title = runner.title;
            metadata.tag = job.release.source_tag != "" ? job.release.source_tag : job.release.title;
            metadata.provider_id = runner.provider_id;
            metadata.tool_id = runner.id;
            metadata.launcher_id = runner.group.launcher.tool_target_id;
            metadata.variant_id = job.selected_variant_identity ();
            metadata.release_id = job.release.upstream_release_id;
            return metadata.save (path);
        }

        private async bool rollback_replaced_runner (string directory, string backup) {
            var failed = "%s.failed".printf (backup);
            if (!yield Utils.Filesystem.move_directory_atomic (directory, failed))
                return false;
            if (!yield Utils.Filesystem.move_directory_atomic (backup, directory)) {
                yield Utils.Filesystem.move_directory_atomic (failed, directory);
                return false;
            }
            return yield Utils.Filesystem.delete_directory (failed);
        }

        private bool release_matches_installed_version (Models.Release release, string version_content, string proton_content) {
            var parts = version_content.split (" ");
            if (parts.length < 2)
                return false;
            var version_title = parts[1].strip ();
            var start_word = "CURRENT_PREFIX_VERSION=\"";
            var start = proton_content.index_of (start_word, 0);
            if (start == -1)
                return false;
            start += start_word.length;
            var end = proton_content.index_of ("\"", start);
            if (end == -1)
                return false;
            var proton_title = proton_content.substring (start, end - start);
            var title = release.source_tag != "" ? release.source_tag : release.title;
            return title == version_title || title == proton_title;
        }

        private bool persist_runner_identity (
            Utils.Metadata metadata,
            Models.Tools.ProviderTool runner,
            string directory,
            string tag,
            string release_id
        ) {
            metadata.runner_endpoint = runner.endpoint;
            metadata.runner_title = runner.title;
            metadata.provider_id = runner.provider_id;
            metadata.tool_id = runner.id;
            metadata.launcher_id = runner.group.launcher.tool_target_id;
            if (tag != "")
                metadata.tag = tag;
            if (release_id != "")
                metadata.release_id = release_id;
            return metadata.save (directory);
        }

        private bool is_request_failure (ReturnCode code) {
            switch (code) {
            case ReturnCode.REQUEST_FAILED:
            case ReturnCode.CONNECTION_ISSUE:
            case ReturnCode.CONNECTION_REFUSED:
            case ReturnCode.CONNECTION_UNKNOWN:
            case ReturnCode.API_LIMIT_REACHED:
            case ReturnCode.INVALID_ACCESS_TOKEN:
            case ReturnCode.TLS_HANDSHAKE_ERROR:
                return true;
            default:
                return false;
            }
        }
    }
}
