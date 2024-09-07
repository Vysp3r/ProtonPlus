namespace ProtonPlus.Utils {
    public class Filesystem {
        public const Posix.mode_t S_IRWXUGO = (Posix.S_IRWXU | Posix.S_IRWXG | Posix.S_IRWXO);

        // Miscellaneous.

        public delegate bool cancel_callback ();

        public async static string extract (string install_location, string tool_name, string extension, cancel_callback cancel_callback) {
            SourceFunc callback = extract.callback;

            string output = "";
            new Thread<void> ("extract", () => {
                const int bufferSize = 192000;

                var archive = new Archive.Read ();
                archive.support_format_all ();
                archive.support_filter_all ();

                int flags;
                flags = Archive.ExtractFlags.ACL;
                flags |= Archive.ExtractFlags.PERM;
                flags |= Archive.ExtractFlags.TIME;
                flags |= Archive.ExtractFlags.FFLAGS;

                var ext = new Archive.WriteDisk ();
                ext.set_standard_lookup ();
                ext.set_options (flags);

                if (archive.open_filename (install_location + tool_name + extension, bufferSize) != Archive.Result.OK)return;

                ssize_t r;

                unowned Archive.Entry entry;

                string sourcePath = "";
                bool firstRun = true;

                for ( ;; ) {
                    if (cancel_callback ())break;
                    r = archive.next_header (out entry);
                    if (r == Archive.Result.EOF)break;
                    if (r < Archive.Result.OK)stderr.printf (ext.error_string ());
                    if (r < Archive.Result.WARN)return;
                    if (firstRun) {
                        sourcePath = entry.pathname ();
                        firstRun = false;
                    }
                    entry.set_pathname (install_location + entry.pathname ());
                    r = ext.write_header (entry);
                    if (r < Archive.Result.OK)stderr.printf (ext.error_string ());
                    else if (entry.size () > 0) {
                        r = copy_data (archive, ext);
                        if (r < Archive.Result.WARN)return;
                    }
                    r = ext.finish_entry ();
                    if (r < Archive.Result.OK)stderr.printf (ext.error_string ());
                    if (r < Archive.Result.WARN)return;
                }

                archive.close ();

                output = install_location + sourcePath;

                if (cancel_callback ()) {
                    delete_directory.begin (output, (obj, res) => {
                        delete_directory.end (res);
                    });
                }

                delete_file (install_location + "/" + tool_name + extension);

                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return output;
        }

        static ssize_t copy_data (Archive.Read ar, Archive.WriteDisk aw) {
            ssize_t r;
            uint8[] buffer;
            Archive.int64_t offset;

            for ( ;; ) {
                r = ar.read_data_block (out buffer, out offset);
                if (r == Archive.Result.EOF)return (Archive.Result.OK);
                if (r < Archive.Result.OK)return (r);
                r = aw.write_data_block (buffer, offset);
                if (r < Archive.Result.OK) {
                    stderr.printf (aw.error_string ());
                    return (r);
                }
            }
        }

        public static string covert_bytes_to_string (int64 size) {
            if (size >= 1073741824) {
                return "%.2f GB".printf ((double) size / (1024 * 1024 * 1024));
            } else if (size > 1048576) {
                return "%.2f MB".printf ((double) size / (1024 * 1024));
            } else {
                return "%lld B".printf (size);
            }
        }

        public static async bool rename (string source_path, string destination_path) {
            SourceFunc callback = rename.callback;

            bool output = false;
            new Thread<void> ("rename", () => {
                output = FileUtils.rename (source_path, destination_path) == 0;
                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return output;
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

        public static string get_file_content (string path) {
            string output = "";

            try {
                File file = File.new_for_path (path);

                uint8[] contents;
                string etag_out;
                file.load_contents (null, out contents, out etag_out);

                output = (string) contents;
            } catch (Error e) {
                message (e.message);
            }

            return output;
        }

        public static void modify_file (string path, string content) {
            delete_file (path);
            create_file (path, content);
        }

        public static void create_file (string path, string? content = null) {
            try {
                var file = File.new_for_path (path);
                FileOutputStream os = file.create (FileCreateFlags.PRIVATE);
                if (content != null)os.write (content.data);
            } catch (Error e) {
                message (e.message);
            }
        }

        static bool delete_file_direct (string path) {
            if (Posix.unlink (path) != 0)
                return false;
            return true;
        }

        public static bool delete_file (string path) {
            return delete_file_direct (path);
        }

        // Directories.

        public static async bool move_dir_contents (string source_dir, string target_dir) {
            SourceFunc callback = move_dir_contents.callback;

            bool output = false;
            new Thread<void> ("move_dir_contents", () => {
                try {
                    Dir dir = Dir.open (source_dir);
                    string? name = null;
                    while ((name = dir.read_name ()) != null) {
                        // NOTE: Includes hidden files (".foo") but not "." and "..".
                        string source_path = Path.build_filename (source_dir, name);
                        string target_path = Path.build_filename (target_dir, name);

                        // message (@"[Move] \"$source_path\"\n    -> \"$target_path\"\n");

                        // Never overwrite existing target (avoids accidental data loss).
                        if (FileUtils.test (target_path, FileTest.EXISTS))
                            return;

                        // Move the "file" regardless of type (such as dir, symlink, etc).
                        if (FileUtils.rename (source_path, target_path) != 0)
                            return;
                    }
                    output = true;
                } catch (Error e) {
                    message (e.message);
                }
                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return output;
        }

        static bool delete_directory_direct (string path) {
            var dir = Posix.opendir (path);
            if (dir == null) {
                return false;
            }

            unowned Posix.DirEnt? cur_d;
            Posix.Stat stat_;
            while ((cur_d = Posix.readdir (dir)) != null) {
                var d_name = (string) cur_d.d_name;
                if (d_name == "." || d_name == "..") {
                    continue;
                }

                var cur_path = @"$path/$d_name";

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

            return true;
        }

        public static async bool delete_directory (string path) {
            SourceFunc callback = delete_directory.callback;

            bool output = false;
            new Thread<void> ("delete_directory", () => {
                if (delete_directory_direct (path)) {
                    if (Posix.rmdir (path) == 0) {
                        output = true;
                    }
                }
                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return output;
        }

        public static async bool create_directory (string path) {
            SourceFunc callback = create_directory.callback;

            bool output = false;
            new Thread<void> ("create_directory", () => {
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
                        // Check failures for any reasons other than "it exists".
                        if (Posix.errno != Posix.EEXIST)
                            return;

                        // Verify that it's a directory (or a directory symlink).
                        // NOTE: We use `stat()` since we ALLOW the dir to be symlinked.
                        if (Posix.stat (current_path, out stat_) != 0)
                            return;
                        if (!Posix.S_ISDIR (stat_.st_mode))
                            return;
                    }

                    output = true;
                }
                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return output;
        }

        public static uint64 get_directory_size (string path) {
            uint64 size = 0;

            var dir = Posix.opendir (path);
            if (dir == null) {
                return 0;
            }

            unowned Posix.DirEnt? cur_d;
            Posix.Stat stat_;
            while ((cur_d = Posix.readdir (dir)) != null) {
                var d_name = (string) cur_d.d_name;
                if (d_name == "." || d_name == "..") {
                    continue;
                }

                var cur_path = @"$path/$d_name";

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

            return size;
        }
    }
}