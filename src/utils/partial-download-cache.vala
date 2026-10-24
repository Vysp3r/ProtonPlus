namespace ProtonPlus.Utils {
    /// Unvalidated bytes only. Completed archives remain owned by the workflow.
    public class PartialDownloadCache : Object {
        [CCode (cname = "flock", cheader_filename = "sys/file.h")]
        private static extern int flock (int fd, int operation);
        private const int LOCK_SH = 1;
        private const int LOCK_EX = 2;
        private const int LOCK_NB = 4;
        public const int64 MAX_AGE_SECONDS = 7 * 24 * 60 * 60;
        public const int64 MAX_BYTES = 2L * 1024 * 1024 * 1024;
        public const int MAX_ENTRIES = 32;

        // Outside the disposable tree: never unlink a lock inode another process holds.
        internal static int lock_cache (string root, bool exclusive) throws Error {
            var parent = Path.get_dirname (root);
            if (DirUtils.create_with_parents (parent, 0700) != 0)
                throw new IOError.FAILED (_("Could not create cache parent"));
            int fd = Posix.open (root + ".downloads.lock", Posix.O_CREAT | Posix.O_RDWR | Posix.O_CLOEXEC | Posix.O_NOFOLLOW, 0600);
            if (fd < 0)
                throw new IOError.FAILED (_("Could not open download cache lock"));
            if (flock (fd, (exclusive ? LOCK_EX : LOCK_SH) | LOCK_NB) != 0) {
                Posix.close (fd);
                return -1;
            }
            return fd;
        }

        public class Lease : Object {
            public string path { get; private set; }
            public int64 offset { get; private set; default = 0; }
            public int64 total { get; private set; default = -1; }
            public string? etag { get; private set; }
            private string identity;
            private string metadata_path;
            private int cache_fd = -1;
            private int entry_fd = -1;

            internal Lease (string root, string identity) throws Error {
                this.identity = identity;
                cache_fd = lock_cache (root, false);
                if (cache_fd < 0)
                    throw new IOError.BUSY (_("The download cache is busy. Try again later."));
                var directory = Path.build_filename (root, "partials", Checksum.compute_for_string (ChecksumType.SHA256, identity));
                foreach (var component in new string[] { root, Path.build_filename (root, "partials"), directory }) {
                    if (FileUtils.test (component, FileTest.IS_SYMLINK))
                        throw new IOError.INVALID_DATA (_("Symlink in partial cache path"));
                }
                if (DirUtils.create_with_parents (directory, 0700) != 0)
                    throw new IOError.FAILED (_("Could not create partial download directory"));
                path = Path.build_filename (directory, "body");
                metadata_path = Path.build_filename (directory, "metadata");
                entry_fd = Posix.open (Path.build_filename (directory, "lock"), Posix.O_CREAT | Posix.O_RDWR | Posix.O_CLOEXEC | Posix.O_NOFOLLOW, 0600);
                if (entry_fd < 0 || flock (entry_fd, LOCK_EX | LOCK_NB) != 0)
                    throw new IOError.BUSY (_("This archive is already being downloaded. Try again later."));
                load ();
            }

            public void release () {
                if (entry_fd >= 0) {
                    Posix.close (entry_fd);
                    entry_fd = -1;
                }
                if (cache_fd >= 0) {
                    Posix.close (cache_fd);
                    cache_fd = -1;
                }
            }

            ~Lease () {
                release ();
            }

            private void load () {
                try {
                    var info = File.new_for_path (path).query_info ("standard::type,standard::size", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                    var metadata_info = File.new_for_path (metadata_path).query_info ("standard::type,standard::size", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                    if (info.get_file_type () != FileType.REGULAR || metadata_info.get_file_type () != FileType.REGULAR || metadata_info.get_size () > 16384)
                        throw new IOError.INVALID_DATA ("Invalid partial file");
                    var metadata = new KeyFile ();
                    metadata.load_from_file (metadata_path, KeyFileFlags.NONE);
                    var saved_etag = metadata.get_string ("download", "etag");
                    var size = metadata.get_int64 ("download", "bytes");
                    var expected = metadata.get_int64 ("download", "total");
                    var age = new DateTime.now_utc ().to_unix () - metadata.get_int64 ("download", "updated");
                    if (metadata.get_integer ("download", "version") != 1 ||
                        metadata.get_string ("download", "identity") != identity ||
                        metadata.get_string ("download", "encoding") != "identity" ||
                        !Web.is_strong_etag (saved_etag) || size <= 0 || size > MAX_BYTES ||
                        size != info.get_size () || expected < -1 || (expected >= 0 && size >= expected) ||
                        age < 0 || age > MAX_AGE_SECONDS)
                        throw new IOError.INVALID_DATA ("Stale or mismatched partial metadata");
                    offset = size;
                    total = expected;
                    etag = saved_etag;
                    return;
                } catch (Error e) {
                    debug ("Partial download not reusable: %s", e.message);
                }
                discard ();
            }

            // A crash while replacing/appending must not leave an old validator
            // describing new bytes, even if the new body happens to have the same size.
            public void invalidate_checkpoint () throws Error {
                try {
                    File.new_for_path (metadata_path).delete ();
                } catch (IOError.NOT_FOUND e) { }
            }

            public void discard () {
                FileUtils.remove (metadata_path);
                FileUtils.remove (path);
                offset = 0;
                total = -1;
                etag = null;
            }

            public void save (int64 bytes, int64 total, string? validator) throws Error {
                if (bytes <= 0 || bytes > MAX_BYTES || !Web.is_strong_etag (validator) || (total >= 0 && bytes >= total)) {
                    discard ();
                    return;
                }
                var metadata = new KeyFile ();
                metadata.set_integer ("download", "version", 1);
                metadata.set_string ("download", "identity", identity);
                metadata.set_string ("download", "encoding", "identity");
                metadata.set_string ("download", "etag", validator);
                metadata.set_int64 ("download", "bytes", bytes);
                metadata.set_int64 ("download", "total", total);
                metadata.set_int64 ("download", "updated", new DateTime.now_utc ().to_unix ());
                FileUtils.set_contents (metadata_path, metadata.to_data ());
            }
        }

        public static async bool download (
            Models.Assets.Asset asset, string url, string destination, Cancellable cancellable,
            Web.progress_callback progress, Web.recovery_callback recovery, out string? error_message
        ) {
            error_message = null;
            var root = Globals.CACHE_PATH;
            yield prune (root);
            Lease? lease = null;
            bool result = false;
            try {
                var node = new Json.Node (Json.NodeType.OBJECT);
                node.set_object (asset.to_json (true));
                lease = acquire (root, Json.to_string (node, false));
                result = yield Web.download_with_recovery (url, destination, cancellable, progress, recovery, lease, null, out error_message);
            } catch (Error e) {
                error_message = e.message;
            }
            if (lease != null)
                lease.release ();
            lease = null;
            yield prune (root);
            return result;
        }

        public static Lease acquire (string root, string identity) throws Error {
            return new Lease (root, identity);
        }

        /// Run off the GTK thread. Exclusive tree lock makes pruning safe across processes.
        public static async void prune (string root) {
            SourceFunc resume = prune.callback;
            new Thread<void> ("partial-cache-prune", () => {
                int fd = -1;
                try {
                    fd = lock_cache (root, true);
                    if (fd >= 0) {
                        if (FileUtils.test (root, FileTest.IS_SYMLINK))
                            throw new IOError.INVALID_DATA ("Invalid cache root");
                        var directory = File.new_for_path (Path.build_filename (root, "partials"));
                        if (directory.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS) != FileType.DIRECTORY)
                            throw new IOError.INVALID_DATA ("Invalid partial cache directory");
                        var entries = new Gee.ArrayList<FileInfo> ();
                        var enumerator = directory.enumerate_children ("standard::name,standard::type,time::modified", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                        FileInfo? info;
                        while ((info = enumerator.next_file ()) != null)
                            entries.add (info);
                        entries.sort ((a, b) => {
                            var x = a.get_attribute_uint64 ("time::modified");
                            var y = b.get_attribute_uint64 ("time::modified");
                            return x > y ? -1 : x < y ? 1 : 0;
                        });
                        int count = 0;
                        int64 bytes = 0;
                        foreach (var entry in entries) {
                            var child = directory.get_child (entry.get_name ());
                            if (entry.get_file_type () != FileType.DIRECTORY) {
                                FileUtils.remove (child.get_path ());
                                continue;
                            }
                            bool keep = false;
                            try {
                                var body = child.get_child ("body").query_info ("standard::size,standard::type", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                                var metadata_info = child.get_child ("metadata").query_info ("standard::type,standard::size", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                                if (metadata_info.get_file_type () != FileType.REGULAR || metadata_info.get_size () > 16384)
                                    throw new IOError.INVALID_DATA ("Invalid metadata");
                                var metadata = new KeyFile ();
                                metadata.load_from_file (child.get_child ("metadata").get_path (), KeyFileFlags.NONE);
                                var age = new DateTime.now_utc ().to_unix () - metadata.get_int64 ("download", "updated");
                                keep = body.get_file_type () == FileType.REGULAR && age >= 0 && age <= MAX_AGE_SECONDS &&
                                    count < MAX_ENTRIES && body.get_size () <= MAX_BYTES - bytes;
                                if (keep) {
                                    count++;
                                    bytes += body.get_size ();
                                }
                            } catch (Error e) { }
                            if (!keep) {
                                // Only fixed owned files; never traverse extracted trees or links.
                                FileUtils.remove (child.get_child ("body").get_path ());
                                FileUtils.remove (child.get_child ("metadata").get_path ());
                                FileUtils.remove (child.get_child ("lock").get_path ());
                                DirUtils.remove (child.get_path ());
                            }
                        }
                    }
                } catch (Error e) {
                    debug ("Partial cache cleanup: %s", e.message);
                }
                if (fd >= 0)
                    Posix.close (fd);
                Idle.add ((owned) resume);
            });
            yield;
        }
    }
}
