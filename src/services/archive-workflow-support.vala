namespace ProtonPlus.Services {
    /// Per-attempt archive paths shared by the two archive-based workflows.
    internal class ArchiveOperation : Object {
        public string operation_path { get; private set; }
        public string archive_path { get; private set; }
        public string extension { get; private set; }
        public string cache_archive_path { get; private set; }
        public Models.Assets.Asset asset { get; private set; }
        public bool from_cache { get; private set; }
        public bool cache_published { get; set; default = false; }
        public string staging_root { get; set; default = ""; }

        public ArchiveOperation (
            string operation_path,
            string archive_path,
            string extension,
            string cache_archive_path,
            Models.Assets.Asset asset,
            bool from_cache
        ) {
            this.operation_path = operation_path;
            this.archive_path = archive_path;
            this.extension = extension;
            this.cache_archive_path = cache_archive_path;
            this.asset = asset;
            this.from_cache = from_cache;
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
            var cache_available = FileUtils.test (cache_archive_path, FileTest.IS_REGULAR);
            if (cache_available && !yield archive_matches_asset (cache_archive_path, job.selected_asset)) {
                debug ("Discarding archive cache entry that failed integrity validation: %s", cache_archive_path);
                if (!Utils.Filesystem.delete_file (cache_archive_path)) {
                    yield cleanup_path (operation_path);
                    return ReturnCode.FILESYSTEM_ERROR;
                }
                cache_available = false;
            }
            var created = new ArchiveOperation (
                operation_path,
                operation_archive_path,
                extension,
                cache_archive_path,
                job.selected_asset,
                cache_available
            );

            job.step = InstallJob.Step.DOWNLOADING;
            if (!cache_available) {
                string? download_error;
                var downloaded = yield job.download_archive (job.selected_asset.download_url, operation_archive_path, out download_error);
                if (!downloaded) {
                    job.error_message = download_error;
                    yield cleanup (created);
                    return ReturnCode.DOWNLOAD_FAILED;
                }
                if (!yield archive_matches_asset (operation_archive_path, job.selected_asset)) {
                    debug ("Downloaded archive failed integrity validation: %s", job.selected_asset.download_url);
                    yield cleanup (created);
                    return ReturnCode.DOWNLOAD_FAILED;
                }
            } else if (!yield Utils.Filesystem.copy_file (cache_archive_path, operation_archive_path)) {
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

        /// Publish only after the owning workflow has validated extraction.
        public async bool publish_archive (ArchiveOperation operation) {
            if (operation.from_cache || operation.cache_published)
                return true;

            if (yield Utils.Filesystem.move_file_atomic_if_absent (
                operation.archive_path, operation.cache_archive_path
            )) {
                operation.cache_published = true;
                return true;
            }

            if (yield archive_matches_asset (operation.cache_archive_path, operation.asset))
                return true;

            if (FileUtils.test (operation.cache_archive_path, FileTest.EXISTS) &&
                !Utils.Filesystem.delete_file (operation.cache_archive_path))
                return false;

            if (yield Utils.Filesystem.move_file_atomic_if_absent (
                operation.archive_path, operation.cache_archive_path
            )) {
                operation.cache_published = true;
                return true;
            }

            return yield archive_matches_asset (operation.cache_archive_path, operation.asset);
        }

        public async ReturnCode complete_attempt (
            ReturnCode code,
            ArchiveOperation operation,
            bool discard_cached_archive = false
        ) {
            var result = code;
            if (discard_cached_archive && operation.from_cache &&
                FileUtils.test (operation.cache_archive_path, FileTest.IS_REGULAR)) {
                debug ("Discarding archive cache entry after validation failure: %s", operation.cache_archive_path);
                if (!Utils.Filesystem.delete_file (operation.cache_archive_path))
                    result = ReturnCode.FILESYSTEM_ERROR;
            }
            yield cleanup (operation);
            return result;
        }

        private async bool archive_matches_asset (string path, Models.Assets.Asset asset) {
            SourceFunc callback = archive_matches_asset.callback;
            var matches = false;

            new Thread<void> ("verify_archive", () => {
                try {
                    var file = File.new_for_path (path);
                    var info = file.query_info (
                        "standard::type,standard::size",
                        FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                        null
                    );
                    if (info.get_file_type () != FileType.REGULAR) {
                        Idle.add ((owned) callback, Priority.DEFAULT);
                        return;
                    }
                    if (asset.download_size > 0 && info.get_size () != asset.download_size) {
                        Idle.add ((owned) callback, Priority.DEFAULT);
                        return;
                    }
                    if (asset.digest == "") {
                        matches = true;
                        Idle.add ((owned) callback, Priority.DEFAULT);
                        return;
                    }

                    ChecksumType checksum_type;
                    string expected_digest;
                    if (!parse_digest (asset.digest, out checksum_type, out expected_digest)) {
                        Idle.add ((owned) callback, Priority.DEFAULT);
                        return;
                    }

                    var checksum = new Checksum (checksum_type);
                    var stream = file.read (null);
                    uint8[] buffer = new uint8[64 * 1024];
                    ssize_t bytes_read;
                    while ((bytes_read = stream.read (buffer, null)) > 0)
                        checksum.update (buffer, bytes_read);
                    matches = checksum.get_string ().down () == expected_digest;
                } catch (Error e) {
                    debug ("Could not validate archive %s: %s", path, e.message);
                }

                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return matches;
        }

        private static bool parse_digest (
            string value,
            out ChecksumType checksum_type,
            out string expected_digest
        ) {
            checksum_type = ChecksumType.SHA256;
            expected_digest = "";
            var parts = value.down ().split (":", 2);
            if (parts.length != 2 || parts[1] == "")
                return false;

            switch (parts[0]) {
            case "md5":
                checksum_type = ChecksumType.MD5;
                break;
            case "sha1":
                checksum_type = ChecksumType.SHA1;
                break;
            case "sha256":
                checksum_type = ChecksumType.SHA256;
                break;
            case "sha384":
                checksum_type = ChecksumType.SHA384;
                break;
            case "sha512":
                checksum_type = ChecksumType.SHA512;
                break;
            default:
                return false;
            }

            foreach (var character in parts[1].data) {
                if (!((character >= '0' && character <= '9') ||
                      (character >= 'a' && character <= 'f')))
                    return false;
            }
            expected_digest = parts[1];
            return true;
        }

        private async void cleanup_path (string path) {
            if (path != "" && FileUtils.test (path, FileTest.IS_DIR))
                yield Utils.Filesystem.delete_directory (path);
        }

        private async void cleanup (ArchiveOperation operation) {
            yield cleanup_path (operation.operation_path);
            if (operation.staging_root != "" && FileUtils.test (operation.staging_root, FileTest.IS_DIR))
                yield Utils.Filesystem.delete_directory (operation.staging_root);
        }
    }
}
