namespace ProtonPlus.Services {
    /// Per-attempt archive paths shared by the two archive-based workflows.
    internal class ArchiveOperation : Object {
        public string operation_path { get; private set; }
        public string archive_path { get; private set; }
        public string extension { get; private set; }
        public string staging_root { get; set; default = ""; }

        public ArchiveOperation (string operation_path, string archive_path, string extension) {
            this.operation_path = operation_path;
            this.archive_path = archive_path;
            this.extension = extension;
        }
    }

    /// Shares only cache/workspace mechanics.  Extraction and promotion stay
    /// in their respective workflows because their transaction shapes differ.
    internal class ArchiveWorkflowSupport : Object {
        public async ReturnCode prepare_archive (
            InstallJob job,
            string operation_prefix,
            out ArchiveOperation? operation
        ) {
            operation = null;
            var extension = Utils.ArchiveHelper.get_archive_extension (job.selected_asset.name, true);
            if (extension == null)
                return ReturnCode.UNSUPPORTED_EXTENSION;

            var archive_cache_path = Path.build_filename (Globals.CACHE_PATH, "archives");
            if (!yield Utils.Filesystem.create_directory_async (archive_cache_path))
                return ReturnCode.FILESYSTEM_ERROR;

            var operation_path = Utils.Filesystem.create_temporary_directory (Globals.CACHE_PATH, operation_prefix);
            if (operation_path == "")
                return ReturnCode.FILESYSTEM_ERROR;

            var archive_key = Checksum.compute_for_string (ChecksumType.SHA256, job.selected_asset.download_url);
            var cache_archive_path = Path.build_filename (archive_cache_path, "%s%s".printf (archive_key, extension));
            var operation_archive_path = Path.build_filename (operation_path, "archive%s".printf (extension));
            var created = new ArchiveOperation (operation_path, operation_archive_path, extension);

            job.step = InstallJob.Step.DOWNLOADING;
            if (!FileUtils.test (cache_archive_path, FileTest.IS_REGULAR)) {
                string? download_error;
                var downloaded = yield job.download_archive (job.selected_asset.download_url, operation_archive_path, out download_error);
                if (!downloaded) {
                    job.error_message = download_error;
                    yield cleanup (created);
                    return ReturnCode.DOWNLOAD_FAILED;
                }
                var cached = yield Utils.Filesystem.move_file_atomic_if_absent (operation_archive_path, cache_archive_path);
                if (!cached && !FileUtils.test (cache_archive_path, FileTest.IS_REGULAR)) {
                    yield cleanup (created);
                    return ReturnCode.FILESYSTEM_ERROR;
                }
            }

            if (!yield Utils.Filesystem.copy_file (cache_archive_path, operation_archive_path)) {
                yield cleanup (created);
                return ReturnCode.FILESYSTEM_ERROR;
            }
            if (job.canceled) {
                yield cleanup (created);
                return ReturnCode.EXTRACTION_FAILED;
            }

            operation = created;
            return ReturnCode.RUNNER_INSTALLED;
        }

        public async ReturnCode complete_attempt (ReturnCode code, ArchiveOperation operation) {
            yield cleanup (operation);
            return code;
        }

        private async void cleanup (ArchiveOperation operation) {
            if (operation.operation_path != "" && FileUtils.test (operation.operation_path, FileTest.IS_DIR))
                yield Utils.Filesystem.delete_directory (operation.operation_path);
            if (operation.staging_root != "" && FileUtils.test (operation.staging_root, FileTest.IS_DIR))
                yield Utils.Filesystem.delete_directory (operation.staging_root);
        }
    }
}
