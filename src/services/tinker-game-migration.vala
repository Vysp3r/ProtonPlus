namespace ProtonPlus.Services {
    public class TinkerGameMigration : Object {
        // No configuration contents are rewritten. In particular commands,
        // shell quoting, absolute paths and Steam assignments remain untouched.
        public static async ReturnCode copy_configuration (
            InstallJob job, string config_root, Cancellable? cancellable = null
        ) {
            if (job.state == InstallJob.State.BUSY_INSTALLING || job.state == InstallJob.State.BUSY_UPDATING ||
                job.state == InstallJob.State.BUSY_REMOVING)
                return ReturnCode.OPERATION_IN_PROGRESS;
            job.refresh_state ();
            if (job.tinker_game_context == null || job.state != InstallJob.State.UP_TO_DATE)
                return ReturnCode.RUNNER_NOT_INSTALLED;
            if (!yield TinkerGameWorkflow.validate_runtime_async (job.install_location, true))
                return ReturnCode.INVALID_DATA;
            var source = Path.build_filename (config_root, "steamtinkerlaunch");
            var destination = Path.build_filename (config_root, "tinkergame");
            if (TinkerGameWorkflow.exists (destination))
                return ReturnCode.RUNNER_ALREADY_INSTALLED;
            if (FileUtils.test (source, FileTest.IS_SYMLINK) || !FileUtils.test (source, FileTest.IS_DIR))
                return ReturnCode.INVALID_DATA;
            var staging = Utils.Filesystem.create_temporary_directory (config_root, ".protonplus-tg-migrate-");
            if (staging == "")
                return ReturnCode.FILESYSTEM_ERROR;
            var copied = Path.build_filename (staging, "configuration");
            var result = ReturnCode.FILESYSTEM_ERROR;
            try {
                yield copy_tree (File.new_for_path (source), File.new_for_path (copied), cancellable);
                // Recheck after yields; no install/remove operation may have
                // invalidated the runtime while configuration was copied.
                var busy = job.state == InstallJob.State.BUSY_INSTALLING ||
                    job.state == InstallJob.State.BUSY_UPDATING || job.state == InstallJob.State.BUSY_REMOVING;
                if (!busy)
                    job.refresh_state ();
                if (busy)
                    result = ReturnCode.OPERATION_IN_PROGRESS;
                else if (job.state != InstallJob.State.UP_TO_DATE)
                    result = ReturnCode.RUNNER_NOT_INSTALLED;
                else if (TinkerGameWorkflow.exists (destination))
                    result = ReturnCode.RUNNER_ALREADY_INSTALLED;
                else {
                    // GIO's no-overwrite move also detects a destination created
                    // after the check, including an empty directory or symlink.
                    yield File.new_for_path (copied).move_async (
                        File.new_for_path (destination), FileCopyFlags.NONE,
                        Priority.DEFAULT, cancellable, null);
                    result = ReturnCode.RUNNER_INSTALLED;
                }
            } catch (Error e) {
                job.error_message = e.message;
            }
            yield Utils.Filesystem.delete_directory (staging);
            return result;
        }

        private static async void copy_tree (File source, File destination, Cancellable? cancellable) throws Error {
            yield destination.make_directory_async (Priority.DEFAULT, cancellable);
            var enumerator = yield source.enumerate_children_async (
                "standard::name,standard::type", FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                Priority.DEFAULT, cancellable);
            while (true) {
                var batch = yield enumerator.next_files_async (32, Priority.DEFAULT, cancellable);
                if (batch == null)
                    break;
                foreach (var info in batch) {
                    var original = source.get_child (info.get_name ());
                    // Verified upstream migration: rename template basenames.
                    // Collisions fail the staged copy; neither tree is overwritten.
                    var renamed = info.get_name ().replace ("SteamTinkerLaunch", "TinkerGame");
                    var target = destination.get_child (renamed);
                    if (info.get_file_type () == FileType.DIRECTORY)
                        yield copy_tree (original, target, cancellable);
                    else if (info.get_file_type () == FileType.REGULAR || info.get_file_type () == FileType.SYMBOLIC_LINK)
                        yield original.copy_async (target, FileCopyFlags.NOFOLLOW_SYMLINKS,
                            Priority.DEFAULT, cancellable, null);
                    else
                        throw new IOError.NOT_SUPPORTED ("Unsupported configuration file type");
                }
            }
            yield enumerator.close_async (Priority.DEFAULT, cancellable);
        }
    }
}
