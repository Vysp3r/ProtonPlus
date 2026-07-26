namespace ProtonPlus.Services {
    /// GTK-free owner of installation transactions.  The code intentionally
    /// preserves the existing staging, atomic-promotion, and rollback shape;
    /// InstallJob supplies the target and observes the result.
    public class InstallationService : Object {
        private static InstallationService? _instance = null;
        public static InstallationService instance {
            get {
                if (_instance == null)
                    _instance = new InstallationService ();
                return _instance;
            }
        }

        private InstallationService () {}

        public async ReturnCode install (InstallJob job, bool replace_existing) {
            if (Utils.DownloadManager.instance.is_downloading (job))
                return ReturnCode.OPERATION_IN_PROGRESS;
            if (job.mode != InstallJob.Mode.STEAM_TINKER_LAUNCH &&
                FileUtils.test (job.install_location, FileTest.EXISTS) && !replace_existing)
                return ReturnCode.RUNNER_ALREADY_INSTALLED;

            var updating = job.state == InstallJob.State.BUSY_UPDATING;
            job.begin_operation ();
            if (!updating)
                job.state = InstallJob.State.BUSY_INSTALLING;
            Utils.DownloadManager.instance.add_download (job);

            yield Utils.CacheManager.begin_cache_operation ();
            var code = job.mode == InstallJob.Mode.STEAM_TINKER_LAUNCH
                ? yield install_steam_tinker_launch (job, replace_existing)
                : yield install_standard (job, replace_existing);
            Utils.CacheManager.end_cache_operation ();
            job.tool.group.invalidate_installed_tool_index ();

            var success = code == ReturnCode.RUNNER_INSTALLED;
            job.is_finished = true;
            job.install_success = success;
            if (success)
                register_installed_tool (job);
            Utils.DownloadManager.instance.remove_download (job);
            Utils.DownloadManager.instance.add_to_history (job, success);
            if (!updating)
                job.finish_operation ();
            return code;
        }

        public async ReturnCode remove (InstallJob job, bool notify_removal) {
            var busy = job.state == InstallJob.State.BUSY_UPDATING || job.state == InstallJob.State.BUSY_INSTALLING;
            if (!busy) {
                job.canceled = false;
                job.state = InstallJob.State.BUSY_REMOVING;
            }

            var code = job.mode == InstallJob.Mode.STEAM_TINKER_LAUNCH
                ? yield remove_steam_tinker_launch (job)
                : yield remove_standard (job);
            job.tool.group.invalidate_installed_tool_index ();
            if (!busy)
                job.finish_operation ();
            if (code == ReturnCode.RUNNER_REMOVED) {
                unregister_installed_tool (job);
                if (notify_removal)
                    Utils.DownloadManager.instance.tool_removed (job);
            }
            return code;
        }

        public async ReturnCode update (InstallJob job) {
            if (Utils.DownloadManager.instance.is_downloading (job))
                return ReturnCode.OPERATION_IN_PROGRESS;
            if (job.mode == InstallJob.Mode.STEAM_TINKER_LAUNCH) {
                job.state = InstallJob.State.BUSY_UPDATING;
                var stl_code = yield install (job, true);
                job.finish_operation ();
                return stl_code == ReturnCode.RUNNER_INSTALLED ? ReturnCode.RUNNER_UPDATED : stl_code;
            }
            if (job.mode != InstallJob.Mode.LATEST)
                return ReturnCode.UNSUPPORTED_OPERATION;
            var runner = job.tool as Models.Tools.Basic;
            if (runner == null)
                return ReturnCode.INVALID_CONFIGURATION;
            ReturnCode lookup_code;
            var latest = yield runner.fetch_latest_eligible_release (out lookup_code);
            if (lookup_code != ReturnCode.RELEASES_LOADED)
                return lookup_code;
            if (latest == null)
                return ReturnCode.NOTHING_TO_UPDATE;
            job.set_release_for_update (latest);
            return yield update_latest_job (job);
        }

        private async ReturnCode install_standard (InstallJob job, bool replace_existing) {
            var extension = Utils.ArchiveHelper.get_archive_extension (job.selected_asset.name, true);
            if (extension == null)
                return ReturnCode.UNSUPPORTED_EXTENSION;

            var archive_cache_path = Path.build_filename (Globals.CACHE_PATH, "archives");
            if (!yield Utils.Filesystem.create_directory_async (archive_cache_path))
                return ReturnCode.FILESYSTEM_ERROR;
            var operation_path = Utils.Filesystem.create_temporary_directory (Globals.CACHE_PATH, ".protonplus-install-");
            if (operation_path == "")
                return ReturnCode.FILESYSTEM_ERROR;
            var staging_root = "";
            var archive_key = Checksum.compute_for_string (ChecksumType.SHA256, job.selected_asset.download_url);
            var cache_archive_path = Path.build_filename (archive_cache_path, "%s%s".printf (archive_key, extension));
            var operation_archive_path = Path.build_filename (operation_path, "archive%s".printf (extension));

            job.step = InstallJob.Step.DOWNLOADING;
            if (!FileUtils.test (cache_archive_path, FileTest.IS_REGULAR)) {
                string? download_error;
                var downloaded = yield job.download_archive (job.selected_asset.download_url, operation_archive_path, out download_error);
                if (!downloaded) {
                    job.error_message = download_error;
                    return yield complete_attempt (ReturnCode.DOWNLOAD_FAILED, operation_path, staging_root);
                }
                var cached = yield Utils.Filesystem.move_file_atomic_if_absent (operation_archive_path, cache_archive_path);
                if (!cached && !FileUtils.test (cache_archive_path, FileTest.IS_REGULAR))
                    return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }

            if (!yield Utils.Filesystem.copy_file (cache_archive_path, operation_archive_path))
                return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            if (job.canceled)
                return yield complete_attempt (ReturnCode.EXTRACTION_FAILED, operation_path, staging_root);

            job.step = InstallJob.Step.EXTRACTING;
            string? source_path = yield Utils.Filesystem.extract (operation_path, "archive", extension, job.get_cancellable ());
            if (source_path == null || source_path == "") {
                if (!job.canceled)
                    job.error_message = _ ("Extraction failed");
                return yield complete_attempt (ReturnCode.EXTRACTION_FAILED, operation_path, staging_root);
            }
            if (requires_nested_archive (job)) {
                source_path = yield extract_nested_archive (job, source_path, operation_path);
                if (source_path == null || source_path == "") {
                    if (!job.canceled)
                        job.error_message = _ ("Extraction failed");
                    return yield complete_attempt (ReturnCode.EXTRACTION_FAILED, operation_path, staging_root);
                }
            }

            job.step = InstallJob.Step.MOVING;
            var install_parent = Path.get_dirname (job.install_location);
            if (!yield Utils.Filesystem.create_directory_async (install_parent))
                return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            staging_root = Utils.Filesystem.create_temporary_directory (install_parent, ".protonplus-stage-");
            if (staging_root == "")
                return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            var staged_install_path = Path.build_filename (staging_root, "installation");
            if (!yield Utils.Filesystem.move_directory (source_path, staged_install_path)) {
                job.error_message = _ ("Moving failed");
                return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }
            if (job.mode == InstallJob.Mode.LATEST && !rewrite_compatibility_tool_vdf (job, staged_install_path))
                return yield complete_attempt (ReturnCode.INVALID_DATA, operation_path, staging_root);
            persist_runner_install_metadata (job, staged_install_path);

            if (FileUtils.test (job.install_location, FileTest.EXISTS)) {
                if (!replace_existing)
                    return yield complete_attempt (ReturnCode.RUNNER_ALREADY_INSTALLED, operation_path, staging_root);
                var backup_path = Path.build_filename (install_parent, ".protonplus-previous-%s".printf (Path.get_basename (staging_root)));
                if (!yield Utils.Filesystem.move_directory_atomic (job.install_location, backup_path))
                    return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
                if (!yield job.promote_staged_installation (staged_install_path)) {
                    yield Utils.Filesystem.move_directory_atomic (backup_path, job.install_location);
                    return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
                }
                job.replacement_backup_path = backup_path;
            } else if (!yield job.promote_staged_installation (staged_install_path)) {
                job.error_message = _ ("Moving failed");
                return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }
            return yield complete_attempt (ReturnCode.RUNNER_INSTALLED, operation_path, staging_root);
        }

        private async ReturnCode complete_attempt (ReturnCode code, string operation_path, string staging_root) {
            if (operation_path != "" && FileUtils.test (operation_path, FileTest.IS_DIR))
                yield Utils.Filesystem.delete_directory (operation_path);
            if (staging_root != "" && FileUtils.test (staging_root, FileTest.IS_DIR))
                yield Utils.Filesystem.delete_directory (staging_root);
            return code;
        }

        private bool requires_nested_archive (InstallJob job) {
            if (job.release.kind == Models.Release.Kind.GITHUB_ACTION)
                return true;
            var runner = job.tool as Models.Tools.Basic;
            var source_runner = runner != null ? runner.source_runner as Models.Launchers.Runners.Base : null;
            return job.mode == InstallJob.Mode.LATEST && source_runner != null &&
                   source_runner.source_type == Models.Launchers.Runners.SourceType.GITHUB_ACTION;
        }

        private async string? extract_nested_archive (InstallJob job, string source_path, string extract_path) {
            var extension = Utils.ArchiveHelper.get_archive_extension (source_path, true);
            if (extension == null)
                return "";
            var archive_name = Path.get_basename (source_path);
            archive_name = archive_name.substring (0, archive_name.length - extension.length);
            return yield Utils.Filesystem.extract (extract_path, archive_name, extension, job.get_cancellable ());
        }

        private bool rewrite_compatibility_tool_vdf (InstallJob job, string staged_install_path) {
            var path = "%s/compatibilitytool.vdf".printf (staged_install_path);
            if (!FileUtils.test (path, FileTest.IS_REGULAR))
                return true;
            var content = Utils.Filesystem.get_file_content (path);
            if (content == "") {
                job.error_message = _ ("Failed to read compatibilitytool.vdf");
                return false;
            }
            var document = Utils.VDF.VdfParser.parse_document (content);
            if (document == null)
                return false;
            var compat_tools = document.root.get_child ("compat_tools");
            if (compat_tools == null || compat_tools.children.size != 1)
                return false;
            var tool = compat_tools.children.get (0);
            if (tool.key == "" || tool.key_start < 0 || tool.key_end < tool.key_start)
                return false;
            content = document.replace_key (tool, job.title);
            document = Utils.VDF.VdfParser.parse_document (content);
            if (document == null)
                return false;
            compat_tools = document.root.get_child ("compat_tools");
            if (compat_tools == null || compat_tools.children.size != 1)
                return false;
            tool = compat_tools.children.get (0);
            var display_name = tool.get_child ("display_name");
            if (display_name == null || display_name.value == null || display_name.value_start < 0 || display_name.value_end < display_name.value_start)
                return false;
            content = document.replace_value (display_name, job.title);
            return Utils.Filesystem.modify_file (path, content);
        }

        private void persist_runner_install_metadata (InstallJob job, string path) {
            var runner = job.tool as Models.Tools.Basic;
            if (runner == null)
                return;
            var metadata = Utils.Metadata.load (path);
            metadata.runner_endpoint = runner.endpoint;
            metadata.runner_title = runner.title;
            metadata.tag = job.release.source_tag != "" ? job.release.source_tag : job.release.title;
            metadata.provider_id = runner.provider_id;
            metadata.tool_id = runner.id;
            metadata.launcher_id = runner.group.launcher.instance_id;
            metadata.variant_id = job.selected_variant_id ();
            metadata.release_id = job.release.upstream_release_id;
            metadata.save (path);
        }

        private async ReturnCode remove_standard (InstallJob job) {
            job.step = InstallJob.Step.REMOVING;
            if (!FileUtils.test (job.install_location, FileTest.IS_DIR))
                return ReturnCode.RUNNER_REMOVED;
            return (yield Utils.Filesystem.delete_directory (job.install_location)) ? ReturnCode.RUNNER_REMOVED : ReturnCode.FILESYSTEM_ERROR;
        }

        private void register_installed_tool (InstallJob job) {
            if (job.mode == InstallJob.Mode.STEAM_TINKER_LAUNCH)
                return;
            var steam = job.tool.group.launcher as Models.Launchers.Steam;
            if (steam != null)
                steam.register_compatibility_tool (new Models.Tools.Simple.from_path (job.install_location));
        }

        private void unregister_installed_tool (InstallJob job) {
            var steam = job.tool.group.launcher as Models.Launchers.Steam;
            if (steam != null)
                steam.unregister_compatibility_tool_by_path (job.install_location);
        }

        public async void refresh_steam_tinker_launch_release (InstallJob job) {
            if (job.mode != InstallJob.Mode.STEAM_TINKER_LAUNCH)
                return;
            job.stl_latest_date = "";
            job.stl_latest_hash = "";
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
                job.stl_latest_date = date[0];
            job.stl_latest_hash = commit_obj.get_string_member_with_default ("sha", "");
            if (job.stl_latest_hash == "")
                return;
            var url = "https://github.com/sonic2kk/steamtinkerlaunch/archive/%s.zip".printf (job.stl_latest_hash);
            job.set_release_for_update (new Models.Release (
                job.release.title, job.release.description, job.stl_latest_date,
                Models.Assets.Asset.from_download_url (url), job.release.page_url, 0,
                job.stl_latest_hash, job.stl_latest_hash, Models.Release.Kind.STEAM_TINKER_LAUNCH
            ));
            job.refresh_state ();
        }

        private async ReturnCode install_steam_tinker_launch (InstallJob job, bool replace_existing) {
            var exists = FileUtils.test (job.stl_base_location, FileTest.EXISTS);
            if (exists && !replace_existing)
                return ReturnCode.RUNNER_ALREADY_INSTALLED;
            var extension = Utils.ArchiveHelper.get_archive_extension (job.selected_asset.name, true);
            if (extension == null)
                return ReturnCode.UNSUPPORTED_EXTENSION;
            var archive_cache_path = Path.build_filename (Globals.CACHE_PATH, "archives");
            if (!yield Utils.Filesystem.create_directory_async (archive_cache_path))
                return ReturnCode.FILESYSTEM_ERROR;
            var operation_path = Utils.Filesystem.create_temporary_directory (Globals.CACHE_PATH, ".protonplus-stl-");
            if (operation_path == "")
                return ReturnCode.FILESYSTEM_ERROR;
            var staging_root = "";
            var key = Checksum.compute_for_string (ChecksumType.SHA256, job.selected_asset.download_url);
            var cached_archive = Path.build_filename (archive_cache_path, "%s%s".printf (key, extension));
            var archive = Path.build_filename (operation_path, "archive%s".printf (extension));
            job.step = InstallJob.Step.DOWNLOADING;
            if (!FileUtils.test (cached_archive, FileTest.IS_REGULAR)) {
                string? download_error;
                if (!yield job.download_archive (job.selected_asset.download_url, archive, out download_error)) {
                    job.error_message = download_error;
                    return yield complete_attempt (ReturnCode.DOWNLOAD_FAILED, operation_path, staging_root);
                }
                var cached = yield Utils.Filesystem.move_file_atomic_if_absent (archive, cached_archive);
                if (!cached && !FileUtils.test (cached_archive, FileTest.IS_REGULAR))
                    return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }
            if (!yield Utils.Filesystem.copy_file (cached_archive, archive))
                return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            if (job.canceled)
                return yield complete_attempt (ReturnCode.EXTRACTION_FAILED, operation_path, staging_root);
            job.step = InstallJob.Step.EXTRACTING;
            var source = yield Utils.Filesystem.extract (operation_path, "archive", extension, job.get_cancellable ());
            if (source == null || source == "") {
                if (!job.canceled)
                    job.error_message = _ ("Extraction failed");
                return yield complete_attempt (ReturnCode.EXTRACTION_FAILED, operation_path, staging_root);
            }
            var parent = Path.get_dirname (job.stl_base_location);
            if (!yield Utils.Filesystem.create_directory_async (parent))
                return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            staging_root = Utils.Filesystem.create_temporary_directory (parent, ".protonplus-stl-stage-");
            if (staging_root == "")
                return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            var staged = Path.build_filename (staging_root, "installation");
            if (!yield Utils.Filesystem.copy_directory (source, staged)) {
                job.error_message = _ ("Moving failed");
                return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }
            Utils.Filesystem.create_file (Path.build_filename (staged, "ProtonPlus.meta"), "%s:%s".printf (job.stl_latest_date, job.stl_latest_hash));
            foreach (var location in job.stl_external_locations) {
                if (!yield Utils.Filesystem.delete_directory (location))
                    return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }
            var previous = "";
            if (exists) {
                previous = Path.build_filename (parent, ".protonplus-stl-previous-%s".printf (Path.get_basename (staging_root)));
                if (!yield Utils.Filesystem.move_directory_atomic (job.stl_base_location, previous))
                    return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }
            job.step = InstallJob.Step.MOVING;
            if (!yield Utils.Filesystem.move_directory_atomic (staged, job.stl_base_location)) {
                if (previous != "")
                    yield Utils.Filesystem.move_directory_atomic (previous, job.stl_base_location);
                return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }
            if (!FileUtils.test (job.stl_link_location, FileTest.EXISTS)) {
                var link_parent_created = yield Utils.Filesystem.create_directory_async (job.stl_link_parent_location);
                var link_created = false;
                if (link_parent_created)
                    link_created = yield Utils.Filesystem.make_symlink (job.stl_link_location, job.stl_binary_location);
                if (!link_created) {
                    yield rollback_steam_tinker_launch (job, previous);
                    return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
                }
            } else if (!FileUtils.test (job.stl_link_location, FileTest.IS_SYMLINK)) {
                yield rollback_steam_tinker_launch (job, previous);
                return yield complete_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }
            if (yield Utils.System.check_dependency ("steamtinkerlaunch"))
                yield Utils.System.run_command ("steamtinkerlaunch compat del");
            yield exec_steam_tinker_launch (job.stl_binary_location, "compat del");
            if (Globals.IS_STEAM_OS)
                yield exec_steam_tinker_launch (job.stl_binary_location, "");
            yield exec_steam_tinker_launch (job.stl_binary_location, "compat add");
            if (previous != "" && !yield Utils.Filesystem.delete_directory (previous))
                warning ("Could not remove the previous SteamTinkerLaunch installation: %s", previous);
            var steam = job.tool.group.launcher as Models.Launchers.Steam;
            if (steam != null)
                steam.register_compatibility_tool (new Models.Tools.Simple.from_path ("%s/SteamTinkerLaunch".printf (job.stl_compat_location)));
            return yield complete_attempt (ReturnCode.RUNNER_INSTALLED, operation_path, staging_root);
        }

        private async void rollback_steam_tinker_launch (InstallJob job, string previous) {
            if (previous == "") {
                if (FileUtils.test (job.stl_base_location, FileTest.IS_DIR))
                    yield Utils.Filesystem.delete_directory (job.stl_base_location);
                return;
            }
            var failed = "%s.failed".printf (previous);
            if (!yield Utils.Filesystem.move_directory_atomic (job.stl_base_location, failed))
                return;
            if (!yield Utils.Filesystem.move_directory_atomic (previous, job.stl_base_location)) {
                yield Utils.Filesystem.move_directory_atomic (failed, job.stl_base_location);
                return;
            }
            yield Utils.Filesystem.delete_directory (failed);
        }

        private async void exec_steam_tinker_launch (string executable, string args) {
            if (!FileUtils.test (executable, FileTest.IS_REGULAR))
                return;
            var quoted = Shell.quote (executable);
            if (!FileUtils.test (executable, FileTest.IS_EXECUTABLE))
                yield Utils.System.run_command ("chmod +x %s".printf (quoted));
            yield Utils.System.run_command ("%s %s".printf (quoted, args));
        }

        private async ReturnCode remove_steam_tinker_launch (InstallJob job) {
            yield exec_steam_tinker_launch (job.stl_binary_location, "compat del");
            if (FileUtils.test (job.stl_link_location, FileTest.EXISTS)) {
                if (!FileUtils.test (job.stl_link_location, FileTest.IS_SYMLINK) || !Utils.Filesystem.delete_file (job.stl_link_location))
                    return ReturnCode.FILESYSTEM_ERROR;
            }
            var remove_location = job.stl_user_requested_removal ? job.stl_manual_remove_location : job.stl_base_location;
            if (FileUtils.test (remove_location, FileTest.EXISTS)) {
                if (!FileUtils.test (remove_location, FileTest.IS_DIR) || !yield Utils.Filesystem.delete_directory (remove_location))
                    return ReturnCode.FILESYSTEM_ERROR;
            }
            if (job.stl_remove_config && FileUtils.test (job.stl_config_location, FileTest.EXISTS)) {
                if (!FileUtils.test (job.stl_config_location, FileTest.IS_DIR) || !yield Utils.Filesystem.delete_directory (job.stl_config_location))
                    return ReturnCode.FILESYSTEM_ERROR;
            }
            var steam = job.tool.group.launcher as Models.Launchers.Steam;
            if (steam != null)
                steam.unregister_compatibility_tool_by_path ("%s/SteamTinkerLaunch".printf (job.stl_compat_location));
            return ReturnCode.RUNNER_REMOVED;
        }

        public async ReturnCode update_specific_runner (Models.Tools.Basic runner) {
            var directory = "%s%s/%s Latest".printf (runner.group.launcher.directory, runner.group.directory, runner.title);
            if (!FileUtils.test (directory, FileTest.IS_DIR))
                return ReturnCode.RUNNER_NOT_INSTALLED;
            var metadata = Utils.Metadata.load (directory);
            ReturnCode lookup_code;
            var release = yield runner.fetch_latest_eligible_release (out lookup_code);
            if (lookup_code != ReturnCode.RELEASES_LOADED) {
                if (!(runner is Providers.Normalizers.GitHubAction) && metadata.tag != "" && is_request_failure (lookup_code))
                    return ReturnCode.NOTHING_TO_UPDATE;
                return lookup_code;
            }
            if (release == null)
                return ReturnCode.NOTHING_TO_UPDATE;
            var job = new InstallJob (release, runner, InstallJob.Mode.LATEST);
            return yield update_latest_job (job);
        }

        private async ReturnCode update_latest_job (InstallJob job) {
            var runner = job.tool as Models.Tools.Basic;
            if (runner == null || !FileUtils.test (job.install_location, FileTest.IS_DIR)) {
                job.refresh_state ();
                return ReturnCode.RUNNER_NOT_INSTALLED;
            }
            var metadata = Utils.Metadata.load (job.install_location);
            var release = job.release;
            if (release.source_tag != "" && metadata.tag == release.source_tag)
                return ReturnCode.NOTHING_TO_UPDATE;
            var version_content = Utils.Filesystem.get_file_content ("%s/version".printf (job.install_location));
            var proton_content = Utils.Filesystem.get_file_content ("%s/proton".printf (job.install_location));
            if (version_content != "" && proton_content != "" && release_matches_installed_version (release, version_content, proton_content)) {
                persist_runner_identity (metadata, runner, job.install_location, release.source_tag != "" ? release.source_tag : release.title, release.upstream_release_id);
                return ReturnCode.NOTHING_TO_UPDATE;
            }
            if (!job.selected_asset.is_archive ())
                return ReturnCode.INVALID_DATA;
            job.state = InstallJob.State.BUSY_UPDATING;
            var install_code = yield install (job, true);
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
            return code;
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

        public async ReturnCode finalize_replaced_runner (string directory, string backup, bool migrate_prefix) {
            var backup_settings = "%s/user_settings.py".printf (backup);
            if (FileUtils.test (backup_settings, FileTest.IS_REGULAR)) {
                var settings = "%s/user_settings.py".printf (directory);
                var copied = true;
                if (FileUtils.test (backup_settings, FileTest.IS_SYMLINK))
                    copied = Utils.Filesystem.copy_symlink (backup_settings, settings);
                else
                    Utils.Filesystem.create_file (settings, Utils.Filesystem.get_file_content (backup_settings));
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
            return (yield Utils.Filesystem.delete_directory (backup)) ? ReturnCode.RUNNER_UPDATED : ReturnCode.FILESYSTEM_ERROR;
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

        private void persist_runner_identity (Utils.Metadata metadata, Models.Tools.Basic runner, string directory, string tag, string release_id) {
            metadata.runner_endpoint = runner.endpoint;
            metadata.runner_title = runner.title;
            metadata.provider_id = runner.provider_id;
            metadata.tool_id = runner.id;
            metadata.launcher_id = runner.group.launcher.instance_id;
            if (tag != "")
                metadata.tag = tag;
            if (release_id != "")
                metadata.release_id = release_id;
            metadata.save (directory);
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

        public async ReturnCode check_for_updates (List<Models.Launcher> launchers) {
            var processes = (yield Utils.System.run_command ("ps -eo args")).stdout.ascii_down ();
            if (processes.contains ("/proton") || processes.contains ("/umu") || processes.contains ("/wine") || processes.contains ("/wine64") || processes.contains (".exe"))
                return ReturnCode.RUNNERS_IN_USE;
            var updated = 0;
            foreach (var launcher in launchers) {
                foreach (var group in launcher.groups) {
                    foreach (var directory in group.get_tool_directories ()) {
                        if (directory.has_suffix (" Latest Backup")) {
                            var stale_backup = "%s%s/%s".printf (launcher.directory, group.directory, directory);
                            if (!yield Utils.Filesystem.delete_directory (stale_backup))
                                return ReturnCode.FILESYSTEM_ERROR;
                        }
                    }
                    foreach (var tool in group.tools) {
                        var runner = tool as Models.Tools.Basic;
                        if (runner == null)
                            continue;
                        var latest = "%s Latest".printf (runner.title);
                        var has_latest = false;
                        foreach (var directory in group.get_tool_directories ()) {
                            if (directory == latest) {
                                has_latest = true;
                                break;
                            }
                        }
                        if (!has_latest)
                            continue;
                        var code = yield update_specific_runner (runner);
                        if (code == ReturnCode.RUNNER_UPDATED)
                            updated++;
                        else if (code != ReturnCode.NOTHING_TO_UPDATE)
                            return code;
                    }
                }
            }
            return updated > 0 ? ReturnCode.RUNNERS_UPDATED : ReturnCode.NOTHING_TO_UPDATE;
        }
    }
}
