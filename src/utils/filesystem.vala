namespace ProtonPlus.Utils {
    public class Filesystem {
        public const Posix.mode_t S_IRWXUGO = (Posix.S_IRWXU | Posix.S_IRWXG | Posix.S_IRWXO);

        // Required GSettings keys for the application to function properly
        private static string[] REQUIRED_SCHEMA_KEYS = {
            "width", "height", "is-maximized", "is-fullscreen",
            "check-updates-on-launch", "background-updates", "background-updates-frequency", "check-updates-on-boot",
            "github-api-key", "gitlab-api-key", "selected-tool-variants", "steam-selected-profile-id",
            "first-run", "theme", "language", "experimental-features", "show-legacy-tools",
            "migrate-default-prefix", "proxy-mode", "proxy-url", "download-speed-limit-bps", "controller-confirm-button",
            "controller-haptics-enabled", "last-version", "steam-dir-custom", "download-speed-unit"
        };

        public static bool is_valid_schema (SettingsSchema schema) {
            foreach (var key in REQUIRED_SCHEMA_KEYS) {
                if (!schema.has_key (key)) {
                    warning ("Missing required GSettings key: %s", key);
                    return false;
                }
            }
            return true;
        }

        // Miscellaneous.

        public async static string? extract (string install_location, string tool_name, string extension, Cancellable cancellable) {
            SourceFunc callback = extract.callback;

            string output = "";
            new Thread<void> ("extract", () => {
                const int BUFFER_SIZE = 192000;

                // The private workspace is trusted, but an OSTree host may
                // expose it through a symlinked ancestor such as /home.
                var extraction_location = Posix.realpath (install_location);
                if (extraction_location == null) {
                    warning ("Could not resolve extraction directory: %s", install_location);
                    Idle.add ((owned) callback, Priority.DEFAULT);
                    return;
                }

                var archive = new Archive.Read ();
                archive.support_format_all ();
                archive.support_filter_all ();

                int flags;
                flags = Archive.ExtractFlags.ACL;
                flags |= Archive.ExtractFlags.PERM;
                flags |= Archive.ExtractFlags.TIME;
                flags |= Archive.ExtractFlags.FFLAGS;
                flags |= Archive.ExtractFlags.SECURE_SYMLINKS;
                flags |= Archive.ExtractFlags.SECURE_NODOTDOT;

                var ext = new Archive.WriteDisk ();
                ext.set_standard_lookup ();
                ext.set_options (flags);

                var archive_path = Path.build_filename ((!) extraction_location, tool_name + extension);
                if (archive.open_filename (archive_path, BUFFER_SIZE) != Archive.Result.OK) {
                    Idle.add ((owned) callback, Priority.DEFAULT);
                    return;
                }

                ssize_t r;

                unowned Archive.Entry entry;

                string source_path = "";
                bool first_run = true;

                for ( ;; ) {
                    if (cancellable.is_cancelled ())
                        break;

                    r = archive.next_header (out entry);
                    if (r == Archive.Result.EOF)
                        break;

                    if (r < Archive.Result.OK)
                        warning ("Could not read archive entry: %s", archive.error_string ());

                    if (r < Archive.Result.WARN) {
                        Idle.add ((owned) callback, Priority.DEFAULT);
                        return;
                    }

                    var original_entry_path = entry.pathname ();
                    if (original_entry_path == "." || original_entry_path == "./")
                        continue;

                    var entry_path = normalize_archive_entry (original_entry_path);
                    if (entry_path == null) {
                        warning ("Refusing to extract unsafe archive entry: %s", original_entry_path);
                        Idle.add ((owned) callback, Priority.DEFAULT);
                        return;
                    }

                    if (first_run) {
                        source_path = entry_path.split ("/", 2)[0];
                        first_run = false;
                    }

                    entry.set_pathname (Path.build_filename ((!) extraction_location, entry_path));
                    r = ext.write_header (entry);

                    if (r < Archive.Result.OK) {
                        warning ("Could not write archive entry: %s", ext.error_string ());
                        if (r < Archive.Result.WARN) {
                            Idle.add ((owned) callback, Priority.DEFAULT);
                            return;
                        }
                    } else if (entry.size () > 0) {
                        r = copy_data (archive, ext, cancellable);
                        if (r < Archive.Result.WARN) {
                            Idle.add ((owned) callback, Priority.DEFAULT);
                            return;
                        }
                    }

                    r = ext.finish_entry ();
                    if (r < Archive.Result.OK)
                        warning ("Could not finish archive entry: %s", ext.error_string ());

                    if (r < Archive.Result.WARN) {
                        Idle.add ((owned) callback, Priority.DEFAULT);
                        return;
                    }
                }

                archive.close ();

                if (source_path != "")
                    output = Path.build_filename (install_location, source_path);

                if (cancellable.is_cancelled ()) {
                    // The owning async operation removes its whole private
                    // workspace once this worker has returned.  Do not start
                    // another async deletion from this worker thread.
                    output = "";
                }

                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return output;
        }

        private static string? normalize_archive_entry (string path) {
            if (path == "" || Path.is_absolute (path))
                return null;

            var normalized_path = path;
            while (normalized_path.has_prefix ("./"))
                normalized_path = normalized_path.substring (2);

            if (normalized_path == "" || normalized_path == ".")
                return null;

            foreach (var component in normalized_path.split ("/")) {
                if (component == "..")
                    return null;
            }

            return normalized_path;
        }

        static ssize_t copy_data (Archive.Read ar, Archive.WriteDisk aw, Cancellable cancellable) {
            ssize_t r;
            uint8[] buffer;
            Archive.int64_t offset;

            for ( ;; ) {
                if (cancellable.is_cancelled ())
                    return Archive.Result.FAILED;

                r = ar.read_data_block (out buffer, out offset);
                if (r == Archive.Result.EOF)
                    return Archive.Result.OK;

                if (r < Archive.Result.OK)
                    return r;

                r = aw.write_data_block (buffer, offset);
                if (r < Archive.Result.OK) {
                    warning ("Could not write archive data: %s", aw.error_string ());
                    return r;
                }
            }
        }

        public static string convert_bytes_to_string (int64 size) {
            return format_size (size);
        }

        public static string convert_download_speed_to_string (int64 bytes_per_second) {
            if (Globals.SETTINGS != null && Globals.SETTINGS.get_enum ("download-speed-unit") == 1)
                return "%.2f KiB".printf ((double) bytes_per_second / 1024.0);

            return "%.0f KB".printf ((double) bytes_per_second / 1000.0);
        }

        public async static bool make_symlink (string link_location, string target_path) {
            var link_file = File.new_for_path (link_location);
            if (link_file.query_exists (null)) {
                // Only attempt to delete link_location if it's already a symlink.
                if (!FileUtils.test (link_location, FileTest.IS_SYMLINK))
                    return false;

                var link_deleted = Utils.Filesystem.delete_file (link_location);
                if (!link_deleted)
                    return false;
            }

            try {
                // Try to create the symlink (will fail if file exists or no permission).
                var link_created = yield link_file.make_symbolic_link_async (target_path, Priority.DEFAULT, null);

                if (!link_created)
                    return false;
            } catch (Error e) {
                return false;
            }

            return true;
        }

        // Files.

        public static string get_file_content (string path, bool use_uri = false) {
            string output = "";

            try {
                File file;

                if (use_uri) {
                    file = File.new_for_uri (path);
                } else {
                    file = File.new_for_path (path);
                }

                uint8[] contents;
                string etag_out;
                file.load_contents (null, out contents, out etag_out);

                output = Parser.data_to_string (contents);
            } catch (Error e) {
                warning (e.message);
            }

            return output;
        }

        public async static string get_file_content_async (string path, bool use_uri = false) {
            string output = "";

            try {
                File file;

                if (use_uri) {
                    file = File.new_for_uri (path);
                } else {
                    file = File.new_for_path (path);
                }

                uint8[] contents;
                string etag_out;
                yield file.load_contents_async (null, out contents, out etag_out);

                output = Parser.data_to_string (contents);
            } catch (Error e) {
                warning (e.message);
            }

            return output;
        }

        public static bool modify_file (string path, string content) {
            try {
                FileUtils.set_contents (path, content);
            } catch (FileError e) {
                warning (e.message);

                return false;
            }

            return get_file_content (path) == content;
        }

        public static bool copy_symlink (string src_path, string dest_path) {
            try {
                File src = File.new_for_path (src_path);
                File dest = File.new_for_path (dest_path);

                return src.copy (dest, FileCopyFlags.NOFOLLOW_SYMLINKS);
            } catch (Error e) {
                warning (e.message);

                return false;
            }
        }

        public static void create_file (string path, string? content = null, bool private_mode = false) {
            try {
                var file = File.parse_name (path);
                // NOTE: "Private" means "no permissions for Group or Other",
                // otherwise we use the default `umask` (usually "-rw-r--r--").
                FileOutputStream os = file.create (private_mode ? FileCreateFlags.PRIVATE : FileCreateFlags.NONE);
                if (content != null)
                    os.write (content.data);
            } catch (Error e) {
                warning (e.message);
            }
        }

        static bool delete_file_direct (string path) {
            return Posix.unlink (path) == 0;
        }

        public static bool delete_file (string path) {
            return delete_file_direct (path);
        }


        // Directories.

        // Creates a directory with a unique suffix directly below `parent`.
        // Keeping operation directories under their eventual destination also
        // lets us promote them with rename(2), instead of a copy/delete pair.
        public static string create_temporary_directory (string parent, string prefix) {
            if (!FileUtils.test (parent, FileTest.IS_DIR))
                return "";

            return DirUtils.mkdtemp (Path.build_filename (parent, "%sXXXXXX".printf (prefix)));
        }

        // Rename is atomic when source and destination share a filesystem.  Do
        // not replace an existing destination: callers use this to promote a
        // fully staged installation without ever overwriting another attempt.
        public static async bool move_directory_atomic (string source, string destination) {
            SourceFunc callback = move_directory_atomic.callback;

            bool output = false;
            new Thread<void> ("move_directory_atomic", () => {
                if (!FileUtils.test (source, FileTest.IS_DIR) || FileUtils.test (destination, FileTest.EXISTS)) {
                    Idle.add ((owned) callback, Priority.DEFAULT);
                    return;
                }

                output = FileUtils.rename (source, destination) == 0;
                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return output;
        }

        // Like move_directory_atomic, but for an archive cache entry.  A
        // concurrent downloader winning the race is harmless: its cache file
        // is retained and the caller can use that immutable result.
        public static async bool move_file_atomic_if_absent (string source, string destination) {
            SourceFunc callback = move_file_atomic_if_absent.callback;

            bool output = false;
            new Thread<void> ("move_file_atomic", () => {
                if (!FileUtils.test (source, FileTest.IS_REGULAR) || FileUtils.test (destination, FileTest.EXISTS)) {
                    Idle.add ((owned) callback, Priority.DEFAULT);
                    return;
                }

                output = FileUtils.rename (source, destination) == 0;
                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return output;
        }

        public static async bool copy_file (string source, string destination) {
            try {
                var source_file = File.parse_name (source);
                var destination_file = File.parse_name (destination);

                if (!source_file.query_exists ())
                    return false;

                yield source_file.copy_async (destination_file, FileCopyFlags.OVERWRITE);
                return true;
            } catch (Error e) {
                warning ("Failed to copy %s: %s", source, e.message);
                return false;
            }
        }

        public static async bool copy_file_verified (string source, string destination) {
            if (!yield copy_file (source, destination))
                return false;

            try {
                uint8[] source_contents;
                uint8[] destination_contents;
                string source_etag;
                string destination_etag;
                yield File.parse_name (source).load_contents_async (
                    null, out source_contents, out source_etag
                );
                yield File.parse_name (destination).load_contents_async (
                    null, out destination_contents, out destination_etag
                );

                if (source_contents.length == destination_contents.length) {
                    for (var index = 0; index < source_contents.length; index++) {
                        if (source_contents[index] != destination_contents[index]) {
                            warning ("Copied file verification failed: %s", destination);
                            return false;
                        }
                    }
                    return true;
                }

                warning ("Copied file verification failed: %s", destination);
            } catch (Error e) {
                warning ("Failed to verify copied file %s: %s", destination, e.message);
            }

            return false;
        }

        public static async bool move_directory (string source, string destination) {
            var destination_existed = FileUtils.test (destination, FileTest.EXISTS);
            var copied = yield copy_directory (source, destination);

            if (!copied) {
                if (!destination_existed && FileUtils.test (destination, GLib.FileTest.IS_DIR))
                    yield delete_directory (destination);

                return false;
            }

            return yield delete_directory (source);
        }

        public static async bool copy_directory (string source, string destination) {
            try {
                File src = File.parse_name (source);
                File dest = File.parse_name (destination);

                // Check if the source directory exists
                if (!src.query_exists ()) {
                    warning ("Source directory does not exist: %s", source);
                    return false;
                }

                // Create the destination directory if it doesn't exist
                if (!dest.query_exists ()) {
                    yield dest.make_directory_async ();
                }

                // Enumerate the contents of the source directory
                FileEnumerator enumerator = yield src.enumerate_children_async (
                    "standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS
                );

                FileInfo? file_info;
                while ((file_info = enumerator.next_file ()) != null) {
                    string file_name = file_info.get_name ();
                    File src_file = src.get_child (file_name);
                    File dest_file = dest.get_child (file_name);

                    // If it's a directory, recurse
                    if (file_info.get_file_type () == FileType.DIRECTORY) {
                        if (!(yield copy_directory (src_file.get_path (), dest_file.get_path ())))
                            return false;
                    } else {
                        // Otherwise, copy the file
                        try {
                            yield src_file.copy_async (dest_file, FileCopyFlags.NOFOLLOW_SYMLINKS);
                        } catch (Error e) {
                            warning ("Failed to copy %s: %s\n", file_name, e.message);
                            return false;
                        }
                    }
                }
            } catch (Error e) {
                warning (e.message);

                return false;
            }

            return true;
        }

        public static async bool move_dir_contents (string source_dir, string target_dir) {
            SourceFunc callback = move_dir_contents.callback;

            bool output = false;
            new Thread<void> ("move_dir_contents", () => {
                try {
                    Dir dir = Dir.open (source_dir);
                    string? name = null;
                    output = true;
                    while ((name = dir.read_name ()) != null) {
                        // NOTE: Includes hidden files (".foo") but not "." and "..".
                        string source_path = Path.build_filename (source_dir, name);
                        string target_path = Path.build_filename (target_dir, name);

                        // Never overwrite existing target (avoids accidental data loss).
                        if (FileUtils.test (target_path, FileTest.EXISTS)) {
                            output = false;
                            break;
                        }

                        // Move the "file" regardless of type (such as dir, symlink, etc).
                        if (FileUtils.rename (source_path, target_path) != 0) {
                            output = false;
                            break;
                        }

                    }
                } catch (Error e) {
                    warning (e.message);
                }
                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return output;
        }

        static bool delete_directory_direct (string path) {
            FileEnumerator? enumerator = null;

            try {
                var directory = File.new_for_path (path);
                enumerator = directory.enumerate_children (
                    "standard::name",
                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                    null
                );

                FileInfo? file_info;
                while ((file_info = enumerator.next_file (null)) != null) {
                    var cur_path = Path.build_filename (path, file_info.get_name ());
                    Posix.Stat stat_;

                    // NOTE: `lstat()` is very important to avoid following symlinks,
                    // otherwise we would wipe out the link target's contents too.
                    if (Posix.lstat (cur_path, out stat_) != 0)
                        return false;

                    if (Posix.S_ISDIR (stat_.st_mode)) {
                        if (!delete_directory_direct (cur_path))
                            return false;
                        if (Posix.rmdir (cur_path) != 0)
                            return false;
                    } else {
                        if (!delete_file_direct (cur_path))
                            return false;
                    }
                }
            } catch (Error e) {
                warning (e.message);
                return false;
            } finally {
                if (enumerator != null) {
                    try {
                        enumerator.close (null);
                    } catch (Error e) {
                        warning (e.message);
                    }
                }
            }

            return true;
        }

        public static async bool delete_directory (string path) {
            SourceFunc callback = delete_directory.callback;

            bool output = false;
            new Thread<void> ("delete_directory", () => {
                Posix.Stat stat_;

                // Enumeration follows a symlink passed as its root even when
                // NOFOLLOW_SYMLINKS is requested.  Inspect the root itself
                // first so deleting a linked directory never reaches its
                // target.
                if (Posix.lstat (path, out stat_) != 0) {
                    output = false;
                } else if (Posix.S_ISLNK (stat_.st_mode)) {
                    output = delete_file_direct (path);
                } else if (Posix.S_ISDIR (stat_.st_mode) && delete_directory_direct (path)) {
                    if (Posix.rmdir (path) == 0) {
                        output = true;
                    }
                }
                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return output;
        }

        public static bool create_directory (string path) {
            // We can safely split on slashes since they're illegal as filenames.
            var has_leading_slash = path.index_of_char ('/') == 0;
            var parts = path.split ("/");

            // Create the target directory components in a top-down fashion.
            // NOTE: If caller gives us a path with `..` such as `/foo/bar/../baz`,
            // then we will end up creating both `/foo/bar` and `/foo/baz`, because
            // there is no easy way to preprocess such directory traversals.
            Posix.Stat stat_;
            var current_path = "";
            foreach (string p in parts) {
                if (p == "")
                    continue;

                if (current_path == "" && !has_leading_slash)
                    current_path = p;
                else
                    current_path += @"/$p";

                // Attempt to create the current path.
                // NOTE: We request full (0777) permission bits. The C library will
                // then filter it down to the correct `umask` for the current user,
                // which is almost always 0755. This is how GNU's mkdir util works.
                // https://pubs.opengroup.org/onlinepubs/9799919799/functions/mkdir.html
                // https://github.com/coreutils/coreutils/blob/408301e4bc171bf5544f373f64bb6ed3351541db/src/mkdir.c#L136
                // https://github.com/coreutils/gnulib/blob/e87d09bee37eeb742b8a34c9054cd2ebde22b835/lib/sys_stat.in.h#L423
                if (Posix.mkdir (current_path, S_IRWXUGO) != 0) {
                    var error_number = Posix.errno;

                    // Check failures for any reasons other than "it exists".
                    if (error_number != Posix.EEXIST) {
                        warning (
                            "Could not create directory '%s': %s",
                            current_path,
                            Posix.strerror (error_number)
                        );
                        return false;
                    }

                    // Verify that it's a directory (or a directory symlink).
                    // NOTE: We use `stat()` since we ALLOW the dir to be symlinked.
                    if (Posix.stat (current_path, out stat_) != 0) {
                        error_number = Posix.errno;
                        warning (
                            "Could not inspect directory '%s': %s",
                            current_path,
                            Posix.strerror (error_number)
                        );
                        return false;
                    }
                    if (!Posix.S_ISDIR (stat_.st_mode)) {
                        warning ("Directory path component is not a directory: %s", current_path);
                        return false;
                    }
                }
            }

            return true;
        }

        public static async bool create_directory_async (string path) {
            SourceFunc callback = create_directory_async.callback;

            bool output = false;
            new Thread<void> ("create_directory", () => {
                output = create_directory (path);
                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return output;
        }

        public static uint64 get_directory_size (string path) {
            uint64 size = 0;

            FileEnumerator? enumerator = null;
            try {
                var directory = File.new_for_path (path);
                enumerator = directory.enumerate_children (
                    "standard::name",
                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                    null
                );

                FileInfo? file_info;
                while ((file_info = enumerator.next_file (null)) != null) {
                    var cur_path = Path.build_filename (path, file_info.get_name ());
                    Posix.Stat stat_;

                    // NOTE: `lstat()` is very important to avoid following symlinks,
                    // to get an accurate count of bytes within real files (not links).
                    if (Posix.lstat (cur_path, out stat_) != 0) {
                        continue;
                    }

                    if (Posix.S_ISDIR (stat_.st_mode)) {
                        size += get_directory_size (cur_path);
                    } else {
                        size += stat_.st_size;
                    }
                }
            } catch (Error e) {
                warning (e.message);
            } finally {
                if (enumerator != null) {
                    try {
                        enumerator.close (null);
                    } catch (Error e) {
                        warning (e.message);
                    }
                }
            }

            return size;
        }
    }
}
