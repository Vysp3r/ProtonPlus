namespace ProtonPlus.Utils {
    public class Filesystem {
        // Other

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

        public static void rename (string sourcePath, string destinationPath) {
            FileUtils.rename (sourcePath, destinationPath);
        }

        // File

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

        // Directory

        static bool delete_directory_direct (string path) {
            var dir = Posix.opendir (path);
            if (dir == null) {
                return false;
            }

            unowned Posix.DirEnt? cur_d;
            Posix.Stat stat_;
            while ((cur_d = Posix.readdir (dir)) != null) {
                if (cur_d.d_name[0] == '.' && ((cur_d.d_name[1] == '.' && cur_d.d_name[2] == '\0') || cur_d.d_name[1] == '\0')) {
                    continue;
                }

                Posix.lstat (path + "/" + (string) cur_d.d_name, out stat_);

                if (Posix.S_ISDIR (stat_.st_mode)) {
                    if (delete_directory_direct (path + "/" + (string) cur_d.d_name) != true)
                        return false;
                    if (Posix.rmdir (path + "/" + (string) cur_d.d_name) != 0)
                        return false;
                } else {
                    if (delete_file_direct (path + "/" + (string) cur_d.d_name) != true)
                        return false;
                }
            }

            return true;
        }

        public async static bool delete_directory (string path) {
            SourceFunc callback = delete_directory.callback;

            bool output = false;
            new Thread<void> ("delete_directory", () => {
                if (delete_directory_direct (path) == true) {
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
                // https://pubs.opengroup.org/onlinepubs/9799919799/functions/mkdir.html
                if (Posix.mkdir (current_path, Posix.S_IRWXU) != 0) {
                    // Check failures for any reasons other than "it exists".
                    if (Posix.errno != Posix.EEXIST)
                        return false;

                    // Verify that it's a directory (or a directory symlink).
                    // NOTE: We use `stat()` since we ALLOW the dir to be symlinked.
                    if (Posix.stat (current_path, out stat_) != 0)
                        return false;
                    if (!Posix.S_ISDIR (stat_.st_mode))
                        return false;
                }
            }

            // Target path exists and is a directory (or dir symlink).
            return true;
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
                if (cur_d.d_name[0] == '.') {
                    continue;
                }

                Posix.lstat (path + "/" + (string) cur_d.d_name, out stat_);

                if (Posix.S_ISDIR (stat_.st_mode)) {
                    size += get_directory_size (path + "/" + (string) cur_d.d_name);
                } else {
                    size += stat_.st_size;
                }
            }

            return size;
        }
    }
}