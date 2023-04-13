namespace Utils {
    public class Filesystem {
        // Other

        public static string Extract (string install_location, string tool_name, string extension, ref bool cancelled) {
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

            if (archive.open_filename (install_location + tool_name + extension, bufferSize) != Archive.Result.OK) return "";

            ssize_t r;

            unowned Archive.Entry entry;

            string sourcePath = "";
            bool firstRun = true;

            for ( ;; ) {
                r = archive.next_header (out entry);
                if (r == Archive.Result.EOF) break;
                if (r < Archive.Result.OK) stderr.printf (ext.error_string ());
                if (r < Archive.Result.WARN) return "";
                if (firstRun) {
                    sourcePath = entry.pathname ();
                    firstRun = false;
                }
                entry.set_pathname (install_location + entry.pathname ());
                r = ext.write_header (entry);
                if (r < Archive.Result.OK) stderr.printf (ext.error_string ());
                else if (entry.size () > 0) {
                    r = copy_data (archive, ext);
                    if (r < Archive.Result.WARN) return "";
                }
                r = ext.finish_entry ();
                if (r < Archive.Result.OK) stderr.printf (ext.error_string ());
                if (r < Archive.Result.WARN) return "";
            }

            archive.close ();

            DeleteFile (install_location + "/" + tool_name + extension);

            return install_location + sourcePath;
        }

        static ssize_t copy_data (Archive.Read ar, Archive.WriteDisk aw) {
            ssize_t r;
            uint8[] buffer;
            Archive.int64_t offset;

            for ( ;; ) {
                r = ar.read_data_block (out buffer, out offset);
                if (r == Archive.Result.EOF) return (Archive.Result.OK);
                if (r < Archive.Result.OK) return (r);
                r = aw.write_data_block (buffer, offset);
                if (r < Archive.Result.OK) {
                    stderr.printf (aw.error_string ());
                    return (r);
                }
            }
        }

        public static string ConvertBytesToString (int64 size) {
            if (size >= 1073741824) {
                return "%.2f GB".printf ((double) size / (1024 * 1024 * 1024));
            } else if (size > 1048576) {
                return "%.2f MB".printf ((double) size / (1024 * 1024));
            } else {
                return "%lld B".printf (size);
            }
        }

        public static void Rename (string sourcePath, string destinationPath) {
            GLib.FileUtils.rename (sourcePath, destinationPath);
        }

        // File

        public static string GetFileContent (string path) {
            string output = "";

            try {
                GLib.File file = GLib.File.new_for_path (path);

                uint8[] contents;
                string etag_out;
                file.load_contents (null, out contents, out etag_out);

                output = (string) contents;
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
            }

            return output;
        }

        public static void ModifyFile (string path, string content) {
            DeleteFile (path);
            CreateFile (path, content);
        }

        public static void CreateFile (string path, string? content = null) {
            try {
                var file = GLib.File.new_for_path (path);
                FileOutputStream os = file.create (FileCreateFlags.PRIVATE);
                if (content != null) os.write (content.data);
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        static bool DeleteFileDirect (string path) {
            if (Posix.unlink (path) != 0)
                return false;
            return true;
        }

        public static bool DeleteFile (string path) {
            return DeleteFileDirect (path);
        }

        // Directory

        static bool DeleteDirectoryDirect (string path) {
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

                Posix.stat (path + "/" + (string) cur_d.d_name, out stat_);

                if (Posix.S_ISDIR (stat_.st_mode)) {
                    if (DeleteDirectoryDirect (path + "/" + (string) cur_d.d_name) != true)
                        return false;
                    if (Posix.rmdir (path + "/" + (string) cur_d.d_name) != 0)
                        return false;
                } else {
                    if (DeleteFileDirect (path + "/" + (string) cur_d.d_name) != true)
                        return false;
                }
            }

            return true;
        }

        public static bool DeleteDirectory (string path) {
            if (DeleteDirectoryDirect (path) == true) {
                if (Posix.rmdir (path) == 0) {
                    return true;
                }
            }
            return false;
        }

        public static void CreateDirectory (string path) {
            Posix.mkdir (path, Posix.S_IRWXU);
        }

        public static uint64 GetDirectorySize (string path) {
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

                Posix.stat (path + "/" + (string) cur_d.d_name, out stat_);

                if (Posix.S_ISDIR (stat_.st_mode)) {
                    size += GetDirectorySize (path + "/" + (string) cur_d.d_name);
                } else {
                    size += stat_.st_size;
                }
            }

            return size;
        }
    }
}
